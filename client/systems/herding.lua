-- HERDING CORE - Core Herding Logic
-- Parte de Advanced Herding System

local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()


-- Tabla local para estados de herding
local herdingStates = {}


function SetupPetHerding(companionid, entity, opts)
    herdingStates[companionid] = {
        entity = entity,
        active = true,
        formation = opts and opts.formation or nil,
        stateChangeTime = GetGameTimer(),
    }
end

function StopPetHerding(companionid)
    local state = herdingStates[companionid]
    if state and DoesEntityExist(state.entity) then
        ClearPedTasks(state.entity)
    end
    herdingStates[companionid] = nil
end

function PausePetHerding(companionid)
    local state = herdingStates[companionid]
    if state then
        state.active = false
    end
end

function ResumePetHerding(companionid)
    local state = herdingStates[companionid]
    if state then
        state.active = true
    end
end


exports('SetupPetHerding', SetupPetHerding)
exports('StopPetHerding', StopPetHerding)
exports('PausePetHerding', PausePetHerding)
exports('ResumePetHerding', ResumePetHerding)
exports('GetPetHerdingState', function(id) return herdingStates[tostring(id)] end)
exports('GetAllHerdingPets', function()
    local pets = {}
    for id, state in pairs(herdingStates) do
        if state.active then table.insert(pets, id) end
    end
    return pets
end)

-- Helper global: ¿hay alguna mascota en herding?
function IsAnyHerdingActive()
    for _, state in pairs(herdingStates) do
        if state.active then return true end
    end
    return false
end
exports('IsAnyHerdingActive', IsAnyHerdingActive)

-- Hilo principal de movimiento y formaciones
local herdingThread = nil
function StartHerdingThread()
    if herdingThread then return end
    herdingThread = CreateThread(function()
        local lastPlayerCoords = vector3(0, 0, 0)
        local minMovementThreshold = 2.0
        while true do
            Wait(2000)
            local anyActive = false
            local petsArray = {}
            for companionid, state in pairs(herdingStates) do
                if state.active and DoesEntityExist(state.entity) then
                    table.insert(petsArray, {companionid=companionid, entity=state.entity})
                    anyActive = true
                end
            end
            if not anyActive then break end
            local petCount = #petsArray
            -- Importa GenerateDynamicFormation desde herding_system.lua
            local formationOffsets = exports['hdrp-pets']:GenerateDynamicFormation(petCount, petsArray)
            local playerCoords = GetEntityCoords(cache.ped)
            local playerMovement = #(playerCoords - lastPlayerCoords)
            if playerMovement > minMovementThreshold then
                lastPlayerCoords = playerCoords
                for i, petData in ipairs(petsArray) do
                    if i <= #formationOffsets then
                        local offset = formationOffsets[i]
                        local followDist = Config.Herding.FollowDistance or 3.0
                        local followSpeed = Config.Herding.Speed or 1.5
                        if DoesEntityExist(petData.entity) and not IsPedDeadOrDying(petData.entity, 0) then
                            TaskFollowToOffsetOfEntity(
                                petData.entity,
                                cache.ped,
                                offset.x, offset.y, 0.0,
                                followSpeed,
                                -1,
                                followDist,
                                0
                            )
                        end
                    end
                end
            end
        end
        herdingThread = nil
    end)
end
exports('StartHerdingThread', StartHerdingThread)

function StopAllHerding()
    for companionid in pairs(herdingStates) do
        StopPetHerding(companionid)
    end
end
exports('StopAllHerding', StopAllHerding)


-- El hilo y lógica de movimiento se migran a helpers que usen herdingStates

---------------------------------
-- COMMAND REGISTRATION
---------------------------------
RegisterCommand('pet_herd', function(source, args, rawCommand)
    if not Config.Herding or not Config.Herding.Enabled then
        lib.notify({ 
            title = locale('cl_herding_disabled'), 
            type = 'error',
            duration = 5000 
        })
        return
    end

    local hasTool = false
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local missingToolsLabels = ""

    if Config.Herding.RequireTool and type(Config.Herding.ToolItem) == "table" then
        for _, toolName in pairs(Config.Herding.ToolItem) do
            for _, item in pairs(PlayerData.items) do
                if item.name == toolName then
                    hasTool = true
                    break
                end
            end
            if hasTool then 
                break 
            else
                local label = RSGCore.Shared.Items[toolName].label or toolName
                missingToolsLabels = missingToolsLabels .. label .. " / "
            end
        end
    end

    if not hasTool then
        missingToolsLabels = string.sub(missingToolsLabels, 1, -4) 

        lib.notify({ 
            title = locale('cl_error_missing_tool'), 
            description = locale('cl_error_need_tool') .. " " .. missingToolsLabels,
            type = 'error',
            duration = 5000 
        })
        return
    end

    OpenHerdingMainMenu()

end, false)

---------------------------------
-- UTILITY FUNCTIONS
---------------------------------
function GetNearbyCompanions()
    local playerPos = GetEntityCoords(cache.ped)
    local nearbyPets = {}
    local activePetsList = State.GetAllPets()
    
    if not activePetsList then return nearbyPets end
    
    for companionid, petData in pairs(activePetsList) do
        if petData and petData.spawned and DoesEntityExist(petData.ped) then
            local petPos = GetEntityCoords(petData.ped)
            local distance = #(playerPos - petPos)
            -- Corregir: obtener nombre personalizado si existe
            local petName = (petData.data and petData.data.info and petData.data.info.name) or petData.name or 'Pet'
            if distance <= Config.Herding.Distance then
                table.insert(nearbyPets, {
                    companionid = companionid,
                    ped = petData.ped,
                    model = petData.model,
                    name = petName,
                    position = petPos,
                    distance = distance
                })
                if Config.Debug then
                    print("^2[HERDING]^7 " .. string.format(locale('debug_herding_found_pet_fmt'), companionid, distance))
                end
            end
        end
    end
    
    if Config.Debug then
        print("^3[HERDING]^7 " .. string.format(locale('debug_herding_nearby_count_fmt'), #nearbyPets))
    end
    
    return nearbyPets
end

function GetPetDisplayName(model)
    -- Try to get display name from config
    if Config.PetModels and Config.PetModels[model] then
        return Config.PetModels[model].label or model
    end
    
    -- Fallback to model name
    return model:gsub("a_c_", ""):gsub("_", " "):gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

---Inicializar sistema de herding

exports('GetHerdingStates', function()
    herdingStates = herdingStates or {}
    if Config.Debug then
        print("^2[HDRP-PETS]^7 " .. locale('debug_herding_system_initialized'))
    end
end)

---------------------------------
-- CLEANUP
---------------------------------
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if herdingStates.active then
        StopHerding()
    end
    herdingStates.selectedPets = {}
end)

AddEventHandler('playerDropped', function()
    if herdingStates.active then
        StopHerding()
    end
    herdingStates.selectedPets = {}
end)

if Config.Debug then
    print("^2[HDRP-PETS]^7 " .. locale('debug_herding_system_loaded'))
end
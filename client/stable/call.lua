local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
local ManageSpawn = require('client.stable.utils_spawn')

--- Función base de spawn que encapsula toda la lógica común
--- @param companionid string ID del companion
--- @param companionData table Datos del companion (decodificado de JSON)
--- @param components table Componentes de customización del ped
--- @param xp number XP de la mascota
--- @param spawnCoords vector3 Coordenadas de spawn
--- @param spawnHeading number Dirección de spawn
--- @param options table Opciones adicionales: {petName = string, isMultiPet = boolean}
--- @return number|nil newPed Entity handle del ped creado (nil si falla)
--- @return number|nil blip Blip handle del blip creado (nil si falla)
function SpawnPetBase(companionid, companionData, components, xp, spawnCoords, spawnHeading, options)
    options = options or {}

    local x, y, z = table.unpack(spawnCoords)
    local _, nodePosition = GetClosestVehicleNode(x - 15, y, z, 0, 3.0, 0.0)
    local distance = math.floor(#(nodePosition - spawnCoords))

    local onRoad = false
    if distance < 50 then onRoad = true end
    if Config.PetAttributes.SpawnOnRoadOnly and not onRoad then lib.notify({ title = locale('cl_error_near_road'), type = 'error', duration = 7000 }) return end

    -- 1. VALIDAR MODELO
    local companionModel = (companionData.info and companionData.info.model)
    if not companionModel then
        return nil, nil
    end
    
    -- 2. CARGAR MODELO
    local modelHash = type(companionModel) == 'number' and companionModel or joaat(companionModel)
    if not lib.requestModel(modelHash, 5000) then
        return nil, nil
    end
    
    -- 3. CREAR PED
    local newPed = nil
    
    -- 4. APLICAR SPAWN EN CARRETERA
    if onRoad then
        newPed = CreatePed(modelHash, nodePosition, spawnHeading, false, false, false, false)
        SetEntityCanBeDamaged(newPed, false)
        Citizen.InvokeNative(0x9587913B9E772D29, newPed, false)
        onRoad = false
    else
        newPed = CreatePed(modelHash, spawnCoords.x - 10, spawnCoords.y, spawnCoords.z, spawnHeading, false, false, false, false)
        SetEntityCanBeDamaged(newPed, false)
        Citizen.InvokeNative(0x9587913B9E772D29, newPed, false)
        ManageSpawn.PlacePedOnGroundProperly(newPed)
    end

    if not DoesEntityExist(newPed) then
        SetModelAsNoLongerNeeded(modelHash)
        return nil, nil
    end
    
    -- 5. CONFIGURAR PED
    SetModelAsNoLongerNeeded(modelHash)
    SetEntityAsNoLongerNeeded(newPed)
    SetEntityAsMissionEntity(newPed, true)
    SetEntityCanBeDamaged(newPed, true)
    local petName = (companionData.info and companionData.info.name) or 'Unknown'
    SetPedNameDebug(newPed, petName)
    SetPedPromptName(newPed, petName)

    Citizen.InvokeNative(0x283978A15512B2FE, newPed, true) -- SetRandomOutfitVariation
                
    -- 6. APLICAR FLAGS
    ManageSpawn.SetCompanionFlags(newPed) -- utils_spawn.lua 
    
    -- 7. APLICAR SKIN PRESET
    local skin = tonumber(companionData.info and companionData.info.skin)
    if skin then
        Citizen.InvokeNative(0x77FF8D35EEC6BBC4, newPed, skin, 0) -- SET_PED_OUTFIT_PRESET
    end
    
    -- 8. APLICAR CUSTOMIZACIÓN Y PROPS DESDE EL JSON ESTRUCTURADO
    ManageSpawn.GetCustomize(newPed, components)

    -- 10. ACTUALIZAR VARIACIÓN DE PED
    ManageSpawn.UpdatePedVariation(newPed)  -- utils.lua 

    -- 12. APLICAR XP Y BONDING
    xp = xp or 0
    ManageSpawn.ApplyBonding(newPed, xp) -- utils_spawn.lua 

    -- 14. CREAR BLIP
    local blip = Citizen.InvokeNative(0x23f74c2fda6e7c61, -1749618580, newPed)
    if Config.Blip.Pet then
        Citizen.InvokeNative(0x662D364ABF16DE2F, blip, Config.Blip.ColorModifier)
        SetBlipSprite(blip, Config.Blip.Pet.blipSprite)
        SetBlipScale(blip, Config.Blip.Pet.blipScale)
        Citizen.InvokeNative(0x45FF974EEA1DCE36, blip, true)
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, (companionData.info and companionData.info.name))
    end

    -- 15. OTRAS NATIVAS DE CONFIGURACIÓN
    Citizen.InvokeNative(0x283978A15512B2FE, newPed, true)                    -- SetRandomOutfitVariation        
    Citizen.InvokeNative(0xFE26E4609B1C3772, newPed, "HorseCompanion", true) -- DecorSetBool
    Citizen.InvokeNative(0xA691C10054275290, cache.ped, newPed, 0) -- unknown
    Citizen.InvokeNative(0x931B241409216C1F, cache.ped, newPed, true)               -- SetPedOwnsAnimal
    Citizen.InvokeNative(0xED1C764997A86D5A, cache.ped, newPed) -- unknown
    
    -- 16. APLICAR PERSONALIDAD
    ManageSpawn.ApplyPersonality(newPed, xp) -- utils_spawn.lua 
    
    -- 17. ESTABLECER ESCALA (CRECIMIENTO)
    local petAge = (companionData.stats and companionData.stats.age) or 0
    local scale = ManageSpawn.CalculateScaleFromAge(petAge)  -- utils_spawn.lua 
    if Config.PetAttributes.RaiseAnimal then
        SetPedScale(newPed, scale)
    end
    
    -- 18. WAIT PARA INICIALIZACIÓN
    Wait(100)
    
    -- 19. ACTUALIZAR ESTADÍSTICAS (FIX v5.8.51+ / v6.0.0)
    ManageSpawn.UpdatePetStats(newPed, xp, (companionData.stats and companionData.stats.dirt)) -- utils_spawn.lua 
    
    -- 20. CONFIGURAR PROMPTS

    if Config.EnablePrompts then
        SetupPromptsForPet(companionid, newPed, xp) -- systems/prompts.lua
    end
    
    -- 21. CONFIGURAR OX_TARGET
    if Config.EnableTarget then
        local petDisplayName = petName
        local menuPrefix = options.isMultiPet and '_multi' or ''

        exports.ox_target:addLocalEntity(newPed, {
            {
                name = 'pet_menu' .. menuPrefix,
                icon = 'fas fa-paw',
                label = options.isMultiPet 
                    and (petDisplayName .. ' - ' .. locale('cl_target_menu_label'))
                    or locale('cl_target_pet_menu_label'),
                onSelect = function(data)
                    ShowPetDashboard(companionid)
                end,
                distance = 5.0
            }
        })
    end

    -- 22. VERIFICAR SI ESTÁ MUERTA (INVINCIBILIDAD)
    if (companionData.veterinary and companionData.veterinary.dead) == true and Config.PetAttributes.Invincible == false then
        Wait(500)
        SetEntityHealth(newPed, 0)
        lib.notify({title = locale('cl_error_pet_dead'), type = 'error', duration = 5000})
    end

    if Config.Debug then print(string.format('^2[SPAWN BASE]^7 ' .. locale('cl_info_spawn_base_scale_fmt'), petName, scale, petAge)) end
    if Config.Debug then print(string.format('^2[SPAWN BASE]^7 ' .. locale('cl_info_spawn_base_spawned_success_fmt'), petName, newPed)) end
    
    return newPed, blip
end

-- Spawn Multi-Pet (for multi-pet system)
local function SpawnMultiPet(dbPetData, delay)
    if delay then Wait(delay) end
    if not dbPetData then
        return false
    end
    local companionid = dbPetData.companionid
    local companionData = type(dbPetData.data) == 'string' and json.decode(dbPetData.data) or dbPetData.data or {}
    local companionModel = companionData.info and companionData.info.model
    -- Comprobar si ya existe una mascota activa y válida
    local petData = State.GetPet(companionid)
    if petData and petData.spawned and DoesEntityExist(petData.ped) then
        -- Ya existe, solo moverla
        ManageSpawn.moveCompanionToPlayer(petData.ped, cache.ped)
        return true
    end

    if not companionModel then
        return false
    end

    -- Calcular spawn cerca del jugador con offset aleatorio
    local playerCoords = GetEntityCoords(cache.ped)
    local playerHeading = GetEntityHeading(cache.ped)
    local offsetX = math.random(-3, 3)
    local offsetY = math.random(-3, 3)
    local spawnCoords = vector3(playerCoords.x + offsetX, playerCoords.y + offsetY, playerCoords.z)
    -- Preparar componentes y XP
    local components = json.decode(dbPetData.components) or {}
    if not (components.custom or components.props) then
        components = { custom = components, props = {} }
    end
    local xp = (companionData.progression and companionData.progression.xp) or 0
    -- USAR FUNCIÓN BASE DE SPAWN
    local newPed, blip = SpawnPetBase(
        companionid,
        companionData,
        components,
        xp,
        spawnCoords,
        playerHeading,
        {
            petName = (companionData.info and companionData.info.name) or 'Unknown',
            isMultiPet = true
        }
    )

    if not newPed then
        return false
    end
    State.RegisterPet(companionid, newPed, blip, companionData)

    if Config.Debug then print(string.format('^2[SPAWN MULTI]^7 ' .. locale('cl_info_spawn_multi_success_fmt'), tostring(companionid), tostring((companionData.info and companionData.info.name) or 'Unknown'))) end
    return true
end

-- Helper function: Call all active pets
local function CallAllActivePets()
    -- Get active pets from database (those marked as active=1)
    RSGCore.Functions.TriggerCallback('hdrp-pets:server:getactivecompanions', function(activePetsData)
        if not activePetsData or #activePetsData == 0 then
            lib.notify({ 
                title = locale('cl_no_active_pets'), 
                type = 'error', 
                duration = 5000 
            })
            return
        end
        local playerCoords = GetEntityCoords(cache.ped)
        local petsToCome = 0
        local petsNeedingSpawn = 0
        local maxCallDistance = Config.MaxCallDistance or 100.0
        -- Process each active pet from database
        for i, dbPetData in ipairs(activePetsData) do
            local companionid = dbPetData.companionid
            local petData = State.GetPet(companionid)
            if petData and petData.spawned and DoesEntityExist(petData.ped) then
                -- Pet is spawned, check distance
                local petCoords = GetEntityCoords(petData.ped)
                local distance = #(playerCoords - petCoords)
                -- Siempre mover la mascota al jugador si está spawneada
                ManageSpawn.moveCompanionToPlayer(petData.ped, cache.ped)
                petsToCome = petsToCome + 1
            else
                -- Pet not spawned - needs to be spawned
                petsNeedingSpawn = petsNeedingSpawn + 1
                local spawnDelay = (i - 1) * 1000  -- 1000ms between each pet
                SpawnMultiPet(dbPetData, spawnDelay)
            end
        end
        -- Single summary notification
        local totalCalled = petsNeedingSpawn + petsToCome
        lib.notify({ 
            title = locale('cl_all_pets_called'), 
            description = locale('cl_pets_responding', petsToCome, totalCalled),
            type = 'info', 
            duration = 5000 
        })
    end)
end

-- HILO DE SEGUIMIENTO REALISTA PARA MULTI-MASCOTA
local followTimers = {}
local FOLLOW_TIME = 10000 -- ms que la mascota sigue tras ser llamada (ajustable)
local function loopCall()
    local playerCoords = GetEntityCoords(cache.ped)
    for companionid, petData in pairs(State.GetAllPets()) do

        local isFollow = (petData and petData.flag and petData.flag.isFollowing) or false
        local isHerding = (petData and petData.flag and petData.flag.isHerding) or false
        local isWandering = (petData and petData.flag and petData.flag.isWandering) or false
        local isHunting = (petData and petData.flag and petData.flag.isHunting) or false
        local isCall = (petData and petData.flag and petData.flag.isCall) or false

        if petData and petData.spawned and isCall and DoesEntityExist(petData.ped) then
            local xp = petData.xp or 0
            local requiredXP = (Config.XP and Config.XP.Trick and Config.XP.Trick.Follow) or 75
            local age = (petData.data and petData.data.stats.age) or petData.stats.age or 0
            local minFollowAge = 3
            if xp >= requiredXP and age >= minFollowAge then
                local petCoords = GetEntityCoords(petData.ped)
                local distance = #(playerCoords - petCoords)
                -- Guardar el estado previo antes de cambiar a isFollowing (por mascota)
                if not petData.flag.prevMovement then
                    if isHunting then
                        petData.flag.prevMovement = 'isHunting'
                    elseif isHerding then
                        petData.flag.prevMovement = 'isHerding'
                    else
                        petData.flag.prevMovement = nil
                    end
                end

                if distance > Config.PetAttributes.FollowDistance then
                    -- Si está lejos, sigue al jugador
                    if petData.flag.prevMovement == 'isHunting' then
                        State.SetPetTrait(companionid, 'isHunting', false)
                    elseif petData.flag.prevMovement == 'isHerding' then
                        StopPetHerding(companionid)
                        State.SetPetTrait(companionid, 'isHerding', false)
                    else
                        StopPetWandering(companionid)
                        State.SetPetTrait(companionid, 'isWandering', false)
                    end
                    State.SetPetTrait(companionid, 'isFollowing', true)
                    ManageSpawn.moveCompanionToPlayer(petData.ped, cache.ped)
                    followTimers[companionid] = GetGameTimer() + FOLLOW_TIME
                else
                    -- Si ya está cerca, inicia el temporizador de seguimiento
                    if not isFollow then
                        if petData.flag.prevMovement == 'isHunting' then
                            State.SetPetTrait(companionid, 'isHunting', false)
                        elseif petData.flag.prevMovement == 'isHerding' then
                            StopPetHerding(companionid)
                            State.SetPetTrait(companionid, 'isHerding', false)
                        else
                            StopPetWandering(companionid)
                            State.SetPetTrait(companionid, 'isWandering', false)
                        end
                        State.SetPetTrait(companionid, 'isFollowing', true)
                        followTimers[companionid] = GetGameTimer() + FOLLOW_TIME
                    end
                end
            end
        end
        -- Si está siguiendo, verifica si debe dejar de seguir
        if isFollow then
            if followTimers[companionid] and GetGameTimer() > followTimers[companionid] then
                followTimers[companionid] = nil
                -- Restaurar el estado previo guardado (por mascota)
                State.SetPetTrait(companionid, 'isFollowing', false)
                Wait(500) -- Small wait before changing state
                if petData.flag.prevMovement == 'isHunting' then
                    State.SetPetTrait(companionid, 'isHunting', true)
                elseif petData.flag.prevMovement == 'isHerding' then
                    State.SetPetTrait(companionid, 'isHerding', true)
                    local herdingState = GetPetHerdingState(companionid)
                    if herdingState and not herdingState.active then
                        ResumePetHerding(companionid)
                    elseif not herdingState then
                        SetupPetHerding(companionid, petData.ped, {})
                    end
                    if Config.Debug then print('^2[FOLLOW]^7 Mascota '..tostring(companionid)..' retoma herding tras seguir al jugador') end
                else
                    State.SetPetTrait(companionid, 'isWandering', true)
                    SetupPetWandering(companionid, petData.ped, GetEntityCoords(petData.ped))
                    if Config.Debug then print('^2[FOLLOW]^7 Mascota '..tostring(companionid)..' deja de seguir y vuelve a su aire (wandering)') end
                end
                -- Limpiar el flag temporal
                if petData.flag then petData.flag.prevMovement = nil end
            end
        end
    end
end

-- HILO DE SEGUIMIENTO Y GESTIÓN DE FLAGS
CreateThread(function()
    while true do
        Wait(1000)
        loopCall()
    end
end)

-- KEY LISTENER - Companion Call key U
CreateThread(function()
    while true do
        Wait(1)
        if Citizen.InvokeNative(0x91AEF906BCA88877, 0, Config.Prompt.CompanionCall) then
            ExecuteCommand('pet_call')
            Wait(2000) -- Anti spam
        end
    end
end)

RegisterCommand("pet_call", function()
    RSGCore.Functions.GetPlayerData(function(PlayerData)
        if PlayerData.metadata["injail"] == 0 and not IsEntityDead(cache.ped) then
            TriggerServerEvent("InteractSound_SV:PlayWithinDistance", 10, 'CALLING_WHISTLE_01', 0.7)
            CallAllActivePets()
        end
    end)
    Wait(2000) -- Anti spam
end, false)

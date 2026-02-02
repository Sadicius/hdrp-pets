local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
local ManageSpawn = lib.load('client.stable.utils_spawn')

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
function SpawnAnimal(companionid, companionData, components, xp, spawnCoords, spawnHeading, options)
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
    
    -- 18.5. ACTUALIZAR ESTADÍSTICAS CON SALUD (FIX v5.8.51+ / v6.0.0)
    local currentHealth = companionData.stats and companionData.stats.health or Config.PetAttributes.Starting.Health or 300
    ManageSpawn.UpdatePetStats(newPed, xp, (companionData.stats and companionData.stats.dirt), currentHealth) -- utils_spawn.lua 
    
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

    -- 23. NOTIFY SERVER THAT PET WAS SPAWNED (FOR MULTIPLAYER SYNC)
    Wait(100)
    local spawnCoords = GetEntityCoords(newPed)
    TriggerServerEvent('hdrp-pets:server:petSpawned', companionid, companionData, spawnCoords)

    return newPed, blip
end

-- Spawn Multi-Pet (for multi-pet system)
local function MultiPet(dbPetData, delay)
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
    local newPed, blip = SpawnAnimal(
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
    -- Asegurar que companionData tiene la estructura requerida
    if not (companionData.data or companionData.progression) then
        companionData = { data = companionData, progression = companionData.progression or {} }
    end
    State.RegisterPet(companionid, newPed, blip, companionData)
    
    -- Actualizar niveles de bonding DESPUÉS de registrar
    State.GetBondingLevels(newPed, companionid)

    return true
end

-- Helper function: Call all active pets
local function CallAll()
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
        local petsToCome = 0
        local petsNeedingSpawn = 0
        -- Process each active pet from database
        for i, dbPetData in ipairs(activePetsData) do
            local companionid = dbPetData.companionid
            local petData = State.GetPet(companionid)
            if petData and petData.spawned and DoesEntityExist(petData.ped) then
                -- Pet is spawned, check distance
                if not State.IsPetNearPlayer(petData, Config.PetAttributes.FollowDistance or 10.0) then
                    ManageSpawn.moveCompanionToPlayer(petData.ped, cache.ped)
                end
                petsToCome = petsToCome + 1
            else
                -- Pet not spawned - needs to be spawned
                petsNeedingSpawn = petsNeedingSpawn + 1
                local spawnDelay = (i - 1) * 1000  -- 1000ms between each pet
                MultiPet(dbPetData, spawnDelay)
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

-- HILO DE SEGUIMIENTO Y GESTIÓN DE FLAGS
CreateThread(function()
    local followTimers = {}
    local FOLLOW_TIME = 10000
    while true do
        Wait(50)
        local anyActive = false
        for companionid, pet in pairs(State.GetAllPets()) do
            if not pet.spawned or not DoesEntityExist(pet.ped) then goto continue end

            local isCall = State.GetFlag(pet, "isCall")
            local isFollow = State.GetFlag(pet, "isFollowing")
            local prevMode = pet.flag.prevMovement

            if isCall then
                anyActive = true
                local xp = pet.xp or 0
                local age = (pet.data and pet.data.stats and pet.data.stats.age) or 0
                if xp >= ((Config.XP and Config.XP.Trick and Config.XP.Trick.Follow) or 75) and age >= 3 then
                    if not prevMode then
                        if State.GetFlag(pet, "isHunting") then pet.flag.prevMovement = "isHunting"
                        elseif State.GetFlag(pet, "isHerding") then pet.flag.prevMovement = "isHerding"
                        else pet.flag.prevMovement = nil end
                    end
                    local dist = State.GetDistanceBetweenEntities(pet.ped, cache.ped)
                    if dist > Config.PetAttributes.FollowDistance then
                        State.SetMode(companionid, "isFollowing", true)
                        ManageSpawn.moveCompanionToPlayer(pet.ped, cache.ped)
                        followTimers[companionid] = GetGameTimer() + FOLLOW_TIME
                    elseif not isFollow then
                        State.SetMode(companionid, "isFollowing", true)
                        followTimers[companionid] = GetGameTimer() + FOLLOW_TIME
                    end
                end
            end
            -- Si está siguiendo, verifica si debe dejar de seguir
            if isFollow and followTimers[companionid] and GetGameTimer() > followTimers[companionid] then
                followTimers[companionid] = nil
                if prevMode then
                    State.SetMode(companionid, prevMode, true)
                else
                    State.SetMode(companionid, "isWandering", true)
                end
                if prevMode == "isHerding" then
                    local herdingState = exports['hdrp-pets']:GetPetHerdingState(companionid)
                    if herdingState and not herdingState.active then ResumePetHerding(companionid)
                    elseif not herdingState then SetupPetHerding(companionid, pet.ped, {}) end
                elseif prevMode == "isWandering" or not prevMode then
                    SetupPetWandering(companionid, pet.ped, GetEntityCoords(pet.ped))
                end
                pet.flag.prevMovement = nil
            end
            ::continue::
        end
        Wait(anyActive and 1000 or 2000)
    end
end)

-- KEY LISTENER - Companion Call key U
CreateThread(function()
    while true do
        Wait(1)
        -- Check if player is in a valid state to call pet
        -- Skip if: in jail, dead, in animation, dead ped, or in UI
        local playerData = RSGCore.Functions.GetPlayerData()
        if playerData and playerData.metadata and playerData.metadata["injail"] == 0 and not IsEntityDead(cache.ped) then
            -- Additional safety checks to prevent accidental triggers
            local isInAnimation = IsEntityPlayingAnim(cache.ped, GetAnimDict(cache.ped), GetAnimName(cache.ped), 3) or IsPedRagdoll(cache.ped)
            local isCanceling = GetLastInputMethod(2) -- Check if using UI
            
            -- Only trigger if NOT in animation and key is pressed
            if not isInAnimation and Citizen.InvokeNative(0x91AEF906BCA88877, 0, Config.Prompt.CompanionCall) then
                ExecuteCommand('pet_call')
                Wait(2000) -- Anti spam
            end
        end
        
        -- If in jail or dead, longer wait
        if not playerData or not playerData.metadata or playerData.metadata["injail"] ~= 0 or IsEntityDead(cache.ped) then
            Wait(1000)
        end
    end
end)


RegisterCommand("pet_call", function()
    RSGCore.Functions.GetPlayerData(function(PlayerData)
        if PlayerData.metadata["injail"] == 0 and not IsEntityDead(cache.ped) then
            TriggerServerEvent("InteractSound_SV:PlayWithinDistance", 10, 'CALLING_WHISTLE_01', 0.7)
            CallAll()
        end
    end)
    Wait(2000) -- Anti spam
end, false)

-- Limpieza al detener/reiniciar el recurso
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    -- Limpiar todas las mascotas, blips y prompts
    for companionid, pet in pairs(State.GetAllPets()) do
        if pet and pet.ped and DoesEntityExist(pet.ped) then
            DeleteEntity(pet.ped)
        end
        if pet and pet.blip and DoesBlipExist(pet.blip) then
            RemoveBlip(pet.blip)
        end
    end
end)

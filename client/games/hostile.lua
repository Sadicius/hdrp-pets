--[[ local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
local gameHostileConfig = Config.Games.Ghostile

-- Migrado: ahora se usa State.Games.hostiles y helpers de state_helpers.lua
local hostileGroupHash = GetHashKey("REL_HOSTILE_PACK")

CreateThread(function()
    -- Safe check: verify function exists and group doesn't exist before calling
    if DoesRelationshipGroupExist and DoesRelationshipGroupExist(hostileGroupHash) == 0 then
        AddRelationshipGroup("REL_HOSTILE_PACK")
    end

    SetRelationshipBetweenGroups(5, hostileGroupHash, GetHashKey("PLAYER"))
    SetRelationshipBetweenGroups(5, GetHashKey("PLAYER"), hostileGroupHash)

    SetRelationshipBetweenGroups(5, hostileGroupHash, GetHashKey("REL_COMPANION_GROUP"))
end)

-- GET RANDOM HOSTILE ANIMAL
local function GetRandomHostileModel()
    local totalWeight = 0
    for _, animal in ipairs(gameHostileConfig.Animals) do
        totalWeight = totalWeight + animal.chance
    end

    local randomNum = math.random(1, totalWeight)
    local currentWeight = 0

    for _, animal in ipairs(gameHostileConfig.Animals) do
        currentWeight = currentWeight + animal.chance
        if randomNum <= currentWeight then
            return animal
        end
    end
    return gameHostileConfig.Animals[1]
end

-- SET HOSTILE ATTRIBUTES
local function SetHostileAttributes(entity)
    if not DoesEntityExist(entity) then return end

    SetPedRelationshipGroupHash(entity, hostileGroupHash)
    SetPedCombatAttributes(entity, 46, true) -- FIGHT_TO_DEATH
    SetPedCombatAttributes(entity, 0, true)  -- CAN_USE_COVER
    SetPedCombatAttributes(entity, 5, true)  -- CAN_FIGHT_ARMED_PED
    SetPedCombatAttributes(entity, 1, false) -- Disable VEHICLE_ATTACK

    SetPedCombatMovement(entity, 2)  -- Aggressive movement
    SetPedCombatRange(entity, 2)     -- Maximum attack range

    SetPedSeeingRange(entity, 100.0)
    SetPedHearingRange(entity, 100.0)

    SetPedFleeAttributes(entity, 0, false)
    SetBlockingOfNonTemporaryEvents(entity, true)
    
    SetEntityVisible(entity, true)
    SetEntityAlpha(entity, 255, false)
    Citizen.InvokeNative(0x283978A15512B2FE, entity, true)
end

-- START HOSTILE ENCOUNTER
RegisterNetEvent('hdrp-pets:client:startHostileEncounter', function()
    local playerPed = cache.ped
    local playerCoords = GetEntityCoords(playerPed)
    
    -- Get ALL active pets for multi-pet support
    local activePets = {}
    for companionid, petData in pairs(State.GetAllPets()) do
        if petData and petData.spawned and DoesEntityExist(petData.ped) and not IsEntityDead(petData.ped) then
            table.insert(activePets, petData.ped)
        end
    end

    local animalData = GetRandomHostileModel()
    local model = joaat(animalData.model)

    local packSize = 1
    if animalData.isPack then
        packSize = math.random(animalData.min, animalData.max)
    end

    lib.requestModel(model)
    
    local titleMsg = animalData.isPack and locale('cl_hostile_pack_title') or locale('cl_hostile_title')
    local descMsg = animalData.isPack and locale('cl_hostile_pack_desc') .. " ("..packSize.."x " .. animalData.label ..")" or locale('cl_hostile_desc')
    
    lib.notify({ 
        title = titleMsg, 
        description = descMsg, 
        type = 'error',
        duration = 6000
    })

    -- SPAWN LOOP
    for i = 1, packSize do
        local angleOffset = (360 / packSize) * i
        local randomVar = math.random(-20, 20)
        local finalAngle = math.rad(angleOffset + randomVar)
        local spawnDist = gameHostileConfig.SpawnDistance + math.random(-2.0, 5.0)
        local spawnX = playerCoords.x + (math.cos(finalAngle) * spawnDist)
        local spawnY = playerCoords.y + (math.sin(finalAngle) * spawnDist)
        local foundGround, spawnZ = GetGroundZFor_3dCoord(spawnX, spawnY, playerCoords.z + 50.0, false)
        if not foundGround then spawnZ = playerCoords.z end
        local hostilePed = CreatePed(model, spawnX, spawnY, spawnZ, 0.0, true, true)
        SetEntityHealth(hostilePed, animalData.health)
        SetEntityMaxHealth(hostilePed, animalData.health)
        SetHostileAttributes(hostilePed)
        TaskTurnPedToFaceEntity(hostilePed, playerPed, 1000)
        local blip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, -1749618580, hostilePed)
        SetBlipSprite(blip, -1379369448)
        SetBlipScale(blip, 0.2)
        Wait(100)
    end

    SetModelAsNoLongerNeeded(model)
    Wait(500)

    for _, hData in pairs(State.Games.hostiles or {}) do
        if DoesEntityExist(hData.ped) then
            TaskCombatPed(hData.ped, playerPed, 0, 16)
            -- PlayPedAmbientSpeechNative(hData.ped, "AGITATED", "SPEECH_PARAMS_FORCE_SHOUTED")
        end
    end

    -- Multi-pet defense: All active pets help defend the player
    if #activePets > 0 then
        Wait(500)
        local petCountMsg = #activePets == 1 and locale('cl_pet_protect') or string.format("%d pets protecting you!", #activePets)
        lib.notify({ title = petCountMsg, type = 'info' })
        for petIndex, petPed in ipairs(activePets) do
            local hostiles = State.Games.hostiles or {}
            if #hostiles > 0 then
                local targetIndex = ((petIndex - 1) % #hostiles) + 1
                local targetEnemy = hostiles[targetIndex].ped
                if DoesEntityExist(targetEnemy) then
                    TaskCombatPed(petPed, targetEnemy, 0, 16)
                end
            end
        end
    end

    CreateThread(function()
        local startTime = GetGameTimer()
        while #(State.Games.hostiles or {}) > 0 do
            Wait(2000)
            local allDead = true
            local playerPos = GetEntityCoords(cache.ped)
            for i = #(State.Games.hostiles or {}), 1, -1 do
                local hData = State.Games.hostiles[i]
                if DoesEntityExist(hData.ped) then
                    if IsEntityDead(hData.ped) then
                        if DoesBlipExist(hData.blip) then RemoveBlip(hData.blip) end
                        table.remove(State.Games.hostiles, i)
                        for companionid, petData in pairs(State.GetAllPets()) do
                            if petData and petData.spawned and DoesEntityExist(petData.ped) then
                                TriggerServerEvent('hdrp-pets:server:givexp', Config.XP.Increase.PerCombat, companionid)
                            end
                        end
                    else
                        allDead = false
                        local dist = #(GetEntityCoords(hData.ped) - playerPos)
                        if dist > gameHostileConfig.DespawnDistance then
                            if DoesBlipExist(hData.blip) then RemoveBlip(hData.blip) end
                            SetEntityAsNoLongerNeeded(hData.ped)
                            DeleteEntity(hData.ped)
                            table.remove(State.Games.hostiles, i)
                        end
                    end
                else
                    table.remove(State.Games.hostiles, i)
                end
            end
            if allDead or (GetGameTimer() - startTime > 300000) then
                break
            end
        end
    end)
end)

-- COMMAND
RegisterCommand('pet_hostile', function()
    TriggerEvent("hdrp-pets:client:startHostileEncounter")
    Wait(3000)
end, false)

-- STOP RESOURCE
AddEventHandler('onResourceStop', function(resource)
    if GetCurrentResourceName() ~= resource then return end
end) ]]
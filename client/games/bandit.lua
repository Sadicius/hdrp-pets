--[[ local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
local gameBanditConfig = Config.Games.Gbandit

-- Migrado: ahora se usa State.Games.bandits y helpers de state_helpers.lua
local hostileGroupHash = GetHashKey("REL_BANDIT_POSSE")

-- SET RELATIONSHIPS
CreateThread(function()
    -- Safe check: verify function exists and group doesn't exist before calling
    if DoesRelationshipGroupExist and DoesRelationshipGroupExist(hostileGroupHash) == 0 then
        AddRelationshipGroup("REL_BANDIT_POSSE")
    end

    SetRelationshipBetweenGroups(5, hostileGroupHash, GetHashKey("PLAYER"))
    SetRelationshipBetweenGroups(5, GetHashKey("PLAYER"), hostileGroupHash)

    SetRelationshipBetweenGroups(5, hostileGroupHash, GetHashKey("REL_COMPANION_GROUP"))
end)

-- GET RANDOM HOSTILE ANIMAL
local function GetRandomBanditData()
    local totalWeight = 0
    for _, group in ipairs(gameBanditConfig.Enemies) do
        totalWeight = totalWeight + group.chance
    end

    local randomNum = math.random(1, totalWeight)
    local currentWeight = 0

    for _, group in ipairs(gameBanditConfig.Enemies) do
        currentWeight = currentWeight + group.chance
        if randomNum <= currentWeight then
            return group
        end
    end
    return gameBanditConfig.Enemies[1]
end

local function GetRandomModelFromGroup(group)
    local models = group.models
    return models[math.random(#models)]
end

-- SET HOSTILE ATTRIBUTES
local function SetBanditAttributes(entity)
    SetPedRelationshipGroupHash(entity, hostileGroupHash)

    -- Atributos de combate HUMANOS
    SetPedCombatAttributes(entity, 46, true)  -- FIGHT_TO_DEATH (Pelear hasta morir)
    SetPedCombatAttributes(entity, 0, true)   -- CAN_USE_COVER (Usar cobertura, CRUCIAL para humanos)
    SetPedCombatAttributes(entity, 5, true)   -- CAN_FIGHT_ARMED_PED
    SetPedCombatAttributes(entity, 1, false)  -- Disable VEHICLE_ATTACK
    SetPedCombatAttributes(entity, 2, true)   -- CAN_COMMUNICATE_WITH_ALLIES (Coordinarse)

    SetPedAccuracy(entity, math.random(40, 60)) 

    SetPedSeeingRange(entity, 150.0)
    SetPedHearingRange(entity, 150.0)

    SetPedFleeAttributes(entity, 0, false) -- No huir
    SetBlockingOfNonTemporaryEvents(entity, true)
    SetEntityVisible(entity, true)

    local weaponHash = gameBanditConfig.WeaponPool[math.random(#gameBanditConfig.WeaponPool)]
    GiveWeaponToPed(entity, weaponHash, 999, false, true)
    SetCurrentPedWeapon(entity, weaponHash, true)
end

-- START HOSTILE ENCOUNTER
RegisterNetEvent('hdrp-pets:client:startBanditEncounter', function()
    local playerPed = cache.ped
    local playerCoords = GetEntityCoords(playerPed)
    
    -- Get ALL active pets for multi-pet support
    local activePets = {}
    for companionid, petData in pairs(State.GetAllPets()) do
        if petData and petData.spawned and DoesEntityExist(petData.ped) and not IsEntityDead(petData.ped) then
            table.insert(activePets, petData.ped)
        end
    end

    local banditGroup = GetRandomBanditData()
    local packSize = 1
    if banditGroup.isPack then
        packSize = math.random(banditGroup.min, banditGroup.max)
    end

    local titleMsg = banditGroup.isPack and locale('cl_bandit_pack_title') or locale('cl_bandit_single_title')
    local descMsg = locale('cl_bandit_attack_desc') .. packSize .. locale('cl_bandit_attack_count') .. banditGroup.label
    
    lib.notify({ 
        title = titleMsg, 
        description = descMsg, 
        type = 'error', 
        duration = 6000 
    })

    for i = 1, packSize do
        local modelHash = GetRandomModelFromGroup(banditGroup)
        lib.requestModel(modelHash)

        local angleOffset = (360 / packSize) * i
        local randomVar = math.random(-25, 25)
        local finalAngle = math.rad(angleOffset + randomVar)

        local spawnDist = gameBanditConfig.SpawnDistance + math.random(-2.0, 5.0)
        local spawnX = playerCoords.x + (math.cos(finalAngle) * spawnDist)
        local spawnY = playerCoords.y + (math.sin(finalAngle) * spawnDist)

        local foundGround, spawnZ = GetGroundZFor_3dCoord(spawnX, spawnY, playerCoords.z + 50.0, false)
        if not foundGround then spawnZ = playerCoords.z end

        local banditPed = CreatePed(modelHash, spawnX, spawnY, spawnZ, 0.0, true, true)
        SetEntityHealth(banditPed, 600)
        SetBanditAttributes(banditPed)
        TaskTurnPedToFaceEntity(banditPed, playerPed, 1000)
        local blip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, -1749618580, banditPed)
        SetBlipSprite(blip, -1832924447)
        SetBlipScale(blip, 0.2)
        State.AddBandit(banditPed, blip)
        SetModelAsNoLongerNeeded(modelHash)
        Wait(100)
    end

    Wait(1000)

    for _, hData in pairs(State.Games.bandits or {}) do
        if DoesEntityExist(hData.ped) then
            TaskCombatPed(hData.ped, playerPed, 0, 16)
            -- ("GET_LOST", "ROBBERY", "CHALLENGE")
            local speechTypes = {"GET_LOST", "CHALLENGE_THREATEN", "ROBBERY_SCREAM"}
            local speech = speechTypes[math.random(#speechTypes)]
            -- PlayPedAmbientSpeechNative(hData.ped, speech, "SPEECH_PARAMS_FORCE_SHOUTED")
        end
    end

    -- Multi-pet defense: All active pets help defend the player
    if #activePets > 0 then
        Wait(500)
        local petCountMsg = #activePets == 1 and locale('cl_pet_protect') or string.format("%d pets protecting you!", #activePets)
        lib.notify({ title = petCountMsg, type = 'info' })
        for petIndex, petPed in ipairs(activePets) do
            local bandits = State.Games.bandits or {}
            if #bandits > 0 then
                local targetIndex = ((petIndex - 1) % #bandits) + 1
                local targetEnemy = bandits[targetIndex].ped
                if DoesEntityExist(targetEnemy) then
                    TaskCombatPed(petPed, targetEnemy, 0, 16)
                end
            end
        end
    end

    CreateThread(function()
        local startTime = GetGameTimer()
        while #(State.Games.bandits or {}) > 0 do
            Wait(2000)
            local allDead = true
            local playerPos = GetEntityCoords(cache.ped)
            for i = #(State.Games.bandits or {}), 1, -1 do
                local hData = State.Games.bandits[i]
                if DoesEntityExist(hData.ped) then
                    if IsEntityDead(hData.ped) then
                        if DoesBlipExist(hData.blip) then RemoveBlip(hData.blip) end
                        table.remove(State.Games.bandits, i)
                        for companionid, petData in pairs(State.GetAllPets()) do
                            if petData and petData.spawned and DoesEntityExist(petData.ped) then
                                TriggerServerEvent('hdrp-pets:server:givexp', Config.XP.Increase.PerCombatHuman, companionid)
                            end
                        end
                    else
                        allDead = false
                        local dist = #(GetEntityCoords(hData.ped) - playerPos)
                        if dist > gameBanditConfig.DespawnDistance then
                            if DoesBlipExist(hData.blip) then RemoveBlip(hData.blip) end
                            SetEntityAsNoLongerNeeded(hData.ped)
                            DeleteEntity(hData.ped)
                            table.remove(State.Games.bandits, i)
                        end
                    end
                else
                    table.remove(State.Games.bandits, i)
                end
            end
            if allDead or (GetGameTimer() - startTime > 300000) then
                break
            end
        end
    end)
end)

-- COMMAND
RegisterCommand('pet_bandit', function()
    TriggerEvent("hdrp-pets:client:startBanditEncounter")
    Wait(3000)
end, false)

-- STOP RESOURCE
AddEventHandler('onResourceStop', function(resource)
    if GetCurrentResourceName() ~= resource then return end
    State.CleanupAllBandits()
end) ]]
local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
local gameTreasureConfig = Config.Games.Gtreasure
local gameHostileConfig = Config.Games.Ghostile
local gameBanditConfig = Config.Games.Gbandit

local ManageSpawn = lib.load('client.stable.utils_spawn')

-- Local state variables
local isTreasureHuntActive = false
local treasureInProgress = false
local treasurePoints = {}
local currentHuntStep = 0
local totalHuntSteps = 0
local gpsRoute = nil
local headingToTarget = false
local waitingForPlayer = false
local itemProps = {}

-- Multi-pet hunt state
local multiPetHuntActive = false
local activeTreasureHunts = {}
local playerFollowingPet = nil

--================================
-- HELPER FUNCTIONS
--================================

local function isWaterAtCoords(coords)
    local waterTypes = Config.WaterTypes
    local waterType = Citizen.InvokeNative(0x5BA7A68A346A5A91, coords.x, coords.y, coords.z)
    for _, v in pairs(waterTypes) do
        if waterType == v.waterhash then
            return true
        end
    end
    return false
end

local function treasureCleanUp()
    -- Clean up props
    for k, v in pairs(itemProps) do
        if v.treasure and DoesEntityExist(v.treasure) then
            SetEntityAsNoLongerNeeded(v.treasure)
            DeleteEntity(v.treasure)
        end
        if v.shovel and DoesEntityExist(v.shovel) then
            SetEntityAsNoLongerNeeded(v.shovel)
            DeleteObject(v.shovel)
        end
        itemProps[k] = nil
    end

    -- Clear GPS route
    if gpsRoute then
        ClearGpsMultiRoute()
        gpsRoute = nil
    end

    -- Reset state
    State.ResetPlayerState(true)
    treasureInProgress = false
    treasurePoints = {}
    currentHuntStep = 0
    totalHuntSteps = 0
    isTreasureHuntActive = false
    multiPetHuntActive = false
    activeTreasureHunts = {}
    playerFollowingPet = nil
    headingToTarget = false
    waitingForPlayer = false
end

--================================
-- TREASURE REWARDS
--================================

local function handleTreasureFound(petId)
    -- Check for hostile encounter
    local hostileRoll = math.random(100)
    if hostileRoll <= gameHostileConfig.Chance then
        TriggerEvent('hdrp-pets:client:startHostileEncounter')
        return
    end

    -- Check for bandit encounter
    local banditRoll = math.random(100)
    if banditRoll <= gameBanditConfig.Chance then
        TriggerEvent('hdrp-pets:client:startBanditEncounter')
        return
    end

    -- Roll for treasure
    local chance = math.random(100)
    if chance <= gameTreasureConfig.lostTreasure then
        ManageSpawn.crouchInspectAnim()
        if petId then
            TriggerServerEvent('hdrp-pets:server:givexp', Config.XP.Increase.PerTreasure, petId)
        end
        -- FIX: Pasar petId al servidor para actualizar achievements de tesoro
        TriggerServerEvent('hdrp-pets:server:givetreasure', petId)
        lib.notify({ title = locale('cl_reward'), description = locale('cl_game_treasure_hunt_give_desc'), type = 'success' })
    else
        lib.notify({ title = locale('cl_game_treasure_hunt_empty'), type = 'info' })
    end
end

--================================
-- SHOVEL MINIGAME
--================================

local function createShovelAndAttach()
    local playerCoords = GetEntityCoords(cache.ped)
    local boneIndex = GetEntityBoneIndexByName(cache.ped, 'SKEL_R_Hand')

    if not lib.requestModel(`p_shovel02x`, 5000) then
        if Config.Debug then print('^1[TREASURE]^7 ' .. locale('cl_debug_treasure_failed_shovel_model')) end
        return nil
    end

    local shovelObject = CreateObject(`p_shovel02x`, playerCoords, true, true, true)
    table.insert(itemProps, { shovel = shovelObject })

    SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)
    AttachEntityToEntity(shovelObject, cache.ped, boneIndex,
        0.0, -0.19, -0.089,
        274.1899, 483.89, 378.40,
        true, true, false, true, 1, true
    )
    return shovelObject
end

local function showSkillCheckShovel(entity, petId)
    local coords = GetEntityCoords(entity, true)
    if treasureInProgress then return end

    treasureInProgress = true
    local waitrand = math.random(10000, 25000)
    local treasureModel = 'mp005_p_dirtpile_tall_unburied'

    if not lib.requestModel(treasureModel, 5000) then
        if Config.Debug then print('^1[TREASURE]^7 ' .. locale('cl_debug_treasure_failed_treasure_model')) end
        treasureInProgress = false
        return
    end

    local animDict = 'amb_work@world_human_gravedig@working@male_b@base'
    if not lib.requestAnimDict(animDict, 5000) then
        if Config.Debug then print('^1[TREASURE]^7 ' .. locale('cl_debug_treasure_failed_dig_anim')) end
        treasureInProgress = false
        return
    end

    local shovelObject = createShovelAndAttach()
    if not shovelObject then
        treasureInProgress = false
        return
    end

    FreezeEntityPosition(cache.ped, true)
    TaskPlayAnim(cache.ped, animDict, 'base', 3.0, 3.0, -1, 1, 0, false, false, false)
    Wait(waitrand)

    local playerCoords = GetEntityCoords(cache.ped)
    local playerForwardVector = GetEntityForwardVector(cache.ped)
    local offsetX = 0.6
    local objectX = playerCoords.x + playerForwardVector.x * offsetX
    local objectY = playerCoords.y + playerForwardVector.y * offsetX
    local objectZ = playerCoords.z - 1

    local treasureObject = CreateObject(treasureModel, objectX, objectY, objectZ, true, true, false)
    table.insert(itemProps, { treasure = treasureObject })

    State.ResetPlayerState(true)

    handleTreasureFound(petId)

    State.ResetPlayerState(true)

    if DoesEntityExist(shovelObject) then
        DeleteObject(shovelObject)
    end

    -- Auto-delete treasure prop
    CreateThread(function()
        Wait(gameTreasureConfig.AutoDelete)
        if treasureObject and DoesEntityExist(treasureObject) then
            SetEntityAsNoLongerNeeded(treasureObject)
            DeleteObject(treasureObject)
            for k, v in pairs(itemProps) do
                if v.treasure == treasureObject then
                    itemProps[k] = nil
                    break
                end
            end
        end
    end)

    treasureCleanUp()
end

--================================
-- FINISH TREASURE HUNT
--================================

local function finishTreasureHunt(entity, petId)
    lib.notify({ title = locale('cl_game_treasure_hunt_started'), description = locale('cl_game_treasure_hunt_started_desc'), type = 'success' })

    local animDig = 'amb_creature_mammal@world_dog_digging@base'

    -- Resolve petId if not provided
    if not petId and entity then
        local petData, resolvedPetId = State.GetPetByEntity(entity)
        petId = resolvedPetId
    end

    -- Play dig animation
    if petId then
        State.PlayPetAnimation(petId, animDig, 'base', true, gameTreasureConfig.anim.digAnimTime)
        Wait(gameTreasureConfig.anim.digAnimTime)
        State.ClearPetAnimation(petId)
    end

    -- Minigame check
    if gameTreasureConfig.DoMiniGame then
        if gameTreasureConfig.MiniGameShovel then
            showSkillCheckShovel(entity, petId)
            return
        else
            local success = lib.skillCheck({{areaSize = 50, speedMultiplier = 0.5}}, {'w', 'a', 's', 'd'})
            if not success then
                local roll = math.random(1, 100)
                if roll <= tonumber(gameTreasureConfig.lostTreasure) then
                    treasureCleanUp()
                end
                SetPedToRagdoll(cache.ped, 1000, 1000, 0, 0, 0, 0)
                Wait(1000)
                State.ResetPlayerState()
                return
            end
        end
    end

    handleTreasureFound(petId)
    treasureCleanUp()
end

--================================
-- ROUTE GENERATION
--================================

local function generateRandomTreasureRoute(startPos, steps)
    local route = {}
    local lastPos = startPos

    -- Restricted zones (cities)
    local restrictedZones = {
        {name = "Valentine", coords = vector3(-306.0, 792.0, 118.0), radius = 150.0},
        {name = "Blackwater", coords = vector3(-813.0, -1324.0, 43.0), radius = 200.0},
        {name = "Rhodes", coords = vector3(1346.0, -1312.0, 76.0), radius = 150.0},
        {name = "Saint Denis", coords = vector3(2632.0, -1312.0, 52.0), radius = 300.0},
        {name = "Strawberry", coords = vector3(-1803.0, -386.0, 160.0), radius = 120.0},
        {name = "Annesburg", coords = vector3(2930.0, 1288.0, 44.0), radius = 120.0},
        {name = "Armadillo", coords = vector3(-3685.0, -2562.0, -13.0), radius = 130.0},
        {name = "Tumbleweed", coords = vector3(-5512.0, -2937.0, -2.0), radius = 130.0},
        {name = "Van Horn", coords = vector3(2976.0, 544.0, 44.0), radius = 100.0},
    }

    local function isInRestrictedZone(point)
        for _, zone in ipairs(restrictedZones) do
            local distance = #(vector3(point.x, point.y, point.z) - zone.coords)
            if distance < zone.radius then
                return true, zone.name
            end
        end
        return false
    end

    for i = 1, steps do
        local validPoint = false
        local newPoint
        local loopAttempts = 0
        local maxAttempts = 100

        while not validPoint and loopAttempts < maxAttempts do
            local dist = math.random(gameTreasureConfig.minDistance, gameTreasureConfig.maxDistance)
            local angle = math.rad(math.random(0, 360))
            local offsetX = math.cos(angle) * dist
            local offsetY = math.sin(angle) * dist
            local newX = lastPos.x + offsetX
            local newY = lastPos.y + offsetY

            local foundGround, groundZ = GetGroundZFor_3dCoord(newX, newY, lastPos.z + 100.0, 0)
            local newZ = foundGround and groundZ or lastPos.z

            newPoint = vector3(newX, newY, newZ)

            local inWater = isWaterAtCoords(newPoint)
            local inRestricted, zoneName = isInRestrictedZone(newPoint)
            local inInterior = GetInteriorFromEntity(cache.ped) ~= 0

            if not inWater and not inRestricted and not inInterior then
                validPoint = true
            elseif Config.Debug and inRestricted then
                print(string.format('^3[TREASURE]^7 Point rejected: too close to %s', zoneName))
            end

            loopAttempts = loopAttempts + 1
        end

        if validPoint and newPoint then
            table.insert(route, newPoint)
            lastPos = newPoint
        else
            if Config.Debug then
                print(string.format('^3[TREASURE]^7 ' .. locale('debug_treasure_no_valid_coord') .. ' (attempts: %d)', loopAttempts))
            end
            break
        end
    end

    if Config.Debug then
        print(string.format('^2[TREASURE]^7 Route generated: %d points', #route))
    end

    return route
end

--================================
-- MOVE TO CLUE (Single Pet Mode)
--================================

local function moveToClue(index, entity)
    if not entity or not DoesEntityExist(entity) then return end
    if not treasurePoints[index] then return end

    local target = treasurePoints[index]
    local targetCoords = vector3(target.x, target.y, target.z)

    -- Set GPS route
    if Config.Blip.Clue.ClueBlip then
        if gpsRoute then ClearGpsMultiRoute() end
        StartGpsMultiRoute(GetHashKey('COLOR_BLUE'), true, true)
        AddPointToGpsMultiRoute(targetCoords.x, targetCoords.y, targetCoords.z)
        SetGpsMultiRouteRender(true)
        gpsRoute = true
    end

    headingToTarget = true
    waitingForPlayer = false

    -- Command pet to move
    TaskGoToCoordAnyMeans(entity, target.x, target.y, target.z, 2.0, 0, 0, 786603, 0)

    lib.notify({
        title = locale('cl_game_treasure_hunt_follow'),
        description = string.format(locale('cl_game_treasure_hunt_follow_desc') .. ' %d ' .. locale('cl_game_treasure_hunt_follow_desc2') .. ' %d', index, totalHuntSteps),
        type = 'info'
    })

    -- Play howl animation
    local animHowl = 'amb_creature_mammal@world_dog_howling_sitting@base'
    local petData, petId = State.GetPetByEntity(entity)
    if petId then
        ClearPedTasksImmediately(entity)
        State.PlayPetAnimation(petId, animHowl, 'base', true, 3000)
        Wait(3000)
        State.ClearPetAnimation(petId)
    end

    TaskGoToCoordAnyMeans(entity, target.x, target.y, target.z, 2.0, 0, 0, 786603, 0)

    if Config.Debug then
        print(locale('cl_print_treasurehunt_move') .. ' ' .. index)
    end

    -- Monitor thread
    CreateThread(function()
        local step = index
        local lastReissueTime = GetGameTimer()
        local clueStartTime = GetGameTimer()
        local clueTimeout = 120000  -- 2 minutes per clue
        local maxIterations = 120
        local iterationCount = 0

        local function shouldCancel()
            return not treasureInProgress or
                   not entity or
                   not DoesEntityExist(entity) or
                   IsEntityDead(entity) or
                   IsEntityDead(cache.ped)
        end

        while treasureInProgress and currentHuntStep == step and iterationCount < maxIterations do
            if shouldCancel() then
                if Config.Debug then
                    print('^3[TREASURE]^7 ' .. locale('cl_debug_treasure_cancelled_conditions'))
                end
                treasureCleanUp()
                return
            end

            iterationCount = iterationCount + 1
            Wait(1000)

            local dogPos = GetEntityCoords(entity)
            local playerPos = GetEntityCoords(cache.ped)
            local distToTarget = #(dogPos - targetCoords)
            local distToPlayer = #(dogPos - playerPos)

            -- Reissue task if stuck
            if GetGameTimer() - lastReissueTime > 10000 and headingToTarget then
                if Config.Debug then print(locale('cl_print_treasurehunt_move_b')) end
                TaskGoToCoordAnyMeans(entity, targetCoords.x, targetCoords.y, targetCoords.z, 2.0, 0, 0, 786603, 0)
                lastReissueTime = GetGameTimer()
            end

            -- Timeout per clue
            if GetGameTimer() - clueStartTime > clueTimeout and headingToTarget then
                lib.notify({ title = locale('cl_game_treasure_hunt_fail'), description = locale('cl_game_treasure_hunt_fail_desc'), type = 'warning' })
                ClearPedTasksImmediately(entity)
                local animSniff = 'amb_creature_mammal@world_dog_sniffing_ground@base'
                if petId then
                    State.PlayPetAnimation(petId, animSniff, 'base', true, gameTreasureConfig.anim.sniAnimTime)
                    Wait(gameTreasureConfig.anim.sniAnimTime)
                    State.ClearPetAnimation(petId)
                end
                TaskGoToCoordAnyMeans(entity, targetCoords.x, targetCoords.y, targetCoords.z, 2.0, 0, 0, 786603, 0)
                clueStartTime = GetGameTimer()
                lastReissueTime = GetGameTimer()
            end

            -- Pet too far from player - wait
            if headingToTarget and distToPlayer > gameTreasureConfig.maxdistToPlayer then
                ClearPedTasksImmediately(entity)
                TaskGoToEntity(entity, cache.ped, -1, 2.0, 2.0, 0, 0)
                lib.notify({ title = locale('cl_game_treasure_hunt_check'), description = locale('cl_game_treasure_hunt_check_desc'), type = 'warning' })
                headingToTarget = false
                waitingForPlayer = true

            elseif waitingForPlayer and distToPlayer <= gameTreasureConfig.mindistToPlayer then
                ClearPedTasksImmediately(entity)
                local animGrowl = 'amb_creature_mammal@world_dog_guard_growl@base'
                if petId then
                    State.PlayPetAnimation(petId, animGrowl, 'base', true, gameTreasureConfig.anim.sniAnimTime)
                    Wait(gameTreasureConfig.anim.sniAnimTime)
                    State.ClearPetAnimation(petId)
                end
                lib.notify({ title = locale('cl_game_treasure_hunt_check_player'), description = locale('cl_game_treasure_hunt_check_player_desc'), type = 'info' })
                TaskGoToCoordAnyMeans(entity, target.x, target.y, target.z, 2.0, 0, 0, 786603, 0)
                headingToTarget = true
                waitingForPlayer = false
                lastReissueTime = GetGameTimer()
            end

            -- Arrived at clue
            if distToTarget < gameTreasureConfig.distToTarget then
                ClearPedTasksImmediately(entity)

                -- Random animation at clue
                local roll = math.random(1, 100)
                local anim = nil
                local animTime = gameTreasureConfig.anim.clueWaitTime

                if roll <= 25 then
                    anim = 'amb_creature_mammal@world_dog_howling_sitting@base'
                    animTime = gameTreasureConfig.anim.howAnimTime
                elseif roll <= 50 then
                    anim = 'amb_creature_mammal@world_dog_sniffing_ground@base'
                elseif roll <= 75 then
                    anim = 'amb_creature_mammal@world_dog_guard_growl@base'
                    animTime = gameTreasureConfig.anim.guaAnimTime
                else
                    anim = 'amb_creature_mammal@world_dog_digging@base'
                end

                if petId and anim then
                    State.PlayPetAnimation(petId, anim, 'base', true, animTime)
                    Wait(animTime)
                    State.ClearPetAnimation(petId)
                end

                -- Show clue blip
                if Config.Blip.Clue.ClueBlip then
                    ClearGpsMultiRoute()
                    gpsRoute = nil

                    local ClueBlip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, targetCoords.x, targetCoords.y, targetCoords.z)
                    Citizen.InvokeNative(0x662D364ABF16DE2F, ClueBlip, Config.Blip.ColorModifier)
                    SetBlipSprite(ClueBlip, Config.Blip.Clue.blipSprite, true)
                    SetBlipScale(ClueBlip, Config.Blip.Clue.blipScale)
                    Citizen.InvokeNative(0x45FF974EEA1DCE36, ClueBlip, true)
                    Citizen.InvokeNative(0x9CB1A1623062F402, ClueBlip, Config.Blip.Clue.blipName)

                    lib.notify({ title = locale('cl_game_treasure_hunt_find'), description = locale('cl_game_treasure_hunt_find_desc'), type = 'success', duration = 5000 })

                    CreateThread(function()
                        Wait(Config.Blip.Clue.blipTime)
                        if ClueBlip and DoesBlipExist(ClueBlip) then RemoveBlip(ClueBlip) end
                    end)
                end

                currentHuntStep = currentHuntStep + 1

                if currentHuntStep > totalHuntSteps then
                    finishTreasureHunt(entity, petId)
                else
                    Wait(500)
                    moveToClue(currentHuntStep, entity)
                end
                break
            end
        end

        -- Timeout notification
        if iterationCount >= maxIterations and treasureInProgress then
            lib.notify({
                title = locale('cl_treasure_hunt_timeout'),
                description = locale('cl_treasure_hunt_timeout_desc'),
                type = 'error',
                duration = 7000
            })

            if Config.Debug then
                print('^3[TREASURE]^7 ' .. locale('cl_debug_treasure_timed_out'))
            end
            treasureCleanUp()
        end
    end)
end

--================================
-- SINGLE PET TREASURE HUNT
--================================

local function startTreasureHunt(entity, petId)
    if treasureInProgress then
        lib.notify({ title = locale('cl_game_treasure_hunt_in_progress'), type = 'error' })
        return
    end

    if not entity or not DoesEntityExist(entity) or IsEntityDead(cache.ped) then
        lib.notify({ title = locale('cl_error_treasurehunt') or 'Error', description = locale('cl_error_treasurehunt_des') or 'Invalid conditions', type = 'error' })
        return
    end

    treasureInProgress = true
    isTreasureHuntActive = true
    currentHuntStep = 1
    totalHuntSteps = math.random(gameTreasureConfig.minSteps, gameTreasureConfig.maxSteps)

    local playerCoords = GetEntityCoords(cache.ped)
    treasurePoints = generateRandomTreasureRoute(playerCoords, totalHuntSteps)

    if next(treasurePoints) then
        lib.notify({
            title = locale('cl_multipet_treasure_started_title') or 'Treasure Hunt Started',
            description = locale('cl_multipet_treasure_started_desc') or 'Follow your pet!',
            type = 'info',
            duration = 7000
        })
        moveToClue(currentHuntStep, entity)
    else
        lib.notify({ title = locale('cl_treasure_error_title'), description = locale('cl_treasure_error_desc'), type = 'error' })
        treasureCleanUp()
    end
end

--================================
-- MULTI-PET TREASURE HUNT (Competition)
--================================

local function startMultiPetTreasureHunt()
    if isTreasureHuntActive then
        lib.notify({ title = locale('cl_game_treasure_hunt_in_progress'), type = 'error' })
        return
    end

    local activePets = State.GetAllPets()
    if not next(activePets) then
        lib.notify({ title = locale('cl_error_no_pet_retrieve_bone'), type = 'error' })
        return
    end

    local petCount = 0
    for _ in pairs(activePets) do petCount = petCount + 1 end

    if petCount < 2 then
        lib.notify({ title = locale('cl_game_treasure_need_two_pets'), type = 'warning' })
        return
    end

    isTreasureHuntActive = true
    multiPetHuntActive = true
    activeTreasureHunts = {}
    playerFollowingPet = nil

    local playerCoords = GetEntityCoords(cache.ped)

    -- Randomly select ONE pet to have the correct treasure
    local petIds = {}
    for id in pairs(activePets) do table.insert(petIds, id) end
    local winnerPetId = petIds[math.random(#petIds)]

    -- Assign outcomes to each pet
    local outcomes = {}
    for id in pairs(activePets) do
        if id == winnerPetId then
            outcomes[id] = 'treasure'
        else
            if math.random(100) <= 50 then
                outcomes[id] = 'hostile'
            else
                outcomes[id] = 'bandit'
            end
        end
    end

    lib.notify({
        title = locale('cl_multipet_treasure_started_title'),
        description = locale('cl_multipet_treasure_started_desc'),
        type = 'success'
    })

    -- Generate different destinations for each pet
    local usedLocations = {}
    local locationSpread = 150.0

    for petId, petData in pairs(activePets) do
        local petPed = petData.ped
        if not petPed or not DoesEntityExist(petPed) then goto continue end

        local validLocation = false
        local targetLocation = nil
        local attempts = 0
        local maxAttempts = 50

        while not validLocation and attempts < maxAttempts do
            local dist = math.random(100, 250)
            local angle = math.rad(math.random(0, 360))
            local offsetX = math.cos(angle) * dist
            local offsetY = math.sin(angle) * dist
            local newX = playerCoords.x + offsetX
            local newY = playerCoords.y + offsetY

            local foundGround, groundZ = GetGroundZFor_3dCoord(newX, newY, playerCoords.z + 100.0, 0)
            local newZ = foundGround and groundZ or playerCoords.z

            targetLocation = vector3(newX, newY, newZ)

            -- Check distance from other locations
            local tooClose = false
            for _, usedLoc in ipairs(usedLocations) do
                if #(targetLocation - usedLoc) < locationSpread then
                    tooClose = true
                    break
                end
            end

            if not tooClose and not isWaterAtCoords(targetLocation) then
                validLocation = true
                table.insert(usedLocations, targetLocation)
            end

            attempts = attempts + 1
        end

        if validLocation and targetLocation then
            activeTreasureHunts[petId] = {
                ped = petPed,
                targetLocation = targetLocation,
                outcome = outcomes[petId],
                hasArrived = false,
                playerIsNear = false,
                reachedTime = nil
            }

            ClearPedTasks(petPed)
            Wait(50)

            -- Play howl animation before departure
            local animHowl = 'amb_creature_mammal@world_dog_howling_sitting@base'
            State.PlayPetAnimation(petId, animHowl, 'base', true, 3000)

            CreateThread(function()
                Wait(3000)
                State.ClearPetAnimation(petId)
                TaskGoToCoordAnyMeans(petPed, targetLocation.x, targetLocation.y, targetLocation.z, 2.5, 0, 0, 786603, 0)
            end)
        end

        ::continue::
    end

    -- Monitor thread for all pets
    CreateThread(function()
        local globalTimeout = GetGameTimer() + 300000 -- 5 minutes total

        while multiPetHuntActive and GetGameTimer() < globalTimeout do
            Wait(1000)

            if IsEntityDead(cache.ped) then
                multiPetHuntActive = false
                break
            end

            local playerPos = GetEntityCoords(cache.ped)

            for petId, huntData in pairs(activeTreasureHunts) do
                if DoesEntityExist(huntData.ped) and not IsEntityDead(huntData.ped) then
                    local petPos = GetEntityCoords(huntData.ped)
                    local distToTarget = #(petPos - huntData.targetLocation)
                    local distToPlayer = #(petPos - playerPos)

                    -- Reissue task if stuck
                    if not huntData.hasArrived and distToTarget > 5.0 then
                        local taskStatus = GetScriptTaskStatus(huntData.ped, 0x8AA1593C)
                        if taskStatus ~= 1 and taskStatus ~= 0 then
                            TaskGoToCoordAnyMeans(huntData.ped, huntData.targetLocation.x, huntData.targetLocation.y, huntData.targetLocation.z, 2.5, 0, 0, 786603, 0)
                        end
                    end

                    -- Pet arrived at destination
                    if not huntData.hasArrived and distToTarget < 5.0 then
                        huntData.hasArrived = true
                        huntData.reachedTime = GetGameTimer()
                        State.ClearPetAnimation(petId)

                        local animDig = 'amb_creature_mammal@world_dog_digging@base'
                        State.PlayPetAnimation(petId, animDig, 'base', true, -1)

                        lib.notify({
                            title = locale('cl_multipet_pet_arrived_title'),
                            description = locale('cl_multipet_pet_arrived_desc'),
                            type = 'info'
                        })
                    end

                    -- Check if player is near arrived pet
                    if huntData.hasArrived and distToPlayer < 15.0 then
                        if not huntData.playerIsNear then
                            huntData.playerIsNear = true
                            playerFollowingPet = petId

                            ClearPedTasksImmediately(huntData.ped)

                            if huntData.outcome == 'treasure' then
                                lib.notify({
                                    title = locale('cl_multipet_treasure_found_title'),
                                    description = locale('cl_multipet_treasure_found_desc'),
                                    type = 'success',
                                    duration = 7000
                                })
                                Wait(1000)
                                finishTreasureHunt(huntData.ped, petId)
                            elseif huntData.outcome == 'hostile' then
                                lib.notify({
                                    title = locale('cl_multipet_hostile_title'),
                                    description = locale('cl_multipet_hostile_desc'),
                                    type = 'warning',
                                    duration = 5000
                                })
                                Wait(1000)
                                TriggerEvent('hdrp-pets:client:startHostileEncounter')
                            elseif huntData.outcome == 'bandit' then
                                lib.notify({
                                    title = locale('cl_multipet_bandit_title'),
                                    description = locale('cl_multipet_bandit_desc'),
                                    type = 'warning',
                                    duration = 5000
                                })
                                Wait(1000)
                                TriggerEvent('hdrp-pets:client:startBanditEncounter')
                            end

                            multiPetHuntActive = false

                            -- Send other pets back to player
                            for otherId, otherData in pairs(activeTreasureHunts) do
                                if otherId ~= petId and DoesEntityExist(otherData.ped) then
                                    ClearPedTasks(otherData.ped)
                                    ManageSpawn.moveCompanionToPlayer(otherData.ped, cache.ped)
                                end
                            end

                            break
                        end
                    end

                    -- Timeout: pet waited too long
                    if huntData.hasArrived and not huntData.playerIsNear then
                        local waitTime = GetGameTimer() - huntData.reachedTime
                        if waitTime > 60000 then -- 1 minute wait
                            ClearPedTasks(huntData.ped)
                            ManageSpawn.moveCompanionToPlayer(huntData.ped, cache.ped)
                            huntData.playerIsNear = true
                        end
                    end
                end
            end

            if not multiPetHuntActive then
                break
            end
        end

        -- Cleanup if timeout reached
        if GetGameTimer() >= globalTimeout then
            lib.notify({
                title = locale('cl_treasure_hunt_timeout'),
                description = locale('cl_treasure_hunt_timeout_desc'),
                type = 'error'
            })
            for petId, huntData in pairs(activeTreasureHunts) do
                if DoesEntityExist(huntData.ped) then
                    ClearPedTasks(huntData.ped)
                    ManageSpawn.moveCompanionToPlayer(huntData.ped, cache.ped)
                end
            end
        end

        treasureCleanUp()
    end)
end

--================================
-- COMMANDS AND EVENTS
--================================

-- Cancel command
RegisterCommand('pet_treasure_cancel', function()
    if treasureInProgress or multiPetHuntActive then
        lib.notify({
            title = locale('cl_treasure_hunt_cancelled'),
            description = locale('cl_treasure_hunt_cancelled_desc'),
            type = 'info'
        })

        -- Clear pet tasks
        local activePets = State.GetAllPets()
        for _, petData in pairs(activePets) do
            if petData.ped and DoesEntityExist(petData.ped) then
                ClearPedTasksImmediately(petData.ped)
                ManageSpawn.moveCompanionToPlayer(petData.ped, cache.ped)
            end
        end

        treasureCleanUp()
    else
        lib.notify({
            title = locale('cl_treasure_hunt_no_active'),
            description = locale('cl_treasure_hunt_no_active_desc'),
            type = 'error'
        })
    end
end, false)

-- Main command
RegisterCommand('pet_treasure', function(source, args)
    if isTreasureHuntActive then
        lib.notify({ title = locale('cl_game_treasure_hunt_in_progress'), type = 'error' })
        return
    end

    local activePets = State.GetAllPets()
    if not next(activePets) then
        lib.notify({ title = locale('cl_error_no_pet_retrieve_bone'), type = 'error' })
        return
    end

    local targetPetId = nil

    -- Check if specific pet argument provided
    if args and args[1] then
        local searchTerm = string.lower(args[1])

        for id, petData in pairs(activePets) do
            if tostring(id) == searchTerm then
                targetPetId = id
                break
            end
            local petName = petData.data and petData.data.info and petData.data.info.name or nil
            if petName and string.lower(petName):find(searchTerm, 1, true) then
                targetPetId = id
                break
            end
        end

        if not targetPetId then
            lib.notify({ title = locale('cl_error_no_pet_retrieve_bone'), description = locale('cl_error_pet_not_found') .. ': ' .. args[1], type = 'error' })
            return
        end

        -- Specific pet treasure hunt
        local petData = State.GetPet(targetPetId)
        local petPed = petData and petData.ped or nil
        if petPed and DoesEntityExist(petPed) then
            startTreasureHunt(petPed, targetPetId)
        end
    else
        -- No argument: multi-pet competition if 2+ pets, otherwise single pet
        local petCount = 0
        for _ in pairs(activePets) do petCount = petCount + 1 end

        if petCount >= 2 then
            startMultiPetTreasureHunt()
        else
            -- Single pet mode
            for companionid, petData in pairs(activePets) do
                if petData and petData.spawned and DoesEntityExist(petData.ped) then
                    startTreasureHunt(petData.ped, companionid)
                    break
                end
            end
        end
    end
end, false)

-- Event from menu
RegisterNetEvent('hdrp-pets:client:startTreasureHunt')
AddEventHandler('hdrp-pets:client:startTreasureHunt', function(petId)
    if isTreasureHuntActive then
        lib.notify({ title = locale('cl_game_treasure_hunt_in_progress'), type = 'error' })
        return
    end

    local petPed = nil
    if petId then
        local petData = State.GetPet(petId)
        petPed = petData and petData.ped or nil
    end

    if petPed and DoesEntityExist(petPed) then
        startTreasureHunt(petPed, petId)
    else
        lib.notify({ title = locale('cl_error_treasurehunt') or 'Error', description = locale('cl_error_treasurehunt_des') or 'Invalid pet', type = 'error' })
    end
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resource)
    if GetCurrentResourceName() ~= resource then return end
    treasureCleanUp()
end)

-- Export for external use
exports('TreasureHunt', function(data)
    if type(data) == 'table' and data.petId then
        local petData = State.GetPet(data.petId)
        if petData and petData.ped then
            startTreasureHunt(petData.ped, data.petId)
        end
    elseif type(data) == 'number' then
        -- Entity passed directly
        startTreasureHunt(data, nil)
    end
end)
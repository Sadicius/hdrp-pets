local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
local ManageSpawn = lib.load('client.stable.utils_spawn')
local gameTreasureConfig = Config.Games.Gtreasure
local gameHostileConfig = Config.Games.Ghostile
local gameBanditConfig = Config.Games.Gbandit

-- Restricted zones (cities) - constant
local RESTRICTED_ZONES = {
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

-- Local state variables
local isTreasureHuntActive = false
local treasureInProgress = false
local treasurePoints = {}
local itemProps = {}
local currentHuntStep = 0
local totalHuntSteps = 0
local gpsRoute = nil
local headingToTarget = false
local waitingForPlayer = false

-- Multi-pet hunt state
local multiPetHuntActive = false
local activeTreasureHunts = {}
local playerFollowingPet = nil
local selectedPetToFollow = nil  -- Pet the player chose to follow


--================================
-- HELPER FUNCTIONS
--================================
---Check if coordinates are in water
---@param coords vector3
---@return boolean inWater
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

---Check if point is in restricted zone (city)
---@param point vector3
---@return boolean inZone
---@return string|nil zoneName
local function isInRestrictedZone(point)
    for _, zone in ipairs(RESTRICTED_ZONES) do
        local distance = #(point - zone.coords)
        if distance < zone.radius then
            return true, zone.name
        end
    end
    return false
end

---Get random clue animation for pet
---@return string anim Animation dictionary path
---@return number animTime Duration in milliseconds
local function getRandomClueAnimation()
    local roll = math.random(1, 100)
    local anim, animTime = nil, gameTreasureConfig.anim.clueWaitTime
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
    return anim, animTime
end

---Find pet by name or ID
---@param searchTerm string Pet name or ID to search
---@param activePets table Table of active pets
---@return string|nil petId
---@return table|nil petData
local function findPetByIdentifier(searchTerm, activePets)
    local lowerTerm = string.lower(searchTerm)
    for id, petData in pairs(activePets) do
        if tostring(id) == lowerTerm then
            return id, petData
        end
        local petName = petData.data and petData.data.info and petData.data.info.name or nil
        if petName and string.lower(petName):find(lowerTerm, 1, true) then
            return id, petData
        end
    end
    return nil, nil
end

---Validate if pet meets treasure hunt requirements
---@param petId string
---@return boolean canStart
---@return string|nil errorMessage
---@return table|nil petData Pet data if validation succeeds
local function validateTreasureRequirements(petId)
    -- Check if pet exists and is alive
    if not State.ShouldThreadContinue(petId) then
        return false, locale('cl_error_treasurehunt') or 'Pet not available', nil
    end
    local petData = State.GetPet(petId)
    if not petData then
        return false, locale('cl_error_treasurehunt') or 'Pet not available', nil
    end
    -- Check XP requirement
    local xp = (petData.data and petData.data.progression and petData.data.progression.xp) or 0
    local requiredXP = Config.XP.Trick.TreasureHunt
    if xp < requiredXP then
        return false, string.format(locale('cl_error_xp_required') or 'XP required: %d (Current: %d)', requiredXP, xp), nil
    end
    -- Check for shovel item
    local hasShovel = RSGCore.Functions.HasItem(Config.Items.Treasure)
    if not hasShovel then
        return false, locale('cl_error_treasure_hunt_requirement') or 'Shovel required', nil
    end
    return true, nil, petData
end

---Get valid pets for treasure hunt (XP + shovel requirements)
---@param activePets table Table of active pets
---@return table validPets Table of pets that meet requirements
---@return number count Number of valid pets
local function getValidPetsForTreasure(activePets)
    local validPets = {}
    local count = 0
    for petId, petData in pairs(activePets) do
        local canStart, _ = validateTreasureRequirements(petId)
        if canStart then
            validPets[petId] = petData
            count = count + 1
        end
    end
    return validPets, count
end

---Clean up treasure hunt props and state
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
    selectedPetToFollow = nil
    headingToTarget = false
    waitingForPlayer = false
end

--================================
-- TREASURE REWARDS
--================================
--- Handle treasure found logic
---@param petId string|nil Pet ID that found the treasure
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

-- SHOVEL MINIGAME
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
--- Finish treasure hunt sequence
---@param entity Entity Pet entity that found the treasure
---@param petId string|nil Pet ID that found the treasure
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
-- UNIFIED CLUE MOVEMENT (Single & Multi-Pet Mode)
--================================

---Move pet to clue location with player follow logic
---Handles both single-pet and multi-pet treasure hunt modes
---@param petId string Pet companion ID
---@param clueIndex number Current clue index (1-based)
---@param isMultiPetMode boolean True for multi-pet competition mode
local function movePetToClue(petId, clueIndex, isMultiPetMode)
    local entity, cluePoints, totalClues, huntData

    if isMultiPetMode then
        huntData = activeTreasureHunts[petId]
        if not huntData then return end
        entity = huntData.ped
        cluePoints = huntData.cluePoints
        totalClues = huntData.totalClues
    else
        local petData = State.GetPet(petId)
        entity = petData and petData.ped or nil
        cluePoints = treasurePoints
        totalClues = totalHuntSteps
    end

    if not entity or not DoesEntityExist(entity) then return end
    if not cluePoints or not cluePoints[clueIndex] then return end

    local target = cluePoints[clueIndex]
    local targetCoords = vector3(target.x, target.y, target.z)

    -- Update state
    if isMultiPetMode then
        huntData.currentClue = clueIndex
        huntData.headingToTarget = true
        huntData.waitingForPlayer = false
    else
        currentHuntStep = clueIndex
        headingToTarget = true
        waitingForPlayer = false
    end

    -- Command pet to move
    TaskGoToCoordAnyMeans(entity, target.x, target.y, target.z, 2.0, 0, 0, 786603, 0)

    -- Only show notifications and GPS for followed pet
    local shouldShowUI = not isMultiPetMode or (selectedPetToFollow == petId)

    if shouldShowUI then
        lib.notify({
            title = locale('cl_game_treasure_hunt_follow'),
            description = string.format(locale('cl_game_treasure_hunt_follow_desc') .. ' %d ' .. locale('cl_game_treasure_hunt_follow_desc2') .. ' %d', clueIndex, totalClues),
            type = 'info'
        })

        -- Set GPS route
        if Config.Blip.Clue.ClueBlip then
            if gpsRoute then ClearGpsMultiRoute() end
            StartGpsMultiRoute(GetHashKey('COLOR_BLUE'), true, true)
            AddPointToGpsMultiRoute(targetCoords.x, targetCoords.y, targetCoords.z)
            SetGpsMultiRouteRender(true)
            gpsRoute = true
        end
    end

    if Config.Debug then
        print(string.format('^2[TREASURE]^7 Pet %s moving to clue %d/%d', petId, clueIndex, totalClues))
    end

    -- Monitor thread
    CreateThread(function()
        local step = clueIndex
        local lastReissueTime = GetGameTimer()
        local clueStartTime = GetGameTimer()
        local clueTimeout = 120000  -- 2 minutes per clue
        local maxIterations = 120
        local iterationCount = 0

        local function shouldCancel()
            if IsEntityDead(cache.ped) then return true end
            if not State.ShouldThreadContinue(petId) then
                return true
            end
            if isMultiPetMode then
                return not multiPetHuntActive
            else
                return not treasureInProgress
            end
        end

        local function getCurrentStep()
            return isMultiPetMode and huntData.currentClue or currentHuntStep
        end

        while not shouldCancel() and getCurrentStep() == step and iterationCount < maxIterations do
            iterationCount = iterationCount + 1
            Wait(1000)

            local dogPos = GetEntityCoords(entity)
            local playerPos = GetEntityCoords(cache.ped)
            local distToTarget = #(dogPos - targetCoords)
            local distToPlayer = State.GetDistancePlayerToPet(petId)

            local isFollowedPet = not isMultiPetMode or (selectedPetToFollow == petId)
            local currentHeading = isMultiPetMode and huntData.headingToTarget or headingToTarget
            local currentWaiting = isMultiPetMode and huntData.waitingForPlayer or waitingForPlayer

            -- Only apply player-follow logic if this pet is selected
            if isFollowedPet then
                -- Reissue task if stuck
                if GetGameTimer() - lastReissueTime > 10000 and currentHeading then
                    if Config.Debug then print('^3[TREASURE]^7 Reissuing move command for pet ' .. petId) end
                    TaskGoToCoordAnyMeans(entity, targetCoords.x, targetCoords.y, targetCoords.z, 2.0, 0, 0, 786603, 0)
                    lastReissueTime = GetGameTimer()
                end

                -- Timeout per clue
                if GetGameTimer() - clueStartTime > clueTimeout and currentHeading then
                    lib.notify({ title = locale('cl_game_treasure_hunt_fail'), description = locale('cl_game_treasure_hunt_fail_desc'), type = 'warning' })
                    ClearPedTasksImmediately(entity)
                    local animSniff = 'amb_creature_mammal@world_dog_sniffing_ground@base'
                    State.PlayPetAnimation(petId, animSniff, 'base', true, gameTreasureConfig.anim.sniAnimTime)
                    Wait(gameTreasureConfig.anim.sniAnimTime)
                    State.ClearPetAnimation(petId)
                    TaskGoToCoordAnyMeans(entity, targetCoords.x, targetCoords.y, targetCoords.z, 2.0, 0, 0, 786603, 0)
                    clueStartTime = GetGameTimer()
                    lastReissueTime = GetGameTimer()
                end
-- Pet too far from player - wait
                if currentHeading and distToPlayer > gameTreasureConfig.maxdistToPlayer then
                    ClearPedTasksImmediately(entity)
                    TaskGoToEntity(entity, cache.ped, -1, 2.0, 2.0, 0, 0)
                    lib.notify({ title = locale('cl_game_treasure_hunt_check'), description = locale('cl_game_treasure_hunt_check_desc'), type = 'warning' })
                   if isMultiPetMode then
                        huntData.headingToTarget = false
                        huntData.waitingForPlayer = true
                    else
                        headingToTarget = false
                        waitingForPlayer = true
                    end

                elseif currentWaiting and distToPlayer <= gameTreasureConfig.mindistToPlayer then
                    ClearPedTasksImmediately(entity)
                    local animGrowl = 'amb_creature_mammal@world_dog_guard_growl@base'
                    State.PlayPetAnimation(petId, animGrowl, 'base', true, gameTreasureConfig.anim.sniAnimTime)
                    Wait(gameTreasureConfig.anim.sniAnimTime)
                    State.ClearPetAnimation(petId)
                    lib.notify({ title = locale('cl_game_treasure_hunt_check_player'), description = locale('cl_game_treasure_hunt_check_player_desc'), type = 'info' })
                    TaskGoToCoordAnyMeans(entity, target.x, target.y, target.z, 2.0, 0, 0, 786603, 0)

                    if isMultiPetMode then
                        huntData.headingToTarget = true
                        huntData.waitingForPlayer = false
                    else
                        headingToTarget = true
                        waitingForPlayer = false
                    end
                    lastReissueTime = GetGameTimer()
                end
            end

            -- Arrived at clue
            if distToTarget < gameTreasureConfig.distToTarget then
                ClearPedTasksImmediately(entity)

                local anim, animTime = getRandomClueAnimation()
                if petId and anim then
                    State.PlayPetAnimation(petId, anim, 'base', true, animTime)
                    Wait(animTime)
                    State.ClearPetAnimation(petId)
                end

                -- Show clue blip if this is the followed pet
                if isFollowedPet and Config.Blip.Clue.ClueBlip then
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

                -- Move to next clue or finish
                if isMultiPetMode then
                    huntData.currentClue = huntData.currentClue + 1
                    if huntData.currentClue > huntData.totalClues then
                        -- Arrived at final destination
                        huntData.hasArrived = true
                        huntData.reachedTime = GetGameTimer()
                        local animDig = 'amb_creature_mammal@world_dog_digging@base'
                        State.PlayPetAnimation(petId, animDig, 'base', true, -1)

                        if selectedPetToFollow == petId then
                            lib.notify({
                                title = locale('cl_multipet_pet_arrived_title'),
                                description = locale('cl_multipet_pet_arrived_desc'),
                                type = 'info'
                            })
                        end
                    else
                        Wait(500)
                        movePetToClue(petId, huntData.currentClue, true)
                    end
                else
                    currentHuntStep = currentHuntStep + 1
                    if currentHuntStep > totalHuntSteps then
                        finishTreasureHunt(entity, petId)
                    else
                        Wait(500)
                        movePetToClue(petId, currentHuntStep, false)
                    end
                end
                break
            end
        end

        -- Timeout notification
        if iterationCount >= maxIterations and not shouldCancel() then
            lib.notify({
                title = locale('cl_treasure_hunt_timeout'),
                description = locale('cl_treasure_hunt_timeout_desc'),
                type = 'error',
                duration = 7000
            })

            if Config.Debug then
                print('^3[TREASURE]^7 ' .. locale('cl_debug_treasure_timed_out'))
            end
            if not isMultiPetMode then
                treasureCleanUp()
            end
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

    -- Validate requirements
    local canStart, errorMsg = validateTreasureRequirements(petId)
    if not canStart then
        lib.notify({ title = locale('cl_error_treasurehunt') or 'Error', description = errorMsg, type = 'error' })
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
        movePetToClue(petId, currentHuntStep, false)
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

    -- Validate requirements for all pets
    local validPets, petCount = getValidPetsForTreasure(activePets)

    if petCount < 2 then
        lib.notify({ title = locale('cl_game_treasure_need_two_pets'), description = locale('cl_error_treasure_hunt_requirement'), type = 'warning' })
        return
    end

    activePets = validPets

    -- Start the hunt immediately - player chooses by approaching a pet
    isTreasureHuntActive = true
    multiPetHuntActive = true
    activeTreasureHunts = {}
    playerFollowingPet = nil
    selectedPetToFollow = nil  -- Will be set when player approaches a pet

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

    -- Generate clue routes for each pet (using the same system as single pet)
    local usedStartDirections = {}

    for petId, petData in pairs(activePets) do
        local petPed = petData.ped
        if not petPed or not DoesEntityExist(petPed) then goto continue end

        -- Generate a unique starting direction for this pet's route
        local validDirection = false
        local startAngle = 0
        local attempts = 0

        while not validDirection and attempts < 20 do
            startAngle = math.random(0, 360)
            local tooClose = true

            -- Check if this direction is far enough from other pets' directions
            if #usedStartDirections == 0 then
                tooClose = false
            else
                tooClose = false
                for _, usedAngle in ipairs(usedStartDirections) do
                    local angleDiff = math.abs(startAngle - usedAngle)
                    if angleDiff > 180 then angleDiff = 360 - angleDiff end
                    if angleDiff < (360 / petCount) * 0.7 then
                        tooClose = true
                        break
                    end
                end
            end

            if not tooClose then
                validDirection = true
                table.insert(usedStartDirections, startAngle)
            end
            attempts = attempts + 1
        end

        -- Generate clue route for this pet
        local numClues = math.random(gameTreasureConfig.minSteps, gameTreasureConfig.maxSteps)

        -- Create a starting point in the pet's unique direction
        local startDist = math.random(gameTreasureConfig.minDistance, gameTreasureConfig.maxDistance)
        local startRad = math.rad(startAngle)
        local startX = playerCoords.x + math.cos(startRad) * startDist
        local startY = playerCoords.y + math.sin(startRad) * startDist
        local foundGround, groundZ = GetGroundZFor_3dCoord(startX, startY, playerCoords.z + 100.0, 0)
        local startZ = foundGround and groundZ or playerCoords.z
        local startPos = vector3(startX, startY, startZ)

        local clueRoute = generateRandomTreasureRoute(startPos, numClues - 1)
        table.insert(clueRoute, 1, startPos) -- Add starting point as first clue

        if #clueRoute > 0 then
            local finalLocation = clueRoute[#clueRoute]

            activeTreasureHunts[petId] = {
                ped = petPed,
                cluePoints = clueRoute,
                totalClues = #clueRoute,
                currentClue = 1,
                targetLocation = finalLocation,
                outcome = outcomes[petId],
                hasArrived = false,
                playerIsNear = false,
                reachedTime = nil,
                headingToTarget = false,
                waitingForPlayer = false
            }

            ClearPedTasks(petPed)
            Wait(50)

            -- Play howl animation before departure
            local animHowl = 'amb_creature_mammal@world_dog_howling_sitting@base'
            State.PlayPetAnimation(petId, animHowl, 'base', true, 3000)

            local currentPetId = petId
            CreateThread(function()
                Wait(3000)
                State.ClearPetAnimation(currentPetId)
                -- Start clue navigation for this pet
                movePetToClue(currentPetId, 1, true)
            end)

            if Config.Debug then
                print(string.format('^2[TREASURE]^7 Pet %s has %d clues, outcome: %s',
                    petId, #clueRoute, outcomes[petId]))
            end
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


            for petId, huntData in pairs(activeTreasureHunts) do
                if State.ShouldThreadContinue(petId) then
                    local distToPlayer = State.GetDistancePlayerToPet(petId)

                    -- Player approaches a pet during navigation - this becomes the followed pet
                    if not selectedPetToFollow and not huntData.hasArrived and distToPlayer < gameTreasureConfig.mindistToPlayer then
                        selectedPetToFollow = petId
                        lib.notify({
                            title = locale('cl_game_treasure_hunt_follow'),
                            description = locale('cl_multipet_pet_arrived_desc'),
                            type = 'info'
                        })

                        -- Set GPS for this pet's current target
                        if Config.Blip.Clue.ClueBlip and huntData.cluePoints[huntData.currentClue] then
                            local target = huntData.cluePoints[huntData.currentClue]
                            if gpsRoute then ClearGpsMultiRoute() end
                            StartGpsMultiRoute(GetHashKey('COLOR_BLUE'), true, true)
                            AddPointToGpsMultiRoute(target.x, target.y, target.z)
                            SetGpsMultiRouteRender(true)
                            gpsRoute = true
                        end
                    end

                    -- Check if player is near an arrived pet
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

                    -- Timeout: pet waited too long at final destination
                    if huntData.hasArrived and not huntData.playerIsNear then
                        local waitTime = GetGameTimer() - huntData.reachedTime
                        if waitTime > 90000 then -- 1.5 minute wait at final location
                            ClearPedTasks(huntData.ped)
                            ManageSpawn.moveCompanionToPlayer(huntData.ped, cache.ped)
                            huntData.playerIsNear = true

                            if petId == selectedPetToFollow then
                                lib.notify({
                                    title = locale('cl_multipet_pet_returned_title') or 'Pet Returned',
                                    description = locale('cl_multipet_pet_returned_desc') or 'Your pet got tired of waiting and came back',
                                    type = 'warning'
                                })
                            end
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

    -- Check if specific pet argument provided
    if args and args[1] then
        local targetPetId, _ = findPetByIdentifier(args[1], activePets)

        if not targetPetId then
            lib.notify({ title = locale('cl_error_no_pet_retrieve_bone'), description = locale('cl_error_pet_not_found') .. ': ' .. args[1], type = 'error' })
            return
        end

        -- Validate requirements for specific pet (returns petData to avoid double State.GetPet call)
        local canStart, errorMsg, petData = validateTreasureRequirements(targetPetId)
        if not canStart then
            lib.notify({ title = locale('cl_error_treasurehunt') or 'Error', description = errorMsg, type = 'error' })
            return
        end

        -- Specific pet treasure hunt
        local petPed = petData and petData.ped or nil
        if petPed and DoesEntityExist(petPed) then
            startTreasureHunt(petPed, targetPetId)
        end
    else
        -- No argument: multi-pet competition if 2+ pets, otherwise single pet
        local validPets, validPetCount = getValidPetsForTreasure(activePets)
        if validPetCount == 0 then
            lib.notify({ title = locale('cl_error_treasurehunt'), description = locale('cl_error_treasure_hunt_requirement'), type = 'error' })
            return
        end

        if validPetCount >= 2 then
            startMultiPetTreasureHunt()
        else
            -- Single pet mode
            for companionid, petData in pairs(validPets) do
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

    -- Validate requirements (returns petData to avoid double State.GetPet call)
    local canStart, errorMsg, petData = validateTreasureRequirements(petId)
    if not canStart then
        lib.notify({ title = locale('cl_error_treasurehunt') or 'Error', description = errorMsg, type = 'error' })
        return
    end
    
    local petPed = petData and petData.ped or nil
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
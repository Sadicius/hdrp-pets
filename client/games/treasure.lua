-- local RSGCore = exports['rsg-core']:GetCoreObject()

-- local State = exports['hdrp-pets']:GetState()
-- local gameHostileConfig = Config.Games.Ghostile
-- local gameBanditConfig = Config.Games.Gbandit
-- local gameTreasureConfig = Config.Games.Gtreasure
-- lib.locale()

-- -- SEARCH TREASURE
-- -- Refactored to support multiple simultaneous pet hunts
-- local activeTreasureHunts = {} -- Track each pet's hunt: [petId] = {currentStep, totalSteps, treasurePoints, isActive, outcome}
-- local isTreasureHuntActive = false -- Global flag to prevent overlapping multi-pet hunts
-- local navigationRoute = nil
-- local playerFollowingPet = nil -- Track which pet player is following
-- local multiPetHuntActive = false -- Flag for multi-pet competition mode
-- local itemProps = {} -- Track props like shovels and treasures
-- if not State.Games then State.Games = {} end
-- if not State.Games.activeTreasureHunts then State.Games.activeTreasureHunts = {} end
-- if not State.Games.treasurePoints then State.Games.treasurePoints = {} end
-- if not State.Games.treasureInProgress then State.Games.treasureInProgress = {} end
-- if not State.Games.currentHuntStep then State.Games.currentHuntStep = {} end
-- if not State.Games.totalHuntSteps then State.Games.totalHuntSteps = {} end

-- local ManageSpawn = require('client.stable.utils_spawn')

-- function isWaterAtCoords(coords)
-- 	local waterTypes = Config.WaterTypes
--     local waterType = Citizen.InvokeNative(0x5BA7A68A346A5A91, coords.x, coords.y, coords.z)
--     for k,v in pairs(waterTypes) do 
--         if waterType == v.waterhash then
--             return true
--         end
--     end
--     return false
-- end

-- -- TREASURE HUNT FUNCTIONS
-- local function checkProximityToTreasure(coords)
--     for _, prop in ipairs(itemProps) do
--         if prop.treasure and DoesEntityExist(prop.treasure) then
--             local treasureCoords = GetEntityCoords(prop.treasure, true)
--             local distance = #(coords - treasureCoords)
--             if distance <= gameTreasureConfig.HoleDistance then
--                 Wait(500)
--                 lib.notify({ title = locale('cl_lang_1'), type = 'info', duration = 7000 })
--                 return true
--             end
--         end
--     end
--     return false
-- end

-- -- HANDLE TREASURE FOUND
-- local function handleTreasureFound(petId)
--     local hostileRoll = math.random(100)
--     local banditRoll = math.random(100)
--     if hostileRoll <= gameHostileConfig.Chance then
--         TriggerEvent('hdrp-pets:client:startHostileEncounter')
--         return 
--     elseif banditRoll <= gameBanditConfig.Chance then
--         TriggerEvent('hdrp-pets:client:startBanditEncounter')
--         return 
--     end

--     local chance = math.random(100)
--     if chance <= gameTreasureConfig.lostTreasure then
--         ManageSpawn.crouchInspectAnim()
--         -- petId is already companionid or nil, pass it correctly
--         TriggerServerEvent('hdrp-pets:server:givexp', Config.XP.Increase.PerTreasure, petId)
--         TriggerServerEvent('hdrp-pets:server:givetreasure')
--         lib.notify({ title = locale('cl_reward'), description = locale('cl_game_treasure_hunt_give_desc'), type = 'success' })
--     else
--         lib.notify({ title = locale('cl_game_treasure_hunt_empty'), type = 'info' })
--     end
-- end

-- local function createShovelAndAttach()
--     local playerCoords = GetEntityCoords(cache.ped)
--     local boneIndex = GetEntityBoneIndexByName(cache.ped, 'SKEL_R_Hand')

--     if not lib.requestModel(`p_shovel02x`, 5000) then
--         print('^1[TREASURE]^7 ' .. locale('cl_debug_treasure_failed_shovel_model'))
--         return nil
--     end
--     local shovelObject = CreateObject(`p_shovel02x`, playerCoords, true, true, true)
--     table.insert(itemProps, { shovel = shovelObject })

--     SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)
--     AttachEntityToEntity(shovelObject, cache.ped, boneIndex,
--         0.0, -0.19, -0.089,
--         274.1899, 483.89, 378.40,
--         true, true, false, true, 1, true
--     )
--     return shovelObject
-- end

-- local function cleanUpTreasure(treasureObject)
--     SetEntityAsNoLongerNeeded(treasureObject)
--     CreateThread(function()
--         Wait(gameTreasureConfig.AutoDelete)
--         if treasureObject and DoesEntityExist(treasureObject) then
--             DeleteObject(treasureObject)
--             -- Más eficiente: iterar en reversa para remover elementos
--             for i = #itemProps, 1, -1 do
--                 if itemProps[i].treasure == treasureObject then
--                     table.remove(itemProps, i)
--                     break
--                 end
--             end
--         end
--     end)
-- end

-- -- LOGIC FUNCTIONS
-- local function showSkillCheckShovel(entity, petId)
--     local coords = GetEntityCoords(entity, true)

--     if checkProximityToTreasure(coords) then return end
--     if State.Games.treasureInProgress[petId] then return end

--     State.Games.treasureInProgress[petId] = true
--     local waitrand = math.random(10000, 25000)
--     local treasureModel = 'mp005_p_dirtpile_tall_unburied'
    
--     if not lib.requestModel(treasureModel, 5000) then
--         print('^1[TREASURE]^7 ' .. locale('cl_debug_treasure_failed_treasure_model'))
--         isTreasure = false
--         return
--     end

--     local animDict = 'amb_work@world_human_gravedig@working@male_b@base'
--     if not lib.requestAnimDict(animDict, 5000) then
--         print('^1[TREASURE]^7 ' .. locale('cl_debug_treasure_failed_dig_anim'))
--         isTreasure = false
--         return
--     end

--     local shovelObject = createShovelAndAttach()
--     if not shovelObject then
--         isTreasure = false
--         return
--     end

--     FreezeEntityPosition(cache.ped, true)
--     TaskPlayAnim(cache.ped, animDict, 'base', 3.0, 3.0, -1, 1, 0, false, false, false)
--     Wait(waitrand)

--     local playerCoords = GetEntityCoords(cache.ped)
--     local playerForwardVector = GetEntityForwardVector(cache.ped)
--     local offsetX = 0.6
--     local objectX = playerCoords.x + playerForwardVector.x * offsetX
--     local objectY = playerCoords.y + playerForwardVector.y * offsetX
--     local objectZ = playerCoords.z - 1

--     local treasureObject = CreateObject(treasureModel, objectX, objectY, objectZ, true, true, false)
--     table.insert(itemProps, { treasure = treasureObject })

--     handleTreasureFound(petId)

--     State.ResetPlayerState(true)

--     if DoesEntityExist(shovelObject) then DeleteObject(shovelObject) end

--     State.Games.treasureInProgress[petId] = false

--     cleanUpTreasure(treasureObject)

--     treasureInProgress = false
--     treasurePoints = {}
--     currentHuntStep = 0
--     totalHuntSteps = 0
-- end

-- local function finishTreasureHunt(entity, petId)
--     lib.notify({ title = locale('cl_game_treasure_hunt_started'), description = locale('cl_game_treasure_hunt_started_desc'), type = 'success' })
--     local animDig = 'amb_creature_mammal@world_dog_digging@base'
--     if not petId then
--         local petData, resolvedPetId = State.GetPetByEntity(entity)
--         petId = resolvedPetId
--     end
--     if petId then
--         State.PlayPetAnimation(petId, animDig, 'base', true, gameTreasureConfig.digAnimTime)
--         Wait(gameTreasureConfig.digAnimTime)
--         State.ClearPetAnimation(petId)
--     end

--     if gameTreasureConfig.DoMiniGame then
--         if gameTreasureConfig.MiniGameShovel then
--             showSkillCheckShovel(entity, petId)
--             return
--         else
--             local success = lib.skillCheck({{areaSize = 50, speedMultiplier = 0.5}}, {'w', 'a', 's', 'd'})
--             if not success then
--                 local numberGenerator = math.random(1, 100)
--                 if numberGenerator <= tonumber(gameTreasureConfig.lostTreasure) then
--                     treasureInProgress = false
--                     treasurePoints = {}
--                     currentHuntStep = 0
--                     totalHuntSteps = 0
--                 end
--                 SetPedToRagdoll(cache.ped, 1000, 1000, 0, 0, 0, 0)
--                 Wait(1000)
--                 State.ResetPlayerState()
--                 return
--             end
--         end
--     end

--     handleTreasureFound(petId)

--     State.Games.treasureInProgress[petId] = false
--     State.Games.treasurePoints[petId] = {}
--     State.Games.currentHuntStep[petId] = 0
--     State.Games.totalHuntSteps[petId] = 0
-- end

-- -- MOVE TO CLUE
-- local function moveToClue(index, entity)
--     if not entity or not DoesEntityExist(entity) then return end
--     if not treasurePoints[index] then return end

--     local target = treasurePoints[index]
--     local targetCoords = vector3(target.x, target.y, target.z)

--     if Config.Blip.Clue.ClueBlip then
--         if gpsRoute then ClearGpsMultiRoute() end
--         StartGpsMultiRoute(GetHashKey('COLOR_BLUE'), true, true)
--         AddPointToGpsMultiRoute(targetCoords.x, targetCoords.y, targetCoords.z)
--         SetGpsMultiRouteRender(true)
--         gpsRoute = true
--     end

--     headingToTarget = true
--     waitingForPlayer = false

--     TaskGoToCoordAnyMeans(entity, target.x, target.y, target.z, 2.0, 0, 0, 786603, 0)

--     lib.notify({title = locale('cl_game_treasure_hunt_follow'),description = string.format(locale('cl_game_treasure_hunt_follow_desc')..' %d '..locale('cl_game_treasure_hunt_follow_desc2')..' %d', index, totalHuntSteps), type = 'info'})

--     local animHowl = 'amb_creature_mammal@world_dog_howling_sitting@base'
--     ClearPedTasksImmediately(entity)
--     local petData, petId = State.GetPetByEntity(entity)
--     if petId then
--         State.PlayPetAnimation(petId, animHowl, 'base', true, 3000)
--         Wait(3000)
--         State.ClearPetAnimation(petId)
--     end

--     TaskGoToCoordAnyMeans(entity, target.x, target.y, target.z, 2.0, 0, 0, 786603, 0)

--     if Config.Debug then
--         print(locale('cl_print_treasurehunt_move')..' ' .. index)
--     end

--     CreateThread(function()
--         local step = index
--         local lastReissueTime = GetGameTimer()
--         local clueStartTime = GetGameTimer()
--         local clueTimeout = 120000  -- FIX: Reduced from 1200000 to 120000 (2 minutes per clue)
--         local maxIterations = 120  -- FIX: Reduced from 300 to 120 (2 minutes total per clue)
--         local iterationCount = 0
        
--         -- FIX: Add manual cancellation detection
--         local function shouldCancel()
--             return not treasureInProgress or 
--                    not entity or 
--                    not DoesEntityExist(entity) or 
--                    IsEntityDead(entity) or
--                    IsEntityDead(cache.ped)
--         end

--         while treasureInProgress and currentHuntStep == step and iterationCount < maxIterations do
--             -- FIX: Check cancel conditions
--             if shouldCancel() then 
--                 if Config.Debug then
--                     print('^3[TREASURE]^7 ' .. locale('cl_debug_treasure_cancelled_conditions'))
--                 end
--                 treasureInProgress = false
--                 return 
--             end
            
--             iterationCount = iterationCount + 1
--             Wait(1000)

--             local dogPos = GetEntityCoords(entity)
--             local playerPos = GetEntityCoords(cache.ped)
--             local distToTarget = #(dogPos - target)
--             local distToPlayer = #(dogPos - playerPos)

--             if GetGameTimer() - lastReissueTime > 10000 and headingToTarget then
--                 if Config.Debug then
--                     print(locale('cl_print_treasurehunt_move_b'))
--                 end
--                 TaskGoToCoordAnyMeans(entity, targetCoords.x, targetCoords.y, targetCoords.z, 2.0, 0, 0, 786603, 0)
--                 lastReissueTime = GetGameTimer()
--             end

--             if GetGameTimer() - clueStartTime > clueTimeout and headingToTarget then
--                 lib.notify({ title = locale('cl_game_treasure_hunt_fail'), description = locale('cl_game_treasure_hunt_fail_desc'), type = 'warning' })
--                 ClearPedTasksImmediately(entity)
--                 local animSniff = 'amb_creature_mammal@world_dog_sniffing_ground@base'
--                 local petData, petId = State.GetPetByEntity(entity)
--                 if petId then
--                     State.PlayPetAnimation(petId, animSniff, 'base', true, gameTreasureConfig.sniAnimTime)
--                     Wait(gameTreasureConfig.sniAnimTime)
--                     State.ClearPetAnimation(petId)
--                 end
--                 TaskGoToCoordAnyMeans(entity, targetCoords.x, targetCoords.y, targetCoords.z, 2.0, 0, 0, 786603, 0)
--                 clueStartTime = GetGameTimer()
--                 lastReissueTime = GetGameTimer()
--             end

--             if headingToTarget and distToPlayer > gameTreasureConfig.maxdistToPlayer then
--                 ClearPedTasksImmediately(entity)
--                 TaskGoToEntity(entity, cache.ped, -1, 2.0, 2.0, 0, 0)
--                 lib.notify({ title = locale('cl_game_treasure_hunt_check'), description = locale('cl_game_treasure_hunt_check_desc'), type = 'warning' })
--                 headingToTarget = false
--                 waitingForPlayer = true

--             elseif waitingForPlayer and distToPlayer <= gameTreasureConfig.mindistToPlayer then
--                 ClearPedTasksImmediately(entity)

--                 local animGrowl = 'amb_creature_mammal@world_dog_guard_growl@base'
--                 local petData, petId = State.GetPetByEntity(entity)
--                 if petId then
--                     State.PlayPetAnimation(petId, animGrowl, 'base', true, gameTreasureConfig.sniAnimTime)
--                     Wait(gameTreasureConfig.sniAnimTime)
--                     State.ClearPetAnimation(petId)
--                 end
--                 lib.notify({ title = locale('cl_game_treasure_hunt_check_player'), description = locale('cl_game_treasure_hunt_check_player_desc'), type = 'info' })
--                 TaskGoToCoordAnyMeans(entity, target.x, target.y, target.z, 2.0, 0, 0, 786603, 0)
--                 headingToTarget = true
--                 waitingForPlayer = false
--                 lastReissueTime = GetGameTimer()
--             end

--             if distToTarget < gameTreasureConfig.distToTarget then
--                 ClearPedTasksImmediately(entity)
--                 local roll = math.random(1, 100)

--                 local petData, petId = State.GetPetByEntity(entity)
--                 if roll <= 25 then
--                     local anim = 'amb_creature_mammal@world_dog_howling_sitting@base'
--                     if petId  then
--                         State.PlayPetAnimation(petId, anim, 'base', true, gameTreasureConfig.anim.howAnimTime)
--                         Wait(gameTreasureConfig.anim.howAnimTime)
--                         State.ClearPetAnimation(petId)
--                     end
--                 elseif roll <= 50 then
--                     local anim = 'amb_creature_mammal@world_dog_sniffing_ground@base'
--                     if petId  then
--                         State.PlayPetAnimation(petId, anim, 'base', true, gameTreasureConfig.anim.clueWaitTime)
--                         Wait(gameTreasureConfig.anim.clueWaitTime)
--                         State.ClearPetAnimation(petId)
--                     end
--                 elseif roll <= 75 then
--                     local anim = 'amb_creature_mammal@world_dog_guard_growl@base'
--                     if petId  then
--                         State.PlayPetAnimation(petId, anim, 'base', true, gameTreasureConfig.anim.guaAnimTime)
--                         Wait(gameTreasureConfig.anim.guaAnimTime)
--                         State.ClearPetAnimation(petId)
--                     end
--                 else
--                     local anim = 'amb_creature_mammal@world_dog_digging@base'
--                     if petId  then
--                         State.PlayPetAnimation(petId, anim, 'base', true, gameTreasureConfig.anim.clueWaitTime)
--                         Wait(gameTreasureConfig.anim.clueWaitTime)
--                         State.ClearPetAnimation(petId)
--                     end
--                 end

--                 if Config.Blip.Clue.ClueBlip then
--                     ClearGpsMultiRoute()
--                     gpsRoute = nil
--                     -- Create a temporary blip
--                     local ClueBlip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, targetCoords.x, targetCoords.y, targetCoords.z)
--                     Citizen.InvokeNative(0x662D364ABF16DE2F, ClueBlip, Config.Blip.ColorModifier)
--                     SetBlipSprite(ClueBlip, Config.Blip.Clue.blipSprite, true)
--                     SetBlipScale(ClueBlip, Config.Blip.Clue.blipScale)
--                     Citizen.InvokeNative(0x45FF974EEA1DCE36, ClueBlip, true)
--                     Citizen.InvokeNative(0x9CB1A1623062F402, ClueBlip, Config.Blip.Clue.blipName)

--                     lib.notify({ title = locale('cl_game_treasure_hunt_find'), description = locale('cl_game_treasure_hunt_find_desc'), type = 'success', duration = 5000 })

--                     CreateThread(function() 
--                         Wait(Config.Blip.Clue.blipTime) 
--                         if ClueBlip and DoesBlipExist(ClueBlip) then RemoveBlip(ClueBlip) end 
--                     end)
--                     if prop.treasure and DoesEntityExist(prop.treasure) then
--                         currentHuntStep = currentHuntStep + 1
--                     end
--                 end

--                 if currentHuntStep > totalHuntSteps then
--                     finishTreasureHunt(entity, nil)
--                 else
--                     Wait(500)
--                     moveToClue(currentHuntStep, entity)
--                 end
--                 break
--             end
--         end
        
--         -- FIX: Add timeout notification if max iterations reached
--         if iterationCount >= maxIterations and treasureInProgress then
--             lib.notify({ 
--                 title = locale('cl_treasure_hunt_timeout'), 
--                 description = locale('cl_treasure_hunt_timeout_desc'), 
--                 type = 'error',
--                 duration = 7000
--             })
            
--             print('^3[TREASURE]^7 ' .. locale('cl_debug_treasure_timed_out'))
--         end
--     end)
-- end

-- -- GENERATE RANDOM TREASURE ROUTE
-- local function generateRandomTreasureRoute(startPos, steps)
--     local route = {}
--     local lastPos = startPos

--     -- Define restricted zones (cities, rivers, etc.)
--     local restrictedZones = {
--         {name = "Valentine", coords = vector3(-306.0, 792.0, 118.0), radius = 150.0},
--         {name = "Blackwater", coords = vector3(-813.0, -1324.0, 43.0), radius = 200.0},
--         {name = "Rhodes", coords = vector3(1346.0, -1312.0, 76.0), radius = 150.0},
--         {name = "Saint Denis", coords = vector3(2632.0, -1312.0, 52.0), radius = 300.0},
--         {name = "Strawberry", coords = vector3(-1803.0, -386.0, 160.0), radius = 120.0},
--         {name = "Annesburg", coords = vector3(2930.0, 1288.0, 44.0), radius = 120.0},
--         {name = "Armadillo", coords = vector3(-3685.0, -2562.0, -13.0), radius = 130.0},
--         {name = "Tumbleweed", coords = vector3(-5512.0, -2937.0, -2.0), radius = 130.0},
--         {name = "Van Horn", coords = vector3(2976.0, 544.0, 44.0), radius = 100.0},
--     }

--     local function isInRestrictedZone(point)
--         for _, zone in ipairs(restrictedZones) do
--             local distance = #(vector3(point.x, point.y, point.z) - zone.coords)
--             if distance < zone.radius then
--                 return true, zone.name
--             end
--         end
--         return false
--     end

--     for i = 1, steps do
        
--         local validPoint = false
--         local newPoint
--         local loopAttempts = 0
--         local maxAttempts = 100  -- FIX: Define max attempts to prevent infinite loop

--         -- FIX: Added protection against infinite loop
--         while not validPoint and loopAttempts < maxAttempts do
--             local dist = math.random(gameTreasureConfig.minDistance, gameTreasureConfig.maxDistance)
--             local angle = math.rad(math.random(0, 360))
--             local offsetX = math.cos(angle) * dist
--             local offsetY = math.sin(angle) * dist
--             local newX = lastPos.x + offsetX
--             local newY = lastPos.y + offsetY

--             local foundGround, groundZ = GetGroundZFor_3dCoord(newX, newY, lastPos.z + 100.0, 0)
--             local newZ = foundGround and groundZ or lastPos.z

--             newPoint = vector3(newX, newY, newZ)
            
--             -- Check water, restricted zones, and interior
--             local inWater = isWaterAtCoords(newPoint)
--             local inRestricted, zoneName = isInRestrictedZone(newPoint)
--             local inInterior = GetInteriorFromEntity(cache.ped) ~= 0
            
--             if not inWater and not inRestricted and not inInterior then
--                 validPoint = true
--             else
--                 if Config.Debug and inRestricted then
--                     print(string.format('^3[TREASURE]^7 ' .. locale('cl_debug_treasure_point_rejected'), zoneName))
--                 end
--             end
            
--             loopAttempts = loopAttempts + 1
--         end

--         -- FIX: If no valid point found after max attempts, break and use existing route
--         if validPoint and newPoint then
--             table.insert(route, newPoint)
--             lastPos = newPoint
--         else
--             if Config.Debug then 
--                 print(string.format('^3[TREASURE]^7 ' .. locale('debug_treasure_no_valid_coord') .. ' (attempts: %d)', loopAttempts)) 
--             end
--             -- Break loop to prevent continuing with invalid data
--             break
--         end
--     end

--     if Config.Debug then 
--         print(string.format('^2[TREASURE]^7 ' .. locale('cl_print_treasurehunt_route'), #route, locale('cl_print_treasurehunt_route_b'))) 
--     end
    
--     return route
-- end

-- -- MULTI-PET TREASURE HUNT SYSTEM
-- local function startMultiPetTreasureHunt()
--     if isTreasureHuntActive then 
--         lib.notify({ title = locale('cl_game_treasure_hunt_in_progress'), type = 'error' }) 
--         return 
--     end

--     local activePets = State.GetAllPets()
--     if not next(activePets) then
--         lib.notify({ title = locale('cl_error_no_pet_retrieve_bone'), type = 'error' })
--         return
--     end

--     local petCount = 0
--     for _ in pairs(activePets) do petCount = petCount + 1 end

--     if petCount < 2 then
--         lib.notify({ title = locale('cl_game_treasure_need_two_pets'), type = 'warning' })
--         return
--     end

--     isTreasureHuntActive = true
--     multiPetHuntActive = true
--     activeTreasureHunts = {}
--     playerFollowingPet = nil

--     local playerCoords = GetEntityCoords(cache.ped)
    
--     -- Randomly select ONE pet to have the correct treasure
--     local petIds = {}
--     for id in pairs(activePets) do table.insert(petIds, id) end
--     local winnerPetId = petIds[math.random(#petIds)]

--     -- Assign outcomes to each pet
--     local outcomes = {}
--     for id in pairs(activePets) do
--         if id == winnerPetId then
--             outcomes[id] = 'treasure' -- Only this pet leads to actual treasure
--         else
--             -- Others lead to hostile or bandit encounters
--             if math.random(100) <= 50 then
--                 outcomes[id] = 'hostile'
--             else
--                 outcomes[id] = 'bandit'
--             end
--         end
--     end

--     lib.notify({ 
--         title = '🗺️ ' .. locale('cl_multipet_treasure_started_title'), 
--         description = locale('cl_multipet_treasure_started_desc'),
--         type = 'success'
--     })

--     -- Generate different single-location destination for each pet
--     local usedLocations = {}
--     local locationSpread = 150.0 -- Minimum distance between pet destinations
    
--     for petId, petPed in pairs(activePets) do
--         local validLocation = false
--         local targetLocation = nil
--         local attempts = 0
--         local maxAttempts = 50

--         while not validLocation and attempts < maxAttempts do
--             local dist = math.random(100, 250) -- Distance from player
--             local angle = math.rad(math.random(0, 360))
--             local offsetX = math.cos(angle) * dist
--             local offsetY = math.sin(angle) * dist
--             local newX = playerCoords.x + offsetX
--             local newY = playerCoords.y + offsetY

--             local foundGround, groundZ = GetGroundZFor_3dCoord(newX, newY, playerCoords.z + 100.0, 0)
--             local newZ = foundGround and groundZ or playerCoords.z

--             targetLocation = vector3(newX, newY, newZ)

--             -- Check if far enough from other pet locations
--             local tooClose = false
--             for _, usedLoc in ipairs(usedLocations) do
--                 if #(targetLocation - usedLoc) < locationSpread then
--                     tooClose = true
--                     break
--                 end
--             end
            
--             -- Validate location (no water, no restricted zones)
--             if not tooClose and not isWaterAtCoords(targetLocation) then
--                 validLocation = true
--                 table.insert(usedLocations, targetLocation)
--             end

--             attempts = attempts + 1
--         end

--         if validLocation and targetLocation then
--             -- Store hunt data for this pet
--             activeTreasureHunts[petId] = {
--                 ped = petPed,
--                 targetLocation = targetLocation,
--                 outcome = outcomes[petId],
--                 hasArrived = false,
--                 playerIsNear = false,
--                 reachedTime = nil
--             }

--             -- Send pet to its destination
--             ClearPedTasks(petPed)
--             Wait(50)

--             -- Play howl animation before departure
--             local animHowl = 'amb_creature_mammal@world_dog_howling_sitting@base'
--             State.PlayPetAnimation(petId, animHowl, 'base', true, 3000)

--             CreateThread(function()
--                 Wait(3000)
--                 State.ClearPetAnimation(petId)
--                 TaskGoToCoordAnyMeans(petPed, targetLocation.x, targetLocation.y, targetLocation.z, 2.5, 0, 0, 786603, 0)
--             end)
--         end
--     end

--     -- Start monitoring thread for all pets
--     CreateThread(function()
--         local globalTimeout = GetGameTimer() + 300000 -- 5 minutes total
        
--         while multiPetHuntActive and GetGameTimer() < globalTimeout do
--             Wait(1000)

--             if IsEntityDead(cache.ped) then
--                 multiPetHuntActive = false
--                 break
--             end

--             local playerPos = GetEntityCoords(cache.ped)
--             local closestPet = nil
--             local closestDist = math.huge

--             -- Check each pet's status
--             for petId, huntData in pairs(activeTreasureHunts) do
--                 if DoesEntityExist(huntData.ped) and not IsEntityDead(huntData.ped) then
--                     local petPos = GetEntityCoords(huntData.ped)
--                     local distToTarget = #(petPos - huntData.targetLocation)
--                     local distToPlayer = #(petPos - playerPos)

--                     -- Reissue task if stuck
--                     if not huntData.hasArrived and distToTarget > 5.0 then
--                         local taskStatus = GetScriptTaskStatus(huntData.ped, 0x8AA1593C)
--                         if taskStatus ~= 1 and taskStatus ~= 0 then
--                             TaskGoToCoordAnyMeans(huntData.ped, huntData.targetLocation.x, huntData.targetLocation.y, huntData.targetLocation.z, 2.5, 0, 0, 786603, 0)
--                         end
--                     end

--                     -- Pet arrived at destination
--                     if not huntData.hasArrived and distToTarget < 5.0 then
--                         huntData.hasArrived = true
--                         huntData.reachedTime = GetGameTimer()
--                         State.ClearPetAnimation(petId)

--                         -- Play digging animation
--                         local animDig = 'amb_creature_mammal@world_dog_digging@base'
--                         State.PlayPetAnimation(petId, animDig, 'base', true, -1)

--                         lib.notify({ 
--                             title = '🐾 ' .. locale('cl_multipet_pet_arrived_title'), 
--                             description = locale('cl_multipet_pet_arrived_desc'), 
--                             type = 'info' 
--                         })
--                     end

--                     -- Check if player is near arrived pet
--                     if huntData.hasArrived and distToPlayer < 15.0 then
--                         if not huntData.playerIsNear then
--                             huntData.playerIsNear = true
--                             playerFollowingPet = petId

--                             -- Trigger outcome based on pet
--                             ClearPedTasksImmediately(huntData.ped)
                            
--                             if huntData.outcome == 'treasure' then
--                                 lib.notify({ 
--                                     title = '💎 ' .. locale('cl_multipet_treasure_found_title'), 
--                                     description = locale('cl_multipet_treasure_found_desc'), 
--                                     type = 'success',
--                                     duration = 7000
--                                 })
--                                 Wait(1000)
--                                 finishTreasureHunt(huntData.ped, petId)
--                             elseif huntData.outcome == 'hostile' then
--                                 lib.notify({ 
--                                     title = '⚠️ ' .. locale('cl_multipet_hostile_title'), 
--                                     description = locale('cl_multipet_hostile_desc'), 
--                                     type = 'warning',
--                                     duration = 5000
--                                 })
--                                 Wait(1000)
--                                 TriggerEvent('hdrp-pets:client:startHostileEncounter')
--                             elseif huntData.outcome == 'bandit' then
--                                 lib.notify({ 
--                                     title = '⚠️ ' .. locale('cl_multipet_bandit_title'), 
--                                     description = locale('cl_multipet_bandit_desc'), 
--                                     type = 'warning',
--                                     duration = 5000
--                                 })
--                                 Wait(1000)
--                                 TriggerEvent('hdrp-pets:client:startBanditEncounter')
--                             end

--                             -- End multi-pet hunt
--                             multiPetHuntActive = false
                            
--                             -- Send other pets back to player
--                             for otherId, otherData in pairs(activeTreasureHunts) do
--                                 if otherId ~= petId and DoesEntityExist(otherData.ped) then
--                                     ClearPedTasks(otherData.ped)
--                                     ManageSpawn.moveCompanionToPlayer(otherData.ped, cache.ped)
--                                 end
--                             end
                            
--                             break
--                         end
--                     end

--                     -- Timeout: pet waited too long, return to player
--                     if huntData.hasArrived and not huntData.playerIsNear then
--                         local waitTime = GetGameTimer() - huntData.reachedTime
--                         if waitTime > 60000 then -- 1 minute wait
--                             ClearPedTasks(huntData.ped)
--                             ManageSpawn.moveCompanionToPlayer(huntData.ped, cache.ped)
--                             huntData.playerIsNear = true -- Prevent re-triggering
--                         end
--                     end

--                     -- Track closest pet for debug
--                     if distToPlayer < closestDist then
--                         closestDist = distToPlayer
--                         closestPet = petId
--                     end
--                 end
--             end

--             if not multiPetHuntActive then
--                 break
--             end
--         end

--         -- Cleanup if timeout reached
--         if GetGameTimer() >= globalTimeout then
--             lib.notify({ 
--                 title = '⏰ ' .. locale('cl_treasure_hunt_timeout'), 
--                 description = locale('cl_treasure_hunt_timeout_desc'), 
--                 type = 'error' 
--             })
--             for petId, huntData in pairs(activeTreasureHunts) do
--                 if DoesEntityExist(huntData.ped) then
--                     ClearPedTasks(huntData.ped)
--                     ManageSpawn.moveCompanionToPlayer(huntData.ped, cache.ped)
--                 end
--             end
--         end

--         isTreasureHuntActive = false
--         multiPetHuntActive = false
--         activeTreasureHunts = {}
--         playerFollowingPet = nil
--     end)
-- end

-- function startTreasureHunt(entity, petId)
--     -- Single-pet treasure hunt (classic mode)
--     if treasureInProgress then lib.notify({ title = locale('cl_game_treasure_hunt_in_progress'), type = 'error' }) return end
--     if not entity or not DoesEntityExist(entity) or IsEntityDead(cache.ped) then lib.notify({ title = locale('cl_error_treasurehunt'), description = locale('cl_error_treasurehunt_des'), type = 'error' }) return end

--     treasureInProgress = true
--     isTreasureHuntActive = true
--     currentHuntStep = 1
--     totalHuntSteps = math.random(gameTreasureConfig.minSteps, gameTreasureConfig.maxSteps)

--     local playerCoords = GetEntityCoords(cache.ped)
--     treasurePoints = generateRandomTreasureRoute(playerCoords, totalHuntSteps)
--     if next(treasurePoints) then
--         moveToClue(currentHuntStep, entity)
--     else
--         lib.notify({ title = locale('cl_treasure_error_title'), description = locale('cl_treasure_error_desc'), type = 'error' })
--         treasureInProgress = false
--             lib.notify({ 
--                 title = '🗺️ ' .. locale('cl_multipet_treasure_started_title'), 
--                 description = locale('cl_multipet_treasure_started_desc'), 
--                 type = 'info',
--                 duration = 7000
--             })
--         if v.treasure and DoesEntityExist(v.treasure) then
--             SetEntityAsNoLongerNeeded(v.treasure)
--             DeleteEntity(v.treasure)
--             itemProps[k] = nil
--         end
--         if v.shovel and DoesEntityExist(v.shovel) then
--             SetEntityAsNoLongerNeeded(v.shovel)
--             DeleteObject(v.shovel)
--             itemProps[k] = nil
--         end
--     end

--     ClearGpsMultiRoute()
--     gpsRoute = nil

--     State.ResetPlayerState(true)
--     isTreasure = false

--     treasureInProgress = false
--     treasurePoints = {}
--     currentHuntStep = 0
--     totalHuntSteps = 0
    
--     -- Multi-pet cleanup
--     isTreasureHuntActive = false
--     multiPetHuntActive = false
--     activeTreasureHunts = {}
--     playerFollowingPet = nil
-- end

-- -- FIX: Add command to manually cancel stuck treasure hunts
-- RegisterCommand('pet_treasure_cancel', function()
--     if treasureInProgress then
--         lib.notify({ 
--             title = locale('cl_treasure_hunt_cancelled'), 
--             description = locale('cl_treasure_hunt_cancelled_desc'), 
--             type = 'info' 
--         })
--         treasureCleanUp()
--         local closestPet = State.GetClosestPet()
--         local petPed = closestPet and closestPet.ped or nil
--         if petPed and DoesEntityExist(petPed) then
--             ClearPedTasksImmediately(petPed)
--         end
--     else
--         lib.notify({ 
--             title = locale('cl_treasure_hunt_no_active'), 
--             description = locale('cl_treasure_hunt_no_active_desc'), 
--             type = 'error' 
--         })
--     end
-- end, false)

-- exports('TreasureHunt', function(data) startTreasureHunt(data) end)

-- -- COMMANDS
-- RegisterCommand('pet_treasure', function(source, args)
--     if isTreasureHuntActive then
--         lib.notify({ title = locale('cl_game_treasure_hunt_in_progress'), type = 'error' })
--         return
--     end

--     local activePets = State.GetAllPets()
--     if not next(activePets) then
--         lib.notify({ title = locale('cl_error_no_pet_retrieve_bone'), type = 'error' })
--         return
--     end

--     local targetPetId = nil
    
--     -- Check if pet argument is provided
--     if args and args[1] then
--         local searchTerm = string.lower(args[1])
        
--         -- Try to find pet by name or ID
--         for id, ped in pairs(activePets) do
--             if tostring(id) == searchTerm then
--                 targetPetId = id
--                 break
--             end
--             -- Try to get pet name from database
--             if GetCompanionById then
--                 GetCompanionById(id, function(data)
--                     if data and data.name and string.lower(data.name):find(searchTerm, 1, true) then
--                         targetPetId = id
--                     end
--                 end)
--             end
--         end
        
--         if not targetPetId then
--             lib.notify({ title = locale('cl_error_no_pet_retrieve_bone'), description = locale('cl_error_pet_not_found') .. ': ' .. args[1], type = 'error' })
--             return
--         end
        
--         -- Mode 3: Specific pet treasure hunt
--         local petData = State.GetPet(targetPetId)
--         local petPed = petData and petData.ped or nil
--         if petPed and DoesEntityExist(petPed) then
--             startTreasureHunt(petPed, targetPetId)
--         end
--     else
--         -- Mode 1: Multi-pet competition
--         local petCount = 0
--         for _ in pairs(activePets) do petCount = petCount + 1 end
        
--         if petCount >= 2 then
--             startMultiPetTreasureHunt()
--         else
--             -- Only one pet, use classic mode
--             for companionid, petData in pairs(activePets) do
--                 if petData and petData.spawned and DoesEntityExist(petData.ped) then
--                     startTreasureHunt(petData.ped, nil)
--                 end
--             end
--             --[[ LEGACY: fallback to single-pet logic
--             local petPed = State.GetFirstPetPed()
--             if petPed and DoesEntityExist(petPed) then
--                 startTreasureHunt(petPed, nil)
--             end
--             -- END LEGACY ]]
--         end
--     end
-- end, false)

-- -- EVENT FROM MENU
-- RegisterNetEvent('hdrp-pets:client:startTreasureHunt')
-- AddEventHandler('hdrp-pets:client:startTreasureHunt', function(petId)
--     -- Mode 2: Specific pet from menu
--     if isTreasureHuntActive then
--         lib.notify({ title = locale('cl_game_treasure_hunt_in_progress'), type = 'error' })
--         return
--     end

--     local petPed = nil
--     if petId then
--         local petData = State.GetPet(petId)
--         petPed = petData and petData.ped or nil
--     end

--     if petPed and DoesEntityExist(petPed) then
--         startTreasureHunt(petPed, petId)
--     else
--         lib.notify({ title = locale('cl_error_treasurehunt'), description = locale('cl_error_treasurehunt_des'), type = 'error' })
--     end
-- end)

-- -- STOP RESOURCE
-- AddEventHandler('onResourceStop', function(resource)
--     if GetCurrentResourceName() ~= resource then return end
--     -- treasureCleanUp()
-- end)
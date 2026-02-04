local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
local gameBonesConfig = Config.Games.Gbones
local gameBuriedConfig = Config.Games.Gburied
local gameDigRandomConfig = Config.Games.Gdigrandom
local ManageSpawn = lib.load('client.stable.utils_spawn')

-- HIDE & SEARCH BONE
local isRetrieving = false
local buriedBoneCoords = nil

RegisterNetEvent("hdrp-pets:client:buryBone", function()
    
    -- Buscar la mascota más cercana y válida (spawneada y viva)
    local closestPet, _, petId = State.GetClosestPet()
    local petPed = closestPet and closestPet.ped or nil
    if not petPed or not DoesEntityExist(petPed) or IsEntityDead(cache.ped) or IsEntityDead(petPed) then return end
    lib.notify({ title = locale('cl_buried'), description = locale('cl_buried_des'), type = 'info' })

    State.PlayPetAnimation(petId, "amb_creature_mammal@world_dog_sitting@base", "base", true, -1)
    
    SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)
    State.ResetPlayerState()
    lib.notify({ title = locale('cl_buried_time'), description = locale('cl_buried_time_des'), type = 'info', duration = gameBuriedConfig.time + 2000 })

    Wait(gameBuriedConfig.time)
    if gameBuriedConfig.DoMiniGame then
        local success = lib.skillCheck({{areaSize = 50, speedMultiplier = 0.5}}, {'w', 'a', 's', 'd'})
        if not success then
            local numberGenerator = math.random(1, 100)

            if numberGenerator <= tonumber(gameBuriedConfig.lostBone) then
                TriggerServerEvent("hdrp-pets:server:removeitem", Config.Items.Bone)
                buriedBoneCoords = nil
                lib.notify({ title = locale('cl_lost_bone'), type = 'error' })
            end

            SetPedToRagdoll(cache.ped, 1000, 1000, 0, 0, 0, 0)
            Wait(1000)
            State.ResetPlayerState()
            return
        end
    end

    local coords = GetEntityCoords(cache.ped)
    -- Obtener la altura correcta del suelo para que la mascota pueda llegar
    local foundGround, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 10.0, false)
    if foundGround then
        coords = vector3(coords.x, coords.y, groundZ)
    end
    ManageSpawn.crouchInspectAnim()

    TriggerServerEvent("hdrp-pets:server:removeitem", Config.Items.Bone)
    lib.notify({ title = locale('cl_buried_player'), description = locale('cl_buried_player_des'), type = 'info' })

    Wait(5000)

    buriedBoneCoords = coords
    lib.notify({ title = locale('cl_buried_hide'), description = locale('cl_buried_hide_des'), type = 'success' })
end)

RegisterNetEvent("hdrp-pets:client:findBuriedBone", function(targetPetId)
    if not buriedBoneCoords then 
        lib.notify({ title = locale('cl_error_buried_hide'), description = locale('cl_error_buried_hide_des'), type = 'error' }) 
        return 
    end

    if IsEntityDead(cache.ped) then return end

    -- Determine which pets compete
    local competingPets = {}
    local petsToCheck = {}
    if targetPetId then
        local petData = State.GetPet(targetPetId)
        if petData and petData.spawned and DoesEntityExist(petData.ped) then
            table.insert(petsToCheck, {id = targetPetId, ped = petData.ped})
        end
    else
        for id, petData in pairs(State.GetAllPets()) do
            if petData and petData.spawned and DoesEntityExist(petData.ped) and not IsEntityDead(petData.ped) then
                table.insert(petsToCheck, {id = id, ped = petData.ped})
            end
        end
    end

    -- Construir lista de mascotas candidatas
    for _, pet in ipairs(petsToCheck) do
        local petData = State.GetPet(pet.id)
        if petData and petData.spawned and DoesEntityExist(petData.ped) and not IsEntityDead(petData.ped) then
            local stats = petData.data and petData.data.stats or {}
            local vet = petData.data and petData.data.veterinary or {}
            local hunger = tonumber(stats.hunger) or 100
            local thirst = tonumber(stats.thirst) or 100
            local happiness = tonumber(stats.happiness) or 100
            local hasDisease = vet.hasdisease or false
            if hunger >= 30 and thirst >= 30 and happiness >= 20 and not hasDisease then
                table.insert(competingPets, {id = pet.id, ped = petData.ped, name = 'Pet'..pet.id, data = petData})
            end
        end
    end

    if #competingPets == 0 then
        lib.notify({ title = locale('cl_error_no_pet_retrieve_bone'), type = 'error' })
        return
    end

    -- Start all competing pets moving to buried location y marcar flags
    for _, pet in ipairs(competingPets) do
        State.petUnfreeze(pet.ped)
        isRetrieving = true    -- Marcar flags temporales
        Wait(50)
        TaskGoToCoordAnyMeans(pet.ped, buriedBoneCoords.x, buriedBoneCoords.y, buriedBoneCoords.z, 2.0, 0, 0, 786603, 0xbf800000)
    end

    if #competingPets > 1 then
        lib.notify({ title = locale('cl_buried_find'), description = locale('cl_game_buried_all_searching'), type = 'info' })
    else
        lib.notify({ title = locale('cl_buried_find'), description = locale('cl_buried_find_des'), type = 'info' })
    end

    local timeout = 0
    local maxTimeout = 40
    local lastTaskReissueTime = GetGameTimer()
    local winnerPet = nil

    -- Competition loop: first to arrive wins
    while not winnerPet and timeout < maxTimeout do
        Wait(1000)
        timeout = timeout + 1
        -- Check each pet's distance
        for _, pet in ipairs(competingPets) do
            if DoesEntityExist(pet.ped) and not IsEntityDead(pet.ped) then
                local dist = #(GetEntityCoords(pet.ped) - buriedBoneCoords)
                if dist < 2.0 then
                    winnerPet = pet
                    break
                end
            end
        end
        if winnerPet then break end
        -- Reissue tasks if needed
        if GetGameTimer() - lastTaskReissueTime > 5000 then
            for _, pet in ipairs(competingPets) do
                if DoesEntityExist(pet.ped) then
                    local taskStatus = GetScriptTaskStatus(pet.ped, 0x8AA1593C)
                    if taskStatus ~= 1 and taskStatus ~= 0 then
                        TaskGoToCoordAnyMeans(pet.ped, buriedBoneCoords.x, buriedBoneCoords.y, buriedBoneCoords.z, 2.0, 0, 0, 786603, 0xbf800000)
                    end
                end
            end
            lastTaskReissueTime = GetGameTimer()
        end
    end

    if not winnerPet then
        lib.notify({ title = locale('cl_error_retrieve_stuck'), type = 'error' })
        for _, pet in ipairs(competingPets) do
            if DoesEntityExist(pet.ped) then
                ClearPedTasks(pet.ped)
            end

            isRetrieving = false
        end
        return
    end

    -- Send losers back to player y limpiar flags
    for _, pet in ipairs(competingPets) do
        if pet ~= winnerPet and DoesEntityExist(pet.ped) then
            ClearPedTasks(pet.ped)
            ManageSpawn.moveCompanionToPlayer(pet.ped, cache.ped)
        end

        isRetrieving = false    -- Limpiar flags temporales
    end

    -- Winner digs and gets reward
    TaskTurnPedToFaceCoord(winnerPet.ped, buriedBoneCoords.x, buriedBoneCoords.y, buriedBoneCoords.z, 1000)
    Wait(1000)
    State.PlayPetAnimation(winnerPet.id, 'amb_creature_mammal@world_dog_digging@base', 'base', true, 5000)
    Wait(5000)
    State.ClearPetAnimation(winnerPet.id)

    -- Calcular nivel localmente
    local currentLevel = winnerPet.data and winnerPet.data.progression and winnerPet.data.progression.level or 1
    local roll = math.random(1, 100)
    if roll <= (gameBuriedConfig.findSpecial + (currentLevel * 2)) then
        TriggerServerEvent('hdrp-pets:server:givexp', Config.XP.Increase.PerFindBuried, winnerPet.id)
        TriggerServerEvent("hdrp-pets:server:giverandom")
        if #competingPets > 1 then
            lib.notify({ title = locale('cl_buried_digrandom'), description = winnerPet.name .. ' ' .. locale('cl_game_buried_found_special'), type = 'success' })
        else
            lib.notify({ title = locale('cl_buried_digrandom'), description = locale('cl_buried_digrandom_des'), type = 'success' })
        end
    elseif roll <= (gameBuriedConfig.findburied + currentLevel) then
        TriggerServerEvent('hdrp-pets:server:givexp', Config.XP.Increase.PerFindBuried, winnerPet.id)
        TriggerServerEvent("hdrp-pets:server:giveitem", Config.Items.Bone)
        if #competingPets > 1 then
            lib.notify({ title = locale('cl_buried_give'), description = winnerPet.name .. ' ' .. locale('cl_game_buried_found_bone'), type = 'warning' })
        else
            lib.notify({ title = locale('cl_buried_give'), description = locale('cl_buried_give_des'), type = 'warning' })
        end
    else
        lib.notify({ title = locale('cl_buried_fail'), description = locale('cl_buried_fail_des'), type = 'error' })
    end

    Wait(1000)
    if DoesEntityExist(winnerPet.ped) then
        ManageSpawn.moveCompanionToPlayer(winnerPet.ped, cache.ped)
    end

    isRetrieving = false    -- Limpiar flags temporales

    lib.notify({ title = locale('cl_buried_loc'), description = locale('cl_buried_loc_des'), type = 'success' })
    buriedBoneCoords = nil
end)

RegisterCommand('pet_buried', function()
    local hasItem = RSGCore.Functions.HasItem(Config.Items.Bone)
    if not hasItem then
        local label = RSGCore.Shared.Items[tostring(Config.Items.Bone)] and RSGCore.Shared.Items[tostring(Config.Items.Bone)].label or Config.Items.Bone
        lib.notify({ title = locale('cl_bone_need_item')..' '.. label, duration = 7000, type = 'error' }) 
        return 
    end

    local closestPet = State.GetClosestPet()
    local petPed = closestPet and closestPet.ped or nil
    if not petPed or not DoesEntityExist(petPed) then return end

    if not IsEntityDead(cache.ped) and not IsEntityDead(petPed) then
        if buriedBoneCoords then
            lib.notify({ title = locale('cl_error_buriedbone'), description = locale('cl_error_buriedbone_des'), type = 'warning' })
            return
        end

        TriggerEvent("hdrp-pets:client:buryBone")
        Wait(3000)
    end
end, false)

RegisterNetEvent("hdrp-pets:client:digRandomItem", function(petId)
    -- Obtener companionid y petData una sola vez
    local companionid, petData, petPed
    if petId then
        companionid = petId
        petData = State.GetPet(companionid)
        petPed = petData and petData.ped or nil
    else
        local closestPet = State.GetClosestPet()
        companionid = closestPet and closestPet.companionid or nil
        petData = companionid and State.GetPet(companionid) or nil
        petPed = petData and petData.ped or nil
    end

    if not petPed or not DoesEntityExist(petPed) or IsEntityDead(cache.ped) or IsEntityDead(petPed) then return end

    local stats = petData and petData.data and petData.data.stats or {}
    local vet = petData and petData.data and petData.data.veterinary or {}
    local hunger = tonumber(stats.hunger) or 100
    local thirst = tonumber(stats.thirst) or 100
    local happiness = tonumber(stats.happiness) or 100
    local hasDisease = vet.hasdisease or false
    if hunger < 30 or thirst < 30 or happiness < 20 or hasDisease then return end

    -- Marcar flags temporales
    isRetrieving = false
    State.petUnfreeze(petPed)
    Wait(100)

    local coords = GetEntityCoords(petPed)
    local randX = math.random(gameDigRandomConfig.min, gameDigRandomConfig.max)
    local randY = math.random(gameDigRandomConfig.min, gameDigRandomConfig.max)
    local targetX = coords.x + randX
    local targetY = coords.y + randY
    local foundGround, targetZ = GetGroundZFor_3dCoord(targetX, targetY, coords.z + 50.0, false)
    if not foundGround then targetZ = coords.z end
    local digSpot = vector3(targetX, targetY, targetZ)

    TaskGoToCoordAnyMeans(petPed, digSpot.x, digSpot.y, digSpot.z, 2.0, 0, 0, 786603, 0xbf800000)
    lib.notify({ title = locale('cl_digrandom'), description = locale('cl_digrandom_des'), type = 'info' })

    local timeout, hasArrived = 0, false
    while true do
        Wait(1000)
        timeout = timeout + 1
        if not DoesEntityExist(petPed) then break end
        local dist = #(GetEntityCoords(petPed) - digSpot)
        if dist < 2.0 then hasArrived = true break end
        if timeout > 20 then
            lib.notify({ title = locale('cl_error_retrieve_stuck'), type = 'error' })
            break
        end
        local taskStatus = GetScriptTaskStatus(petPed, 0x8AA1593C)
        if taskStatus ~= 1 and taskStatus ~= 0 then
            TaskGoToCoordAnyMeans(petPed, digSpot.x, digSpot.y, digSpot.z, 2.0, 0, 0, 786603, 0xbf800000)
        end
    end

    if hasArrived then
        TaskTurnPedToFaceCoord(petPed, digSpot.x, digSpot.y, digSpot.z, 1000)
        Wait(1000)
        State.PlayPetAnimation(companionid, 'amb_creature_mammal@world_dog_digging@base', 'base', true, 6000)
        Wait(6000)
        State.ClearPetAnimation(companionid)
    end

    -- Limpiar flags temporales y devolver mascota
    -- State.SetPetTrait(companionid, 'isRetrieving', false)
    isRetrieving = false
    Wait(1000)
    if DoesEntityExist(petPed) then
        ManageSpawn.moveCompanionToPlayer(petPed, cache.ped)
        local coordsPlayer = GetEntityCoords(cache.ped)
        local distToPlayer = #(GetEntityCoords(petPed) - coordsPlayer)
        if distToPlayer > 3.0 then
            -- Calcular nivel y recompensa
            local progression = petData and petData.data and petData.data.progression or {}
            local currentLevel = progression.level or 1
            local roll = math.random(1, 100)
            if roll <= (gameDigRandomConfig.lostreward + (currentLevel * 2)) then
                ManageSpawn.crouchInspectAnim()
                TriggerServerEvent('hdrp-pets:server:givexp', Config.XP.Increase.PerDigRandom, companionid)
                TriggerServerEvent("hdrp-pets:server:giverandom")
                lib.notify({ title = locale('cl_digrandom_give'), description = locale('cl_digrandom_give_des'), type = 'success' })
            else
                lib.notify({ title = locale('cl_digrandom_fail'), description = locale('cl_digrandom_fail_des'), type = 'error' })
            end
        end
    end
end)

exports('BuriedBoneCoords', function()
    return buriedBoneCoords or nil
end)

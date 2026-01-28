local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
local gameBonesConfig = Config.Games.Gbones
local retrievedEntities = {}
local itemProps = {}
local isRetrieving = false

local ManageSpawn = require('client.stable.utils_spawn')

----------------------------
-- GAMES FOR ADD XP
----------------------------
-- BRING BONE
local function CleanBoneAnimation(prop, player, petPed)
    local coords = GetEntityCoords(player)
    if not petPed or not DoesEntityExist(petPed) then return end

    TaskGoToCoordAnyMeans(petPed, coords.x, coords.y, coords.z, 1.5, 0, 0, 786603, 0xbf800000)

    local timeout = 0
    while true do
        Wait(1000)
        timeout = timeout + 1

        if not DoesEntityExist(petPed) or IsEntityDead(petPed) then 
            isRetrieving = false
            return 
        end

        local coords = GetEntityCoords(player)
        local coords2 = GetEntityCoords(petPed)
        local dist = #(coords - coords2)

        if timeout > 30 then
            lib.notify({ title = locale('cl_error_retrieve_stuck'), type = 'error' })
            isRetrieving = false
            return
        end

        if prop and DoesEntityExist(prop) and dist <= 2.5 then
            DetachEntity(prop)
            Wait(100)
            ClearPedTasks(petPed)

            ActivatePhysics(prop)
            PlaceObjectOnGroundProperly(prop)
            Wait(1000)

            SetModelAsNoLongerNeeded(prop)
            isRetrieving = false

            ManageSpawn.moveCompanionToPlayer(petPed, player)

            break
        else
            local taskStatus = GetScriptTaskStatus(petPed, 0x8AA1593C) -- TASK_GO_TO_COORD_ANY_MEANS
            if taskStatus ~= 1 and taskStatus ~= 0 then
                TaskGoToCoordAnyMeans(petPed, coords.x, coords.y, coords.z, 1.5, 0, 0, 786603, 0xbf800000)
            end
        end
    end

    Wait(1500)

    TaskTurnPedToFaceEntity(prop, cache.ped, 2000)
    Wait(500)
    TaskTurnPedToFaceEntity(cache.ped, prop, 2000)

    ManageSpawn.crouchInspectAnim()

    TriggerServerEvent('hdrp-pets:server:giveitem', Config.Items.Bone)

    for k, v in ipairs(itemProps) do
        if v.boneitem == prop then
            if DoesEntityExist(v.boneitem) then
                SetEntityAsNoLongerNeeded(v.boneitem)  -- FIX v5.8.56: Memory leak prevention
                DeleteEntity(v.boneitem)
            end
            itemProps[k] = nil
            -- Limpieza extra de retrievedEntities
            if retrievedEntities[prop] ~= nil then
                retrievedEntities[prop] = nil
            end
        end
        Wait(50) -- Sleep corto para evitar picos de CPU si hay muchos props
    end

    if petPed then
        local _, petId = State.GetPetByEntity(petPed)
        TriggerServerEvent('hdrp-pets:server:useitem', Config.Items.Bone, petId)
    end
end

local function RetrieveBone(ClosestBone, targetPetId)
    local Obj = ClosestBone
    local Rcoords = GetEntityCoords(Obj)

    -- Determine which pets should compete for the bone
    local competingPets = {}
    if targetPetId then
        -- MODE 2: Specific pet from menu
        local petData = State.GetPet(targetPetId)
        if petData and petData.spawned and DoesEntityExist(petData.ped) and not IsEntityDead(petData.ped) then
            table.insert(competingPets, {
                ped = petData.ped,
                id = targetPetId,
                data = petData
            })
        end
    else
        -- MODE 1: All pets compete (item use or command without args)
        for companionid, petData in pairs(State.GetAllPets()) do
            if petData and petData.spawned and DoesEntityExist(petData.ped) and not IsEntityDead(petData.ped) then
                table.insert(competingPets, {
                    ped = petData.ped,
                    id = companionid,
                    data = petData
                })
            end
        end
    end

    if #competingPets == 0 then
        lib.notify({ title = locale('cl_error_no_retrieve_bone'), type = 'error', duration = 7000 })
        return
    end

    -- Freeze and clear tasks for all competing pets, set flags
    for _, pet in ipairs(competingPets) do
        local companionid = pet.id
        FreezeEntityPosition(pet.ped, false)
        ClearPedTasks(pet.ped)
        Wait(50)
    end

    -- Filtrar mascotas que cumplen condiciones robustas (hunger, thirst, happiness, disease, distancia)
    local validPets = {}
    for _, pet in ipairs(competingPets) do
        local data = pet.data
        local hunger = data and data.stats and tonumber(data.stats.hunger) or 100
        local thirst = data and data.stats and tonumber(data.stats.thirst) or 100
        local happiness = data and data.stats and tonumber(data.stats.happiness) or 100
        local hasDisease = data and data.veterinary and data.veterinary.hasdisease or false
        local dist = #(Rcoords - GetEntityCoords(pet.ped))
        if hunger >= 30 and thirst >= 30 and happiness >= 20 and not hasDisease and dist <= gameBonesConfig.MaxDist then
            table.insert(validPets, pet)
        end
    end
    if #validPets == 0 then
        lib.notify({ title = locale('cl_error_no_pet_retrieve_bone'), type = 'error', duration = 7000 })
        return
    end
    competingPets = validPets

    -- Command all competing pets to go for the bone
    for _, pet in ipairs(competingPets) do
        TaskGoToCoordAnyMeans(pet.ped, Rcoords.x, Rcoords.y, Rcoords.z, 2.5, 0, 0, 786603, 0xbf800000)
        Wait(50)
    end

    isRetrieving = true
            
    -- Flags ya marcados por mascota
    if #competingPets > 1 then
        lib.notify({
            title = locale('cl_bone_competition'),
            description = string.format("%d pets racing for the bone!", #competingPets),
            type = 'info',
            duration = 5000
        })
    end
    
    local winnerPet = nil
    local timeout = 0
    local finished = false
    while not finished do
        local sleep = #competingPets > 2 and 700 or 500
        Wait(sleep)
        timeout = timeout + 1

        -- Abort if all pets lost isRetrieving or were removed
        local anyRetrieving = false
        for _, pet in ipairs(competingPets) do
            local companionid = pet.id
            if isRetrieving and DoesEntityExist(pet.ped) then
                anyRetrieving = true
                break
            end
        end
        if not anyRetrieving then
            for _, pet in ipairs(competingPets) do
                local companionid = pet.id
                isRetrieving = false
                if DoesEntityExist(pet.ped) then
                    ClearPedTasks(pet.ped)
                end
                Wait(50)
            end
            lib.notify({ title = locale('cl_error_retrieve_aborted'), type = 'error', duration = 7000 })
            finished = true
            break
        end

        if not DoesEntityExist(Obj) then
            isRetrieving = false
            for _, pet in ipairs(competingPets) do
                if DoesEntityExist(pet.ped) then
                    ClearPedTasks(pet.ped)
                end
                Wait(50)
            end
            finished = true
            break
        end

        Rcoords = GetEntityCoords(Obj)
        if timeout > 80 then -- 40 seconds timeout
            isRetrieving = false
            
            for _, pet in ipairs(competingPets) do
                if DoesEntityExist(pet.ped) then
                    ClearPedTasks(pet.ped)
                end
                Wait(50)
            end
            lib.notify({ title = locale('cl_error_retrieve_stuck'), type = 'error', duration = 7000 })
            finished = true
            break
        end

        
        for _, pet in ipairs(competingPets) do
            if DoesEntityExist(pet.ped) and not IsEntityDead(pet.ped) then
                local petCoords = GetEntityCoords(pet.ped)
                local dist = #(Rcoords - petCoords)
                if dist <= 2.5 then
                    winnerPet = pet
                    finished = true
                    break
                end
            end
        end
        
        if winnerPet then
            break
        end
    end

    -- Procesar resultado
    if winnerPet and DoesEntityExist(winnerPet.ped) then
        -- Stop all other pets
        for _, pet in ipairs(competingPets) do
            if pet.id ~= winnerPet.id and DoesEntityExist(pet.ped) then
                ClearPedTasks(pet.ped)
                ManageSpawn.moveCompanionToPlayer(pet.ped, cache.ped)
            end
            Wait(50)
        end

        local xp = winnerPet.data and winnerPet.data.progression and tonumber(winnerPet.data.progression.xp) or 0
        -- Winner retrieves the bone
        if xp >= Config.XP.Trick.Bone then
            AttachEntityToEntity(Obj, winnerPet.ped, GetPedBoneIndex(winnerPet.ped, 21030),
                0.14, 0.14, 0.09798,
                90.0, 0.0, 0.0,
                true, true, false, true, 1, true
            )
            
            retrievedEntities[Obj] = true
            
            if #competingPets > 1 then
                local winnerName = winnerPet.data and winnerPet.data.info and winnerPet.data.info.name or "Pet"
                lib.notify({
                    title = locale('cl_bone_winner'),
                    description = string.format("%s won the race!", winnerName),
                    type = 'success',
                    duration = 5000
                })
            end
            CleanBoneAnimation(Obj, cache.ped, winnerPet.ped)
        else
            -- Not trained enough - chance to fail
            local chance = math.random(1, 100)
            if chance >= (100 - gameBonesConfig.LostTraining) then
                Wait(2000)
                ClearPedTasks(winnerPet.ped)
                lib.notify({ title = locale('cl_error_lost_retrieve_bone'), type = 'error', duration = 7000 })
                -- Play lay animation usando State.PlayPetAnimation
                local animDict = 'amb_creature_mammal@world_dog_resting@stand_enter'
                local companionid = winnerPet.id
                State.PlayPetAnimation(companionid, animDict, 'enter_front', true, 5000)
                Wait(5000)
                State.ClearPetAnimation(companionid)
                SetEntityAsNoLongerNeeded(Obj)
                DeleteEntity(Obj)
                retrievedEntities[Obj] = false
                isRetrieving = false
                
                ManageSpawn.moveCompanionToPlayer(winnerPet.ped, cache.ped)
            else
                AttachEntityToEntity(Obj, winnerPet.ped, GetPedBoneIndex(winnerPet.ped, 21030),
                    0.14, 0.14, 0.09798,
                    90.0, 0.0, 0.0,
                    true, true, false, true, 1, true
                )
                retrievedEntities[Obj] = true
                CleanBoneAnimation(Obj, cache.ped, winnerPet.ped)
            end
        end
    else
        lib.notify({ title = locale('cl_error_no_pet_retrieve_bone'), type = 'error', duration = 7000 })
    end
end

local function PlayerBoneAnimation(targetPetId)

    SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)
    State.ResetPlayerState()
    Wait(100)

    local pcoords = GetEntityCoords(cache.ped)
    local boneIndex = GetEntityBoneIndexByName(cache.ped, "SKEL_R_Finger00")

    local forwardVector = GetEntityForwardVector(cache.ped)

    local forceMultiplier = math.random(8, 12)
    local forceX = forwardVector.x * forceMultiplier
    local forceY = forwardVector.y * forceMultiplier
    local forceZ = 3.5

    local boneitem = CreateObject(`p_humanskeleton02x_upperarmr`, pcoords.x, pcoords.y, pcoords.z, true, true, true)
    table.insert(itemProps, {boneitem = boneitem} )
    AttachEntityToEntity(boneitem, cache.ped, boneIndex,
        0.10, -0.04, -0.01,
        -15.0, 90.0, 180.0,
        true, false, true, false, 0, true
    )

    local dict = "mech_weapons_thrown@base"
    if not lib.requestAnimDict(dict, 5000) then
        lib.notify({ title = locale('cl_error_no_pet_player_bone'), type = 'error', duration = 7000 })
        return
    end

    local time = math.random(1000, 3600)
    TaskPlayAnim(cache.ped, dict, "throw_m_fb_stand", 8.0, -8.0, time or -1, 0, 0, false, false, false)
    Wait(300)

    local velocity = forwardVector * math.random(10, 15)
    DetachEntity(boneitem, true, true)

    ApplyForceToEntity(boneitem, 1, forceX, forceY, forceZ, 0, 0, 0, boneIndex, false, false, false, true, true)
    SetEntityVelocity(boneitem, velocity.x, velocity.y, velocity.z + 2.0)
    SetEntityRotation(boneitem, math.random(1, 360), math.random(1, 360), math.random(1, 360), 0, true)

    local timeout = GetGameTimer() + 10000
    while GetGameTimer() < timeout do
        Wait(100)
        if #(GetEntityVelocity(boneitem)) < 0.2 then
            break
        end
    end

    SetEntityAsNoLongerNeeded(boneitem)

    CreateThread(function()
        Wait(gameBonesConfig.AutoDelete)
        if boneitem and DoesEntityExist(boneitem) then
            if not retrievedEntities[boneitem] then
                SetEntityAsNoLongerNeeded(boneitem)  -- FIX v5.8.56: Memory leak prevention
                DeleteEntity(boneitem)
                for k, v in pairs(itemProps) do
                    if v.boneitem == boneitem then
                        itemProps[k] = nil
                        break
                    end
                end
            end
            lib.notify({ title = locale('cl_lost_bone'), description = locale('cl_lost_bone_des'), type = 'info', duration = 7000  })
        end
    end)

    RetrieveBone(boneitem, targetPetId)
end

local function StartBone(targetPetId)
    TriggerServerEvent("hdrp-pets:server:removeitem", Config.Items.Bone)
    PlayerBoneAnimation(targetPetId)
end

RegisterNetEvent('hdrp-pets:client:playbone')
AddEventHandler('hdrp-pets:client:playbone', function(petId)
    -- When triggered from menu, specific pet is passed
    StartBone(petId)
end)

RegisterCommand('pet_bone', function(source, args)
    local hasItem = RSGCore.Functions.HasItem(Config.Items.Bone)
    if not hasItem then 
        lib.notify({ title = locale('cl_bone_need_item')..' '.. (RSGCore.Shared.Items[tostring(Config.Items.Bone)] and RSGCore.Shared.Items[tostring(Config.Items.Bone)].label or Config.Items.Bone), duration = 7000, type = 'error' }) 
        return 
    end
    
    local targetPetId = nil
    local activePets = State.GetAllPets()
    
    -- Check if pet argument is provided
    if args and args[1] then
        local searchTerm = string.lower(args[1])
        
        -- Try to find pet by name or ID
        for id, pet in pairs(activePets) do
            local petName = pet.data and pet.data.info and pet.data.info.name or nil
            if tostring(id) == searchTerm or (petName and string.lower(petName):find(searchTerm, 1, true)) then
                targetPetId = id
                break
            end
        end
        
        if not targetPetId then
            lib.notify({ title = locale('cl_error_no_pet_retrieve_bone'), description = locale('cl_error_pet_not_found') .. ': ' .. args[1], type = 'error' })
            return
        end
    else
        -- No argument: all pets compete
        if not next(activePets) then
            lib.notify({ title = locale('cl_error_no_pet_retrieve_bone'), type = 'error' })
            return
        end
    end
    
    if not IsEntityDead(cache.ped) then
        StartBone(targetPetId)
        Wait(3000)
    end
end, false)
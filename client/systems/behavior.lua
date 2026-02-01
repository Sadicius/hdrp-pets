local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState() -- Asegura acceso a State
local attackedGroup = nil
local gpsRoute = nil

-- ================================================
-- HELPERS: Utilities
-- ================================================

function CleanUpRelationshipGroup()
    if attackedGroup then
        RemoveRelationshipGroup(attackedGroup)
        attackedGroup = nil  -- Limpiar la variable
        if Config.Debug then
            print(locale('cl_print_clean_relation'))
        end
    end
end

local function IsPedAnimal(entity)
    local pedType = GetPedType(entity)    -- Use GetPedType() to identify animal-like entities
    return pedType >= 28 and pedType <= 31    -- Animal types are typically different from human types
end

---Command a pet to attack a target
---@param data table|number Target entity or data table {entity = target, petId = optional}
function AttackTarget(data)
    -- Normalize input: support both entity directly or data table
    local target = type(data) == "table" and data.entity or data
    local petId = type(data) == "table" and data.petId or nil
    
    -- Get pet to use for this action
    local petPed, _ = State.GetPetForAction(petId)
    
    if not petPed or not DoesEntityExist(petPed) then
        lib.notify({ title = locale('cl_error_attack_tar'), description = locale('cl_error_attack_tar_des'), type = 'error' })
        return
    end
    
    if not target or not DoesEntityExist(target) or (not IsPedHuman(target) and not IsPedAnimal(target)) or IsPedAPlayer(target) then
        lib.notify({ title = locale('cl_error_attack_inv_target'), description = locale('cl_error_attack_inv_target_des'), type = 'error' })
        return
    end
    
    if not NetworkHasControlOfEntity(petPed) then
        lib.notify({ title = locale('cl_error_attack_target'), description = locale('cl_error_attack_target_des'), type = 'error' })
        return
    end
    
    -- Setup attack relationship group
    if not attackedGroup then
        local retval, group = AddRelationshipGroup("attackedPeds")
        attackedGroup = group
    end
    
    -- Configure combat relationships and attributes
    SetPedRelationshipGroupHash(target, attackedGroup)
    SetRelationshipBetweenGroups(5, GetPedRelationshipGroupHash(petPed), GetPedRelationshipGroupHash(target))
    SetPedCombatAttributes(petPed, 5, true)   -- Always fight
    SetPedCombatAttributes(petPed, 46, true)  -- Unrestricted combat
    SetPedCombatMovement(petPed, 2)           -- Aggressive movement
    SetPedCombatRange(petPed, 2)              -- Maximum attack range
    SetPedFleeAttributes(petPed, 0, false)
    
    lib.notify({ title = locale('cl_action_attack_target'), description = locale('cl_action_attack_target_des'), type = 'info', duration = 7000 })
    TaskCombatPed(petPed, target, 0, 16)  -- Command pet to attack
end

exports('AttackTarget', function(data) AttackTarget(data) end)

---Command ALL active pets to attack a target
---@param data table|number Target entity or data table {entity = target}
function AttackTargetAllPets(data)
    local target = type(data) == "table" and data.entity or data
    
    if not target or not DoesEntityExist(target) or (not IsPedHuman(target) and not IsPedAnimal(target)) or IsPedAPlayer(target) then
        lib.notify({ title = locale('cl_error_attack_inv_target'), description = locale('cl_error_attack_inv_target_des'), type = 'error' })
        return
    end
    
    local activePets = State.GetAllActivePets()
    if #activePets == 0 then
        lib.notify({ title = locale('cl_error_attack_tar'), description = locale('cl_error_attack_tar_des'), type = 'error' })
        return
    end
    
    -- Setup attack relationship group
    if not attackedGroup then
        local retval, group = AddRelationshipGroup("attackedPeds")
        attackedGroup = group
    end
    SetPedRelationshipGroupHash(target, attackedGroup)
    
    local successCount = 0
    -- Sleep dinámico según cantidad de mascotas
    local sleep = #activePets > 3 and 1000 or 2000
    for _, pet in ipairs(activePets) do
        if NetworkHasControlOfEntity(pet.ped) then
            SetRelationshipBetweenGroups(5, GetPedRelationshipGroupHash(pet.ped), GetPedRelationshipGroupHash(target))
            SetPedCombatAttributes(pet.ped, 5, true)
            SetPedCombatAttributes(pet.ped, 46, true)
            SetPedCombatMovement(pet.ped, 2)
            SetPedCombatRange(pet.ped, 2)
            SetPedFleeAttributes(pet.ped, 0, false)
            TaskCombatPed(pet.ped, target, 0, 16)
            successCount = successCount + 1
        end
        Wait(sleep)
    end
    
    if successCount > 0 then
        lib.notify({ 
            title = locale('cl_action_attack_target'), 
            description = string.format("%d pet(s) attacking target", successCount), 
            type = 'info', 
            duration = 7000 
        })
    else
        lib.notify({ title = locale('cl_error_attack_target'), description = locale('cl_error_attack_target_des'), type = 'error' })
    end
end

---Command a pet to track a target
---@param data table|number Target entity or data table {entity = target, petId = optional}
function TrackTarget(data)
    -- Normalize input
    local target = type(data) == "table" and data.entity or data
    local petId = type(data) == "table" and data.petId or nil
    
    -- Get pet to use for this action
    local petPed, _ = State.GetPetForAction(petId)
    
    if not petPed or not DoesEntityExist(petPed) then 
        lib.notify({title = locale('cl_error_track_tar'), type = 'error'})
        return 
    end
    
    if not target or not DoesEntityExist(target) or (not IsPedHuman(target) and not IsPedAnimal(target)) or IsPedAPlayer(target) then
        lib.notify({title = locale('cl_error_track_inv_target'), type = 'error'})
        return
    end

    if not NetworkHasControlOfEntity(petPed) then
        lib.notify({ title = locale('cl_error_track_action'), description = locale('cl_error_track_action_des'), type = 'error'})
        return
    end
    
    -- Setup GPS route
    if gpsRoute then ClearGpsMultiRoute() end
    StartGpsMultiRoute(GetHashKey("COLOR_BLUE"), true, true)
    local targetCoords = GetEntityCoords(target)
    AddPointToGpsMultiRoute(targetCoords.x, targetCoords.y, targetCoords.z)
    SetGpsMultiRouteRender(true)
    gpsRoute = true
    
    -- Command pet to track target
    TaskFollowToOffsetOfEntity(petPed, target, 0.0, -1.5, 0.0, 1.0, -1, Config.Blip.Track.Distance * 100000000, 1, 1, 0, 0, 1)
    
    -- Create monitoring thread
    CreateThread(function()
        local timeout = 0
        local success, err = pcall(function()
            while true do
                local companionCoords = GetEntityCoords(petPed)
                local targetCoords = GetEntityCoords(target)
                local distance = #(companionCoords - targetCoords)
                local sleep = distance > 15.0 and 1000 or (distance > 5.0 and 500 or 150)

                -- Prevent freezing by yielding each loop
                Wait(100)

                -- Check if pet still exists
                if not DoesEntityExist(petPed) or not DoesEntityExist(target) then
                    if gpsRoute then ClearGpsMultiRoute(); gpsRoute = nil end
                    Wait(sleep)
                    break
                end

                if distance > 10.0 then
                    TaskFollowToOffsetOfEntity(petPed, target, 0.0, -1.5, 0.0, 1.0, -1, Config.Blip.Track.Distance * 100000000, 1, 1, 0, 0, 1)
                elseif distance <= 3.0 then
                    if gpsRoute then ClearGpsMultiRoute(); gpsRoute = nil end

                    -- Create temporary blip
                    local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, targetCoords.x, targetCoords.y, targetCoords.z)
                    Citizen.InvokeNative(0x662D364ABF16DE2F, blip, Config.Blip.ColorModifier)
                    SetBlipSprite(blip, Config.Blip.Track.blipSprite, true)
                    SetBlipScale(blip, Config.Blip.Track.blipScale)
                    Citizen.InvokeNative(0x45FF974EEA1DCE36, blip, true)
                    Citizen.InvokeNative(0x9CB1A1623062F402, blip, Config.Blip.Track.blipName)
                    lib.notify({ title = locale('cl_track_target_complete'), description = locale('cl_track_target_complete_des'), type = 'success', duration = 5000 })

                    CreateThread(function()
                        Wait(Config.Blip.Track.blipTime)
                        if DoesBlipExist(blip) then RemoveBlip(blip) end
                    end)

                    Wait(sleep)
                    break
                end

                timeout = timeout + 1
                if timeout > 300 then
                    if gpsRoute then ClearGpsMultiRoute(); gpsRoute = nil end
                    Wait(sleep)
                    break
                end

                Wait(sleep)
            end
        end)

        -- Cleanup on error
        if not success then
            if gpsRoute then ClearGpsMultiRoute(); gpsRoute = nil end
            if Config.Debug then
                print('^1[TRACKING ERROR]^7 ' .. string.format(locale('cl_debug_tracking_error_fmt'), tostring(err)))
            end
        end
    end)
    
    lib.notify({ title = locale('cl_track_action'), description = locale('cl_track_action_des'), type = 'info', duration = 7000 })
end

---Command a pet to hunt an animal
---@param data table|number Target entity or data table {entity = target, petId = optional}
function HuntAnimals(data)
    -- Normalize input
    local target = type(data) == "table" and data.entity or data
    local petId = type(data) == "table" and data.petId or nil
    
    -- Get pet to use for this action
    local petPed, _ = State.GetPetForAction(petId)
    
    if not petPed or not DoesEntityExist(petPed) then
        lib.notify({ title = locale('cl_error_hunt_action_ava'), description = locale('cl_error_hunt_action_ava_des'), type = 'error' })
        return
    end
    
    if not target or not DoesEntityExist(target) or not IsEntityAPed(target) or IsEntityDead(target) or IsPedAPlayer(target) then
        lib.notify({ title = locale('cl_error_hunt_action_inv'), description = locale('cl_error_hunt_action_inv_des'), type = 'error' })
        return
    end
    
    if not NetworkHasControlOfEntity(petPed) then
        lib.notify({ title = locale('cl_error_hunt_action'), description = locale('cl_error_hunt_action_des'), type = 'error' })
        return
    end
    
    TaskGoToEntity(petPed, target, -1, 2.0, 1.0, 1073741824, 0)
    
    CreateThread(function()  
        if not DoesEntityExist(petPed) or not DoesEntityExist(target) then return end
        
        local timeout = GetGameTimer() + 15000
        local huntSuccessful = false
        
        while not IsEntityDead(target) and GetGameTimer() < timeout do
            if not DoesEntityExist(target) then break end
            Wait(100)
            
            local distance = #(GetEntityCoords(petPed) - GetEntityCoords(target))
            if distance <= 3.0 then
                TaskCombatPed(petPed, target, 0, 16)
            end
            
            if IsEntityDead(target) then 
                huntSuccessful = true 
                break 
            end
        end
        
        if huntSuccessful then
            TaskGoToEntity(petPed, cache.ped, -1, 2.0, 1.0, 1073741824, 0)
            TriggerServerEvent('hdrp-pets:server:food')
            Wait(5000)
            lib.notify({ title = locale('cl_hunt_target_reward'), description = locale('cl_hunt_target_reward'), type = 'success', duration = 5000 })
        end
    end)
    
    lib.notify({ title = locale('cl_hunt_target_action'), description = locale('cl_hunt_target_action_des'), type = 'info', duration = 5000 })
end

exports('AttackTargetAllPets', function(data) AttackTargetAllPets(data) end)
exports('TrackTarget', function(data) TrackTarget(data) end)
exports('HuntAnimals', function(data) HuntAnimals(data) end)

-- Limpieza de grupo de relación al parar el recurso
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if attackedGroup then
        RemoveRelationshipGroup(attackedGroup)
        attackedGroup = nil
        if Config and Config.Debug then
            print('^2[HDRP-PETS]^7 Limpieza de attackedGroup en onResourceStop')
        end
    end
end)
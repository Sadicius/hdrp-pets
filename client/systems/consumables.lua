local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()

local ManageSpawn = lib.load('client.stable.utils_spawn')
-----------------------------------------
-- ACTIONS FEED, ANIMATIONS
-----------------------------------------

-- player feed companion
---
RegisterNetEvent('hdrp-pets:client:feed')
AddEventHandler('hdrp-pets:client:feed', function(itemName, companionid)
    local petData, distance
    if companionid then
        petData = State.GetPet(companionid)
        if petData and petData.ped and DoesEntityExist(petData.ped) then
            local playerCoords = GetEntityCoords(cache.ped)
            local petCoords = GetEntityCoords(petData.ped)
            distance = #(playerCoords - petCoords)
        else
            petData, distance, companionid = State.GetClosestPet()
        end
    else
        petData, distance, companionid = State.GetClosestPet()
    end

    if not petData or not petData.ped or not DoesEntityExist(petData.ped) then
        lib.notify({ title = locale('cl_error_no_pet_out'), type = 'error', duration = 7000 })
        return
    end

    local pcoords = GetEntityCoords(cache.ped)
    local hcoords = GetEntityCoords(petData.ped)

    -- Si el item es el revividor y la mascota está muerta, dispara revive robusto y detén lógica normal
    if itemName == Config.Items.Revive and IsEntityDead(petData.ped) then
        TriggerEvent('hdrp-pets:client:revive')
        return
    end

    SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)
    State.ResetPlayerState()

    if Config.PetFeed[itemName] then
        if Config.PetFeed[itemName]["ismedicine"] then
            if distance > 2.5 then
                lib.notify({ title = locale('cl_error_med_need_to_be_closer'), type = 'error', duration = 7000 })
                return
            end
            if Config.PetFeed[itemName]["medicineModelHash"] then medicineModelHash = Config.PetFeed[itemName]["medicineModelHash"] end
            TaskTurnPedToFaceEntity(cache.ped, petData.ped, 5000)
            ManageSpawn.crouchInspectAnim()

            local valueHealth = Citizen.InvokeNative(0x36731AC041289BB1, petData.ped, 0)
            if not tonumber(valueHealth) then valueHealth = 0 end
            local newHealth = Config.PetFeed[itemName]["health"]
            if Config.Debug then print(valueHealth, newHealth) end
            Citizen.InvokeNative(0xC6258F41D86676E0, petData.ped, 0, newHealth)

            --[[ 
                local valueStamina = Citizen.InvokeNative(0x36731AC041289BB1, petData.ped, 1)
                if not tonumber(valueStamina) then valueStamina = 0 end
                local newStamina = Config.PetFeed[itemName]["stamina"]
                if Config.Debug then print(valueStamina, newStamina) end
                Citizen.InvokeNative(0xC6258F41D86676E0, petData.ped, 1, newStamina)
            ]]
                
            Wait(3500)
            Citizen.InvokeNative(0x50C803A4CD5932C5, true)
            Citizen.InvokeNative(0xD4EE21B7CC7FD350, true)
            TriggerServerEvent('hdrp-pets:server:useitem', itemName, companionid)
            PlaySoundFrontend("Core_Fill_Up", "Consumption_Sounds", true, 0)
            State.ResetPlayerState()
            SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, false)

        elseif not Config.PetFeed[itemName]["ismedicine"] then
            if distance > tonumber(Config.DistanceFeed) then
                lib.notify({ title = locale('cl_error_not_med_need_to_be_closer'), type = 'error', duration = 7000 })
                return
            end
            local heading = GetEntityHeading(cache.ped)
            local distanceInFront = -1.00
            local radians = math.rad(heading)
            local offsetX = -distanceInFront * math.sin(radians)
            local offsetY = distanceInFront * math.cos(radians)
            local objectX = pcoords.x - offsetX
            local objectY = pcoords.y - offsetY
            local objectZ = pcoords.z - 1.0
            TaskTurnPedToFaceEntity(cache.ped, petData.ped, 5000)
            ManageSpawn.crouchInspectAnim()
            Wait(3000)
            local cookitem = nil
            if itemName == 'raw_meat' or itemName == 'water' then
                cookitem = nil
            elseif Config.PetFeed[itemName]["ModelHash"] then
                cookitem = CreateObject(Config.PetFeed[itemName]["ModelHash"], objectX, objectY, objectZ, true, true, true)
            else
                cookitem = CreateObject(`s_dogbowl01x`, objectX, objectY, objectZ, true, true, true)
            end
            -- Asociar el objeto de comida a la mascota específica
            if cookitem then
                if not petData._foodProps then petData._foodProps = {} end
                table.insert(petData._foodProps, cookitem)
            end
            State.ResetPlayerState()
            TaskTurnPedToFaceEntity(petData.ped, cache.ped, 1000)
            ClearPedTasks(petData.ped)
            FreezeEntityPosition(petData.ped, false)
            local maxWaitTime = 10000
            local startTime = GetGameTimer()
            if itemName == 'raw_meat' or itemName == 'water' then
                local player_coords = GetEntityCoords(cache.ped)
                local dist = #(hcoords - player_coords)
                TaskGoToCoordAnyMeans(petData.ped, player_coords.x, player_coords.y, player_coords.z, 1.0, 0, false, 786603, 0xbf800000)
                while dist > 1.0 do
                    Citizen.Wait(100)
                    hcoords = GetEntityCoords(petData.ped)
                    dist = #(hcoords - player_coords)
                    if GetGameTimer() - startTime > maxWaitTime then break end
                end
                TaskTurnPedToFaceEntity(petData.ped, cache.ped, 2000)
                Wait(500)
            else
                local p_coords = GetEntityCoords(cookitem)
                local dist = #(hcoords - p_coords)
                TaskGoToCoordAnyMeans(petData.ped, p_coords.x, p_coords.y, p_coords.z, 1.0, 0, false, 786603, 0xbf800000)
                while dist > 1.2 do
                    Citizen.Wait(100)
                    hcoords = GetEntityCoords(petData.ped)
                    dist = #(hcoords - p_coords)
                    if GetGameTimer() - startTime > maxWaitTime then break end
                end
                TaskTurnPedToFaceEntity(petData.ped, cookitem, 2000)
                Wait(500)
            end

            State.PlayPetAnimation(companionid, "amb_creature_mammal@world_dog_eating_ground@base", "base", false)
            PlaySoundFrontend("Core_Fill_Up", "Consumption_Sounds", true, 0)
            Wait(2000)

            SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, false)
            TriggerServerEvent('hdrp-pets:server:useitem', itemName, companionid)
            local companionHealth = Citizen.InvokeNative(0x36731AC041289BB1, petData.ped, 0)
            if not tonumber(companionHealth) then companionHealth = 0 end
            local newHealth = Config.PetFeed[itemName]["health"] + companionHealth
            Citizen.InvokeNative(0xC6258F41D86676E0, petData.ped, 0, newHealth)
            Wait(8000)

            State.ClearPetAnimation(companionid)
            -- Limpiar solo el objeto de comida asociado a esta mascota
            if cookitem and petData._foodProps then
                for i, obj in ipairs(petData._foodProps) do
                    if DoesEntityExist(obj) then
                        SetEntityAsNoLongerNeeded(obj)
                        DeleteEntity(obj)
                    end
                    petData._foodProps[i] = nil
                end
            end
            Wait(2000)
            local ManageSpawn = lib.load('client.stable.utils_spawn')
            ManageSpawn.moveCompanionToPlayer(petData.ped, cache.ped)
        else
            lib.notify({ title = locale('cl_error_feed')..' ' .. itemName .. ' '..locale('cl_error_feed_invalid'), type = 'error', duration = 7000 })
        end
    end
end)

-----------------
-- ACTIONS CLEAN
-----------------
-- dirt check thread
CreateThread(function()
    while true do
        Wait(10)
        for companionid, petData in pairs(State.GetAllPets()) do
            if petData and petData.spawned and DoesEntityExist(petData.ped) then
                local sleep = 5000
                local petdirt = Citizen.InvokeNative(0x147149F2E909323C, petData.ped, 16, Citizen.ResultAsInteger())
                -- Sincroniza dirt con el server y actualiza el State local si aplica
                if companionid and petdirt then
                    TriggerServerEvent('hdrp-pets:server:setdirt', companionid, petdirt)
                    if petData.data and petData.data.stats then
                        petData.data.stats.dirt = petdirt
                    end
                end
                Wait(sleep)
            else
                Wait(10000)
            end
        end
    end
end)

-- player brush companion
RegisterNetEvent('hdrp-pets:client:brush')
AddEventHandler('hdrp-pets:client:brush', function(itemName)
    -- Usar el helper centralizado para obtener la mascota más cercana
    local petData, distance, companionid = State.GetClosestPet()
    if not petData or not petData.ped or not DoesEntityExist(petData.ped) then
        lib.notify({ title = locale('cl_error_no_pet_out'), type = 'error', duration = 7000 })
        return
    end

    local pcoords = GetEntityCoords(cache.ped)
    local hcoords = GetEntityCoords(petData.ped)
    if distance > 2.0 then
        lib.notify({ title = locale('cl_error_brush_need_to_be_closer'), type = 'error', duration = 7000 })
        return
    end

    if not RSGCore.Functions.HasItem(itemName) then
        lib.notify({ title = locale('cl_brush_need_item')..' '.. RSGCore.Shared.Items[tostring(itemName)].label, duration = 7000, type = 'error' })
        return
    end

    SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)
    State.ResetPlayerState()
    Wait(100)
    local boneIndex = GetEntityBoneIndexByName(cache.ped, "SKEL_R_Finger00")
    local brushitem = CreateObject(`p_brushHorse02x`, pcoords.x, pcoords.y, pcoords.z, true, true, true)
    AttachEntityToEntity(brushitem, cache.ped, boneIndex, 0.06, -0.08, -0.03, -30.0, 0.0, 60.0, true, false, true, false, 0, true)
    Citizen.InvokeNative(0xCD181A959CFDD7F4, cache.ped, petData.ped, `INTERACTION_DOG_PATTING`, 0, 0)
    Wait(8000)
    Citizen.InvokeNative(0xE3144B932DFDFF65, petData.ped, 0.0, -1, 1, 1)
    ClearPedEnvDirt(petData.ped)
    ClearPedDamageDecalByZone(petData.ped, 10, "ALL")
    ClearPedBloodDamage(petData.ped)
    Citizen.InvokeNative(0xD8544F6260F5F01E, petData.ped, 10)

    -- Limpieza del prop
    if brushitem and DoesEntityExist(brushitem) then
        SetEntityAsNoLongerNeeded(brushitem)
        DeleteEntity(brushitem)
    end

    PlaySoundFrontend("Core_Fill_Up", "Consumption_Sounds", true, 0)
    Wait(100)
    State.ResetPlayerState()
    SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, false)
    local companiondirt = Citizen.InvokeNative(0x147149F2E909323C, petData.ped, 16, Citizen.ResultAsInteger())
    local dirt = (companiondirt - Config.Consumables.Brushdirt) or 0
    Citizen.InvokeNative(0xC6258F41D86676E0, petData.ped, 16, dirt)
    TriggerServerEvent('hdrp-pets:server:useitem', itemName, companionid)
end)

-----------------
-- ACTIONS REVIVE
-----------------
-- blip for dead pet
local function blipfordead(entity)
    if not entity or not DoesEntityExist(entity) then return end
    local petData, companionid = State.GetPetByEntity(entity)
    if not petData or not companionid then return end

    -- Crear blip temporal
    local targetCoords = GetEntityCoords(entity)
    local blipdead = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, targetCoords.x, targetCoords.y, targetCoords.z)
    Citizen.InvokeNative(0x662D364ABF16DE2F, blipdead, Config.Blip.ColorModifier)
    SetBlipSprite(blipdead, Config.Blip.Dead.blipSprite, true)
    SetBlipScale(blipdead, Config.Blip.Dead.blipScale)
    Citizen.InvokeNative(0x45FF974EEA1DCE36, blipdead, true)
    Citizen.InvokeNative(0x9CB1A1623062F402, blipdead, Config.Blip.Dead.blipName)
    lib.notify({ title = locale('cl_error_pet_dead'), type = 'error', duration = 5000 })

    if DoesBlipExist(blipdead) then
        Wait(Config.Blip.Dead.blipTime)
        RemoveBlip(blipdead)
    end

    -- Limpieza y despawn si aplica
    if Config.PetAttributes.AutoDeadSpawn.active then
        Wait(Config.PetAttributes.AutoDeadSpawn.Time)
        DeletePed(entity)
        SetEntityAsNoLongerNeeded(entity)
        -- Limpieza robusta usando helpers
        State.DismissPet(companionid)
    end
end

-- Health/Hunger/Death Check with Safety Timeout
CreateThread(function()
    while true do
        Wait(10)
        for companionid, petData in pairs(State.GetAllPets()) do
            if petData and petData.spawned and DoesEntityExist(petData.ped) then
                local sleep = 5000
                local stats = petData.data and petData.data.stats or {}
                local vet = petData.data and petData.data.veterinary or {}
                local pedDead = vet.dead or IsEntityDead(petData.ped)
                local curHp = GetEntityHealth(petData.ped)
                local hunger = tonumber(stats.hunger) or 100
                local thirst = tonumber(stats.thirst) or 100
                local happiness = tonumber(stats.happiness) or 100
                local cleanliness = 100 - (tonumber(stats.dirt) or 0)

                if pedDead then
                    -- Marcar como muerto y limpiar estado
                    SetEntityHealth(petData.ped, 0)
                    if not vet.dead then
                        vet.dead = true
                        TriggerServerEvent('hdrp-pets:server:setrip', companionid)
                    end
                    -- Blip y limpieza visual
                    if blipfordead then blipfordead(petData.ped) end
                    sleep = 1000
                else
                    -- Mascota viva: actualizar stats y vida
                    if vet.dead then vet.dead = false end
                    if hunger == 0 or thirst == 0 or happiness < 10 or cleanliness < 20 then
                        if curHp > 0 then SetEntityHealth(petData.ped, curHp - 5) end
                    elseif hunger < 30 or thirst < 30 or happiness < 20 or cleanliness < 40 then
                        if curHp > 0 then SetEntityHealth(petData.ped, curHp - 1) end
                    end
                end
                Wait(sleep)
            else
                Wait(10000)
            end
        end
    end
end)


-- Player revive companion
RegisterNetEvent("hdrp-pets:client:revive")
AddEventHandler("hdrp-pets:client:revive", function()
    -- Usar el helper centralizado para obtener la mascota más cercana
    local petData, distance, companionid = State.GetClosestPet()
    if not petData or not petData.ped or not DoesEntityExist(petData.ped) then
        lib.notify({ title = locale('cl_error_no_pet_out'), type = 'error', duration = 7000 })
        return
    end

    if IsEntityDead(cache.ped) then
        lib.notify({ title = locale('cl_error_player_dead'), type = 'error', duration = 7000 })
        return
    end

    if distance > 2.5 then
        lib.notify({ title = locale('cl_error_pet_too_far'), type = 'error', duration = 7000 })
        return
    end

    if not IsEntityDead(petData.ped) then
        lib.notify({ title = locale('cl_error_pet_not_injured_dead'), type = 'error', duration = 7000 })
        return
    end

    local itemRevive = Config.Items.Revive
    if not RSGCore.Functions.HasItem(itemRevive) then
        lib.notify({ title = locale('cl_error_revive_need_item')..' '.. RSGCore.Shared.Items[tostring(itemRevive)].label, duration = 7000, type = 'error' })
        return
    end

    State.RequestControl(petData.ped)
    ManageSpawn.crouchInspectAnim()
    Wait(3000)
    State.ResetPlayerState(true)

    TriggerServerEvent('hdrp-pets:server:setrevive', itemRevive, companionid)
    State.DismissPet(companionid)
    Wait(1000)
    ExecuteCommand('pet_call')
end)
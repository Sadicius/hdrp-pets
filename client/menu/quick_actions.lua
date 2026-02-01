local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

--[[
    QUICK ACTIONS MENU
    Acciones rápidas para controlar todas las mascotas spawneadas
    - Control: Follow All, Stay All, Call All, Dismiss All
]]
local State = exports['hdrp-pets']:GetState()
local ManageSpawn = lib.load('client.stable.utils_spawn')
local QuickActions = {}

function QuickActions.ShowMenu()
    RSGCore.Functions.TriggerCallback('hdrp-pets:server:getactivecompanions', function(serverPets)
        State.Pets = State.Pets or {}
        for _, dbPetData in ipairs(serverPets or {}) do
            local companionid = dbPetData.companionid or nil
            local petData = type(dbPetData.data) == 'string' and json.decode(dbPetData.data) or dbPetData.data or {}
            State.Pets[companionid] = State.Pets[companionid] or {}
            State.Pets[companionid].data = petData
            -- Puedes sincronizar otros campos si es necesario
        end
        local activePets = State.GetAllPets()
        local spawnedPets = {}
        for companionid, petData in pairs(activePets) do
            if petData and petData.spawned and DoesEntityExist(petData.ped) then
                spawnedPets[companionid] = petData
            end
        end
        local petCount = State.GetActivePetCount()
        if petCount == 0 then
            lib.notify({ title = locale('cl_error_pet_no_active'), type = 'error', duration = 5000 })
            return
        end
        local options = {}

        -- CONTROL 1: FOLLOW ALL
        options[#options + 1] = {
            title = locale('cl_action_follow_all'),
            metadata = {
                {label = locale('cl_pet_count'), value = petCount},
            },
            onSelect = function()
                local successCount = 0
                local petIndex = 0
                local offsets = {
                    {x = -2.0, y = -2.0},
                    {x = -2.0, y = 2.0},
                    {x = -3.5, y = -1.0},
                    {x = -3.5, y = 1.0},
                    {x = -4.5, y = 0.0},
                    {x = -5.0, y = -2.0},
                    {x = -5.0, y = 2.0},
                    {x = -6.0, y = 0.0}
                }
                for companionid, petData in pairs(spawnedPets) do
                    if DoesEntityExist(petData.ped) then
                        petIndex = petIndex + 1
                        local isHerding = State.GetFlag(petData.ped, 'isHerding')
                        local isWandering = State.GetFlag(petData.ped, 'isWandering')
                        local isFrozen = State.GetFlag(petData.ped, 'isFrozen')
                        if isHerding then StopPetHerding(companionid) end
                        if isWandering then StopPetWandering(companionid) end
                        if isFrozen then
                            State.petUnfreeze(petData.ped)
                        end
                        ClearPedTasksImmediately(petData.ped)
                        if State.SetPetTrait then
                            State.SetPetTrait(companionid, 'isFollowing', true)
                        end
                        local offset = offsets[petIndex] or {x = -4.0, y = 0.0}
                        Wait(100)
                        TaskFollowToOffsetOfEntity( petData.ped, cache.ped, offset.x, offset.y, 0.0, 1.5, -1, 3.0, 0 )
                        successCount = successCount + 1
                    end
                end
                lib.notify({ title = locale('cl_success_follow_all'):format(successCount), type = 'success', duration = 5000 })
            end
        }

        -- CONTROL 2: STAY ALL
        options[#options + 1] = {
            title = '🛑 ' .. locale('cl_action_stay_all'),
            onSelect = function()
                local successCount = 0
                for companionid, petData in pairs(spawnedPets) do
                    if DoesEntityExist(petData.ped) then
                        ClearPedTasksImmediately(petData.ped)
                        State.PlayPetAnimation(companionid, "amb_creature_mammal@world_dog_sitting@base", "base", true, -1)
                        successCount = successCount + 1
                        Wait(50)
                    end
                end
                lib.notify({ title = locale('cl_success_stay_all'):format(successCount),  type = 'success',  duration = 5000 })
            end
        }

        -- CONTROL 3: HUNT ALL
        options[#options + 1] = {
            title = '🦅 ' .. locale('cl_action_hunt'),
            onSelect = function()
                local dismissedCount = 0
                local successCount = 0
                for companionid, petData in pairs(spawnedPets) do
                    local xp = (petData.progression and petData.progression.xp) or 0
                    local isHunting = State.GetFlag(petData.ped, "isHunting")
                    if xp < Config.XP.Trick.Hunt then
                        lib.notify({ title = locale('cl_error_xp_needed'):format(Config.XP.Trick.Hunt), type = 'error' })
                        return
                    end
                    if petData.ped and DoesEntityExist(petData.ped) and not IsEntityDead(petData.ped) and companionid then
                        if not isHunting then
                            State.SetPetTrait(companionid, 'isHunting', true)
                            dismissedCount = dismissedCount + 1
                            Wait(100)
                        else
                            State.SetPetTrait(companionid, 'isHunting', false)
                            successCount = successCount + 1
                            Wait(100)
                        end
                    end
                end
                if not isHunting then
                    lib.notify({  title = locale('cl_info_retrieve'),  description = dismissedCount .. ' pet(s)', type = 'success',  duration = 5000  })
                else
                    lib.notify({  title = locale('cl_info_hunt_disabled'),  description = dismissedCount .. ' pet(s)', type = 'success',  duration = 5000  })
                end
            end
        }

        -- CONTROL 4: MULTI-PET TREASURE HUNT
        local validTreasurePets = 0
        local hasShovel = RSGCore.Functions.HasItem(Config.Items.Treasure)
        for companionid, petData in pairs(spawnedPets) do
            local xp = (petData.data and petData.data.progression and petData.data.progression.xp) or 0
            if xp >= Config.XP.Trick.TreasureHunt and hasShovel then
                validTreasurePets = validTreasurePets + 1
            end
        end

        if validTreasurePets >= 2 then
            options[#options + 1] = {
                title = '💎 ' .. locale('cl_action_treasure_hunt_multi'),
                metadata = {
                    {label = locale('cl_valid_pets'), value = validTreasurePets},
                    {label = locale('cl_xp_required'), value = Config.XP.Trick.TreasureHunt},
                    {label = locale('cl_item_required'), value = 'shovel ' .. (hasShovel and '✅' or '❌')},
                },
                onSelect = function()
                    if not hasShovel then
                        lib.notify({ title = locale('cl_error_treasure_hunt_requirement'), type = 'error' })
                        return
                    end
                    -- Execute multi-pet treasure hunt command
                    ExecuteCommand('pet_treasure')
                end
            }
        end 

        -- CONTROL 5: DISMISS ALL
        options[#options + 1] = {
            title = '👋 ' .. locale('cl_pet_menu_dismiss_all'),
            onSelect = function()
                local dismissedCount = 0
                for companionid, petData in pairs(spawnedPets) do
                    if petData and petData.ped then
                        Flee(petData.ped)
                        dismissedCount = dismissedCount + 1
                        Wait(100)
                    end
                end
                lib.notify({  title = locale('cl_success_title'),  description = dismissedCount .. ' pet(s) dismissed', type = 'success',  duration = 5000  })
            end
        }

        -- CARE 6: STORE ALL
        options[#options + 1] = {
            title = '💤 ' .. locale('cl_action_store_all'),
            onSelect = function()
                local successCount = 0
                for companionid, petData in pairs(spawnedPets) do
                    TriggerServerEvent('hdrp-pets:server:store', companionid)
                    if petData and petData.ped then
                        Flee(petData.ped)
                        successCount = successCount + 1
                        Wait(100)
                    end
                end
                lib.notify({ title = locale('cl_success_store_all'):format(successCount),  type = 'success', duration = 5000 })
            end
        }  

        lib.registerContext({
            id = 'quick_actions_menu',
            title = locale('cl_pet_menu_quick_actions'),
            menu = 'pet_main_menu',
            onBack = function() end,
            options = options
        })
        
        lib.showContext('quick_actions_menu')
    end)
end

return QuickActions
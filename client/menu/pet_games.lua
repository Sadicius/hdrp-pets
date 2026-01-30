--[[
    - Bone Game (XP >= 50 + bone)
    - Bury Bone (XP >= 100 + bone + no buried)
    - Find Buried Bone (XP >= 100 + buried exists)
    - Dig Random (XP >= 150)
    - Treasure Hunt (XP >= 200 + treasure_map)
]]

local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()

function ShowPetGamesTab(companionid)
    local pet = State.GetPet(companionid)
    local companionData = pet and pet.data or {}
    local petName = (companionData.info and companionData.info.name) or 'Unknown'
    local xp = (companionData.progression and companionData.progression.xp) or 0
    local isPetAlive = pet and pet.spawned and DoesEntityExist(pet.ped) and not IsEntityDead(pet.ped)
    local options = {}
    if not isPetAlive then
        options[#options + 1] = {
            title = '❌ ' .. locale('cl_error_pet_dead'),
            disabled = true
        }
    else
        -- Check if pet has low needs
        local hunger = (companionData.stats and companionData.stats.hunger) or 100
        local thirst = (companionData.stats and companionData.stats.thirst) or 100
        local happiness = (companionData.stats and companionData.stats.happiness) or 100
        if hunger < 30 or thirst < 30 or happiness < 20 then
            options[#options + 1] = {
                title = '⚠️ ' .. locale('cl_warning_needs'),
                metadata = {
                    {label = locale('cl_stat_hunger'), value = hunger .. '%'},
                    {label = locale('cl_stat_thirst'), value = thirst .. '%'},
                    {label = locale('cl_stat_happiness'), value = happiness .. '%'}
                }
            }
        end

        -- GAME 1: BONE GAME (XP >= 50 + bone)
        local canPlayBone = xp >= Config.XP.Trick.Bone
        local hasBone = RSGCore.Functions.HasItem(Config.Items.Bone)
        
        if canPlayBone then
            options[#options + 1] = {
                title = '🦴 ' .. locale('cl_game_bone'),
                metadata = {
                    {label = locale('cl_xp_required'), value = Config.XP.Trick.Bone .. (canPlayBone and ' ✅' or ' ❌')},
                    {label = locale('cl_item_required'), value = 'bone ' .. (hasBone and '✅' or '❌')},
                    {label = 'XP Reward', value = '+' .. Config.XP.Increase.PerBone .. ' XP'}
                },
                onSelect = function()
                    if not hasBone then
                        lib.notify({ title = locale('cl_error_bone_need_item'), type = 'error' })
                        return
                    end
                    TriggerEvent('hdrp-pets:client:playbone', companionid)
                end
            }
        end

        -- GAME 2: BURY BONE (XP >= 100 + bone + no buried)
        local canBuryBone = xp >= Config.XP.Trick.BuriedBone
        local isBuriedBone = exports['hdrp-pets']:BuriedBoneCoords()
        
        if canBuryBone then
            options[#options + 1] = {
                title = '🕳️ ' .. locale('cl_game_buried_bone'),
                disabled = not (canBuryBone and hasBone and not isBuriedBone),
                metadata = {
                    {label = locale('cl_xp_required'), value = Config.XP.Trick.BuriedBone .. (canBuryBone and ' ✅' or ' ❌')},
                    {label = locale('cl_item_required'), value = 'bone ' .. (hasBone and '✅' or '❌')},
                    {label = locale('cl_status'), value = isBuriedBone and locale('cl_already_buried') .. ' ❌' or locale('cl_can_bury') .. ' ✅'}
                },
                onSelect = function()
                    if not hasBone then
                        lib.notify({ title = locale('cl_error_bone_need_item'), type = 'error' })
                        return
                    end
                    if isBuriedBone then
                        lib.notify({ title = locale('cl_error_bone_already_buried'), type = 'error' })
                        return
                    end
                    TriggerEvent('hdrp-pets:client:buryBone')
                end
            }

        -- GAME 3: FIND BURIED BONE (XP >= 100 + buried exists)
            options[#options + 1] = {
                title = '🔍 ' .. locale('cl_game_find_buried'),
                disabled = not (canBuryBone and isBuriedBone),
                metadata = {
                    {label = locale('cl_xp_required'), value = Config.XP.Trick.BuriedBone .. (canBuryBone and ' ✅' or ' ❌')},
                    {label = locale('cl_buried_bone'), value = isBuriedBone and locale('cl_yes') .. ' ✅' or locale('cl_no') .. ' ❌'}
                },
                onSelect = function()
                    if not isBuriedBone then
                        lib.notify({ title = locale('cl_error_no_buried_bone'), type = 'error' })
                        return
                    end
                    TriggerEvent('hdrp-pets:client:findBuriedBone', companionid)
                end
            }
        end

        -- GAME 4: DIG RANDOM (XP >= 150)
        local canDigRandom = xp >= Config.XP.Trick.digRandom
        if canDigRandom then
            options[#options + 1] = {
                title = '🎲 ' .. locale('cl_game_dig_random'),
                metadata = {
                    {label = locale('cl_xp_required'), value = Config.XP.Trick.digRandom .. (canDigRandom and ' ✅' or ' ❌')},
                    {label = 'XP Reward', value = '+' .. Config.XP.Increase.PerDigRandom .. ' XP'},
                    {label = locale('cl_success_rate'), value = '20%'},
                    {label = locale('cl_possible_rewards'), value = 'Raw Meat, Bread, Water'}
                },
                onSelect = function()
                    TriggerEvent('hdrp-pets:client:digRandomItem', companionid)
                end
            }
        end

        -- GAME 5: TREASURE HUNT (XP >= 200 + treasure_map)
        local canTreasureHunt = xp >= Config.XP.Trick.TreasureHunt
        local hasTreasureMap = RSGCore.Functions.HasItem(Config.Items.Treasure)
        if canTreasureHunt then 
            options[#options + 1] = {
                title = '💎 ' .. locale('cl_game_treasure_hunt'),
                metadata = {
                    {label = locale('cl_xp_required'), value = Config.XP.Trick.TreasureHunt .. (canTreasureHunt and ' ✅' or ' ❌')},
                    {label = locale('cl_item_required'), value = 'treasure_map ' .. (hasTreasureMap and '✅' or '❌')},
                    {label = 'XP Reward', value = '+' .. Config.XP.Increase.PerTreasure .. ' XP'},
                    {label = locale('cl_clues'), value = '2-6 ' .. locale('cl_steps')},
                    {label = locale('cl_distance'), value = '50-100m ' .. locale('cl_per_clue')},
                    {label = '⚠️ ' .. locale('cl_risk'), value = '15% ' .. locale('cl_hostile_encounter')}
                },
                onSelect = function()
                    if not hasTreasureMap then
                        lib.notify({ title = locale('cl_error_treasure_hunt_requirement'), type = 'error' })
                        return
                    end
                    TriggerEvent('hdrp-pets:client:startTreasureHunt', companionid)
                end
            }
        end
    end
    
    lib.registerContext({
        id = 'pet_games_tab',
        title = locale('cl_tab_games'),
        menu = 'pet_dashboard',
        onBack = function() end,
        onExit = function()
        end,
        options = options
    })
    
    lib.showContext('pet_games_tab')
end

local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
local ManageSpawn = lib.load('client.stable.utils_spawn')
--[[
    - Store, Follow, Stay, Lay, Hunt, Call, Dismiss (alive)
    - Animations, Track, Wandering Mode
    - Store, Revive (dead)
]]

local Actions = {}
    
local function ShowWanderingSettingsMenu(companionid)
    local pet = State.GetPet(companionid)
    local isWanderingEnabled = (pet and pet.flag and pet.flag.isWandering) or false
    local currentDistance = (Config.Wandering and Config.Wandering.MaxDistance) or 20
    local options = {}
    
    -- STATUS INFO
    options[#options + 1] = {
        title = '📊 ' .. locale('cl_wandering_status_title'),
        description = locale('cl_wandering_status_desc'),
    }
    
    -- TOGGLE ENABLED
    options[#options + 1] = {
        title = '🔄 ' .. locale('cl_wandering_toggle'),
        description = locale('cl_wandering_status') .. ': ' .. (isWanderingEnabled and locale('cl_enabled') or locale('cl_disabled')),
        icon = isWanderingEnabled and 'fa-solid fa-toggle-on' or 'fa-solid fa-toggle-off',
        onSelect = function()
            -- Toggle wandering
            TriggerEvent('hdrp-pets:client:toggleWandering', companionid)
        end
    }
    
    -- DISTANCE SETTINGS
    options[#options + 1] = {
        title = '📏 ' .. locale('cl_wandering_distance'),
        description = locale('cl_wandering_distance_desc'):format(currentDistance),
        metadata = {
            {label = locale('cl_current_distance'), value = currentDistance .. 'm'}
        },
        -- disabled = true
    }
    
    lib.registerContext({
        id = 'wandering_settings_menu',
        title = locale('cl_wandering_settings'),
        menu = 'pet_actions_tab',
        onBack = function() end,
        options = options
    })
    
    lib.showContext('wandering_settings_menu')
end

--[[
    MAIN ACTIONS TAB
    Menú principal de acciones de la mascota
]]

function Actions.ShowTab(companionid)
    local pet = State.GetPet(companionid)
    local companionData = pet and pet.data or {}
    local petName = companionData.info and companionData.info.name or 'Unknown'
    local xp = (companionData.progression and companionData.progression.xp) or 0
    local isHunting = (pet and pet.flag and pet.flag.isHunting) or false
    local isPetAlive = pet and pet.spawned and DoesEntityExist(pet.ped) and not IsEntityDead(pet.ped)
    local options = {}

    if isPetAlive then
        -- ALIVE PET ACTIONS

        if Config.Wandering.Enabled then
            options[#options + 1] = {
                title = '🚶 ' .. locale('cl_action_wandering'),
                arrow = true,
                onSelect = function()
                    ShowWanderingSettingsMenu(companionid)
                end
            }
        end

        local canHunt = xp >= Config.XP.Trick.Hunt
        if canHunt then
            options[#options + 1] = {
                title = '🦅 ' .. locale('cl_action_hunt'),
                onSelect = function()
                    if xp < Config.XP.Trick.Hunt then
                        lib.notify({ title = locale('cl_error_xp_needed'):format(Config.XP.Trick.Hunt), type = 'error' })
                        return
                    end
                    if not isHunting then
                        lib.notify({ title = locale('cl_info_retrieve'), type = 'info', duration = 7000 })
                        State.SetPetTrait(companionid, 'isHunting', true)
                    else
                        State.SetPetTrait(companionid, 'isHunting', false)
                        lib.notify({ title = locale('cl_info_hunt_disabled'), type = 'info', duration = 7000 })
                    end
                end
            }
        end

        local canStay = xp >= Config.XP.Trick.Stay
        if canStay then
            options[#options + 1] = {
                title = '🛑 ' .. locale('cl_action_stay'),
                onSelect = function()
                    if xp < Config.XP.Trick.Stay then
                        lib.notify({ title = locale('cl_error_xp_needed'):format(Config.XP.Trick.Stay), type = 'error' })
                        return
                    end
                    if not pet or not pet.ped or not DoesEntityExist(pet.ped) then
                        lib.notify({ title = locale('cl_error_pet_no_active'), type = 'error' })
                        return
                    end
                    State.PlayPetAnimation(companionid, "amb_creature_mammal@world_dog_sitting@base", "base", true)
                    lib.notify({ title = locale('cl_success_stay'), type = 'success' })
                end
            }
        end

        local canLay = xp >= Config.XP.Trick.Lay
        if canLay then
            options[#options + 1] = {
                title = '🦴 ' .. locale('cl_action_lay'),
                onSelect = function()
                    if xp < Config.XP.Trick.Lay then
                        lib.notify({ title = locale('cl_error_xp_needed'):format(Config.XP.Trick.Lay), type = 'error' })
                        return
                    end
                    State.PlayPetAnimation(companionid, 'amb_creature_mammal@world_dog_resting@base', 'base', true)
                    lib.notify({ title = locale('cl_success_lay'), type = 'success' })
                end
            }
        end

        options[#options + 1] = {
            title = '🚶 ' .. locale('cl_action_follow'),
            onSelect = function()
                if not pet or not pet.ped or not DoesEntityExist(pet.ped) then
                    lib.notify({ title = locale('cl_error_pet_no_active'), type = 'error' })
                    return
                end
                ManageSpawn.moveCompanionToPlayer(pet.ped, cache.ped)
                lib.notify({ title = locale('cl_success_follow'), type = 'success' })
            end
        }

        options[#options + 1] = {
            title = '💤 ' .. locale('cl_action_store'),
            onSelect = function()
                TriggerServerEvent('hdrp-pets:server:store', companionid)
                if pet and pet.ped then
                    Flee(pet.ped)
                end
                lib.notify({ title = locale('cl_success_sleep'), type = 'success' })
            end
        }

        options[#options + 1] = {
            title = '👋 ' .. locale('cl_action_dismiss'),
            onSelect = function()
                if pet and pet.ped then
                    Flee(pet.ped)
                end
                lib.notify({ title = locale('cl_success_dismiss'), type = 'success' })
            end
        }

    else
        -- DEAD PET ACTIONS
        options[#options + 1] = {
            title = '💤 ' .. locale('cl_action_store'),
            onSelect = function()
                TriggerServerEvent('hdrp-pets:server:store', companionid)
                if pet and pet.ped then
                    Flee(pet.ped)
                end
                lib.notify({ title = locale('cl_success_store'), type = 'success' })
            end
        }

        local itemrevivesend = Config.Items.Revive
        local hasItem = RSGCore.Functions.HasItem(itemrevivesend)
        options[#options + 1] = {
            title = '💊 ' .. locale('cl_action_revive'),
            disabled = not hasItem,
            metadata = {
                {label = locale('cl_item_required'), value = hasItem and '✅' or '❌'}
            },
            onSelect = function()
                if not hasItem then
                    lib.notify({ title = locale('cl_error_revive_need_item'), type = 'error' })
                    return
                end
                TriggerEvent('hdrp-pets:client:feed', itemrevivesend, companionid)
            end
        }
    end

    lib.registerContext({
        id = 'pet_actions_tab',
        title = locale('cl_label_actions'),
        menu = 'pet_dashboard',
        onBack = function() end,
        onExit = function()
        end,
        options = options
    })

    lib.showContext('pet_actions_tab')
end

--[[
    ANIMATIONS MENU
    Sub-menú de animaciones
]]

function Actions.ShowAnimationsMenu(companionid)
    local petState = State.GetPet(companionid)
    if not petState or not petState.ped or not DoesEntityExist(petState.ped) then
        lib.notify({ title = locale('cl_error_pet_no_active'), type = 'error' })
        return
    end
    local xp = (petState.data and petState.data.progression and petState.data.progression.xp) or 0
    local options = {}


    -- Load animations config
    local animations = Config.Animations or {}
    local unlockedCount = 0
    local totalCount = #animations

    -- Count unlocked animations
    for _, anim in ipairs(animations) do
        if xp >= anim.experience then
            unlockedCount = unlockedCount + 1
        end
    end

    -- Header with progress
    options[#options + 1] = {
        title = '📊 ' .. locale('cl_unlocked') .. ': ' .. unlockedCount .. '/' .. totalCount,
        disabled = true
    }

    -- Footer with next unlock
    if unlockedCount < totalCount then
        for _, anim in ipairs(animations) do
            if xp < anim.experience then
                local xpNeeded = anim.experience - xp
                options[#options + 1] = {
                    title = '👉🏻 ' .. locale('cl_next_unlock'),
                    metadata = {
                        {label = locale('cl_buy_pet_type'), value = anim.label},
                        {label = locale('cl_in'), value = xpNeeded .. ' XP'}
                    },
                }
                break
            end
        end
    end
    -- STOP ANIMATION
    options[#options + 1] = {
        title = '✋🏻 ' .. locale('cl_action_anim_stop'),
        onSelect = function()
            State.ClearPetAnimation(companionid)
            lib.showContext('animations_menu')
        end
    }

    -- Animation options
    for _, anim in ipairs(animations) do
        local isUnlocked = xp >= anim.experience
        local icon = isUnlocked and '✅' or '🔒'
        local xpNeeded = isUnlocked and 0 or (anim.experience - xp)

        options[#options + 1] = {
            title = icon .. ' ' .. anim.label,
            metadata = {
               {label = locale('cl_xp_required'), value = anim.experience .. ' '..icon}
            },
            onSelect = function()
                State.PlayPetAnimation(companionid, anim.dict, anim.dictname, true)
                lib.showContext('animations_menu')
            end
        }
    end

    lib.registerContext({
        id = 'animations_menu',
        title = locale('cl_menu_animations'),
        menu = 'pet_actions_tab',
        onBack = function() end,
        options = options
    })

    lib.showContext('animations_menu')
end

return Actions
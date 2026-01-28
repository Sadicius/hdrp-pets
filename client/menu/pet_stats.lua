local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
local Stats = {}

local function notifyNoItem(item)
    lib.notify({
        title = locale('sv_error_brush') .. ' ' .. RSGCore.Shared.Items[tostring(item)].label,
        type = 'error',
        duration = 5000
    })
end

local function createInteractiveOption(title, value, color, hasItem, item, event, petData, companionid)
    return {
        title = title .. ': ' .. value .. '%',
        progress = value,
        colorScheme = color,
        onSelect = function()
            if not hasItem then
                notifyNoItem(item)
                return
            end
            -- State.SetTargetedPet(petData and petData.ped, companionid)
            TriggerEvent(event, item, companionid)
        end
    }
end

function Stats.ShowTab(companionid)
    local pet = State.GetPet(companionid)
    if not pet or not pet.data then
        lib.notify({ title = locale('cl_error_pet_not_found'), type = 'error', duration = 5000 })
        return
    end
    local data = pet.data
    local info = data.info or {}
    local stats = data.stats or {}
    local petName = info.name or 'Unknown'
    local xp = math.floor((data.progression and data.progression.xp) or 0)
    local level = State.GetPetLevel and State.GetPetLevel(xp) or math.floor(xp / 100) + 1
    local age = math.floor(stats.age or 0)

    local options = {}

    -- XP & LEVEL
    local xpForNextLevel = (level * 100)
    local xpProgress = xp % 100
    local xpNeeded = xpForNextLevel - xp
    options[#options + 1] = {
        title = '💫 XP: ' .. xp .. '/' .. xpForNextLevel .. ' (' .. locale('cl_level') .. ' ' .. level .. ')',
        progress = math.floor((xpProgress / 100) * 100),
        colorScheme = '#e8a93f',
        metadata = {
            {label = locale('cl_current_level'), value = xpNeeded .. ' XP ' .. locale('cl_to_level') .. ' ' .. (level + 1)},
            {label = locale('cl_current_level'), value = level},
            {label = locale('cl_xp_to_next'), value = xpNeeded .. '/' .. (level * 100) .. ' (' .. math.floor((xpProgress / 100) * 100) .. '%)'},
            {label = locale('cl_next_unlock'), value = locale('cl_check_actions')}
        }
    }

    -- HEALTH
    local health = 100
    if pet.spawned and DoesEntityExist(pet.ped) then
        local currentHealth = GetEntityHealth(pet.ped)
        local maxHealth = GetEntityMaxHealth(pet.ped)
        health = math.floor((currentHealth / maxHealth) * 100)
    end
    local itemstimulantsend = Config.Items.Stimulant
    local hasItemS = RSGCore.Functions.HasItem(itemstimulantsend)
    options[#options + 1] = createInteractiveOption('💚 ' .. locale('cl_stat_health'), health, '#359d93', hasItemS, itemstimulantsend, 'hdrp-pets:client:feed', pet, companionid)

    -- HAPPINESS
    local happiness = math.floor(stats.happiness or 0)
    local itemhappysend = Config.Items.Happy
    local hasItemH = RSGCore.Functions.HasItem(itemhappysend)
    options[#options + 1] = createInteractiveOption('😊 ' .. locale('cl_stat_happiness'), happiness, '#eebd6b', hasItemH, itemhappysend, 'hdrp-pets:client:feed', pet, companionid)

    -- HUNGER
    local hunger = math.floor(stats.hunger or 0)
    local hungerColor = hunger < 30 and '#F44336' or '#bfe6ef'
    local itemfoodsend = Config.Items.Food
    local hasItemF = RSGCore.Functions.HasItem(itemfoodsend)
    options[#options + 1] = createInteractiveOption('🍖 ' .. locale('cl_stat_hunger'), hunger, hungerColor, hasItemF, itemfoodsend, 'hdrp-pets:client:feed', pet, companionid)

    -- THIRST
    local thirst = math.floor(stats.thirst or 0)
    local thirstColor = thirst < 30 and '#F44336' or '#447695'
    local itemdrinksend = Config.Items.Drink
    local hasItemT = RSGCore.Functions.HasItem(itemdrinksend)
    options[#options + 1] = createInteractiveOption('💧 ' .. locale('cl_stat_thirst'), thirst, thirstColor, hasItemT, itemdrinksend, 'hdrp-pets:client:feed', pet, companionid)

    -- CLEANLINESS
    local dirt = math.floor(stats.dirt or 0)
    local cleanliness = 100 - dirt
    local itembrushsend = Config.Items.Brush
    local hasItemB = RSGCore.Functions.HasItem(itembrushsend)
    options[#options + 1] = createInteractiveOption('🧼 ' .. locale('cl_stat_cleanliness'), cleanliness, '#04082e', hasItemB, itembrushsend, 'hdrp-pets:client:brush', pet, companionid)

    -- STRENGTH
    local strength = math.floor(stats.strength or 0)
    options[#options + 1] = {
        title = '💪 ' .. locale('cl_stat_strength') .. ': ' .. strength,
        progress = strength,
        colorScheme = '#b8860b',
    }

    lib.registerContext({
        id = 'pet_stats_tab',
        title = locale('cl_tab_statistics') , -- .. ' - ' .. petName
        menu = 'pet_dashboard',
        onBack = function() end,
        options = options
    })
    lib.showContext('pet_stats_tab')
end

return Stats
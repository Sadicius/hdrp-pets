local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- Load Database module
local Database = lib.load('server.core.database')

--================================
-- PET COMMANDS
--================================

---Find pet location
RSGCore.Commands.Add('pet_find', locale('cmd_find'), {}, false, function(source)
    TriggerClientEvent('hdrp-pets:client:getlocation', source)
end)

---Revive active pet
RSGCore.Commands.Add('pet_revive', locale('cmd_revive'), {}, false, function(source)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Get active companion using Database module
    local activeCompanion = Database.GetAllCompanionsActive(Player.PlayerData.citizenid)
    if not activeCompanion then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_error_no_active'), type = 'error', duration = 5000 })
        return
    end
    
    TriggerClientEvent('hdrp-pets:client:revive', src, activeCompanion)
end)

--================================
-- USEABLE ITEMS
--================================

---Register useable item for brush
RSGCore.Functions.CreateUseableItem(Config.Items.Brush, function(source, item)
    TriggerClientEvent('hdrp-pets:client:brush', source, item.name)
end)

---Register useable item for bone (play with pet)
RSGCore.Functions.CreateUseableItem(Config.Items.Bone, function(source)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Check for active companion using Database module
    local activeCompanion = Database.GetAllCompanionsActive(Player.PlayerData.citizenid)
    if not activeCompanion then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_error_no_active'), type = 'error', duration = 5000 })
        return
    end

    TriggerClientEvent('hdrp-pets:client:playbone', src)
end)

---Register useable item for stimulant
RSGCore.Functions.CreateUseableItem(Config.Items.Stimulant, function(source, item)
    TriggerClientEvent('hdrp-pets:client:feed', source, item.name)
end)

---Register useable item for food
RSGCore.Functions.CreateUseableItem(Config.Items.Food, function(source, item)
    TriggerClientEvent('hdrp-pets:client:feed', source, item.name)
end)

---Register useable item for drink
RSGCore.Functions.CreateUseableItem(Config.Items.Drink, function(source, item)
    TriggerClientEvent('hdrp-pets:client:feed', source, item.name)
end)

---Register useable item for happiness boost
RSGCore.Functions.CreateUseableItem(Config.Items.Happy, function(source, item)
    TriggerClientEvent('hdrp-pets:client:feed', source, item.name)
end)

---Register useable item for revive
RSGCore.Functions.CreateUseableItem(Config.Items.Revive, function(source)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    TriggerClientEvent('hdrp-pets:client:feed', src, Config.Items.Revive)
end)

-- REVIVE COMPANION
RegisterServerEvent('hdrp-pets:server:setrevive', function(item, companionid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local activeCompanion = Database.GetAllCompanionsActive(Player.PlayerData.citizenid)
    if not activeCompanion then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_error_no_active_pet'),  type = 'error',  duration = 5000  })
        return
    end

    local reviveItem = item or Config.Items.Revive
    local hasItem = reviveItem and Player.Functions.GetItemByName(reviveItem)
    if not hasItem then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_error_revive_item'), type = 'error', duration = 5000 })
        return
    end

    Player.Functions.RemoveItem(item, 1)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'remove', 1)

    local success, result = pcall(MySQL.query.await, 'SELECT * FROM pet_companion WHERE companionid = ?', { companionid })
    if not success then return end

    local currentData = json.decode(result[1].data) or json.decode(activeCompanion.data) or '{}'

    if result[1] then
        currentData.stats.hunger = Config.PetFeed['pet_reviver'].health or 75
        currentData.stats.thirst = Config.PetFeed['pet_reviver'].thirst or 75
        currentData.stats.happiness = Config.PetFeed['pet_reviver'].happiness or 50
        currentData.stats.dirt = 50
        currentData.stats.strength = Config.PetFeed['pet_reviver'].strength or 50
        currentData.veterinary.dead = false

        Database.UpdateCompanionData(companionid, currentData)
        TriggerClientEvent('hdrp-pets:client:updateanimals', src, companionid, currentData)

        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_success_pet_revived'), type = 'success', duration = 5000 })

    end

    local discordMessage = string.format(
        locale('sv_log_user')..":** %s \n**"
        ..locale('debug_id')..":** %d \n**"
        ..locale('cl_input_setup_name')..":** %s %s \n**"
        ..locale('sv_log_details').."**",
        Player.PlayerData.citizenid,
        Player.PlayerData.cid,
        Player.PlayerData.charinfo.firstname,
        Player.PlayerData.charinfo.lastname
    )
    TriggerEvent('rsg-log:server:CreateLog', Config.WebhookName, Config.WebhookTitle, Config.WebhookColour, discordMessage, false)
end)

--================================
-- ITEM USAGE ON PETS
--================================

---Use consumable items on specific companion
RegisterServerEvent('hdrp-pets:server:useitem', function(item, companionid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local activeCompanion = nil
    if companionid then
        activeCompanion = Database.GetCompanionByCompanionId(companionid)
        if not activeCompanion or activeCompanion.citizenid ~= Player.PlayerData.citizenid then
            TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_error_no_active_pet'), type = 'error', duration = 5000 })
            return
        end
    else
        activeCompanion = Database.GetAllCompanionsActive(Player.PlayerData.citizenid)
        if not activeCompanion then
            TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_error_no_active_pet'), type = 'error', duration = 5000 })
            return
        end
    end

    local currentData = json.decode(activeCompanion.data)
    
    -- Validate player has item or it's a special case
    if not (Player.Functions.GetItemByName(item) or item == Config.Items.Bone or item == 'no-item') then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_error_brush')..' '..RSGCore.Shared.Items[tostring(item)].label, type = 'error', duration = 5000 })
        return
    end
    
    -- Process item usage
    local statsChanged = false
    
    if item == Config.Items.Drink then
        Player.Functions.RemoveItem(Config.Items.Drink, 1)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[Config.Items.Drink], "remove", 1)
        
        currentData.stats.hunger = math.min(100, (currentData.stats.hunger or 0) + Config.Consumables.Hunger)
        currentData.stats.thirst = math.min(100, (currentData.stats.thirst or 0) + Config.Consumables.Thirst)
        currentData.stats.happiness = math.min(100, (currentData.stats.happiness or 0) + Config.Consumables.Happiness)
        currentData.stats.strength = math.min(100, (currentData.stats.strength or 0) + Config.Consumables.Strength)
        currentData.progression.xp = (currentData.progression.xp or 0) + Config.XP.Increase.PerDrink
        statsChanged = true
        
    elseif item == Config.Items.Food then
        Player.Functions.RemoveItem(Config.Items.Food, 1)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[Config.Items.Food], "remove", 1)
        
        currentData.stats.hunger = math.min(100, (currentData.stats.hunger or 0) + Config.Consumables.Hunger)
        currentData.stats.thirst = math.min(100, (currentData.stats.thirst or 0) + Config.Consumables.Thirst)
        currentData.stats.happiness = math.min(100, (currentData.stats.happiness or 0) + Config.Consumables.Happiness)
        currentData.stats.strength = math.min(100, (currentData.stats.strength or 0) + Config.Consumables.Strength)
        currentData.progression.xp = (currentData.progression.xp or 0) + Config.XP.Increase.PerFeed
        statsChanged = true
        
    elseif item == Config.Items.Happy then
        Player.Functions.RemoveItem(Config.Items.Happy, 1)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[Config.Items.Happy], "remove", 1)
        
        currentData.stats.hunger = math.min(100, (currentData.stats.hunger or 0) + Config.Consumables.Hunger)
        currentData.stats.thirst = math.min(100, (currentData.stats.thirst or 0) + Config.Consumables.Thirst)
        currentData.stats.happiness = math.min(100, (currentData.stats.happiness or 0) + Config.Consumables.Happiness)
        currentData.stats.strength = math.min(100, (currentData.stats.strength or 0) + Config.Consumables.Strength)
        currentData.progression.xp = (currentData.progression.xp or 0) + Config.XP.Increase.PerDrink
        statsChanged = true
        
    elseif item == Config.Items.Stimulant then
        Player.Functions.RemoveItem(Config.Items.Stimulant, 1)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[Config.Items.Stimulant], "remove", 1)
        
        currentData.stats.hunger = math.min(100, (currentData.stats.hunger or 0) + Config.Consumables.Hunger)
        currentData.stats.thirst = math.min(100, (currentData.stats.thirst or 0) + Config.Consumables.Thirst)
        currentData.stats.happiness = math.min(100, (currentData.stats.happiness or 0) + Config.Consumables.Happiness)
        currentData.stats.strength = math.min(100, (currentData.stats.strength or 0) + Config.Consumables.Strength)
        currentData.progression.xp = (currentData.progression.xp or 0) + Config.XP.Increase.PerStimulant
        statsChanged = true
        
    elseif item == 'water' then
        Player.Functions.RemoveItem("water", 1)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items["water"], "remove", 1)
        
        currentData.stats.thirst = math.min(100, (currentData.stats.thirst or 0) + Config.Consumables.Thirst)
        currentData.stats.happiness = math.min(100, (currentData.stats.happiness or 0) + Config.Consumables.Happiness)
        currentData.progression.xp = (currentData.progression.xp or 0) + Config.XP.Increase.PerDrink
        statsChanged = true
        
    elseif item == 'raw_meat' then
        Player.Functions.RemoveItem('raw_meat', 1)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['raw_meat'], "remove", 1)
        
        currentData.stats.hunger = math.min(100, (currentData.stats.hunger or 0) + Config.Consumables.Hunger)
        currentData.stats.happiness = math.min(100, (currentData.stats.happiness or 0) + Config.Consumables.Happiness)
        currentData.progression.xp = (currentData.progression.xp or 0) + Config.XP.Increase.PerFeed
        statsChanged = true
        
    elseif item == 'sugarcube' then
        Player.Functions.RemoveItem('sugarcube', 1)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['sugarcube'], "remove", 1)
        
        currentData.stats.thirst = math.min(100, (currentData.stats.thirst or 0) + Config.Consumables.Thirst)
        currentData.stats.hunger = math.min(100, (currentData.stats.hunger or 0) + Config.Consumables.Hunger)
        currentData.stats.happiness = math.min(100, (currentData.stats.happiness or 0) + Config.Consumables.Happiness)
        currentData.stats.strength = math.min(100, (currentData.stats.strength or 0) + Config.Consumables.Strength)
        currentData.progression.xp = (currentData.progression.xp or 0) + Config.XP.Increase.PerDrink
        statsChanged = true
        
    elseif item == Config.Items.Brush then
        currentData.stats.happiness = math.min(100, (currentData.stats.happiness or 0) + Config.Consumables.Happiness)
        currentData.stats.dirt = 0.0
        currentData.progression.xp = (currentData.progression.xp or 0) + Config.XP.Increase.PerClean
        statsChanged = true
        
    elseif item == Config.Items.Bone then
        currentData.stats.happiness = math.min(100, (currentData.stats.happiness or 0) + Config.Consumables.Happiness)
        currentData.progression.xp = (currentData.progression.xp or 0) + Config.XP.Increase.PerBone
        statsChanged = true
        
    elseif item == 'no-item' then
        currentData.progression.xp = (currentData.progression.xp or 0) + Config.XP.Increase.PerMove
        statsChanged = true
    end
    
    -- Update companion data if stats changed
    if statsChanged then
        Database.UpdateCompanionData(companionid, currentData)

        TriggerClientEvent('hdrp-pets:client:updateanimals', src, companionid, currentData)
    end
end)
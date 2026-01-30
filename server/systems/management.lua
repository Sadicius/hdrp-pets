local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- Load modules
local Database = lib.load('server.core.database')
local Validation = lib.load('server.core.validation')

-- Load configs
local PetShopPrice = Config.PetShopPrice
local gameDigRandomConfig = Config.Games.Gdigrandom
local gameTreasureConfig = Config.Games.Gtreasure

-- PET DELETION/SELLING
---Delete/sell companion
RegisterServerEvent('hdrp-pets:server:delete', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local companionid = data.companionid
    
    -- Verify ownership using Validation module
    if not Validation.PetOwnership(Player.PlayerData.citizenid, companionid) then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_error_not_owner'), type = 'error', duration = 5000 })
        return
    end
    
    -- Get companion data
    local companion = Database.GetCompanionByCompanionId(companionid)
    if not companion then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_error_pet_not_found'), type = 'error', duration = 5000 })
        return
    end
    
    local currentData = json.decode(companion.data)
    local modelCompanion = currentData.info.model
    local companionname = currentData.info.name
    local xp = (currentData.progression and currentData.progression.xp) or 0
    
    -- Calculate sell price
    local sellprice = 0.0
    
    for k, v in pairs(PetShopPrice) do
        if v.npcpetmodel == modelCompanion then
            sellprice = (v.npcpetprice * (Config.priceDepreciation / 100)) + (xp / 100)
            if Config.Debug then print('^2[SELL DEBUG]^7 Match found! Base price: $' .. v.npcpetprice .. ' | Depreciation: ' .. Config.priceDepreciation..  ' | Bonification XP: ' .. (xp / 100) .. '% | Sell price: $' .. sellprice) end
            break
        end
    end
    
    -- Delete companion using Database module
    local success = Database.DeleteCompanion(companionid, Player.PlayerData.citizenid)
    if not success then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('cl_error_delete_failed'), type = 'error', duration = 5000 })
        return
    end

    -- Give money to player
    Player.Functions.AddMoney('cash', sellprice)
    TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_success_pet_sold')..sellprice, type = 'success', duration = 5000 })
    
    -- Log to Discord
    local discordMessage = string.format(
        locale('sv_log_user')..":** %s \n**"
        ..locale('debug_id')..":** %d \n**"
        ..locale('cl_input_setup_name')..":** %s %s \n**"
        ..locale('sv_log_breed')..":** %s \n**"
        ..locale('sv_log_action')..":** SOLD \n**"
        ..locale('sv_log_amount')..":** $%.2f**",
        Player.PlayerData.citizenid,
        Player.PlayerData.cid,
        Player.PlayerData.charinfo.firstname,
        Player.PlayerData.charinfo.lastname,
        modelCompanion,
        sellprice
    )
    TriggerEvent('rsg-log:server:CreateLog', Config.WebhookName, Config.WebhookTitle, Config.WebhookColour, discordMessage, false)

end)

-- RANDOM REWARDS (DIGGING)
---Give random item reward (from digging minigame)
RegisterServerEvent('hdrp-pets:server:giverandom', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Check for active companion
    local activeCompanion = Database.GetAllCompanionsActive(Player.PlayerData.citizenid)
    if not activeCompanion then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_error_no_active'), type = 'error', duration = 5000 })
        return
    end
    
    -- Get random reward based on chance
    local function getRandomReward()
        local roll = math.random(1, 100)
        local acc = 0
        for _, reward in ipairs(gameDigRandomConfig.rewards) do
            acc = acc + reward.chance
            if roll <= acc then
                return reward
            end
        end
        return nil
    end
    
    local reward = getRandomReward()
    if reward and reward.items and #reward.items > 0 then
        for _, item in ipairs(reward.items) do
            local itemSuccess, itemErr = pcall(function()
                Player.Functions.AddItem(item, 1)
                TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'add', 1)
            end)
            if not itemSuccess and Config.Debug then
                print('^1[MANAGEMENT ERROR]^7 Failed to add item ' .. item .. ' to player ' .. src .. ': ' .. tostring(itemErr))
            end
        end
    end
    
    -- Log to Discord
    local rewardStr = locale('ui_reward_none')
    if reward and reward.items then
        local items = table.concat(reward.items, ", ")
        rewardStr = string.format(locale('ui_reward_chance') .. ": %s | " .. locale('ui_reward_items') .. ": [%s]", reward.chance, items)
    end
    
    local discordMessage = string.format(
        locale('sv_log_user')..":** %s \n**"
        ..locale('debug_id')..":** %d \n**"
        ..locale('cl_input_setup_name')..":** %s %s \n**"
        ..locale('sv_log_price')..":** %s \n**",
        Player.PlayerData.citizenid,
        Player.PlayerData.cid,
        Player.PlayerData.charinfo.firstname,
        Player.PlayerData.charinfo.lastname,
        rewardStr
    )
    TriggerEvent('rsg-log:server:CreateLog', Config.WebhookName, Config.WebhookTitle, Config.WebhookColour, discordMessage, false)

end)

-- TREASURE REWARDS
---Give treasure item reward (from treasure hunt minigame)
---FIX: Actualizado para recibir petId y actualizar achievements de tesoro
RegisterServerEvent('hdrp-pets:server:givetreasure', function(petId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    -- FIX: Actualizar achievements de tesoro si se proporciona petId
    if petId then
        local companion = Database.GetCompanionByCompanionId(petId)
        if companion then
            local achievements = companion.achievements and json.decode(companion.achievements) or {}
            achievements.treasure = achievements.treasure or { completed = 0 }
            achievements.treasure.completed = (achievements.treasure.completed or 0) + 1
            achievements.unlocked = achievements.unlocked or {}

            -- Verificar logros de tesoro
            local xpBonus = 0
            for key, ach in pairs(Config.XP.Achievements.List) do
                if ach.requirement and ach.requirement.type == 'treasure' then
                    if (achievements.treasure.completed or 0) >= ach.requirement.value then
                        if not achievements.unlocked[key] then
                            achievements.unlocked[key] = true
                            xpBonus = xpBonus + (ach.xpBonus or 0)
                            TriggerClientEvent('hdrp-pets:client:achievement', src, ach.name, ach.description .. ' +' .. tostring(ach.xpBonus or 0) .. ' XP')
                        end
                    end
                end
            end

            Database.UpdateCompanionAchievements(petId, achievements)

            -- Actualizar XP si hay bonus
            if xpBonus > 0 then
                local data = companion.data and json.decode(companion.data) or {}
                data.progression = data.progression or {}
                data.progression.xp = (data.progression.xp or 0) + xpBonus
                Database.UpdateCompanionData(petId, data)
                TriggerClientEvent('hdrp-pets:client:updateanimals', src, petId, data)
            end

            if Config.Debug then
                print('^2[TREASURE]^7 Updated treasure achievements for pet ' .. petId .. '. Total: ' .. achievements.treasure.completed)
            end
        end
    end

    -- Get treasure reward based on chance
    local function getTreasureReward()
        local roll = math.random(1, 100)
        local acc = 0
        for _, reward in ipairs(gameTreasureConfig.rewards) do
            acc = acc + reward.chance
            if roll <= acc then
                return reward
            end
        end
        return nil
    end

    local rewards = getTreasureReward()
    if rewards and type(rewards.items) == "table" and #rewards.items > 0 then
        local item = rewards.items[math.random(#rewards.items)]
        local itemSuccess, itemErr = pcall(function()
            Player.Functions.AddItem(item, 1)
            TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'add', 1)
        end)
        if not itemSuccess and Config.Debug then
            print('^1[MANAGEMENT ERROR]^7 Failed to add treasure item ' .. item .. ' to player ' .. src .. ': ' .. tostring(itemErr))
        end
    end

    -- Log to Discord
    local rewardStr = locale('ui_reward_none')
    if rewards and rewards.items then
        local items = table.concat(rewards.items, ", ")
        rewardStr = string.format(locale('ui_reward_chance') .. ": %s | " .. locale('ui_reward_items') .. ": [%s]", rewards.chance, items)
    end

    local discordMessage = string.format(
        locale('sv_log_user')..":** %s \n**"
        ..locale('debug_id')..":** %d \n**"
        ..locale('cl_input_setup_name')..":** %s %s \n**"
        ..locale('sv_log_price')..":** %s \n**",
        Player.PlayerData.citizenid,
        Player.PlayerData.cid,
        Player.PlayerData.charinfo.firstname,
        Player.PlayerData.charinfo.lastname,
        rewardStr
    )
    TriggerEvent('rsg-log:server:CreateLog', Config.WebhookName, Config.WebhookTitle, Config.WebhookColour, discordMessage, false)
end)

-- ITEM REWARDS
---Give item to player
RegisterServerEvent('hdrp-pets:server:giveitem', function(item)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    Player.Functions.AddItem(item, 1)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'add', 1)
end)

---Remove item from player
RegisterServerEvent('hdrp-pets:server:removeitem', function(item)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    Player.Functions.RemoveItem(item, 1)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'remove', 1)
end)

---Give food reward to player (from pet hunting/games)
RegisterServerEvent('hdrp-pets:server:food', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    Player.Functions.AddItem('raw_meat', 1)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['raw_meat'], 'add', 1)
end)
local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- Load core modules
local Validation = lib.load('server.core.validation')
local Database = lib.load('server.core.database')

--================================
-- TRADING SYSTEM
--================================

local tradeRequests = {} -- Store pending trade requests

---Initiate trade request
RegisterServerEvent('hdrp-pets:server:InitiateTrade')
AddEventHandler('hdrp-pets:server:InitiateTrade', function(targetId, companionid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local Target = RSGCore.Functions.GetPlayer(targetId)
    if not Target then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_error_player_not_found'),
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Verify ownership using Validation module
    if not Validation.PetOwnership(Player.PlayerData.citizenid, companionid) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_error_not_owner'),
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Check if target already has a pending trade
    if tradeRequests[targetId] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_error_trade_pending'),
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Store trade request
    tradeRequests[targetId] = {
        from = src,
        fromCitizenId = Player.PlayerData.citizenid,
        companionid = companionid,
        timestamp = os.time()
    }
    
    -- Notify both players
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('sv_trade_request_sent'),
        description = string.format(locale('sv_trade_sent_to'), Target.PlayerData.charinfo.firstname, Target.PlayerData.charinfo.lastname),
        type = 'inform',
        duration = 7000
    })
    
    TriggerClientEvent('ox_lib:notify', targetId, {
        title = locale('sv_trade_request_received'),
        description = string.format(locale('sv_trade_from'), Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname),
        type = 'inform',
        duration = 10000
    })
    
    if Config.Debug then
        print(string.format("^3[TRADING]^7 %s initiated trade with %s for pet %s", 
            Player.PlayerData.citizenid, Target.PlayerData.citizenid, companionid))
    end
end)

---Accept trade
RegisterServerEvent('hdrp-pets:server:AcceptTrade')
AddEventHandler('hdrp-pets:server:AcceptTrade', function()
    local src = source
    local trade = tradeRequests[src]
    
    if not trade then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_error_no_trade_request'),
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Check if trade expired (5 minutes)
    if os.time() - trade.timestamp > 300 then
        tradeRequests[src] = nil
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_error_trade_expired'),
            type = 'error',
            duration = 5000
        })
        return
    end
    
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then
        tradeRequests[src] = nil
        return
    end
    
    local Trader = RSGCore.Functions.GetPlayer(trade.from)
    if not Trader then
        tradeRequests[src] = nil
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_error_trader_offline'),
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Double-check ownership using Validation module
    if not Validation.PetOwnership(trade.fromCitizenId, trade.companionid) then
        tradeRequests[src] = nil
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_error_trade_invalid'),
            type = 'error',
            duration = 5000
        })
        TriggerClientEvent('ox_lib:notify', trade.from, {
            title = locale('sv_error_trade_invalid'),
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Transfer pet ownership (ATOMIC)
    local success = MySQL.update.await(
        'UPDATE pet_companion SET citizenid = ?, active = 0 WHERE citizenid = ? AND companionid = ?',
        {Player.PlayerData.citizenid, trade.fromCitizenId, trade.companionid}
    )
    
    if success then
        -- Notify both players
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_trade_accepted'),
            description = locale('sv_trade_received_pet'),
            type = 'success',
            duration = 7000
        })
        
        TriggerClientEvent('ox_lib:notify', trade.from, {
            title = locale('sv_trade_completed'),
            description = locale('sv_trade_transferred_pet'),
            type = 'success',
            duration = 7000
        })
        
        -- Trigger client events to update pet lists
        TriggerClientEvent('hdrp-pets:client:tradeCompleted', src)
        TriggerClientEvent('hdrp-pets:client:tradeCompleted', trade.from)
        
        -- Log trade to Discord
        local discordMessage = string.format(
            "**TRADE COMPLETED**\n**From:** %s %s (%s)\n**To:** %s %s (%s)\n**Pet ID:** %s\n**Time:** %s",
            Trader.PlayerData.charinfo.firstname,
            Trader.PlayerData.charinfo.lastname,
            trade.fromCitizenId,
            Player.PlayerData.charinfo.firstname,
            Player.PlayerData.charinfo.lastname,
            Player.PlayerData.citizenid,
            trade.companionid,
            os.date('%Y-%m-%d %H:%M:%S')
        )
        TriggerEvent('rsg-log:server:CreateLog', Config.WebhookName, 'Pet Trade', 'blue', discordMessage, false)
        
        if Config.Debug then
            print(string.format("^2[TRADING]^7 Trade completed: %s -> %s (Pet: %s)", 
                trade.fromCitizenId, Player.PlayerData.citizenid, trade.companionid))
        end
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_error_trade_failed'),
            type = 'error',
            duration = 5000
        })
        
        TriggerClientEvent('ox_lib:notify', trade.from, {
            title = locale('sv_error_trade_failed'),
            type = 'error',
            duration = 5000
        })
        
        if Config.Debug then
            print(string.format("^1[TRADING]^7 Trade failed: Database error for pet %s", trade.companionid))
        end
    end
    
    tradeRequests[src] = nil
end)

---Decline trade
RegisterServerEvent('hdrp-pets:server:DeclineTrade')
AddEventHandler('hdrp-pets:server:DeclineTrade', function()
    local src = source
    local trade = tradeRequests[src]
    
    if not trade then return end
    
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then 
        tradeRequests[src] = nil
        return 
    end
    
    local Trader = RSGCore.Functions.GetPlayer(trade.from)
    if not Trader then
        tradeRequests[src] = nil
        return
    end
    
    TriggerClientEvent('ox_lib:notify', trade.from, {
        title = locale('sv_trade_declined'),
        description = string.format(locale('sv_trade_declined_by'), Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname),
        type = 'error',
        duration = 7000
    })
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('sv_trade_declined_sent'),
        type = 'inform',
        duration = 5000
    })
    
    if Config.Debug then
        print(string.format("^3[TRADING]^7 Trade declined by %s", Player.PlayerData.citizenid))
    end
    
    tradeRequests[src] = nil
end)

---Cancel ongoing trade (if player disconnects or cancels)
RegisterServerEvent('hdrp-pets:server:CancelTrade')
AddEventHandler('hdrp-pets:server:CancelTrade', function()
    local src = source
    
    -- Check if player has incoming trade
    if tradeRequests[src] then
        local trade = tradeRequests[src]
        local Trader = RSGCore.Functions.GetPlayer(trade.from)
        if not Trader then
            tradeRequests[src] = nil
            return
        end
        
        TriggerClientEvent('ox_lib:notify', trade.from, {
            title = locale('sv_trade_cancelled'),
            type = 'inform',
            duration = 5000
        })
        
        tradeRequests[src] = nil
    end
    
    -- Check if player has outgoing trade
    for playerId, trade in pairs(tradeRequests) do
        if trade.from == src then
            TriggerClientEvent('ox_lib:notify', playerId, {
                title = locale('sv_trade_cancelled'),
                type = 'inform',
                duration = 5000
            })
            tradeRequests[playerId] = nil
            break
        end
    end
end)

-- Clean expired trade requests every 5 minutes
CreateThread(function()
    while true do
        Wait(300000) -- 5 minutes
        local currentTime = os.time()
        local expiredCount = 0
        
        for playerId, trade in pairs(tradeRequests) do
            if currentTime - trade.timestamp > 300 then
                -- Notify player if still online
                local Player = RSGCore.Functions.GetPlayer(playerId)
                if not Player then
                    tradeRequests[playerId] = nil
                    expiredCount = expiredCount + 1
                else
                    TriggerClientEvent('ox_lib:notify', playerId, {
                        title = locale('sv_error_trade_expired'),
                        type = 'error',
                        duration = 5000
                    })
                    tradeRequests[playerId] = nil
                    expiredCount = expiredCount + 1
                end
            end
        end
        
        if Config.Debug and expiredCount > 0 then
            print(string.format("^3[TRADING]^7 Cleaned %d expired trade requests", expiredCount))
        end
    end
end)

-- TRADING COMMANDS
---Initiate pet trade with another player
RSGCore.Commands.Add('tradepet', locale('cmd_tradepet'), {
    {name = 'id', help = locale('cmd_tradepet_arg_id')}, 
    {name = 'petid', help = locale('cmd_tradepet_arg_petid')}
}, true, function(source, args)
    local src = source
    local targetId = tonumber(args[1])
    local companionid = args[2]
    
    if not targetId or not companionid then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_error_invalid_arguments'),
            description = locale('sv_error_usage_tradepet'),
            type = 'error',
            duration = 5000
        })
        return
    end
    
    TriggerEvent('hdrp-pets:server:InitiateTrade', src, targetId, companionid)
end)

---Accept pending trade
RSGCore.Commands.Add('pet_accepttrade', locale('cmd_accepttrade'), {}, false, function(source)
    TriggerEvent('hdrp-pets:server:AcceptTrade', source)
end)

---Decline pending trade
RSGCore.Commands.Add('pet_declinetrade', locale('cmd_declinetrade'), {}, false, function(source)
    TriggerEvent('hdrp-pets:server:DeclineTrade', source)
end)

-- Cleanup on player disconnect
AddEventHandler('playerDropped', function()
    local src = source
    TriggerEvent('hdrp-pets:server:CancelTrade', src)
end)

-- REVISION DE CÓDIGO PARA INTERCAMBIO DE MASCOTAS ENTRE JUGADORES

-- TRADE COMPANION
RegisterNetEvent('hdrp-pets:server:TradeCompanion', function(playerId, companionId, price)
    local src = source
    local Seller = RSGCore.Functions.GetPlayer(src)
    local Buyer = RSGCore.Functions.GetPlayer(playerId)
    if not Seller then return end
    if not Buyer then return end
    local BuyerCid = Buyer.PlayerData.citizenid
    price = tonumber(price) or 0

    -- Si el precio es mayor a 0, pedir confirmación al comprador
    if price > 0 then
        TriggerClientEvent('hdrp-pets:client:TradeCompanionConfirm', playerId, Seller, companionId, price)
        return
    end

    -- Si no hay precio, transferir directamente
    local success, result = pcall(MySQL.update, 'UPDATE pet_companion SET citizenid = ? WHERE companionid = ? AND active = ?', {BuyerCid, companionId, 1})
    if not success then return end
    local successB, resultB = pcall(MySQL.update, 'UPDATE pet_companion SET active = ? WHERE citizenid = ? AND active = ?', {0, BuyerCid, 1})
    if not successB then return end

    TriggerClientEvent('ox_lib:notify', playerId, {title = locale('sv_success_pet_owned'), type = 'success', duration = 5000 })
    TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_success_pet_traded'), type = 'success', duration = 5000 })

    local discordMessage = string.format(
        locale('sv_log_user')..":** %s \n**"
        ..locale('debug_id')..":** %d \n**"
        ..locale('cl_input_setup_name')..":** %s %s \n**"
        ..locale('sv_log_event')..":** %s \n**"
        ..locale('sv_log_breed')..":** %s **",
        Buyer.PlayerData.citizenid,
        Buyer.PlayerData.cid,
        Buyer.PlayerData.charinfo.firstname,
        Buyer.PlayerData.charinfo.lastname,
        playerId,
        companionId
    )
    TriggerEvent('rsg-log:server:CreateLog', Config.WebhookName, Config.WebhookTitle, Config.WebhookColour, discordMessage, false)
end)

-- Confirmación del comprador para el trade con precio
RegisterNetEvent('hdrp-pets:server:TradeCompanionConfirm', function(Seller, companionId, price, response)
    local Buyer = RSGCore.Functions.GetPlayer(source)
    if not Buyer or not Seller or not companionId then return end
    local Seller = RSGCore.Functions.GetPlayer(Seller)
    if not Seller then return end
    local price = tonumber(price) or 0
    if response ~= 'accept' then
        TriggerClientEvent('ox_lib:notify', source, {title = locale('cl_trade_declined') or 'Intercambio cancelado', type = 'error', duration = 5000 })
        TriggerClientEvent('ox_lib:notify', Seller, {title = locale('cl_trade_declined_by_buyer') or 'El comprador rechazó el intercambio', type = 'error', duration = 5000 })
        return
    end
    -- Validar fondos
    local cash = tonumber(Buyer.PlayerData.money and Buyer.PlayerData.money.cash) or 0
    if cash < price then
        TriggerClientEvent('ox_lib:notify', source, {title = locale('sv_error_no_cash'), type = 'error', duration = 5000 })
        TriggerClientEvent('ox_lib:notify', Seller, {title = locale('cl_trade_buyer_no_cash') or 'El comprador no tiene suficiente dinero', type = 'error', duration = 5000 })
        return
    end
    -- Transferir dinero
    Buyer.Functions.RemoveMoney('cash', price)
    Seller.Functions.AddMoney('cash', price)
    -- Transferir mascota
    local BuyerCid = Buyer.PlayerData.citizenid
    local success, result = pcall(MySQL.update, 'UPDATE pet_companion SET citizenid = ? WHERE companionid = ? AND active = ?', {BuyerCid, companionId, 1})
    if not success then return end
    local successB, resultB = pcall(MySQL.update, 'UPDATE pet_companion SET active = ? WHERE citizenid = ? AND active = ?', {0, BuyerCid, 1})
    if not successB then return end
    TriggerClientEvent('ox_lib:notify', source, {title = locale('sv_success_pet_owned'), type = 'success', duration = 5000 })
    TriggerClientEvent('ox_lib:notify', Seller, {title = locale('sv_success_pet_traded') or 'Mascota transferida', type = 'success', duration = 5000 })
    local discordMessage = string.format(
        locale('sv_log_user')..":** %s \n**"
        ..locale('debug_id')..":** %d \n**"
        ..locale('cl_input_setup_name')..":** %s %s \n**"
        ..locale('sv_log_event')..":** %s \n**"
        ..locale('sv_log_breed')..":** %s \n**"
        ..'Precio: $'..tostring(price)..'**',
        Buyer.PlayerData.citizenid,
        Buyer.PlayerData.cid,
        Buyer.PlayerData.charinfo.firstname,
        Buyer.PlayerData.charinfo.lastname,
        source,
        companionId
    )
    TriggerEvent('rsg-log:server:CreateLog', Config.WebhookName, Config.WebhookTitle, Config.WebhookColour, discordMessage, false)
end)
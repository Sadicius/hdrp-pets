local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-----------------------------------
-- Companion Customization
----------------------------------
-- Buckets for customization sessions
RegisterServerEvent('hdrp-pets:server:setbucket', function(random, ped)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if random then
        local BucketID = RSGCore.Shared.RandomInt(1000, 9999)
        SetRoutingBucketPopulationEnabled(BucketID, false)
        SetPlayerRoutingBucket(src, BucketID)
        SetPlayerRoutingBucket(ped, BucketID)
    else
        SetPlayerRoutingBucket(src, 0)
        SetPlayerRoutingBucket(ped, 0)
    end
end)

-- save saddle
RegisterNetEvent('hdrp-pets:server:savecomponent', function(component, companionid, price)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    if (Player.PlayerData.money.cash < price) then TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_error_no_cash'), type = 'error', duration = 5000 }) return end
    if component then
        local success, result = pcall(MySQL.update, 'UPDATE pet_companion SET components = ? WHERE citizenid = ? AND companionid = ?', {json.encode(component), citizenid, companionid})
        if not success then return end
        Player.Functions.RemoveMoney('cash', price)
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_success_component_saved') .. price, type = 'success', duration = 5000 })
    end
end)

--[[ 
RSGCore.Commands.Add('loadpet', locale('sv_command_load'), {}, false, function(source, args)
end)

local activeAttachments = {}
RegisterNetEvent('hdrp-pets:server:AttachItem')
AddEventHandler('hdrp-pets:server:AttachItem', function(netId, itemHashes)
    for _, hash in ipairs(itemHashes) do
        TriggerClientEvent('hdrp-pets:client:UpdateAttachment', -1, netId, hash, source)
    end
end)

RegisterServerEvent('hdrp-pets:server:RequestAttachments')
AddEventHandler('hdrp-pets:server:RequestAttachments', function()
    local src = source
    for netId, data in pairs(activeAttachments) do
        if netId then
            TriggerClientEvent('hdrp-pets:client:UpdateAttachment', src, netId, data.hash, data.source)
        else
            activeAttachments[netId] = nil
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    activeAttachments = {}
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    for netId, data in pairs(activeAttachments) do
        if data.source == src then
            activeAttachments[netId] = nil
            TriggerClientEvent('hdrp-pets:client:RemoveAttachment', -1, netId, data.hash)
        end
    end
end) 
]]

--[[
    NETWORKING & REPLICATION SYSTEM
    ====================================
    Sincroniza las mascotas entre jugadores
    - Notifica a otros jugadores cuando una mascota es spawned
    - Mantiene la lista de mascotas activas por jugador
    - Sincroniza eventos de mascotas cercanas
]]

local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- Track active pets per player for networking
local ActivePlayerPets = {}

-- UPDATE PET COORDINATES PERIODICALLY
CreateThread(function()
    while true do
        Wait(1000) -- Update every second
        
        -- Update coordinates for all active pets by polling player positions
        local players = RSGCore.Functions.GetPlayers()
        for _, playerId in ipairs(players) do
            if ActivePlayerPets[playerId] then
                for companionid, petInfo in pairs(ActivePlayerPets[playerId]) do
                    -- We'll update this via client polling, not server side
                    -- since we don't have pet entity data on server
                end
            end
        end
    end
end)

-- NOTIFY ALL NEARBY PLAYERS WHEN A PET IS SPAWNED
-- Call this when a player spawns their pet
RegisterNetEvent('hdrp-pets:server:petSpawned')
AddEventHandler('hdrp-pets:server:petSpawned', function(companionid, petData, playerCoords)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Store pet info
    ActivePlayerPets[src] = ActivePlayerPets[src] or {}
    ActivePlayerPets[src][companionid] = {
        data = petData,
        coords = playerCoords,
        owner = src,
        ownerCitizenId = Player.PlayerData.citizenid,
        ownerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
        spawnedAt = os.time()
    }
    
    -- Notify ALL nearby players (within 100 meters)
    local players = RSGCore.Functions.GetPlayers()
    for _, playerId in ipairs(players) do
        if playerId ~= src then
            local targetPlayer = RSGCore.Functions.GetPlayer(playerId)
            if targetPlayer then
                local targetCoords = GetEntityCoords(GetPlayerPed(playerId))
                local distance = #(playerCoords - targetCoords)
                
                if distance < 100.0 then
                    -- Send pet info to nearby player so they can spawn it locally
                    TriggerClientEvent('hdrp-pets:client:petSpawnedNearby', playerId, companionid, petData, Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname)
                end
            end
        end
    end
    
    if Config.Debug then
        print('^2[NETWORKING]^7 Pet spawned: ' .. (petData.info.name or 'Unknown') .. ' by ' .. Player.PlayerData.charinfo.firstname)
    end
end)

-- NOTIFY WHEN A PET IS DISMISSED/DESPAWNED
RegisterNetEvent('hdrp-pets:server:petDespawned')
AddEventHandler('hdrp-pets:server:petDespawned', function(companionid)
    local src = source
    
    -- Remove from tracking
    if ActivePlayerPets[src] and ActivePlayerPets[src][companionid] then
        ActivePlayerPets[src][companionid] = nil
    end
    
    -- Notify all players to remove the pet locally
    TriggerClientEvent('hdrp-pets:client:petDespawnedRemote', -1, src, companionid)
    
    if Config.Debug then
        print('^3[NETWORKING]^7 Pet despawned: ' .. companionid .. ' by player ' .. src)
    end
end)

-- RECEIVE PET COORDINATE UPDATES
-- Players send pet position updates so others can track moving pets
RegisterNetEvent('hdrp-pets:server:updatePetCoords')
AddEventHandler('hdrp-pets:server:updatePetCoords', function(companionid, newCoords)
    local src = source
    
    if ActivePlayerPets[src] and ActivePlayerPets[src][companionid] then
        -- Update coordinates
        ActivePlayerPets[src][companionid].coords = newCoords
        
        -- Broadcast to all nearby players (including this one for clients that just arrived)
        local players = RSGCore.Functions.GetPlayers()
        for _, playerId in ipairs(players) do
            if playerId ~= src then
                local targetPlayer = RSGCore.Functions.GetPlayer(playerId)
                if targetPlayer then
                    local targetCoords = GetEntityCoords(GetPlayerPed(playerId))
                    local distance = #(newCoords - targetCoords)
                    
                    -- Send update if nearby
                    if distance < 150.0 then  -- Slightly larger range for position updates
                        TriggerClientEvent('hdrp-pets:client:updateRemotePetCoords', playerId, companionid, newCoords)
                    end
                end
            end
        end
    end
end)

-- GET LIST OF NEARBY SPAWNED PETS
lib.callback.register('hdrp-pets:server:getNearbyPets', function(source, playerCoords)
    local src = source
    local nearbyPets = {}
    
    local players = RSGCore.Functions.GetPlayers()
    for _, playerId in ipairs(players) do
        if playerId ~= src and ActivePlayerPets[playerId] then
            for companionid, petInfo in pairs(ActivePlayerPets[playerId]) do
                if petInfo and petInfo.data then
                    local distance = #(playerCoords - petInfo.coords)
                    if distance < 100.0 then
                        table.insert(nearbyPets, {
                            companionid = companionid,
                            data = petInfo.data,
                            owner = playerId,
                            ownerName = petInfo.ownerName,
                            distance = distance
                        })
                    end
                end
            end
        end
    end
    
    return nearbyPets
end)

-- CLEANUP ON PLAYER DISCONNECT
AddEventHandler('playerDropped', function()
    local src = source
    
    -- Clear all pets for disconnected player
    if ActivePlayerPets[src] then
        for companionid, _ in pairs(ActivePlayerPets[src]) do
            TriggerClientEvent('hdrp-pets:client:petDespawnedRemote', -1, src, companionid)
        end
        ActivePlayerPets[src] = nil
    end
end)

-- SYNC PET SOUNDS ACROSS NETWORK
RegisterNetEvent('hdrp-pets:server:playPetSound')
AddEventHandler('hdrp-pets:server:playPetSound', function(companionid, soundName, maxDistance)
    local src = source
    maxDistance = maxDistance or 20.0
    
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local petInfo = nil
    if ActivePlayerPets[src] then
        petInfo = ActivePlayerPets[src][companionid]
    end
    
    if petInfo then
        -- Get players within sound distance
        local players = RSGCore.Functions.GetPlayers()
        for _, playerId in ipairs(players) do
            local targetPlayer = RSGCore.Functions.GetPlayer(playerId)
            if targetPlayer then
                local targetCoords = GetEntityCoords(GetPlayerPed(playerId))
                local distance = #(petInfo.coords - targetCoords)
                
                if distance < maxDistance then
                    TriggerClientEvent('hdrp-pets:client:playRemotePetSound', playerId, soundName, petInfo.coords, distance)
                end
            end
        end
    end
end)

-- EXPORT FOR GETTING ACTIVE PETS
exports('GetActivePets', function()
    return ActivePlayerPets
end)

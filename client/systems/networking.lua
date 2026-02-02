--[[
    CLIENT NETWORKING & REPLICATION
    ====================================
    Recibe eventos de replicación de mascotas de otros jugadores
]]

local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
local ManageSpawn = lib.load('client.stable.utils_spawn')

-- Store remote pets from other players (PEDs spawned on this client for visibility)
local RemotePets = {}

--[[
    SEND PET POSITION UPDATES TO SERVER
    This allows other players to track pet positions as they move
]]
CreateThread(function()
    while true do
        Wait(2000) -- Send position update every 2 seconds
        
        local myPets = State.GetAllPets()
        if next(myPets) then
            for companionid, petData in pairs(myPets) do
                if petData and petData.spawned and DoesEntityExist(petData.ped) then
                    local petCoords = GetEntityCoords(petData.ped)
                    -- Send update to server
                    TriggerServerEvent('hdrp-pets:server:updatePetCoords', companionid, petCoords)
                end
            end
        end
        
        if not State.HasActivePets() then
            Wait(5000) -- Wait longer if no pets
        end
    end
end)

--[[
    RECEIVE PET SPAWN EVENT FROM OTHER PLAYERS
    Spawns a visual representation (NPC) of other players' pets nearby
]]
RegisterNetEvent('hdrp-pets:client:petSpawnedNearby')
AddEventHandler('hdrp-pets:client:petSpawnedNearby', function(companionid, petData, ownerName)
    -- Don't spawn if this is our own pet
    local myPets = State.GetAllPets()
    for myPetId, myPetData in pairs(myPets) do
        if myPetId == companionid then
            return -- This is our pet, ignore
        end
    end
    
    -- Spawn NPC representation
    local playerPed = cache.ped
    local playerCoords = GetEntityCoords(playerPed)
    local petName = (petData.info and petData.info.name) or 'Pet'
    local petModel = (petData.info and petData.info.model) or 'a_m_m_business_1'
    
    -- Spawn near player
    local spawnCoords = playerCoords + (GetEntityForwardVector(playerPed) * 2.0)
    
    local modelHash = GetHashKey(petModel)
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 30 do
        Wait(100)
        timeout = timeout + 1
    end
    
    if not HasModelLoaded(modelHash) then
        SetModelAsNoLongerNeeded(modelHash)
        return
    end
    
    -- Create PED
    local remotePed = CreatePed(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0.0, false, false, false, false)
    SetModelAsNoLongerNeeded(modelHash)
    
    if not DoesEntityExist(remotePed) then return end
    
    -- Configure PED
    SetEntityAsMissionEntity(remotePed, true)
    SetEntityCanBeDamaged(remotePed, false)
    SetPedNameDebug(remotePed, petName .. ' (' .. ownerName .. ')')
    
    -- Apply basic flags
    Citizen.InvokeNative(0x283978A15512B2FE, remotePed, true)
    
    -- Set as non-hostile
    SetPedFleeAttributes(remotePed, 0, true)
    SetBlockingOfNonTemporaryEvents(remotePed, true)
    
    -- Create blip
    local blip = Citizen.InvokeNative(0x23f74c2fda6e7c61, -1749618580, remotePed)
    if Config.Blip.Pet then
        Citizen.InvokeNative(0x662D364ABF16DE2F, blip, Config.Blip.ColorModifier)
        SetBlipSprite(blip, Config.Blip.Pet.blipSprite)
        SetBlipScale(blip, Config.Blip.Pet.blipScale)
        Citizen.InvokeNative(0x45FF974EEA1DCE36, blip, true)
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, petName .. ' (' .. ownerName .. ')')
    end
    
    -- Store in remote pets
    RemotePets[companionid] = {
        ped = remotePed,
        blip = blip,
        data = petData,
        ownerName = ownerName,
        name = petName
    }
    
    if Config.Debug then
        print('^2[NETWORKING]^7 Remote pet spawned: ' .. petName .. ' by ' .. ownerName)
    end
end)

--[[
    RECEIVE PET DESPAWN EVENT FROM OTHER PLAYERS
    Removes visual representation of other players' pets
]]
RegisterNetEvent('hdrp-pets:client:petDespawnedRemote')
AddEventHandler('hdrp-pets:client:petDespawnedRemote', function(ownerPlayerId, companionid)
    if RemotePets[companionid] then
        local remotePet = RemotePets[companionid]
        
        -- Remove blip
        if remotePet.blip and DoesBlipExist(remotePet.blip) then
            RemoveBlip(remotePet.blip)
        end
        
        -- Delete PED
        if remotePet.ped and DoesEntityExist(remotePet.ped) then
            DeleteEntity(remotePet.ped)
            SetEntityAsNoLongerNeeded(remotePet.ped)
        end
        
        RemotePets[companionid] = nil
        
        if Config.Debug then
            print('^3[NETWORKING]^7 Remote pet despawned: ' .. companionid)
        end
    end
end)

--[[
    UPDATE REMOTE PET COORDINATES
    Move remote pet representations as they move with their owner
]]
RegisterNetEvent('hdrp-pets:client:updateRemotePetCoords')
AddEventHandler('hdrp-pets:client:updateRemotePetCoords', function(companionid, newCoords)
    if RemotePets[companionid] then
        local remotePet = RemotePets[companionid]
        
        if remotePet.ped and DoesEntityExist(remotePet.ped) then
            -- Move pet smoothly to new coordinates
            TaskGoToCoordAnyMeans(remotePet.ped, newCoords.x, newCoords.y, newCoords.z, 1.0, 0, 0, 786603, 0xbf800000)
            
            if Config.Debug then
                print('^5[NETWORKING]^7 Updated remote pet ' .. companionid .. ' coords')
            end
        end
    end
end)

--[[
    RECEIVE REMOTE PET SOUND
    Play pet sounds from other players' pets
]]
RegisterNetEvent('hdrp-pets:client:playRemotePetSound')
AddEventHandler('hdrp-pets:client:playRemotePetSound', function(soundName, soundCoords, distance)
    -- Adjust volume based on distance
    local maxDistance = 20.0
    local volume = 1.0 - (distance / maxDistance)
    volume = math.max(0.0, math.min(1.0, volume))
    
    -- Play sound with proper distance attenuation
    TriggerEvent('InteractSound_CL:PlayOnSource', soundName, volume)
    
    if Config.Debug then
        print('^5[NETWORKING SOUND]^7 Playing ' .. soundName .. ' (volume: ' .. string.format('%.2f', volume) .. ')')
    end
end)

--[[
    PERIODICALLY SYNC WITH SERVER TO GET NEARBY PETS
    This ensures we always have updated info about nearby pets
]]
CreateThread(function()
    while true do
        Wait(5000) -- Check every 5 seconds
        
        local playerCoords = GetEntityCoords(cache.ped)
        
        lib.callback('hdrp-pets:server:getNearbyPets', playerCoords, function(nearbyPets)
            if nearbyPets and #nearbyPets > 0 then
                for _, petInfo in ipairs(nearbyPets) do
                    -- Check if we already have this pet spawned
                    if not RemotePets[petInfo.companionid] then
                        -- Spawn it
                        TriggerEvent('hdrp-pets:client:petSpawnedNearby', petInfo.companionid, petInfo.data, petInfo.ownerName)
                    end
                end
            end
        end, playerCoords)
    end
end)

--[[
    CLEANUP REMOTE PETS WHEN TOO FAR
    Remove pets that are > 100 meters away
]]
CreateThread(function()
    while true do
        Wait(10000) -- Check every 10 seconds
        
        local playerCoords = GetEntityCoords(cache.ped)
        
        for companionid, remotePet in pairs(RemotePets) do
            if remotePet and remotePet.ped and DoesEntityExist(remotePet.ped) then
                local petCoords = GetEntityCoords(remotePet.ped)
                local distance = #(playerCoords - petCoords)
                
                if distance > 100.0 then
                    -- Too far, remove it
                    if remotePet.blip and DoesBlipExist(remotePet.blip) then
                        RemoveBlip(remotePet.blip)
                    end
                    DeleteEntity(remotePet.ped)
                    SetEntityAsNoLongerNeeded(remotePet.ped)
                    RemotePets[companionid] = nil
                    
                    if Config.Debug then
                        print('^3[NETWORKING]^7 Removed distant remote pet: ' .. companionid .. ' (distance: ' .. string.format('%.2f', distance) .. 'm)')
                    end
                end
            end
        end
    end
end)

-- EXPORT remote pets for other systems
return RemotePets

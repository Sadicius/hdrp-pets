local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- Load modules
local Database = lib.load('server.core.database')
local Validation = lib.load('server.core.validation')

--================================
-- TRACKING SYSTEM
-- Sin usos, todos los eventos estan sin llamadas desde el cliente
--================================

---Parse JSON coordinates from database fields
---@param coordsData string JSON string or comma-separated coordinates
---@return table|nil Parsed coordinates {x, y, z}
local function parseJSONCoords(coordsData)
    if not coordsData or coordsData == "" then
        return nil
    end
    
    -- Try to parse as JSON first
    local success, result = pcall(json.decode, coordsData)
    if success and type(result) == "table" then
        if result.x and result.y and result.z then
            return {x = result.x, y = result.y, z = result.z}
        elseif result[1] and result[2] and result[3] then
            return {x = result[1], y = result[2], z = result[3]}
        end
    end
    
    -- Fallback: parse as comma-separated values
    local coords = {}
    for coord in string.gmatch(coordsData, "[^,]+") do
        table.insert(coords, tonumber(coord))
    end
    
    if #coords >= 3 then
        return {x = coords[1], y = coords[2], z = coords[3]}
    end
    
    return nil
end

---Detect coordinates from configured database tables
---@param playerCoords vector3 Player position
---@param radius number Search radius
---@return table|nil Found coordinates and metadata
local function DetectCoordinates(playerCoords, radius)
    if not Config.TablesTrack or not Config.TablesTrack.coordsColumns then
        if Config.Debug then print("^3[TRACKING]^7 Warning: Config.TablesTrack.coordsColumns not configured") end
        return nil
    end
    
    local foundCoords = {}
    
    -- Iterate through configured tables
    for tableName, columns in pairs(Config.TablesTrack.coordsColumns) do
        local coordColumn = columns.coords
        local nameColumn = columns.name or 'name'
        local typeColumn = columns.type or 'type'
        
        -- Query database table
        local query = string.format(
            'SELECT %s, %s, %s FROM %s',
            coordColumn, nameColumn, typeColumn, tableName
        )
        
        local results = MySQL.query.await(query, {})
        
        if results then
            for _, row in ipairs(results) do
                local coords = parseJSONCoords(row[coordColumn])
                
                if coords then
                    -- Calculate distance
                    local distance = #(playerCoords - vector3(coords.x, coords.y, coords.z))
                    
                    -- Check if within radius
                    if distance <= radius then
                        table.insert(foundCoords, {
                            coords = coords,
                            distance = distance,
                            name = row[nameColumn] or locale('ui_track_unknown'),
                            type = row[typeColumn] or locale('ui_track_location'),
                            table = tableName
                        })
                    end
                end
            end
        end
    end
    
    -- Sort by distance (closest first)
    table.sort(foundCoords, function(a, b) return a.distance < b.distance end)
    
    return foundCoords
end

---Find trackable locations near player
RegisterServerEvent('hdrp-pets:server:findtrackablelocations')
AddEventHandler('hdrp-pets:server:findtrackablelocations', function(playerCoords)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Validate player coords
    if not playerCoords or type(playerCoords) ~= "table" then
        if Config.Debug then print(string.format("^3[TRACKING]^7 Invalid coordinates from player %s", src)) end
        return
    end
    
    local coords = vector3(playerCoords.x, playerCoords.y, playerCoords.z)
    local trackingRadius = Config.TrackingSystem.detectionRadius or 1000.0
    
    -- Detect nearby coordinates
    local locations = DetectCoordinates(coords, trackingRadius)
    
    if locations and #locations > 0 then
        if Config.Debug then print(string.format("^2[TRACKING]^7 Found %d locations for player %s", #locations, src)) end
        TriggerClientEvent('hdrp-pets:client:receiveTrackableLocations', src, locations)
    else
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_track_no_locations'), type = 'inform', duration = 5000 })
    end
end)

---Start tracking to specific coordinates
RegisterServerEvent('hdrp-pets:server:starttracking')
AddEventHandler('hdrp-pets:server:starttracking', function(companionid, targetCoords)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Verify ownership
    if not Validation.PetOwnership(Player.PlayerData.citizenid, companionid) then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_error_not_owner'), type = 'error', duration = 5000 })
        return
    end
    
    -- Validate coordinates
    if not targetCoords or type(targetCoords) ~= "table" then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_error_invalid_coords'), type = 'error', duration = 5000 })
        return
    end
    
    -- Send tracking data to client
    TriggerClientEvent('hdrp-pets:client:startTracking', src, targetCoords)
    
    if Config.Debug then print(string.format("^2[TRACKING]^7 Player %s started tracking to coords: %.2f, %.2f, %.2f", src, targetCoords.x, targetCoords.y, targetCoords.z)) end
end)

---Stop tracking
RegisterServerEvent('hdrp-pets:server:stoptracking')
AddEventHandler('hdrp-pets:server:stoptracking', function()
    local src = source
    TriggerClientEvent('hdrp-pets:client:stopTracking', src)
    
    if Config.Debug then print(string.format("^3[TRACKING]^7 Player %s stopped tracking", src)) end
end)

---Get tracking skill level (based on pet level/bond)
RegisterServerEvent('hdrp-pets:server:gettrackingskill')
AddEventHandler('hdrp-pets:server:gettrackingskill', function(companionid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Get companion data
    local companion = Database.GetCompanionByCompanionId(companionid)
    if not companion then
        TriggerClientEvent('hdrp-pets:client:receivetrackingskill', src, 1.0) -- Default
        return
    end

    local data = json.decode(companion.data)
    local petLevel = data.progression.level or 1
    local bond = data.progression.bonding or 0
    
    -- Calculate skill multiplier (higher level + bond = better tracking)
    -- Level 1-10: 1.0x - 1.5x
    -- Bond 0-100: +0.0x - +0.5x
    local levelMultiplier = 1.0 + (petLevel * 0.05)
    local bondMultiplier = bond * 0.005
    local totalMultiplier = levelMultiplier + bondMultiplier
    
    -- Cap at 2.0x
    totalMultiplier = math.min(totalMultiplier, 2.0)
    
    TriggerClientEvent('hdrp-pets:client:receivetrackingskill', src, totalMultiplier)
    
    if Config.Debug then print(string.format("^2[TRACKING]^7 Pet %s tracking skill: %.2fx (Level: %d, Bond: %d)", companionid, totalMultiplier, petLevel, bond)) end
end)

-- Buscar en base de datos (llamado desde prompts del cliente)
RegisterServerEvent('hdrp-pets:server:searchDatabase')
AddEventHandler('hdrp-pets:server:searchDatabase', function(playerCoords, companionid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Validar coordenadas
    if not playerCoords or type(playerCoords) ~= "table" then
        TriggerClientEvent('ox_lib:notify', src, { 
            title = locale('sv_error_invalid_coords'), 
            type = 'error' 
        })
        return
    end
    
    local coords = vector3(playerCoords.x, playerCoords.y, playerCoords.z)
    local searchRadius = Config.TrackingSystem and Config.TrackingSystem.searchRadius or 500.0
    
    -- Usar la funcion existente DetectCoordinates
    local locations = DetectCoordinates(coords, searchRadius)
    
    if locations and #locations > 0 then
        TriggerClientEvent('hdrp-pets:client:receiveTrackableLocations', src, locations)
    else
        TriggerClientEvent('ox_lib:notify', src, { 
            title = locale('sv_track_no_locations') or 'No locations found', 
            type = 'inform' 
        })
    end
end)

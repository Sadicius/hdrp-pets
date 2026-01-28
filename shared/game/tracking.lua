--[[
    HDRP-PETS CONFIGURATION - TRACKING
    Configuración del sistema de rastreo
    Versión: 5.7.0
]]
lib.locale()

return {
    SearchData = true, -- Enable database search tracking
    detectionRadius = 1000.0, -- Radius to detect coordinates in meters
    searchRadius = 500.0, -- Radius to search for trackable items in meters
    -- Track prompt filters
    TrackOnly = {
        Active = true,      -- Enable filtered tracking
        Animals = true,     -- Can track animals
        NPC = true,         -- Can track NPCs
        Players = true      -- Can track players
    },
    
    -- Attack prompt filters
    AttackOnly = {
        Active = false,      -- Enable filtered attacks
        NPC = false,         -- Can attack NPCs
        Players = false      -- Can attack players
    },
    
    -- Hunt animals prompt filter
    HuntAnimalsOnly = {
        Active = false       -- Enable hunt animals feature
    },
    
    TrackingJob = {
        'leo',
        'medic',
        'govenor',
        'horsetrainer',
        'rancher',
        'unemployed'
    },
    
    AllowedSearchTables = {
        {table = 'criminal_activities', label = locale('cl_search_criminal')},
        {table = 'rex_camping', label = locale('cl_search_camping')},
        {table = 'rex_mining', label = locale('cl_search_mining')},
        {table = 'rex_trapfishing', label = locale('cl_search_trapfishing')},
        {table = 'hunting_traps', label = locale('cl_search_traps')},
        {table = 'player_weapons_custom', label = locale('cl_search_weapons')},
        {table = 'qc_fplants', label = locale('cl_search_plants')},
--        {table = 'rex_farming', label = locale('cl_search_farming')},
--        {table = 'rex_market', label = locale('cl_search_market')},
--        {table = 'moonshiner', label = locale('cl_search_moonshiner')}
    },
    
    coordsColumns = {
        "coords",
        "coordinates",
        "location",
        "position",
        "xyz",
        "pos",
        "properties",
        "propdata",
        "plate"
        -- "xpos" and "ypos" and "zpos",
    }
}

fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'hdrp-pets - Advanced Pet System for RedM by Sadicius'
version '6.7.8'

shared_scripts {
    '@ox_lib/init.lua',
    
    'shared/main.lua',                      -- CONFIG: Modular system

    'shared/config/attributes.lua',         -- Centralized pet attributes
    'shared/config/systems.lua',            -- Centralized systems (Herding, Wandering, Reproduction, Veterinary, Decay, etc)
    'shared/config/blips.lua',              -- Centralized blip
    'shared/config/consumables.lua',        -- Consumables & feed items

    'shared/game/animations.lua',           -- Pet animations
    'shared/game/games.lua',                -- Mini-games & Achievements
    'shared/game/retrievable_animals.lua',  -- Retrievable animals list
    'shared/game/tracking.lua',             -- Tracking system
    'shared/game/water_types.lua',          -- Water types for water detection
    'shared/game/xp.lua',                   -- XP system

    'shared/stable/stables.lua',            -- Stable locations
    'shared/stable/shop_prices.lua',        -- Stable prices for buy pet
    'shared/stable/shop_comp.lua',          -- Stable components for pet
    'shared/stable/shop_props.lua',         -- Stable props for pet
    'shared/stable/shop_helpers.lua',       -- Helper functions for components
}

client_scripts {
    -- SYSTEM
    'client/state.lua',                 -- State management

    -- CUSTOMIZATION
    'client/systems/customize.lua',     -- Pet customization system
    -- CORE
    'client/systems/wandering.lua',     -- WANDERING (Natural Pet Movement)
    'client/systems/herding.lua',       -- HERDING (Multi-Pet Group Following)  
    'client/systems/herding_helpers.lua',
    'client/systems/dataview.lua',      -- Data view system
    'client/systems/inventory.lua',     -- Inventory handling
    'client/systems/ambient.lua',       -- Ambient dog resting logic
    'client/systems/consumables.lua',   -- Feed, Water, Treats, Revive
    'client/systems/hunt.lua',          -- Pet behavior AI 
    'client/systems/behavior.lua',      -- Pet behavior AI 
    'client/systems/notify.lua',        -- Notify decay, level up, etc.
    'client/systems/prompts.lua',       -- Prompt system
    'client/systems/breeding.lua',    -- breeding
    'client/systems/tracking.lua',      -- TRACKING (Find lost pets & track targets)

    -- GAMES (Mini-Games for Pets)
    'client/games/bandit.lua',          -- Bandit encounters
    'client/games/bone.lua',            -- Bone game
    'client/games/buried.lua',          -- Buried treasure
    'client/games/fight.lua',           -- Dog fighting & betting
    'client/games/hostile.lua',         -- Hostile NPCs
    'client/games/race.lua',            -- Pet racing system
    'client/games/treasure.lua',        -- Treasure hunt

    -- MENUS
    'client/menu/main_menu.lua',        -- Main (/pet_menu command)
    'client/menu/quick_actions.lua',    -- Quick actions
    'client/menu/quick_care.lua',       -- Quick care / NOTA: Las funciones basicas de opciones para cuidados
    'client/menu/pet_dashboard.lua',    -- Pet dashboard & list
    'client/menu/pet_stats.lua',        -- Stats
    'client/menu/pet_actions.lua',      -- Actions
    'client/menu/pet_breed.lua',        -- Breeding
    'client/menu/pet_herding.lua',      -- Herding
    'client/menu/pet_games.lua',        -- Games
    'client/menu/pet_achievements.lua', -- Achievements

    -- STABLE 
    'client/stable/utils_spawn.lua',    -- Pet spawning utilities
    'client/stable/call.lua',           -- Call pet system
    'client/stable/flee.lua',           -- Flee / store pet system
    'client/stable/rename.lua',         -- Rename system
    'client/stable/trade.lua',          -- Trade system / NOTA: falta confirmar que funciona
    'client/stable/menu_stable.lua',    -- Stable NPC menu
    'client/stable/pets.lua',           -- Pet spawning & management
    'client/stable/npcs.lua',           -- NPC management

}

files {
    'locales/*.json'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    
    'server/core/validation.lua',
    'server/core/database.lua',
    'server/core/callbacks.lua',

    'server/systems/customize.lua',
    'server/systems/items.lua',       -- items consumables to pets
    'server/systems/fight.lua',
    'server/systems/race.lua',        -- pet racing system
    'server/systems/management.lua',  -- rewards + customization
    'server/systems/tracking.lua',    -- pet tracking
    'server/systems/trade.lua',       -- pet trading
    'server/systems/lifecycle.lua',   -- lifecycle + decay (consolidated)
    'server/systems/veterinary.lua',  -- veterinary services
    'server/systems/breeding.lua',    -- breeding
    'server/systems/xp.lua',          -- xp

    'server/main.lua',
    'server/versionchecker.lua',

}

dependencies {
    -- `oxmysql`,
    'rsg-core',
    'ox_lib',
    -- `ox_target`,
    -- `interact-sound`
}

lua54 'yes'

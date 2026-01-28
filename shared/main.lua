Config = Config or {}

Config.Debug = true

-- GENERAL SETTINGS
Config.EnableTarget = true       -- toggle between target and prompt
Config.EnablePrompts = true      -- enable prompts

Config.EnabledBetsFight = true  -- enable betting system for dog fights
Config.EnableBuyPetMenu = true   -- enable buy pet option in stable menu (alternative to target system)

-- STABLE SETTINGS
Config.KeyBind = 'J'             -- keybind to open stable menu if prompts are enabled
Config.DistanceSpawn = 20.0      -- distance to spawn/despawn NPCs
Config.FadeIn = true             -- fade in/out NPCs on spawn/despawn
Config.MovePetBasePrice = 50.0  -- base price to move pet between stables
Config.MoveFeePerMeter = 0.1    -- additional fee per meter to move pet
Config.priceDepreciation = 50    -- Price sell 0 - 100 (100%)
Config.MaxActivePets = 10
Config.MaxCallDistance = 50.0     -- Max distance to "move" vs "spawn"
    
-- ITEMS
Config.Items = {
    Bone = 'pet_bone',
    Brush = 'pet_brush',
    Stimulant = 'pet_stimulant',
    Revive = 'pet_reviver',
    Food = 'pet_feed',
    Drink = 'pet_water',
    Happy = 'sugarcube',
    Treasure = 'shovel'
}

-- PROMPTS / KEYBINDS
Config.Prompt = { -- Load prompts/keybinds configuration
    CompanionCall       = 0xD8F73058, -- U INPUT_AIM_IN_AIR   -- CallPet
    CompanionFlee       = 0x4216AF06, -- F INPUT_HORSE_COMMAND_FLEE (when horse menu is active)
    CompanionSaddleBag  = 0xC7B5340A, -- ENTER INPUT_FRONTEND_ACCEPT
    CompanionBrush      = 0x63A38F2C, -- B INPUT_INTERACT_HORSE_BRUSH

    CompanionHunt       = 0x71F89BBC, -- R INPUT_INTERACT_LOCKON_CALL_ANIMAL -- HUNTER
    CompanionActions    = 0xF3830D8E, -- J INPUT_OPEN_JOURNAL 
    CompanionAttack     = 0x620A6C5E, -- V INPUT_CINEMATIC_CAM    -- PetAttack
    CompanionTrack      = 0xD8CF0C95, -- C INPUT_CREATOR_RS    -- PetTrack
    CompanionHuntAnimals = 0x620A6C5E, -- V INPUT_CINEMATIC_CAM    -- PetAttack
    CompanionSearch     = 0xD8CF0C95, -- C INPUT_CREATOR_RS    -- PetTrack

    CompanionDrink      = 0xD8CF0C95, -- C INPUT_CREATOR_RS
    CompanionEat        = 0xD8CF0C95, -- C INPUT_CREATOR_RS

    Rotate = { 0x7065027D, 0xB4E465B4 }, -- Left Right arrows
}

-- WEBHOOKS (Logging)
Config.WebhookName = 'hdrp-pets'
Config.WebhookTitle = 'Pet System Logs'
Config.WebhookColour = 'orange'

-- ADDITIONAL CONFIGURATIONS WIP
Config.EnablePetCustom = false  -- enable pet customization system (WIP)
Config.EnablePetProps  = true    -- enable pet props system
Config.PriceComponent  = {
    -- clothes
    neckwear = 5,
    hats = 10,
    -- horses
    blankets = 12,
    saddles = 15,
    saddlebags = 10,
    bedrolls = 8,
    stirrups = 6,
    -- props
    Accessories = 8,
    Cosmetics = 5,
    Bags = 10,
    Neck = 7,
    Medal = 8,
    Masks = 3
}

-- ================================================
-- LOAD MODULAR CONFIGURATIONS
-- ================================================
Config.PetStables = lib.load('shared.stable.stables') -- Load pet stables configuration
Config.PetShopPrice = lib.load('shared.stable.shop_prices') -- Load pet shop prices configuration
Config.PetShopComp = lib.load('shared.stable.shop_comp') -- Load pet shop components configuration
Config.PetShopProps = lib.load('shared.stable.shop_props') -- Load pet shop props configuration

Config.WaterTypes = lib.load('shared.game.water_types') -- Load water types configuration
Config.Games = lib.load('shared.game.games') -- Load games configuration
Config.RetrievableAnimals = lib.load('shared.game.retrievable_animals') -- Load retrievable animals configuration
Config.TablesTrack = lib.load('shared.game.tracking') -- Load tracking configuration
Config.Animations = lib.load('shared.game.animations') -- Load animations configuration
Config.XP = lib.load('shared.game.xp') -- Load XP system configuration

Config.PetAttributes = lib.load('shared.config.attributes') -- Load pet attributes configuration
Config.Blip = lib.load('shared.config.blips') -- Load blip configuration

-- FIX v5.8.51+: Load consumables configuration (was missing)
local Consumables = lib.load('shared.config.consumables')
Config.PetFeed = Consumables.Items
Config.DistanceFeed = Consumables.DistanceFeed
Config.Consumables = Consumables.DefaultValues

local Systems = lib.load('shared.config.systems') -- Load systems configuration
Config.AutoDecay = Systems.AutomaticDecay
Config.Lifecycle = Systems.Lifecycle
Config.Ambient = Systems.Ambient
Config.Herding = Systems.Herding
Config.Wandering = Systems.Wandering
Config.Reproduction = Systems.Reproduction
Config.Veterinary = Systems.Veterinary
Config.PetStatistics = Systems.Statistics

return Config

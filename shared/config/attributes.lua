
return {
    SpawnOnRoadOnly  = false, -- always spawn on road
    RaiseAnimal      = true,  -- If enabled, you have to feed your animal for it to gain XP and grow
    NoFear           = false, -- Set to true if using Bears/Wolves as pets so horses won't be in fear
    Invincible       = false,
    DefensiveMode    = true,  -- If true, pets become hostile to anything you are in combat with
    FollowDistance   = 3,     -- distance pet follows player
    -- FollowSpeed      = 1,     -- pet follow speed
    SearchRadius     = 50.0,  -- How far the pet will search for a hunted animal

    Starting = {
        Health     = 300,
        Hunger     = 75.0,
        Thirst     = 75.0,
        Happiness   = 75.0,
        Strength   = 50.0,
        MaxBonding = 5000.0,
    },
    
    AttributeRatios = {     -- Attribute point distribution ratios
        Stamina   = 0.10,   -- Calculate hValue based on XP 0 - 1
        Agility   = 0.10,
        Courage   = 0.10,
        Speed     = 0.05,
        Acceleration = 0.05
    },

    AutomaticDecay = {    -- AUTOMATIC DECAY SYSTEM
        Enabled = false,
        CronJob = '*/15 * * * *',  -- Every 15 minutes
        DecayRates = {
            Hunger = 5,       -- Per cycle
            Thirst = 5,       -- Per cycle
            Cleanliness = 3,  -- Per cycle
            Strength = 2      -- Per cycle (if neglected)
        },
        HealthConsequences = {
            CriticalHunger = 30,      -- If hunger < 30, health -2 per cycle
            CriticalThirst = 30,      -- If thirst < 30, health -2 per cycle
            CriticalCleanliness = 20  -- If cleanliness < 20, health -1 per cycle
        },
        HealthRegeneration = {
            RequiredHunger = 80,  -- Minimum for regeneration
            RequiredThirst = 80,
            RegenAmount = 3       -- Health regenerated per cycle
        }
    },

    Lifecycle = {    -- LIFECYCLE SYSTEM
        Enabled = true,  -- Toggle lifecycle system
        PetStages = {
            Baby = {
                ageMin = 0,
                ageMax = 7,
                xpMultiplier = 1.5,
                healthMultiplier = 0.5
            },
            Young = {
                ageMin = 8,
                ageMax = 30,
                xpMultiplier = 1.2,
                healthMultiplier = 0.8
            },
            Adult = {
                ageMin = 31,
                ageMax = 90,
                xpMultiplier = 1.0,
                healthMultiplier = 1.0
            },
            Senior = {
                ageMin = 91,
                ageMax = 180,
                xpMultiplier = 0.8,
                healthMultiplier = 0.9
            }
        },
        MaxAge = 180,  -- Days before natural death
    },

    -- Companion inventory by level
    levelAttributes = {
        {xpMin = 0,    xpMax = 99,         invWeight = 1000,  invSlots = 1},
        {xpMin = 100,  xpMax = 199,        invWeight = 1000,  invSlots = 1},
        {xpMin = 200,  xpMax = 299,        invWeight = 2000,  invSlots = 2},
        {xpMin = 300,  xpMax = 399,        invWeight = 2000,  invSlots = 2},
        {xpMin = 400,  xpMax = 499,        invWeight = 3000,  invSlots = 3},
        {xpMin = 500,  xpMax = 599,        invWeight = 3000,  invSlots = 3},
        {xpMin = 600,  xpMax = 699,        invWeight = 4000,  invSlots = 4},
        {xpMin = 700,  xpMax = 799,        invWeight = 4000,  invSlots = 4},
        {xpMin = 800,  xpMax = 899,        invWeight = 5000,  invSlots = 5},
        {xpMin = 900,  xpMax = 999,        invWeight = 5000,  invSlots = 5},
        {xpMin = 1000, xpMax = 1249,       invWeight = 6000,  invSlots = 6},
        {xpMin = 1250, xpMax = 1499,       invWeight = 8000,  invSlots = 8},
        {xpMin = 1500, xpMax = 1749,       invWeight = 10000, invSlots = 10},
        {xpMin = 1750, xpMax = 1999,       invWeight = 12000, invSlots = 12},
        {xpMin = 2000, xpMax = math.huge,  invWeight = 16000, invSlots = 16}
    },

    -- AI Personalities by XP level
    personalities = {
        {xp = 2000, hash = 'GUARD_DOG'},
        {xp = 1000, hash = 'TIMIDGUARDDOG'},
        {xp = 0,    hash = 'AVOID_DOG'} -- Default
    },
    
    -- Auto-spawn on death
    AutoDeadSpawn = {
        active = true,
        Time   = 5 * 60 * 1000 -- 5 minutes
    },
    
}

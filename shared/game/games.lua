--[[
    HDRP-PETS GAMES CONFIGURATION
    Separated from: shared/games.lua (v5.8.0+)
    Updated: v5.8.1+ - Removed Ranimals (moved to retrievable_animals.lua)
    
    Contains:
    - Bone game settings
    - Buried bone settings
    - Dig random rewards
    - Treasure hunt configuration
    - Hostile encounters
    - Bandit encounters
]]

lib.locale()

-------------------------
-- EXTRA GAME SETTINGS
-----------------------
-- BRING BONE
local Game_bones = {
    AutoDelete      =  1 * 60 * 1000, -- 1 min for clean prop bone
    MaxDist         = 50.0, -- max dist 
    LostTraining    = 40 -- 1 - 100 %
}

-- HIDE & SEARCH BONE
local Game_buried = {
    time = 10 * 1000, -- waiting time until the bone is hidden
    DoMiniGame = false, -- active o no skills for % lostBone 
    lostBone = 80, -- 1-100 % lost bone for no skills in buried bone
    -- Odds of finding the buried bone 1-100 divided into three sections: none, common, special
    findburied = 65, -- base to find something special (rare)
    findSpecial = 10 -- trash finder (common)
}

-- DIG RANDOMLY
local Game_digrandom = {
    min = -30, -- The companion goes to a nearby random coordinate
    max = 30, -- The companion goes to a nearby random coordinate
    lostreward = 80, -- 80% win, 100 -1 % Found something useful
    rewards = {
        { chance = 20, items = {"raw_meat", "pet_feed"} },
        { chance = 30, items = {"bread", "pet_water"} },
        -- { chance = 50, items = {} }
    }
}

-- SEARCH TREASURE
local Game_treasure = {        

    DoMiniGame = true, -- active o no skills for search treasure
    MiniGameShovel = true, -- active o no shovel actions for find treasure  / in false active skills press W S A D
    HoleDistance = 1.5, -- dist for search with shovel
    AutoDelete = 10 * 60 * 1000, -- time for clean prop digging
    lostTreasure = 80, -- 1-100 % lost bone for no skills in buried bone

    minSteps = 2, -- min clue
    maxSteps = 6, -- max clue
    minDistance = 50.0, -- min dist point clue
    maxDistance = 100.0, -- max dist new point clue

    mindistToPlayer = 10.0, -- min separation between player and pet
    maxdistToPlayer = 30.0, -- max separation between player and pet
    distToTarget = 3.0, -- distance to the runway coordinates

    rewards = {
        { chance = 20, items = {"raw_meat", "pet_feed"} },
        { chance = 30, items = {"bread", "pet_water"} }
    },

    anim = {
        clueWaitTime = 2000, -- ms entre pistas
        digAnimTime = 5000, -- WORLD_DOG_DIGGING
        sniAnimTime = 5000, -- WORLD_DOG_SNIFFING_GROUND_WANDER
        guaAnimTime = 5000, -- WORLD_DOG_GUARD_GROWL
        howAnimTime = 5000, -- WORLD_DOG_HOWLING
    }
}

-- HOSTILE ENCOUNTERS
local Game_hostile = {
    SpawnDistance = 10.0,
    DespawnDistance = 100.0,

    Chance = 15,     -- treasure.lua

    Animals = {
        -- chance: Peso para la probabilidad (cuanto más alto, más común)
        { model = 'A_C_Wolf_Small', label = locale('enemy_wolf_pack'), health = 120, chance = 40, isPack = true, min = 2, max = 5 },
        { model = 'a_c_wolf_medium', label = locale('enemy_wolf_pack'), health = 200, chance = 40, isPack = true, min = 2, max = 3 },
        { model = 'A_C_Cougar_01', label = locale('enemy_cougar'), health = 300, chance = 25, isPack = true, min = 1, max = 2 },
        { model = 'A_C_Boar_01', label = locale('enemy_boar_rabid'), health = 150, chance = 20, isPack = true, min = 2, max = 4 },
        { model = 'a_c_snakeblacktailrattle_01', label = locale('enemy_snake'), health = 20, chance = 10, isPack = true, min = 2, max = 4 },
        { model = 'A_C_Bear_01', label = locale('enemy_bear'), health = 450, chance = 15, isPack = false },
        { model = 'A_C_BearBlack_01', label = locale('enemy_bear'), health = 300, chance = 50, isPack = false },
        { model = 'A_C_Panther_01', label = locale('enemy_panther'), health = 300, chance = 50, isPack = false },
        { model = 'a_c_lionmangy_01', label = locale('enemy_lion'), health = 300, chance = 50, isPack = false },
    }
}

local Game_bandit = {
    SpawnDistance = 25.0,
    DespawnDistance = 150.0,
    Chance = 20, 

    WeaponPool = {
        `WEAPON_REVOLVER_CATTLEMAN`,
        `WEAPON_REVOLVER_SCHOFIELD`,
        `WEAPON_REPEATER_CARBINE`,
        `WEAPON_SHOTGUN_SAWEDOFF`,

        `weapon_melee_knife`,
        `weapon_melee_machete`,
        `weapon_melee_hatchet`,
        `weapon_melee_cleaver`,
        `weapon_bow`,
        `weapon_bow_improved`,
    },

    Enemies = {
        { 
            label = locale('enemy_odriscolls'), 
            chance = 40, 
            isPack = true, min = 2, max = 8,
            models = { `g_m_m_uniduster_01`, `g_m_m_uniduster_02`, `g_m_m_uniduster_03` }
        },
        { 
            label = locale('enemy_rustlers'), 
            chance = 30, 
            isPack = true, min = 3, max = 5,
            models = { `u_m_m_bountytarget_01`, `u_m_m_bountytarget_02`, `u_m_m_bountytarget_03` }
        },
        { 
            label = locale('enemy_lone_bandit'), 
            chance = 30, 
            isPack = false,
            models = { `g_m_m_unicriminals_01`, `g_m_m_unicriminals_02` }
        },
    }
}

local Game_fight = {
    MinBet = 10,
    MaxBet = 1000,
    FightCooldown = 60,

    Location = {
        { Coords = vector3(-2411.77, -2455.10, 60.17), PromptName = locale('cl_fight_start_prompt'), PromptKey = "J", HoldDuration = 1000, PromptDistance = 3.0, ShowBlip = true, Blip = { blipSprite = -1646261997, blipScale = 0.8, blipName = locale('cl_fight_blip') } },
        { Coords = vector3(-1795.0, -420.0, 158.0), PromptName = locale('cl_fight_start_prompt'), PromptKey = "J", HoldDuration = 1000, PromptDistance = 3.0, ShowBlip = true, Blip = { blipSprite = -1646261997, blipScale = 0.8, blipName = locale('cl_fight_blip') } }
    },

    Dogs = {
        { Name = locale('dog_bluetickcoonhound'), Model = "a_c_dogbluetickcoonhound_01", Health = 100, Strength = 80, Desc = locale('cl_figh_dog_desc_a') },
        { Name = locale('dog_collie'), Model = "a_c_dogcollie_01", Health = 100, Strength = 90, Desc = locale('cl_figh_dog_desc_b') },
        { Name = locale('dog_husky'), Model = "a_c_doghusky_01", Health = 100, Strength = 88, Desc = locale('cl_figh_dog_desc_e') },
        { Name = locale('dog_rufus'), Model = "a_c_dogrufus_01", Health = 100, Strength = 75, Desc = locale('cl_figh_dog_desc_f') },
        { Name = locale('dog_catahoulacur'), Model = "a_c_dogcatahoulacur_01", Health = 100, Strength = 85, Desc = locale('cl_figh_dog_desc_c') },
        { Name = locale('dog_hound'), Model = "a_c_doghound_01", Health = 100, Strength = 70, Desc = locale('cl_figh_dog_desc_d') },
    },

    LawAlertActive       = true, -- turn law alert on/off
    LawAlertChance       = 20, -- 20% chance of informing the law
    OutlawStatusAdd      = 5, -- amount of outlaw points to add
    OutlawStatusBet      = 1, -- per bet placed

    -- PVP Direct Challenge System
    PvP = {
        Enabled = true,                     -- Enable PvP challenges
        ChallengeTimeout = 60,              -- Seconds to accept a challenge
        NearbyRadius = 50.0,                -- Radius to find nearby players for challenges
        NotifyRadius = 100.0,               -- Radius to notify spectators about fights

        -- Owner bets (between pet owners)
        OwnerBets = {
            Enabled = true,                 -- Enable betting between owners
            MinBet = 50,                    -- Minimum bet for owner fights
            MaxBet = 5000,                  -- Maximum bet for owner fights
            WinMultiplier = 2.0,            -- Winner gets bet * multiplier (2x = double)
        },

        -- Spectator bets (others watching the fight)
        SpectatorBets = {
            Enabled = true,                 -- Enable spectator betting
            MinBet = 10,                    -- Minimum spectator bet
            MaxBet = 500,                   -- Maximum spectator bet
            WinMultiplier = 1.8,            -- Spectator win multiplier
            BettingWindow = 15,             -- Seconds to place bets after fight starts
        },

        -- XP rewards for PvP fights
        XPRewards = {
            Winner = 25,                    -- XP for winning
            Loser = 5,                      -- XP for participating (loser)
            KOBonus = 10,                   -- Extra XP for KO victory
        },
    },

}

return {

    Gbones = Game_bones,
    Gburied = Game_buried,
    Gdigrandom = Game_digrandom,
    Gtreasure = Game_treasure,
    Ghostile = Game_hostile,
    Gbandit = Game_bandit,
    Gdogfight = Game_fight
}

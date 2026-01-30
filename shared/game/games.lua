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

-- PET RACING SYSTEM
-- Three race modes:
-- 1. Solo Race: Player's own pets race against each other
-- 2. NPC Race: Player's pet races against NPC pets
-- 3. PvP Race: Multiple players race their pets against each other
local Game_race = {
    -- General settings
    MinBet = 10,
    MaxBet = 1000,
    RaceCooldown = 120,         -- Cooldown between races (seconds)
    CountdownTime = 10,          -- Countdown before race starts (seconds)
    MaxRaceTime = 120,          -- Maximum race duration (seconds)

    -- Checkpoint settings
    CheckpointModel = `mp001_s_mp_racecheckflag01x`,  -- Flag model for checkpoints
    CheckpointRadius = 3.0,      -- Radius to trigger checkpoint

    -- Race track locations
    Location = {
        {
            Coords = vector3(606.10, -221.13, 146.26),
            PromptName = locale('cl_race_start_prompt') or 'Start Race',
            HoldDuration = 1000,
            PromptDistance = 3.0,
            -- Race track checkpoints (relative offsets from start)
            Track = {
                { offset = vector3(0, 20, 0) },
                { offset = vector3(15, 40, 0) },
                { offset = vector3(30, 35, 0) },
                { offset = vector3(40, 15, 0) },
                { offset = vector3(35, -5, 0) },
                { offset = vector3(15, -15, 0) },
                { offset = vector3(0, 0, 0) },  -- Finish line (back to start)
            }
        },
        {
            Coords = vector3(-1447.27, -1158.45, 74.10),
            PromptName = locale('cl_race_start_prompt') or 'Start Race',
            HoldDuration = 1000,
            PromptDistance = 3.0,
            Track = {
                { offset = vector3(0, 25, 0) },
                { offset = vector3(20, 45, 0) },
                { offset = vector3(40, 40, 0) },
                { offset = vector3(50, 20, 0) },
                { offset = vector3(45, 0, 0) },
                { offset = vector3(25, -10, 0) },
                { offset = vector3(0, 0, 0) },
            }
        }
    },

    -- NPC Dogs for racing (used in NPC mode)
    NPCDogs = {
        { Name = locale('dog_bluetickcoonhound') or 'Blue Tick', Model = "a_c_dogbluetickcoonhound_01", Speed = 80, Stamina = 75, Desc = locale('cl_race_dog_desc_a') or 'Fast starter' },
        { Name = locale('dog_collie') or 'Collie', Model = "a_c_dogcollie_01", Speed = 85, Stamina = 80, Desc = locale('cl_race_dog_desc_b') or 'Balanced runner' },
        { Name = locale('dog_husky') or 'Husky', Model = "a_c_doghusky_01", Speed = 90, Stamina = 85, Desc = locale('cl_race_dog_desc_c') or 'Endurance champion' },
        { Name = locale('dog_rufus') or 'Rufus', Model = "a_c_dogrufus_01", Speed = 70, Stamina = 90, Desc = locale('cl_race_dog_desc_d') or 'Slow but steady' },
        { Name = locale('dog_catahoulacur') or 'Catahoula', Model = "a_c_dogcatahoulacur_01", Speed = 88, Stamina = 70, Desc = locale('cl_race_dog_desc_e') or 'Sprint specialist' },
        { Name = locale('dog_hound') or 'Hound', Model = "a_c_doghound_01", Speed = 75, Stamina = 95, Desc = locale('cl_race_dog_desc_f') or 'Marathon runner' },
    },

    -- Solo Race settings (player's pets compete)
    Solo = {
        MinPets = 2,            -- Minimum pets required for solo race
        MaxPets = 6,            -- Maximum pets in a solo race
        XPReward = {
            Winner = 30,
            Participant = 10,
        }
    },

    -- NPC Race settings (player vs NPCs)
    NPC = {
        NPCCount = 3,           -- Number of NPC competitors
        MinXP = 50,             -- Minimum XP required to participate
        XPReward = {
            Winner = 40,
            Second = 20,
            Third = 10,
            Participant = 5,
        },
        Prizes = {
            First = 100,        -- Cash prize for 1st place
            Second = 50,        -- Cash prize for 2nd place
            Third = 25,         -- Cash prize for 3rd place
        }
    },

    -- PvP Race settings (multiplayer)
    PvP = {
        Enabled = true,
        MinPlayers = 2,         -- Minimum players to start
        MaxPlayers = 8,         -- Maximum players in a race
        JoinTimeout = 60,       -- Seconds to join a race
        NearbyRadius = 100.0,   -- Radius to notify nearby players

        -- Entry fee and betting
        EntryFee = {
            Enabled = true,
            MinFee = 50,
            MaxFee = 500,
        },

        -- Spectator betting
        SpectatorBets = {
            Enabled = true,
            MinBet = 10,
            MaxBet = 200,
            WinMultiplier = 2.5,
            BettingWindow = 20,  -- Seconds to place bets after race starts
        },

        -- XP rewards
        XPRewards = {
            Winner = 50,
            Second = 30,
            Third = 20,
            Participant = 10,
        },

        -- Prize pool distribution (percentage)
        PrizeDistribution = {
            First = 60,          -- Winner gets 60% of pool
            Second = 25,         -- 2nd gets 25%
            Third = 15,          -- 3rd gets 15%
        }
    },

    -- Law alert settings (optional)
    LawAlertActive = false,
    LawAlertChance = 10,
    OutlawStatusAdd = 2,
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

-- FIGHTING SYSTEM
local Game_fight = {
    Enabled = false, -- Enable/disable the dog fighting system
    MinBet = 10,
    MaxBet = 1000,
    FightCooldown = 60,

    Location = {
        {
            Coords = vector3(-2411.77, -2455.10, 60.17),
            PromptName = locale('cl_fight_start_prompt'),
            HoldDuration = 1000,
            PromptDistance = 3.0
        },
        { 
            Coords = vector3(-1795.0, -420.0, 158.0),
            PromptName = locale('cl_fight_start_prompt'),
            HoldDuration = 1000,
            PromptDistance = 3.0
        }
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
    Gdogfight = Game_fight,
    Gpetracing = Game_race
}

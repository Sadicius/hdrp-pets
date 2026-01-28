--[[
    HDRP-PETS CONFIGURATION - XP SYSTEM
    Configuración del sistema de experiencia
    Versión: 5.7.0
]]
lib.locale()

return {
    Trick = { -- xp required to unlock tricks
        -- animations
        Stay = 0, -- 50,
        Lay = 0, -- 105,
        Animations = 0, -- 500,
        Follow = 0, -- 75, -- XP necesario para que la mascota siga de forma continua
        -- games
        Bone = 0, --50,
        Hunt = 0, --150,
        BuriedBone = 0, -- 100,
        digRandom = 0, -- 150,
        TreasureHunt = 0, -- 200,
        -- attacker
        Track = 0, -- 250,
        HuntAnimals = 0, -- 100,
        Attack = 0, -- 500,
        SearchData = 0, -- 500,
        -- fighting
        pet_vs_npc = 0, -- 500,
        pet_vs_player = 0, -- 750,
        own_pets = 0, -- 50,
        -- formations
        formationExpLimits = {
            formation_line = 0,
            formation_column = 0,
            formation_diamond = 0, -- 100,
            formation_escalonada = 0, -- 50,
            formation_peloton = 0, -- 120,
            formation_square = 0, -- 80,
            formation_dispersed = 0,
            formation_zigzag = 0, -- 40,
            formation_doublezigzag = 0, -- 60,
            formation_stair = 0, -- 30,
            formation_spiral = 0, -- 100,
            formation_snail = 0, -- 120,
            formation_wave = 0, -- 80,
            formation_star = 0, -- 150,
            formation_heart = 0, -- 200,
            formation_s = 0, -- 100,
            formation_h = 0, -- 150,
            formation_v = 0, -- 30,
            formation_circle = 0, -- 40,
            formation_arc = 0 -- 40,
        }
    },
    
    -- XP INCREASE PER ACTION
    Increase = {
        -- actions (fixed ranges for consistent progression)
        PerFeed      = 7,   -- XP per feed (5-10 range midpoint)
        PerDrink     = 7,   -- XP per drink (5-10 range midpoint)
        PerStimulant = 7,   -- XP per stimulant (5-10 range midpoint)
        PerClean     = 5,   -- XP per clean (5-10 range midpoint)
        PerMove      = 1,   -- XP per move to player (1-2 range minimum)
        -- games
        PerBone       = 7,  -- XP per play (1-5 range midpoint)
        PerFindBuried = 10,  -- XP per find buried (1-5 range midpoint)
        PerDigRandom  = 3,  -- XP per dig random (5-10 range midpoint)
        PerTreasure   = 35, -- XP per treasure hunt (20-50 range midpoint)
        PerCombat     = 15, -- XP per combat (10-20 range midpoint)
        PerCombatHuman = 20 -- XP per combat vs human (15-25 range midpoint)
    },

    -- LEVEL UP NOTIFICATIONS
    LevelUpNotifications = {
        Enabled = true,
        ShowParticleEffect = true,  -- Visual effect on level up
        PlaySound = true,           -- Play sound effect
        SoundName = 'REWARD_NEW_GUN',
        BroadcastRadius = 50.0
    },

    -- ACHIEVEMENT SYSTEM
    Achievements = {
        Enabled = true,
        List = {
            FirstSteps = {
                name = locale('cl_achiev_first_steps'),
                description = locale('cl_achiev_first_steps_desc'),
                requirement = {type = 'level', value = 5},
                xpBonus = 50,
                oneTime = true
            },
            FirstCombatWin = {
                name = locale('cl_achiev_first_combat_win'),
                description = locale('cl_achiev_first_combat_win_desc'),
                requirement = {type = 'fight', value = 1},
                xpBonus = 50,
                oneTime = true
            },
            Combat10Wins = {
                name = locale('cl_achiev_10_combat_wins'),
                description = locale('cl_achiev_10_combat_wins_desc'),
                requirement = {type = 'fight', value = 10},
                xpBonus = 100,
                oneTime = true
            },
            CombatStreak5 = {
                name = locale('cl_achiev_5_streak'),
                description = locale('cl_achiev_5_streak_desc'),
                requirement = {type = 'fight_streak', value = 5},
                xpBonus = 75,
                oneTime = true
            },
            Apprentice = {
                name = locale('cl_achiev_apprentice_trainer'),
                description = locale('cl_achiev_apprentice_trainer_desc'),
                requirement = {type = 'level', value = 10},
                xpBonus = 100,
                oneTime = true
            },
            Expert = {
                name = locale('cl_achiev_expert_trainer'),
                description = locale('cl_achiev_expert_trainer_desc'),
                requirement = {type = 'level', value = 15},
                xpBonus = 200,
                oneTime = true
            },
            FormationApprentice = {
                name = locale('cl_achiev_formation_apprentice'),
                description = locale('cl_achiev_formation_apprentice_desc'),
                requirement = {type = 'formation', value = 10},
                xpBonus = 100,
                oneTime = false
            },
            FormationVeteran = {
                name = locale('cl_achiev_formation_master'),
                description = locale('cl_achiev_formation_master_desc'),
                requirement = {type = 'formation', value = 20},
                xpBonus = 150,
                oneTime = false
            },
            TreasureHunter5 = {
                name = locale('cl_achiev_treasure_hunter'),
                description = locale('cl_achiev_treasure_hunter_desc'),
                requirement = {type = 'treasure', value = 5},
                xpBonus = 150,
                oneTime = false
            },
            TreasureHunter10 = {
                name = locale('cl_achiev_treasure_hunter'),
                description = locale('cl_achiev_treasure_hunter_desc'),
                requirement = {type = 'treasure', value = 10},
                xpBonus = 150,
                oneTime = false
            },
            TreasureHunter25 = {
                name = locale('cl_achiev_treasure_hunter'),
                description = locale('cl_achiev_treasure_hunter_desc'),
                requirement = {type = 'treasure', value = 25},
                xpBonus = 150,
                oneTime = false
            },
            CombatVeteran = {
                name = locale('cl_achiev_combat'),
                description = locale('cl_achiev_combat_desc'),
                requirement = {type = 'fight', value = 50},
                xpBonus = 150,
                oneTime = false
            }
        }
    },

    -- PARTY XP SHARING (Cooperative Activities)
    PartyXPSharing = {
        Enabled = true,
        -- Activities that share XP among all active pets
        CooperativeActivities = {
            'hostile',  -- Combat vs NPCs
            'bandit'    -- Combat vs humans
        },
        -- Activities that give XP to specific pet only
        IndividualActivities = {
            'dig_random',
            'find_buried',
            'treasure',
            'feed',
            'drink',
            'clean'
        },
        ShareMultiplier = 1.0  -- 1.0 = full XP to all, 0.5 = half XP to all
    }
}

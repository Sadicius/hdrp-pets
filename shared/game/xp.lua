--[[
    HDRP-PETS CONFIGURATION - XP SYSTEM
    Configuración del sistema de experiencia
    Versión: 5.7.0
]]
lib.locale()

return {
    Trick = { -- xp required to unlock tricks
        -- animations
        Stay = 50,
        Lay = 105,
        Animations = 500,
        Follow = 75, -- XP necesario para que la mascota siga de forma continua
        -- games
        Bone = 50,
        Hunt = 150,
        BuriedBone = 100,
        digRandom = 150,
        TreasureHunt = 200,
        -- attacker
        Track = 250,
        HuntAnimals = 100,
        Attack = 500,
        SearchData = 500,
        -- fighting
        pet_vs_npc = 500,
        pet_vs_player = 750,
        own_pets = 50,
        -- formations
        formationExpLimits = {
            formation_line = 0,
            formation_column = 0,
            formation_diamond = 100,
            formation_escalonada = 50,
            formation_peloton = 120,
            formation_square = 80,
            formation_dispersed = 0,
            formation_zigzag = 40,
            formation_doublezigzag = 60,
            formation_stair = 30,
            formation_spiral = 100,
            formation_snail = 120,
            formation_wave = 80,
            formation_star = 150,
            formation_heart = 200,
            formation_s = 100,
            formation_h = 450,
            formation_v = 150,
            formation_circle = 600,
            formation_arc = 400
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

}

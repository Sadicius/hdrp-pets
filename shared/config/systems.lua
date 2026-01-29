--[[
    HDRP-PETS CONFIGURATION - SYSTEMS
    Configuración de todos los sistemas del mod
    Versión: 5.7.0
]]

return {
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

    Ambient = {
        ObjectAction = true,
        BoostAction = {
            Health = math.random(3, 9),
            -- Stamina = math.random(3, 9)
        },
        ObjectActionList = {
            [1] = {`p_watertrough02x`, 'drink'},
            [2] = {`p_watertrough01x`, 'drink'},
            [3] = {`p_haypile01x`, 'feed'},
        },
        Anim = {
            Drink  = { dict = 'amb_creature_mammal@world_dog_eating_ground@base', anim = 'base', duration = 20 }, --duration in seconds
            Drink2 = { dict = 'amb_creature_mammal@world_dog_eating_ground@base', anim = 'base', duration = 20 },
            Graze  = { dict = 'amb_creature_mammal@world_dog_eating_ground@base', anim = 'base', duration = 20 }
        }
    },

    Herding = {    -- ADVANCED HERDING SYSTEM
        Enabled = true,                -- Activar/desactivar el sistema avanzado
        RequireTool = false,           -- ¿Requiere herramienta específica para usar?
        ToolItem = {'weapon_lasso', 'weapon_lasso_reinforced'},    -- Nombre del ítem requerido (si aplica)
        Distance = 15.0,               -- Distancia máxima para selección de mascotas
        FollowDistance = 3.0,          -- Distancia a la que las mascotas siguen al jugador
        Speed = 1.5,                   -- Velocidad de movimiento de las mascotas durante el herding
        DistanceSelection = true,      -- Permitir selección por distancia
        IndividualSelection = true,    -- Permitir selección individual
        -- TypeSelection = true,          -- Permitir selección por tipo
        MaxAnimals = 10,                -- Máximo de mascotas a herdear a la vez
        Timeout = 60,                  -- Tiempo máximo de herding (segundos)
        ShowDistance = true,           -- Mostrar distancia en UI
        EscortDistance = 10.0,         -- Distancia de escolta
        SelectionRangeMultiplier = 1.5, -- Multiplicador para rango de selección
    
        formationMinLimits = { -- Límites mínimos para formaciones
            formation_line = 2,
            formation_column = 2,
            formation_diamond = 4,
            formation_escalonada = 3,
            formation_peloton = 4,
            formation_square = 4,
            formation_dispersed = 2,
            formation_zigzag = 3,
            formation_doublezigzag = 4,
            formation_stair = 3,
            formation_spiral = 3,
            formation_snail = 3,
            formation_wave = 3,
            formation_star = 5,
            formation_heart = 6,
            formation_s = 4,
            formation_h = 5,
            formation_v = 3,
            formation_circle = 3,
            formation_arc = 3
        }
    },

    Wandering = {    -- WANDERING SYSTEM (Phase 3)
        Enabled = true,
        WanderRadius = 10.0,
        WanderSpeed = 1.0,
        IdleAnimDict = 'amb_creature_mammal@world_dog_idle@base',
        IdleAnimName = 'base',
        CheckInterval = 10000,  -- in milliseconds
        MaxDistance = 50.0,
        MinDistance = 5.0,
        WaitTime = {min = 10000, max = 30000}
    },

    Reproduction = {    -- REPRODUCTION SYSTEM (BREEDING)
        Enabled = true,  -- Disabled: major gameplay change
        MinAgeForBreeding = 30,      -- Days
        MaxBreedingAge = 120,
        GestationPeriod = 172800,    -- 2 days in seconds
        BreedingDistance = 5.0,
        CooldownMale = 3600,         -- 1 hour
        CooldownFemale = 86400,      -- 24 hours
        RequiredHealth = 70,
        RequiredHunger = 70,
        RequiredThirst = 70,
        GenealogyEnabled = true, -- Permite activar/desactivar el sistema de genealogía
    },

    Veterinary = {    -- VETERINARY SYSTEM
        Enabled = true,
        VeterinaryNPCs = {
            -- Add NPC locations here
            -- { name = 'Valentine', coords = vector3(...) }
        },
        Services = {
            FullCheckup = {
                price = 50,
                healsAll = true
            },
            Vaccination = {
                price = 25,
                preventsDisease = true
            },
            Surgery = {
                price = 150,
                criticalOnly = true
            },
            Sterilization = {
                price = 100,
                preventsBreed = true
            }
        },
        DiseaseSystem = {
            Enabled = true,
            RiskFactors = {
                DirtinessOver = 80,
                HungerBelow = 20,
                ThirstBelow = 20
            }
        }
    },

    Statistics = {    -- STATISTICS SYSTEM
        TrackActivity = true,
        Activities = {
            'fed', 'drank', 'groomed', 'played', 'trained',
            'hunted', 'attacked', 'tracked', 'generated_resources'
        },
        CompetitiveStats = {
            Enabled = true,
            TrackInDatabase = true,
            Categories = {
                'totalHunted',
                'totalXP',
                'longestLived',
                'mostFed'
            }
        }
    }
}

# REFERENCE STRUCTURE FOR State TABLE

## Estructura recomendada para State:

```lua
State = { 
    Pets[companionid] = {
        data    = {       -- Datos persistentes sincronizados con server (ver docs)

            id = companionid,                -- ID único de la mascota

            info = {
                name    = companionname or nil,     -- Nombre personalizado
                model   = model or nil,             -- Modelo o especie
                skin    = skin or 0,                -- Skin/variante visual
                gender  = gender,                   -- Género
                type    = category,                 -- Tipo o raza
                born    = os.time(),                -- Fecha de nacimiento (timestamp)
            },
        
            stats = {
                hunger      = Config.PetAttributes.Starting.Hunger or 100,      -- Hambre (0-100)
                thirst      = Config.PetAttributes.Starting.Thirst or 100,      -- Sed (0-100)
                happiness   = Config.PetAttributes.Starting.Happiness or 100,   -- Felicidad (0-100)
                dirt        = Config.PetAttributes.Starting.Dirt or 100,        -- Suciedad (0-100)
                strength    = Config.PetAttributes.Starting.Strength or 100,    -- Fortaleza (0-100)
                health      = Config.PetAttributes.Starting.Health or 100,      -- Salud actual
                age         = 1.0,                                              -- Edad en días
                scale       = 0.5                                               -- Escala visual
            },
        
            progression = {
                xp      = 0.0,  -- Experiencia total
                level   = 1,    -- Nivel calculado
                bonding = 0,    -- Nivel de vínculo
            },
        
            veterinary = {
                dead            = false,  -- Estado de vida
                hasdisease      = false,  -- Enfermedad activa
                diseasetype     = nil,    -- Tipo de enfermedad
                diseaseddate    = nil,    -- Fecha de diagnóstico
                
                isvaccinated    = false,  -- Estado de vacunación
                vaccineexpire   = nil,    -- Fecha de expiración de vacuna
                vaccinationdate = nil,    -- Fecha de vacunación
                
                lastcheckup     = nil,    -- Último chequeo veterinario
                daysatcheckup   = 0,      -- Días transcurridos desde el último chequeo
                dayssincecheckup = 0,     -- Días transcurridos desde el último chequeo
                
                lastsurgery     = nil,    -- Fecha de la última cirugía
                daysatsurgery   = 0,      -- Días transcurridos desde la última cirugía
                dayssincesurgery = 0,     -- Días transcurridos desde la última cirugía

                breedable               = false,  -- Puede reproducirse. Se sustituye "No" por false,
                sterilizationdate       = nil,    -- Fecha de esterilización
                daysatsterilization     = 0,      -- Días desde esterilización
                dayssincesterilization  = 0,      -- Días desde esterilización
                
                inbreed                 = false,  -- Esta preñada. Se sustituye "No" por false
                breedingcooldown        = nil,    -- Fecha de cooldown de reproducción
                gestationstart          = nil,    -- Fecha de inicio de gestación
                gestationperiod         = nil     -- Periodo de gestación en segundos
            },

            personality = {
                wild = false,       -- Si es salvaje o domesticado
                type = nil,         -- Tipo de personalidad
                progress = 0        -- Progreso de personalidad
            },
        
            genealogy = {
                parents = {},   -- IDs de padres
                offspring = {}  -- IDs de descendencia
            },
        
            history = {},  -- Historial de eventos relevantes
        },

        ped     = nil,          -- <entity>,         -- Entidad en el mundo (runtime)
        blip    = nil,          -- <blip>,          -- Blip en el mapa (runtime)
        spawned = true,         -- Si está spawneada (runtime)
        flag = {                -- Flags temporales
            isCustom    = false,
            isWild      = false,

            isCall          = false,
            isBusy          = false,
            isFrozen        = false,
            isWandering     = false,
            isHerding       = false,
            isFollowing     = false,
            isTrack         = false,

            isGame          = false,
            isHunting       = false, -- Está en modo caza
            isRetrieving    = false, -- Está en proceso de recuperar algo
            isRetrieved     = false, -- Ha recuperado algo

            isDefensive     = false,
            isInCombat      = false,
            isCombat        = false,
            isFight         = false,

            isCritical      = false,
            isSterilization = false,
            isHasDisease    = false,
            isVaccine       = false,
            isBreeding      = false,
        },
        lastAction  = <timestamp>,
        timers      = {       -- Timers/cooldowns
            recentlyCombatTime = 0,
        },
        visualState = { ... },      -- Animaciones/props
        achievements= { ... },      -- Logros temporales (si aplica)
        dataVersion = 1             -- Versión de la estructura cargada
    },

    Behavior = {
        ClaimedAnimals = {},
        retrievedEntities = {},
        attackedGroup = nil,
        fetchedObj = nil,
        gpsRoute = nil,
    },

    Games = {
        buriedBoneCoords = nil
    },

    Common = {
        itemProps = {},
    
        closestStable = nil,


        timeout = false,
        timeoutTimer = 30,
    },
}
```

Estructura de wanderStates:
```lua
local wanderStates = {
    [companionid] = {
        entity = pedEntity,
        homePosition = vector3(x, y, z),
        state = 'idle' | 'moving' | 'returning' | 'paused',
        stateChangeTime = timestamp,
        targetPosition = vector3(x, y, z) | nil,
        active = true | false,
        distanceFromHome = number,
        idleTimeSet = nil,
        moveTimeSet = nil
    },
    ...
}
```

Estructura de herdingStates:
```lua
local herdingStates = {
        active = false,
        pets = {},
        selectedPets = {},
        type = nil,
        threadId = nil,
        startTime = nil,
    },
```

Estructura de Prompts principales por mascota (por entidad)
```lua
local petPrompts = {
    [entityId] = {
        actions = <prompt_handle>,
        flee = <prompt_handle>,
        saddlebag = <prompt_handle>,
        hunt = <prompt_handle>, -- opcional según XP
        petId = <companionid>
    },
    ...
}

-- Prompts contextuales (track, attack, hunt externo, search)
local TrackPrompts = { [entityId] = <prompt_handle>, ... }
local AttackPrompts = { [entityId] = <prompt_handle>, ... }
local HuntAnimalsPrompts = { [entityId] = <prompt_handle>, ... }
local SearchDatabasePrompt = { [entityId] = <prompt_handle>, ... }
```
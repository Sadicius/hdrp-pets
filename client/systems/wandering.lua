local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- Tabla local para estados de wandering
local State = exports['hdrp-pets']:GetState()
local wanderStates = {} -- Estados de wandering

---------------------------------
-- START WANDER
---------------------------------
local function StartPetWander(companionid, pet)
    local entity = pet.entity
    local homePos = pet.homePosition
    local wanderRadius = Config.Wandering.WanderRadius
    if not DoesEntityExist(entity) then return end
    local angle = math.random(0, 360) * (math.pi / 180)
    local distance = math.random(1, 10) / 10 * wanderRadius
    local targetX = homePos.x + math.cos(angle) * distance
    local targetY = homePos.y + math.sin(angle) * distance
    local targetZ = homePos.z
    local groundZ = 0
    RequestCollisionAtCoord(targetX, targetY, targetZ)
    -- GetGroundZFor_3dCoord(targetX, targetY, targetZ, groundZ, false)
    local found, groundZ = GetGroundZFor_3dCoord(targetX, targetY, targetZ, false)
    if groundZ ~= 0 then targetZ = groundZ end
    pet.targetPosition = vector3(targetX, targetY, targetZ)
    pet.state = 'moving'
    pet.stateChangeTime = GetGameTimer()
    local wanderSpeed = Config.Wandering.WanderSpeed or 1.0
    TaskGoToCoordAnyMeans(entity, targetX, targetY, targetZ, wanderSpeed, 0, false, 786603, 0xbf800000)
    if Config.Debug then print('^2[WANDERING]^7 ' .. locale('wander_debug_moving', companionid, distance, wanderRadius)) end
end

local function TransitionToIdle(companionid, wanderState)
    local entity = wanderState.entity
    if DoesEntityExist(entity) then
        ClearPedTasks(entity)
        local idleAnimDict = Config.Wandering.IdleAnimDict or 'amb_creature_mammal@world_dog_idle@base'
        local idleAnimName = Config.Wandering.IdleAnimName or 'base'
        State.PlayPetAnimation(companionid, idleAnimDict, idleAnimName, false)
    end
    wanderState.state = 'idle'
    wanderState.targetPosition = nil
    wanderState.stateChangeTime = GetGameTimer()
    if Config.Debug then print('^2[WANDERING]^7 ' .. locale('wander_debug_transition_idle', companionid)) end
end

local function ReturnPetToHome(companionid, wanderState)
    local entity = wanderState.entity
    local homePos = wanderState.homePosition
    wanderState.state = 'returning'
    wanderState.targetPosition = homePos
    wanderState.stateChangeTime = GetGameTimer()
    local returnSpeed = (Config.Wandering.WanderSpeed * 1.5)
    TaskGoToCoordAnyMeans(entity, homePos.x, homePos.y, homePos.z, returnSpeed, 0, false, 786603, 0xbf800000)
    if Config.Debug then print('^1[WANDERING]^7 ' .. locale('wander_debug_too_far', companionid, wanderState.distanceFromHome)) end
end
---------------------------------
-- STATE PROCESSORS
---------------------------------
local function ProcessIdleState(companionid, pet, timeSinceChange)
    local idleTime = Config.Wandering.WaitTime.max or 30000
    if pet.idleTimeSet then
        idleTime = pet.idleTimeSet
    else
        idleTime = math.random(Config.Wandering.WaitTime.min, Config.Wandering.WaitTime.max)
        pet.idleTimeSet = idleTime
    end
    
    if timeSinceChange >= idleTime then
        pet.idleTimeSet = nil
        StartPetWander(companionid, pet)
    end
end

local function ProcessMovingState(companionid, pet, timeSinceChange)
    local moveTime = Config.Wandering.WaitTime.max or 15000
    if pet.moveTimeSet then
        moveTime = pet.moveTimeSet
    else
        moveTime = math.random(Config.Wandering.WaitTime.min, Config.Wandering.WaitTime.max)
        pet.moveTimeSet = moveTime
    end
    
    if timeSinceChange >= moveTime then
        pet.moveTimeSet = nil
        TransitionToIdle(companionid, pet)
    end
    
    -- Verificar si se alejó demasiado
    local distanceFromHome = pet.distanceFromHome
    if distanceFromHome > (Config.Wandering.MaxDistance or 50.0) then
        pet.moveTimeSet = nil
        ReturnPetToHome(companionid, pet)
    end
end

local function ProcessReturningState(companionid, pet, distanceFromHome)
    local returnThreshold = Config.Wandering.MinDistance or 5.0
    
    if distanceFromHome <= returnThreshold then
        TransitionToIdle(companionid, pet)
    end
end

---------------------------------
-- UPDATE LOGIC
---------------------------------
local function UpdatePetWander(companionid)
    if not wanderStates[companionid] then return end
    local pet = wanderStates[companionid]
    local entity = pet.entity
    if not DoesEntityExist(entity) then StopPetWandering(companionid); return end
    local homePos = pet.homePosition
    local currentPos = GetEntityCoords(entity)
    local distanceFromHome = #(currentPos - homePos)
    pet.distanceFromHome = distanceFromHome
    if pet.state == 'paused' then return end
    local timeSinceChange = GetGameTimer() - pet.stateChangeTime
    if pet.state == 'idle' then ProcessIdleState(companionid, pet, timeSinceChange)
    elseif pet.state == 'moving' then ProcessMovingState(companionid, pet, timeSinceChange)
    elseif pet.state == 'returning' then ProcessReturningState(companionid, pet, distanceFromHome)
    end
end

---------------------------------
-- WANDER THREAD
---------------------------------
local function WanderBehaviorThread(companionid)
    CreateThread(function()
        while wanderStates[companionid] and wanderStates[companionid].active do
            UpdatePetWander(companionid)
            Wait(Config.Wandering.CheckInterval)
        end
    end)
end

---------------------------------
-- SETUP/CLEANUP FUNCTIONS
---------------------------------
function SetupPetWandering(companionid, entity, spawnPos)
    if not Config.Wandering.Enabled then return end
    if not DoesEntityExist(entity) then
        if Config.Debug then print('^1[WANDERING]^7 ' .. locale('wander_error_entity_not_exist', companionid)) end
        return
    end
    companionid = tostring(companionid)
    local pet = State.Pets[companionid]
    if not pet or not pet.flag or not pet.flag.isWandering then return end
    if wanderStates[companionid] then StopPetWandering(companionid) end
    wanderStates[companionid] = {
        entity = entity,
        homePosition = spawnPos,
        state = 'idle',
        stateChangeTime = GetGameTimer(),
        targetPosition = nil,
        active = true,
        distanceFromHome = 0
    }
    WanderBehaviorThread(companionid)
    if Config.Debug then print('^2[WANDERING]^7 ' .. locale('wander_debug_setup_pet', companionid)) end
end

function StopPetWandering(companionid)
    companionid = tostring(companionid)
    if not wanderStates[companionid] then return end
    local wanderState = wanderStates[companionid]
    local entity = wanderState.entity
    if DoesEntityExist(entity) then ClearPedTasks(entity) end
    wanderStates[companionid] = nil
    if Config.Debug then print('^3[WANDERING]^7 ' .. locale('wander_debug_stop_pet', companionid)) end
end

function PausePetWandering(companionid)
    companionid = tostring(companionid)
    if not wanderStates[companionid] then return end
    local wanderState = wanderStates[companionid]
    local entity = wanderState.entity
    if DoesEntityExist(entity) then ClearPedTasks(entity) end
    wanderState.state = 'paused'
    wanderState.stateChangeTime = GetGameTimer()
    if Config.Debug then print('^3[WANDERING]^7 ' .. locale('wander_debug_pause_pet', companionid)) end
end

function ResumePetWandering(companionid)
    companionid = tostring(companionid)
    if not wanderStates[companionid] then return end
    local wanderState = wanderStates[companionid]
    if wanderState.state ~= 'paused' then return end
    wanderState.state = 'idle'
    wanderState.stateChangeTime = GetGameTimer()
    wanderState.targetPosition = nil
    local pet = State.Pets[companionid]
    if pet and pet.flag then
        pet.flag.isWandering = true
    end
    if Config.Debug then print('^2[WANDERING]^7 ' .. locale('wander_debug_resume_pet', companionid)) end
end
-- antiguo wandering_behavior.lua
-- antiguo wandering_utilities.lua

local function GetPetWanderState(petId)
    petId = tostring(petId)
    return wanderStates[petId]
end

local function IsPetWandering(petId)
    petId = tostring(petId)
    local state = wanderStates[petId]
    return state ~= nil and state.active and state.state ~= 'paused'
end

local function GetAllWanderingPets()
    local pets = {}
    for petId, state in pairs(wanderStates) do
        if state.active then table.insert(pets, petId) end
    end
    return pets
end

local function CleanupAllWandering()
    for petId, _ in pairs(wanderStates) do
        StopPetWandering(petId)
    end
    wanderStates = {}
    if Config.Debug then print('^3[WANDERING]^7 ' .. locale('wander_debug_system_cleanup')) end
end

if Config.Debug then
    RegisterCommand('petwander_status', function()
        local count = 0
        print('^3[WANDERING DEBUG]^7 Estado actual de todos los pets:')
            for petId, state in pairs(wanderStates) do
            count = count + 1
            print('  ' .. locale('wander_debug_status', petId, state.state, state.distanceFromHome or 0, tostring(state.active)))
        end
        print('^3[WANDERING DEBUG]^7 ' .. locale('wander_debug_count', count))
    end, false)
    
    RegisterCommand('petwander_cleanup', function()
        CleanupAllWandering()
        print('^2[WANDERING DEBUG]^7 ' .. locale('wander_debug_system_cleanup'))
    end, false)
end

-- antiguo wander_system.lua
local initialized = false

---------------------------------------------
-- INITIALIZATION
---------------------------------------------
function InitializeWanderingSystem()
    if initialized then
        if Config.Debug then print('^3[WANDERING]^7 ' .. locale('wander_error_already_initialized')) end
        return
    end
    local cfg = Config.Wandering
    if not cfg then print('^1[WANDERING ERROR]^7 ' .. locale('wander_error_config_missing')); return end
    cfg.CheckInterval = cfg.CheckInterval or 2000
    cfg.WanderRadius = cfg.WanderRadius or cfg.MinDistance or 10.0
    cfg.MaxDistance = cfg.MaxDistance or 50.0
    local waitMin = (cfg.WaitTime and cfg.WaitTime.min) or 10000
    local waitMax = (cfg.WaitTime and cfg.WaitTime.max) or 30000
    if cfg.CheckInterval <= 0 then print('^1[WANDERING ERROR]^7 ' .. locale('wander_error_checkinterval_invalid')); cfg.CheckInterval = 2000 end
    if cfg.MaxDistance <= cfg.WanderRadius then print('^3[WANDERING WARNING]^7 ' .. locale('wander_warning_maxdistance_gt_wanderradius')); cfg.MaxDistance = cfg.WanderRadius + 10.0 end
    initialized = true
    if Config.Debug then
        print('^2[WANDERING]^7 ' .. locale('wander_debug_system_initialized'))
        print('^2[WANDERING]^7 ' .. string.format(locale('wander_debug_enabled_fmt'), tostring(Config.Wandering.Enabled)))
        print('^2[WANDERING]^7 ' .. string.format(locale('wander_debug_radius_fmt'), tostring(Config.Wandering.WanderRadius)))
        print('^2[WANDERING]^7 ' .. string.format(locale('wander_debug_interval_fmt'), tostring(Config.Wandering.CheckInterval)))
    end
end

---------------------------------------------
-- EVENTS
---------------------------------------------
-- Cleanup al descargar el recurso
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for petId, _ in pairs(wanderStates) do
            StopPetWandering(petId)
        end
        wanderStates = {}
    end
end)

---------------------------------------------
-- STARTUP
---------------------------------------------
-- Inicializar cuando el recurso cargue
CreateThread(function()
    Wait(5000) -- Esperar a que el framework y otros sistemas carguen
    InitializeWanderingSystem()
end)

---------------------------------------------
-- EXPORTS
---------------------------------------------

exports('SetupPetWandering', SetupPetWandering)
exports('StopPetWandering', StopPetWandering)
exports('PausePetWandering', PausePetWandering)
exports('ResumePetWandering', ResumePetWandering)
exports('GetPetWanderState', function(petId) return wanderStates[tostring(petId)] end)
exports('IsPetWandering', function(petId) local state = wanderStates[tostring(petId)]; return state ~= nil and state.active and state.state ~= 'paused' end)
exports('GetAllWanderingPets', function() local pets = {}; for petId, state in pairs(wanderStates) do if state.active then table.insert(pets, petId) end end; return pets end)
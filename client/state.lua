------------------------------------------
-- GLOBAL STATE TABLE
------------------------------------------
State = {} -- Estados globales

State.Pets      = {} -- Mascotas activas
State.Threads   = {} -- Control de threads activos por mascota
State.GlobalThreads = { active = true } -- Control de threads globales
State.Games     = {
    bandits = {},   -- Entidades bandido activas
    hostiles = {},  -- Entidades hostiles activas
    fights = {},    -- Peleas activas (dogfights)
} -- Estado de minijuegos

------------------------------------------
-- THREAD CONTROL SYSTEM (Previene memory leaks)
------------------------------------------

---Verifica si un thread de mascota debe continuar ejecutándose
---@param companionid string
---@return boolean shouldContinue
function State.ShouldThreadContinue(companionid)
    if not companionid then return false end
    local pet = State.Pets[companionid]
    return pet ~= nil and pet.spawned == true and pet.ped ~= nil and DoesEntityExist(pet.ped)
end

---Verifica si los threads globales deben continuar (hay mascotas activas)
---@return boolean shouldContinue
function State.HasActivePets()
    for _, pet in pairs(State.Pets) do
        if pet and pet.spawned and pet.ped and DoesEntityExist(pet.ped) then
            return true
        end
    end
    return false
end

---Registra un thread asociado a una mascota específica
---@param companionid string
---@param threadName string identificador único del thread
function State.RegisterThread(companionid, threadName)
    if not companionid then return end
    State.Threads[companionid] = State.Threads[companionid] or {}
    State.Threads[companionid][threadName] = true
end

---Cancela todos los threads de una mascota
---@param companionid string
function State.CancelPetThreads(companionid)
    if not companionid then return end
    if State.Threads[companionid] then
        for threadName, _ in pairs(State.Threads[companionid]) do
            State.Threads[companionid][threadName] = false
        end
    end
end

---Verifica si un thread específico debe continuar
---@param companionid string
---@param threadName string
---@return boolean shouldContinue
function State.IsThreadActive(companionid, threadName)
    if not companionid or not threadName then return false end
    if not State.Threads[companionid] then return false end
    return State.Threads[companionid][threadName] == true and State.ShouldThreadContinue(companionid)
end

---Limpia los registros de threads de una mascota
---@param companionid string
function State.CleanupPetThreads(companionid)
    if companionid then
        State.Threads[companionid] = nil
    end
end

------------------------------------------
-- HOSTILES & BANDITS HELPERS
------------------------------------------

------------------------------------------
-- Añadir un bandido activo
function State.AddBandit(entity, blip)
    State.Games.bandits = State.Games.bandits or {}
    table.insert(State.Games.bandits, {ped = entity, blip = blip})
end

-- Añadir un hostil activo
function State.AddHostile(entity, blip)
    State.Games.hostiles = State.Games.hostiles or {}
    table.insert(State.Games.hostiles, {ped = entity, blip = blip})
end

-- Limpiar todos los bandidos activos
function State.CleanupAllBandits()
    for i = #State.Games.bandits, 1, -1 do
        local b = State.Games.bandits[i]
        if b.ped and DoesEntityExist(b.ped) then
            SetEntityAsNoLongerNeeded(b.ped)
            DeleteEntity(b.ped)
        end
        if b.blip and DoesBlipExist(b.blip) then
            RemoveBlip(b.blip)
        end
        table.remove(State.Games.bandits, i)
    end
end

-- Limpiar todos los hostiles activos
function State.CleanupAllHostiles()
    for i = #State.Games.hostiles, 1, -1 do
        local h = State.Games.hostiles[i]
        if h.ped and DoesEntityExist(h.ped) then
            SetEntityAsNoLongerNeeded(h.ped)
            DeleteEntity(h.ped)
        end
        if h.blip and DoesBlipExist(h.blip) then
            RemoveBlip(h.blip)
        end
        table.remove(State.Games.hostiles, i)
    end
end

function State.IsPedAnimal(entity)
    local pedType = GetPedType(entity)    -- Use GetPedType() to identify animal-like entities
    return pedType >= 28 and pedType <= 31    -- Animal types are typically different from human types
end

------------------------------------------
-- PETS HELPERS
------------------------------------------
---Get all pets
---@return table pets
function State.GetAllPets()
    return State.Pets or {}
end

---Get pet by ID
---@param companionid string
function State.GetPet(companionid)
    if not companionid then return nil end
    return State.Pets[companionid]
end

---Get pet by entity handle
---@param entity number Entity handle
---@return table|nil, string|nil pet data, companionid
function State.GetPetByEntity(entity)
    if not entity or not DoesEntityExist(entity) then return nil, nil end

    for companionid, v in pairs(State.GetAllPets()) do
        if v and v.spawned and DoesEntityExist(v.ped) and v.ped == entity then
            return v, companionid
        end
    end

    return nil, nil
end

-- HELPERS: Pet Selection
---Get all active pet entities
---@return table Array of {ped, id} for all active pets
function State.GetAllActivePets()
    local pets = {}
    for companionid, petData in pairs(State.GetAllPets()) do
        if petData and petData.spawned and DoesEntityExist(petData.ped) then
            table.insert(pets, {ped = petData.ped, id = companionid})
        end
    end
    return pets
end

---Determine which pet(s) to use for an action
---Priority: 1. Targeted pet, 2. Specified petId, 3. Closest pet
---@param companionid string|nil Optional specific pet ID
---@return number|nil, string|nil Pet entity and ID
function State.GetPetForAction(companionid)
    -- Priority 1: Specified pet ID
    if companionid then
        local petData = State.GetPet(companionid)
        if petData and petData.spawned and DoesEntityExist(petData.ped) then
            return petData.ped, companionid
        end
    end

    -- Priority 2: Closest pet to player
    local closestPet, _, closestId = State.GetClosestPet()
    if closestPet and closestPet.spawned and DoesEntityExist(closestPet.ped) then
        return closestPet.ped, closestId
    end

    return nil, nil
end

------------------------------------------
-- REGISTER FUNCTIONS
------------------------------------------
---Register pet in system
---@param companionid string
---@param ped number entity handle
---@param blip number blip handle
---@param data table pet data
function State.RegisterPet(companionid, ped, blip, data)
    -- Si ya existe, limpiar entidad anterior
    if State.Pets[companionid] and State.Pets[companionid].ped and DoesEntityExist(State.Pets[companionid].ped) then
        SetEntityAsNoLongerNeeded(State.Pets[companionid].ped)
        DeleteEntity(State.Pets[companionid].ped)
    end
    State.Pets[companionid] = {
        ped = ped,
        blip = blip,
        spawned = true,
        data = data or {},
        flag = {
            -- isCustom = false,
            -- isWild = false,
            isCall = false,
            isFrozen = false,
            isWandering = false,
            isHerding = false,
            isFollowing = false,
            isTrack = false,
            isHunting = false,
            isRetrieving = false,
            isRetrieved = false,
            --isGame = false,
            -- isDefensive = false,
            -- isInCombat = false,
            -- isCombat = false,
            -- isFight = false,
            isCritical = false,
            isSterilization = false,
            isHasDisease = false,
            isVaccine = false,
            isBreeding = false
        },
        lastAction = nil,
        timers = {
            recentlyCombatTime = 0
        },
        visualState = {},
        historial = {},
        dataVersion = 1
    }
end

-- DISMISS PETS
---Dismiss all active pets
function State.DismissAllPets()
    for companionid, _ in pairs(State.GetAllPets()) do
        State.DismissPet(companionid)
    end
end

---Dismiss a specific pet
---@param companionid string
function State.DismissPet(companionid)
    local pet = State.GetPet(companionid)
    if not pet then
        return
    end

    -- Esto previene memory leaks cuando la mascota se despawnea
    State.CancelPetThreads(companionid)

    pet.spawned = false

    -- Detener wandering si aplica
    if (Config.Wandering and Config.Wandering.Enabled) then
        pcall(function()
            -- exports['hdrp-pets']:StopPetWandering(tostring(companionid))
            StopPetWandering(tostring(companionid))
        end)
    end

    -- Limpiar prompts y otros subcampos si aplica
    for k, _ in pairs(pet.flag) do
        pet.flag[k] = false
    end

    for k, _ in pairs(pet.visualState) do
        pet.visualState[k] = nil
    end

    for k, _ in pairs(pet.timers) do
        pet.timers[k] = nil
    end

    -- Eliminar entidad y blip
    if pet.ped and DoesEntityExist(pet.ped) then
        SetEntityAsNoLongerNeeded(pet.ped)
        DeleteEntity(pet.ped)
    end
    if pet.blip and DoesBlipExist(pet.blip) then
        RemoveBlip(pet.blip)
    end

    State.CleanupPetPrompts(companionid)
    State.CleanupPetThreads(companionid)
    -- ...otros helpers de limpieza individual...

    State.Pets[companionid] = nil
end

------------------------------------------
-- DISTANCE CHECKING
------------------------------------------
---Get closest pet to player
---@return table|nil, number, string|nil pet data, distance, companionid
function State.GetClosestPet()
    local data = nil
    local closestDist = 999999
    local closestId = nil

    for companionid, v in pairs(State.GetAllPets()) do
        if v and v.spawned and DoesEntityExist(v.ped) then
            local dist = State.GetDistancePlayerToPet(companionid)
            if dist < closestDist then
                closestDist = dist
                data = v or {}
                closestId = companionid or nil
            end
        end
    end
    
    return data, closestDist, closestId
end

---Get distance to pet
---@param companionid string
---@return number distance in meters
function State.GetDistancePlayerToPet(companionid)
    local pet = State.GetPet(companionid)
    if not pet or not DoesEntityExist(pet.ped) then return 999999 end
    
    local playerCoords = GetEntityCoords(cache.ped)
    local petCoords = GetEntityCoords(pet.ped)
    return #(playerCoords - petCoords)
end

------------------------------------------
-- COUNT FUNCTIONS
------------------------------------------
--- Get total number of active pets/spawned pets
---@return number
function State.GetActivePetCount()
    local count = 0
    for companionid, v in pairs(State.GetAllPets()) do
        if v and v.spawned and DoesEntityExist(v.ped) then
            count = count + 1
        end
    end
    return count
end

------------------------------------------
-- CLEANUP FUNCTIONS
------------------------------------------
---Full cleanup on resource stop
function State.Cleanup()
    State.CleanupAllPetPrompts()    -- Cleanup prompts

    State.DismissAllPets()          -- Dismiss all pets
end

-- ITEMS
-- PROMPTS
-- Limpia los prompts inactivos de todas las mascotas activas
function State.CleanupAllPetPrompts()
    for companionid, _ in pairs(State.GetAllPets()) do
        State.CleanupPetPrompts(companionid)
    end
end

-- Helper functions for managing pet state
---@param companionid string
function State.CleanupPetPrompts(companionid)
    local pet = State.GetPet(companionid)
    if not pet or not pet.prompts then return end
    for k, prompt in pairs(pet.prompts) do
        if prompt and type(prompt) == 'number' and not IsPromptActive(prompt) then
            pet.prompts[k] = nil
        end
    end
end

-- Asigna un prompt a una mascota específica
---@param companionid string
---@param promptType string
---@param promptHandle number
function State.SetPetPrompt(companionid, promptType, promptHandle)
    local pet = State.GetPet(companionid)
    if not pet then return end
    pet.prompts = pet.prompts or {}
    pet.prompts[promptType] = promptHandle
end

-- Obtiene el handle de un prompt de una mascota
---@param companionid string
---@param promptType string
---@return number|nil prompt handle
function State.GetPetPrompt(companionid, promptType)
    local pet = State.GetPet(companionid)
    if not pet or not pet.prompts then return nil end
    return pet.prompts[promptType]
end

------------------------------------------
-- XP AND LEVELING
------------------------------------------
---Get pet level based on XP
---@param xp number
---@return number level
function State.GetPetLevel(xp)
    if not Config.PetAttributes or not Config.PetAttributes.levelAttributes then
        return 1
    end
    
    for i, level in ipairs(Config.PetAttributes.levelAttributes) do
        if xp >= level.xpMin and xp <= level.xpMax then
            return i
        end
    end
    return #Config.PetAttributes.levelAttributes
end

-- Actualiza los niveles de vinculación de todas las mascotas activas
-- Sin usar de momento
function State.GetBondingLevels()
    for companionid, v in pairs(State.GetAllPets()) do
        if v and DoesEntityExist(v.ped) then
            local maxBonding = GetMaxAttributePoints(v.ped, 7)
            local currentBonding = GetAttributePoints(v.ped, 7)
            local thirdBonding = maxBonding / 3
            local bondingLevel = 1

            if currentBonding >= maxBonding then bondingLevel = 4 end
            if currentBonding >= thirdBonding and thirdBonding * 2 > currentBonding then bondingLevel = 2 end
            if currentBonding >= thirdBonding * 2 and maxBonding > currentBonding then bondingLevel = 3 end
            if thirdBonding > currentBonding then bondingLevel = 1 end
            -- v.data.progression.bonding = bondingLevel
            State.Pets[companionid].data.progression.bonding = bondingLevel
            TriggerServerEvent('hdrp-pets:server:updateanimals', companionid, v.data)
        end
    end
end

------------------------------------------
-- CONTROL ENTITY
------------------------------------------
---Request control of an entity
---@param entity number
function State.RequestControl(entity)
    local type = GetEntityType(entity)
    if type < 1 or type > 3 then return end
    NetworkRequestControlOfEntity(entity)
end

---Wait for control of an entity
---@param entity number
function State.GetControlOfEntity(entity)
    if not DoesEntityExist(entity) then return false end
    NetworkRequestControlOfEntity(entity)
    SetEntityAsMissionEntity(entity, true, true)
    local timeout = 2000
    while timeout > 0 and not NetworkHasControlOfEntity(entity) do 
        Wait(100)
        timeout = timeout - 100
    end
    return NetworkHasControlOfEntity(entity)
end

------------------------------------------
-- ANIMATION HELPERS
------------------------------------------
---Play animation on pet
---@param companionid string
---@param dict string
---@param anim string
---@param freeze boolean
---@param time number
function State.PlayPetAnimation(companionid, dict, anim, freeze, time)
    local pet = State.GetPet(companionid)
    if not pet or not pet.ped then return end
    if not lib.requestAnimDict(dict, 5000) then return end
    ClearPedTasks(pet.ped)
    TaskPlayAnim(pet.ped, dict, anim, 1.0, 1.0, time or -1, 1, 0, false, false, false)
    if freeze then
        FreezeEntityPosition(pet.ped, true)
        State.SetPetTrait(companionid, 'isFrozen', true)
    end
    pet.visualState = { dict = dict, anim = anim, freeze = freeze }
end

---Clear pet animation
---@param companionid string
function State.ClearPetAnimation(companionid)
    local pet = State.GetPet(companionid)
    if not pet or not pet.ped then return end
    FreezeEntityPosition(pet.ped, false)
    ClearPedTasks(pet.ped)
    State.SetPetTrait(companionid, 'isFrozen', false)
    pet.visualState = {}
end

------------------------------------------
-- FLAGS ENTITY
------------------------------------------
-- Freeze player
---@param unfreeze boolean
function State.ResetPlayerState(unfreeze)
    if unfreeze then
        FreezeEntityPosition(cache.ped, false)
    end
    ClearPedTasks(cache.ped)
end

---Unfreeze pet entity
---@param entity number
function State.petUnfreeze(entity)
    if DoesEntityExist(entity) then
        FreezeEntityPosition(entity, false)
        ClearPedTasksImmediately(entity)
        local petData, companionid = State.GetPetByEntity(entity)
        if petData and companionid then
            State.SetPetTrait(companionid, 'isFrozen', false)
        end
    end
end

-- Definimos qué flags pertenecen a qué categoría.
-- Al activar una flag de un grupo, SOLO se desactivan las de ese mismo grupo.
local ModeGroups = {
    -- Grupo 1: Movimiento Base (Solo uno activo a la vez)
    Movement = {
        'isWandering',
        'isHerding',
        'isFollowing',
        'isHunting',
        'isCritical',
        'isHasDisease',
        -- 'isFrozen' -- ya tiene su propia lógica aparte
    },
    -- NOTA: 'isSterilization' y 'isVaccine' no están aquí porque deberían ser permanentes.
}

---Función interna para gestionar el cambio de flags
local function SetFlagGroup(companionid, groupName, activeMode)
    local petData = State.Pets[companionid]
    if not petData or not petData.flag then return end
    
    local group = ModeGroups[groupName]
    if not group then return end

    -- 1. Desactivar todas las flags de ESTE grupo específico
    for _, flagName in ipairs(group) do
        petData.flag[flagName] = false
    end

    -- 2. Activar la flag solicitada (si existe en la lista o si se pasa explícitamente)
    -- Asumimos que el input 'activeMode' es el nombre exacto de la flag (ej: 'isWandering')
    -- O puedes hacer un mapeo string -> flag si prefieres inputs cortos como 'wandering'.
    if activeMode then
        petData.flag[activeMode] = true
    end
end

---Setea el movimiento. No afecta al combate ni a la salud.
---@param mode string 'isWandering', 'isFollowing', 'isHerding', 'isFrozen'
function State.SetPetMovement(companionid, mode)
    SetFlagGroup(companionid, "Movement", mode)
end

---Para rasgos permanentes (Toggle simple)
function State.SetPetTrait(companionid, trait, isActive)
    local flags = State.Pets[companionid] and State.Pets[companionid].flag
    if flags then
        -- Ejemplo traits: 'isSterilization', 'isVaccine', 'isBreeding'
        flags[trait] = isActive
    end
end

------------------------------------------
-- EVENT HANDLERS
------------------------------------------
-- 
--[[ RegisterNetEvent('hdrp-pets:client:updateanimals', function()
    for companionid, newData in pairs(State.GetAllPets()) do
        local pet = State.GetPet(companionid)
    end
end) ]]
RegisterNetEvent('hdrp-pets:client:tradeCompleted')
AddEventHandler('hdrp-pets:client:tradeCompleted', function()
    -- Refrescar lista de mascotas del jugador
    TriggerServerEvent('hdrp-pets:server:requestCompanions')
    
    lib.notify({ 
        title = locale('cl_trade_completed') or 'Trade completed', 
        type = 'success',
        duration = 5000
    })
end)

RegisterNetEvent('hdrp-pets:client:updateanimals', function(id, newData)
    if State.Pets[id] then
        State.Pets[id].data = newData
    end
end)

-- Cleanup cada 5 min
CreateThread(function()
    while true do
        Wait(300000) -- 5 min
        State.CleanupAllPetPrompts()
    end
end)
------------------------------------------
-- EXPORTS
------------------------------------------

exports('GetState', function()
    return State
end)

exports('GetActivePets', function()
    return State.GetAllPets()
end)

exports('GetPetById', function(companionid)
    return State.GetPet(companionid)
end)

exports('GetPetByEntity', function(entity)
    return State.GetPetByEntity(entity)
end)

exports('RegisterPet', function(companionid, ped, blip, data)
    State.RegisterPet(companionid, ped, blip, data)
end)

exports('GetActivePetCount', function()
    return State.GetActivePetCount()
end)

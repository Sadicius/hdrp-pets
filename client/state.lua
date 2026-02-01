
------------------------------------------
-- GLOBAL STATE TABLE
------------------------------------------
State = {} -- Estados globales
State.Pets      = {} -- Mascotas activas

-- THREAD CONTROL SYSTEM (Previene memory leaks)
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

---Verifica si un thread de mascota debe continuar ejecutándose
---@param companionid string
---@return boolean shouldContinue
function State.ShouldThreadContinue(companionid)
    if not companionid then return false end
    local pet = State.Pets[companionid]
    return pet ~= nil and pet.spawned == true and pet.ped ~= nil and DoesEntityExist(pet.ped)
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
    if not pet then return end

    pet.spawned = false

    if (Config.Wandering and Config.Wandering.Enabled) then
        pcall(function()
            StopPetWandering(tostring(companionid))
        end)
    end

    pet.flag = {}
    pet.visualState = {}
    pet.timers = {}

    if pet.ped and DoesEntityExist(pet.ped) then
        SetEntityAsMissionEntity(pet.ped, true, true)
        DeleteEntity(pet.ped)
        SetEntityAsNoLongerNeeded(pet.ped)
    end
    if pet.blip and DoesBlipExist(pet.blip) then
        RemoveBlip(pet.blip)
    end

    State.Pets[companionid] = nil
end

-- DISTANCE CHECKING
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

---Get distance between two entities
---@param ent1 number
---@param ent2 number
---@return number distance in meters
function State.GetDistanceBetweenEntities(ent1, ent2)
    if not ent1 or not ent2 or not DoesEntityExist(ent1) or not DoesEntityExist(ent2) then return 999999 end
    local coords1 = GetEntityCoords(ent1)
    local coords2 = GetEntityCoords(ent2)
    return #(coords1 - coords2)
end

---Check if pet is near player
---@param pet table
---@param maxDistance number
---@return boolean
function State.IsPetNearPlayer(pet, maxDistance)
    if not pet or not pet.ped or not DoesEntityExist(pet.ped) then return false end
    local dist = State.GetDistanceBetweenEntities(pet.ped, cache.ped)
    return dist <= (maxDistance or 10.0)
end

---Get position in front of an entity
---@param entity number
---@param distance number
---@return vector3
function State.GetPositionInFrontOfEntity(entity, distance)
    if not entity or not DoesEntityExist(entity) then return GetEntityCoords(entity) end
    local heading = GetEntityHeading(entity)
    local radians = math.rad(heading)
    local offsetX = -distance * math.sin(radians)
    local offsetY = distance * math.cos(radians)
    local coords = GetEntityCoords(entity)
    return vector3(coords.x - offsetX, coords.y - offsetY, coords.z - 1.0)
end

-- COUNT FUNCTIONS
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

-- XP AND LEVELING
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
function State.GetBondingLevels(entity, companionid)
    if entity and DoesEntityExist(entity) then
        local maxBonding = GetMaxAttributePoints(entity, 7)
        local currentBonding = GetAttributePoints(entity, 7)
        local thirdBonding = maxBonding / 3
        local bondingLevel = 1

        if currentBonding >= maxBonding then bondingLevel = 4 end
        if currentBonding >= thirdBonding and thirdBonding * 2 > currentBonding then bondingLevel = 2 end
        if currentBonding >= thirdBonding * 2 and maxBonding > currentBonding then bondingLevel = 3 end
        if thirdBonding > currentBonding then bondingLevel = 1 end
        -- v.data.progression.bonding = bondingLevel
        State.Pets[companionid].data.progression.bonding = bondingLevel
        TriggerServerEvent('hdrp-pets:server:updateanimals', companionid, State.Pets[companionid].data)
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

---Para rasgos permanentes (Toggle simple)
function State.SetPetTrait(companionid, trait, isActive)
    local flags = State.Pets[companionid] and State.Pets[companionid].flag
    if flags then
        -- Ejemplo traits: 'isSterilization', 'isVaccine', 'isBreeding'
        flags[trait] = isActive
    end
end

function State.GetFlag(pet, flag)
    return pet and pet.flag and pet.flag[flag]
end

function State.SetMode(companionid, mode)
    local pet = State.GetPet(companionid)
    if not pet or not pet.flag then return end
    for _, flag in ipairs({"isFollowing", "isHerding", "isWandering", "isHunting"}) do
        pet.flag[flag] = (flag == mode)
    end
end
------------------------------------------
-- EVENT HANDLERS
------------------------------------------
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

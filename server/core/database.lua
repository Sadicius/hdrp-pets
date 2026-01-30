

local RSGCore = exports['rsg-core']:GetCoreObject()
local Database = {}
lib.locale()

-- COMPANION QUERIES

---Get all companions for a player
---@param citizenid string
---@return table|nil companions
function Database.GetAllCompanions(citizenid)
    if not citizenid then return nil end
    
    local success, companions = pcall(
        MySQL.query.await,
        'SELECT * FROM pet_companion WHERE citizenid = ?',
        {citizenid}
    )
    
    if success and companions and companions[1] then
        return companions
    end
    
    return nil
end

---Get active companion(s) for a player
---@param citizenid string
---@return table|nil
function Database.GetAllCompanionsActive(citizenid)
    if not citizenid then return nil end
    
    local limit = Config.MaxActivePets or 1
    
    local success, result = pcall(
        MySQL.query.await,
        'SELECT * FROM pet_companion WHERE citizenid = ? AND active = 1 LIMIT ?',
        {citizenid, limit}
    )
    
    if not success or not result or #result == 0 then
        return {}
    end
    return result
end

---Check if pet name exists for a player (case-insensitive)
---@param citizenid string
---@param name string
---@return boolean exists
function Database.PetNameExists(citizenid, name)
    if not citizenid or not name then return false end
    local success, result = pcall(
        MySQL.scalar.await,
        'SELECT COUNT(*) FROM pet_companion WHERE citizenid = ? AND LOWER(JSON_UNQUOTE(JSON_EXTRACT(data, "$.name"))) = LOWER(?)',
        {citizenid, name}
    )
    if not success then
        if Config.Debug then print('^1[DATABASE ERROR]^7 Failed to check pet name existence for ' .. citizenid .. ' name: ' .. tostring(name)) end
        return false
    end
    return result and tonumber(result) > 0
end

---Get companion by ID
---@param id string
---@return table|nil
function Database.GetCompanionById(id)
    if not id then return nil end
    
    local success, result = pcall(
        MySQL.query.await,
        'SELECT * FROM pet_companion WHERE id = ?',
        {id}
    )
    if Config.Debug then print('^3[DATABASE] GetCompanionById called with ID: ' .. tostring(id) .. '^7') end

    if success and result and result[1] then
        return result[1]
    end
    
    return nil
end

---Get companion by companionid
---@param companionid string
---@return table|nil
function Database.GetCompanionByCompanionId(companionid)
    if not companionid then return nil end
    local success, result = pcall(
        MySQL.query.await,
        'SELECT * FROM pet_companion WHERE companionid = ?',
        {companionid}
    )
    if Config.Debug then print('^3[DATABASE] GetCompanionByCompanionId called with companionid: ' .. tostring(companionid) .. '^7') end
    if success and result and result[1] then
        return result[1]
    end
    return nil
end

---Count active companions for a player
---@param citizenid string
---@return number count
function Database.CountActiveCompanions(citizenid)
    if not citizenid then return 0 end
    
    local success, result = pcall(
        MySQL.scalar.await,
        'SELECT COUNT(*) FROM pet_companion WHERE citizenid = ? AND active = 1',
        {citizenid}
    )
    
    if not success then
        if Config.Debug then
            if Config.Debug then print('^1[DATABASE ERROR]^7 Failed to count active companions for ' .. citizenid) end
        end
        return 0
    end
    
    return result and tonumber(result) or 0
end

---Activate a companion
---@param companionid string
---@param citizenid string
---@return boolean success
function Database.ActivateCompanion(companionid, citizenid)
    if not companionid or not citizenid then return false end
    
    local success, result = pcall(
        MySQL.update.await,
        'UPDATE pet_companion SET active = ? WHERE companionid = ? AND citizenid = ?',
        {true, companionid, citizenid}
    )
    
    return success and result > 0
end

---Activate companion with race condition protection (atomic operation)
---FIX: Uses transaction to prevent multiple simultaneous activations exceeding limit
---@param id 
---@param citizenid string
---@param maxPets number Maximum allowed active pets
---@return boolean success, string|nil error
function Database.ActivateCompanionAtomic(companionId, citizenid, maxPets)
    if not companionId or not citizenid then return false, "Invalid parameters" end
    if Config.Debug then print('^3[DATABASE] Attempting to activate companion ID ' .. tostring(companionId) .. ' for citizenid ' .. tostring(citizenid) .. '^7') end
    -- Atomic operation using MySQL transaction
    -- This prevents race condition when multiple requests come simultaneously
    local success, result = pcall(function()
        -- Use UPDATE with subquery to check count atomically
        local affected = MySQL.update.await([[
            UPDATE pet_companion 
            SET active = 1 
            WHERE companionid = ? 
            AND citizenid = ? 
            AND (SELECT COUNT(*) FROM pet_companion WHERE citizenid = ? AND active = 1) < ?
        ]], {companionId, citizenid, citizenid, maxPets})
        if Config.Debug then print('^3[DATABASE] Activation affected rows: ' .. tostring(affected) .. '^7') end
        return affected
    end)
    if Config.Debug then print('^3[DATABASE] Activation success: ' .. tostring(success) .. ', result: ' .. tostring(result) .. '^7') end
    if success and result and result > 0 then
        return true, nil
    elseif success and result == 0 then
        return false, "Max pets limit reached"
    else
        return false, "Database error"
    end
end

---Deactivate a companion and store in stable
---@param companionid string
---@param citizenid string
---@param stableid string Stable location
---@return boolean success
function Database.DeactivateCompanion(companionid, citizenid, stableid)
    if not companionid or not citizenid then return false end
    
    -- Si no se proporciona stableid, obtener el stable actual de la mascota
    if not stableid or stableid == nil then
        local companion = Database.GetCompanionByCompanionId(companionid)
        if companion and companion.stable then
            stableid = companion.stable
        else
            stableid = 'valentine' -- Fallback por defecto
        end
    end

    local success, result = pcall(
        MySQL.update.await,
        'UPDATE pet_companion SET active = ?, stable = ? WHERE companionid = ? AND citizenid = ?',
        {false, stableid, companionid, citizenid}
    )
    
    return success and result > 0
end

---Insert new companion
---@param data table Companion data
---@return boolean success, number|nil insertId
function Database.InsertCompanion(data)
    if not data or not data.citizenid or not data.companionid then
        return false, "Invalid data parameters"
    end
    
    if Config.Debug then print('^3[DATABASE] Inserting companion with data: stable=' .. tostring(data.stable) .. ', citizenid=' .. tostring(data.citizenid) .. ', companionid=' .. tostring(data.companionid) .. '^7') end
    
    -- First, check if table exists
    local tableCheck = pcall(function()
        return MySQL.scalar.await('SELECT 1 FROM pet_companion LIMIT 1')
    end)

    if not tableCheck then
        if Config.Debug then print('^1[DATABASE ERROR] Table pet_companion does not exist or is not accessible!^7') end
        return false, "Table does not exist"
    end

    if Config.Debug then print('^2[DATABASE] Table pet_companion exists and is accessible^7') end
    
    -- Convert boolean to tinyint (0/1)
    local activeValue = data.active and 1 or 0
    
    if Config.Debug then print('^3[DATABASE] Executing INSERT query...^7') end
    local result, errorMsg = MySQL.insert.await(
        'INSERT INTO pet_companion(stable, citizenid, companionid, data, active) VALUES(?, ?, ?, ?, ?)',
        {
            data.stable or 'valentine',
            data.citizenid,
            data.companionid,
            data.data or '{}',
            activeValue
        }
    )
    
    if not result then
        if Config.Debug then
            print('^1[DATABASE ERROR] MySQL insert failed!^7')
            print('^1[DATABASE ERROR] Error message: ' .. tostring(errorMsg) .. '^7')
            print('^1[DATABASE ERROR] Data attempted: stable=' .. tostring(data.stable) .. ', citizenid=' .. tostring(data.citizenid) .. ', companionid=' .. tostring(data.companionid) .. ', active=' .. tostring(activeValue) .. '^7')
        end
        return false, tostring(errorMsg)
    end
    
    if result == 0 then
        if Config.Debug then print('^1[DATABASE ERROR] Insert returned 0 (no rows affected)^7') end
        return false, "Insert returned no ID"
    end
    
    if Config.Debug then print('^2[DATABASE] Companion inserted successfully. Insert ID: ' .. tostring(result) .. '^7') end
    
    return true, result
end

-- ================================================
-- COMPANION UPDATE QUERIES
-- ================================================

---Update companion achievements
---@param companionid string
---@param achievements table
---@return boolean success
function Database.UpdateCompanionAchievements(companionid, achievements)
    if not companionid or not achievements then return false end
    
    local success, result = pcall(
        MySQL.update.await,
        'UPDATE pet_companion SET achievements = ? WHERE companionid = ?',
        {json.encode(achievements), companionid}
    )

    return success and result ~= nil
end

---Update companion data
---@param companionid string
---@param data table
---@return boolean success
function Database.UpdateCompanionData(companionid, data)
    if not companionid or not data then return false end
    
    local success, result = pcall(
        MySQL.update.await,
        'UPDATE pet_companion SET data = ? WHERE companionid = ?',
        {json.encode(data), companionid}
    )
    
    return success and result ~= nil
end

-- ================================================
-- COMPANION INSERT/DELETE QUERIES
-- ================================================

---Note: InsertCompanion is defined earlier to accept a data table payload.
---The older param-based variant has been removed to avoid overriding the table-based API
---used by server/main.lua. This prevents nil results when passing a single table.

---Delete companion
---@param companionid string
---@return boolean success
function Database.DeleteCompanion(companionid)
    if not companionid then return false end
    
    local success, affectedRows = pcall(
        MySQL.update.await,
        'DELETE FROM pet_companion WHERE companionid = ?',
        {companionid}
    )
    
    if success and affectedRows and affectedRows > 0 then
        return true
    end
    return false
end

-- ================================================
-- COMPANION ID GENERATION
-- ================================================
---Generate unique companion ID
---@return string|nil companionid
function Database.GenerateCompanionId()
    local UniqueFound = false
    local companionid = nil
    
    while not UniqueFound do
        companionid = tostring(RSGCore.Shared.RandomStr(3) .. RSGCore.Shared.RandomInt(3)):upper()
        
        local success, result = pcall(
            MySQL.prepare.await,
            'SELECT COUNT(*) AS count FROM pet_companion WHERE companionid = ?',
            {companionid}
        )
    
        if success and result and tonumber(result) == 0 then
            UniqueFound = true
        else
            if not success then
                break
            end
        end
        
    end
    
    return companionid
end

-- ================================================
-- BULK OPERATIONS
-- ================================================
---Get all active companions (for decay system)
---@return table|nil companions
function Database.GetAllActiveCompanions()
    local success, companions = pcall(
        MySQL.query.await,
        'SELECT * FROM pet_companion WHERE active = 1'
    )
    
    if not success then
        if Config.Debug then
            print('^1[DATABASE ERROR]^7 Failed to fetch all active companions')
        end
        return {}
    end

    if companions then
        return companions
    end

    return {}
end

function Database.GetAllCompanionsForRanking()
    local success, result = pcall(MySQL.query.await, 
        'SELECT companionid, achievements FROM pet_companion WHERE achievements IS NOT NULL'
    )
    if success and result then
        return result
    end
    return {}
end

-- ================================================
-- PET_BREEDING QUERIES (historial y genealogía por jugador)
-- ================================================

---Get genealogy for a specific offspring from pet_breeding table
---Busca en el campo 'offspring' del registro de breeding del dueño
---@param offspring_id string - companionid de la mascota
---@return table|nil genealogy {offspring_id, parent_a_id, parent_b_id, parent_a_data, parent_b_data}
function Database.GetGenealogyByOffspringId(offspring_id)
    if not offspring_id then return nil end

    -- Obtener la mascota para saber su dueño
    local companion = Database.GetCompanionByCompanionId(offspring_id)
    if not companion then return nil end

    local citizenid = companion.citizenid
    local record = Database.GetOrCreateBreedingRecord(citizenid)
    if not record then return nil end

    local offspringList = record.offspring and json.decode(record.offspring) or {}

    -- Buscar en la lista de offspring
    for _, entry in ipairs(offspringList) do
        if entry.petid == offspring_id or entry.companionid == offspring_id then
            return {
                offspring_id = offspring_id,
                parent_a_id = entry.parent_a,
                parent_b_id = entry.parent_b,
                parent_a_data = entry.parent_a_data and json.encode(entry.parent_a_data) or nil,
                parent_b_data = entry.parent_b_data and json.encode(entry.parent_b_data) or nil,
                date = entry.date
            }
        end
    end

    return nil
end

---Add offspring with genealogy data to pet_breeding
---@param citizenid string
---@param offspringData table {petid/companionid, parent_a, parent_b, parent_a_data, parent_b_data, date}
---@return boolean success
function Database.AddOffspringGenealogy(citizenid, offspringData)
    if not citizenid or not offspringData then return false end

    local record = Database.GetOrCreateBreedingRecord(citizenid)
    if not record then return false end

    local offspringList = record.offspring and json.decode(record.offspring) or {}
    table.insert(offspringList, offspringData)

    local success = pcall(function()
        MySQL.update.await('UPDATE pet_breeding SET offspring = ? WHERE citizenid = ?',
            {json.encode(offspringList), citizenid})
    end)

    if Config.Debug and success then
        print('^2[DATABASE] Offspring genealogy added for ' .. (offspringData.petid or offspringData.companionid) .. '^7')
    end

    return success
end

---Get or create breeding record for a player
---@param citizenid string
---@return table breedingData
function Database.GetOrCreateBreedingRecord(citizenid)
    if not citizenid then return nil end
    local success, result = pcall(
        MySQL.query.await,
        'SELECT * FROM pet_breeding WHERE citizenid = ? LIMIT 1',
        {citizenid}
    )
    if success and result and result[1] then
        return result[1]
    else
        -- Crear registro vacío si no existe
        local insertSuccess, insertId = pcall(function()
            return MySQL.insert.await('INSERT INTO pet_breeding (citizenid, history, parents, offspring, cooldown, last_breeding) VALUES (?, ?, ?, ?, ?, ?)',
                {citizenid, '[]', '[]', '[]', 0, 0})
        end)
        if insertSuccess and insertId then
            Database.GetOrCreateBreedingRecord(citizenid)
            return
        end
    end
    return nil
end

---Add breeding event to history
---@param citizenid string
---@param event table {date, action, petA, petB, offspring, notes}
---@return boolean success
function Database.AddBreedingEvent(citizenid, event)
    if not citizenid or not event then return false end
    local record = Database.GetOrCreateBreedingRecord(citizenid)
    if not record then return false end
    local history = record.history and json.decode(record.history) or {}
    table.insert(history, event)
    local success = pcall(function()
        MySQL.update.await('UPDATE pet_breeding SET history = ?, last_breeding = ? WHERE citizenid = ?',
            {json.encode(history), event.date or os.time(), citizenid})
    end)
    return success
end

---Update parents and offspring info
---@param citizenid string
---@param parents table
---@param offspring table
---@return boolean success
function Database.UpdateBreedingParentsOffspring(citizenid, parents, offspring)
    if not citizenid then return false end
    local success = pcall(function()
        MySQL.update.await('UPDATE pet_breeding SET parents = ?, offspring = ? WHERE citizenid = ?',
            {json.encode(parents or {}), json.encode(offspring or {}), citizenid})
    end)
    return success
end

---Get breeding history for a player
---@param citizenid string
---@return table history
function Database.GetBreedingHistory(citizenid)
    if not citizenid then return {} end
    local record = Database.GetOrCreateBreedingRecord(citizenid)
    if not record then return {} end
    return record.history and json.decode(record.history) or {}
end

---Get all offspring for a player
---@param citizenid string
---@return table offspring
function Database.GetBreedingOffspring(citizenid)
    if not citizenid then return {} end
    local record = Database.GetOrCreateBreedingRecord(citizenid)
    if not record then return {} end
    return record.offspring and json.decode(record.offspring) or {}
end

---Get all parents for a player
---@param citizenid string
---@return table parents
function Database.GetBreedingParents(citizenid)
    if not citizenid then return {} end
    local record = Database.GetOrCreateBreedingRecord(citizenid)
    if not record then return {} end
    return record.parents and json.decode(record.parents) or {}
end

return Database

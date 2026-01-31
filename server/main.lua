local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local Database = lib.load('server.core.database')
local PetShopPrice = Config.PetShopPrice


-- ========================================
-- P0 FIX: UPDATE QUEUE SYSTEM
-- Prevents race conditions and reduces DB load
-- ========================================
local updateQueue = {
    health = {}, -- {[companionid] = {health, citizenid, timestamp}}
    dirt = {}    -- {[companionid] = {dirt, citizenid, timestamp}}
}
 
local QUEUE_FLUSH_INTERVAL = 10000 -- 10 seconds
 
-- Flush queue thread
CreateThread(function()
    while true do
        Wait(QUEUE_FLUSH_INTERVAL)
 
        local healthUpdates = {}
        local dirtUpdates = {}
        local totalUpdates = 0
 
        -- Collect health updates
        for companionid, data in pairs(updateQueue.health) do
            totalUpdates = totalUpdates + 1
            table.insert(healthUpdates, {
                companionid = companionid,
                health = data.health,
                citizenid = data.citizenid
            })
        end
 
        -- Collect dirt updates
        for companionid, data in pairs(updateQueue.dirt) do
            if not updateQueue.health[companionid] then -- Avoid duplicate processing
                totalUpdates = totalUpdates + 1
            end
            table.insert(dirtUpdates, {
                companionid = companionid,
                dirt = data.dirt,
                citizenid = data.citizenid
            })
        end
 
        -- Process batch if there are updates
        if totalUpdates > 0 then
            if Config.Debug then
                print(string.format('^2[UPDATE QUEUE]^7 Flushing %d updates (%d health, %d dirt)',
                    totalUpdates, #healthUpdates, #dirtUpdates))
            end
 
            -- Merge updates: if pet has both health and dirt updates, combine them
            local mergedUpdates = {}
            local processedIds = {}
 
            for _, update in ipairs(healthUpdates) do
                local dirtData = updateQueue.dirt[update.companionid]
 
                -- Fetch current data
                local success, result = pcall(MySQL.query.await,
                    'SELECT data FROM pet_companion WHERE companionid = ? AND citizenid = ?',
                    {update.companionid, update.citizenid})
 
                if success and result and result[1] then
                    local currentData = json.decode(result[1].data)
                    currentData.stats.health = update.health
 
                    -- Merge dirt if exists
                    if dirtData then
                        currentData.stats.dirt = dirtData.dirt
                        processedIds[update.companionid] = true
                    end
 
                    table.insert(mergedUpdates, {
                        companionid = update.companionid,
                        data = currentData
                    })
                end
            end
 
            -- Process dirt-only updates
            for _, update in ipairs(dirtUpdates) do
                if not processedIds[update.companionid] then
                    local success, result = pcall(MySQL.query.await,
                        'SELECT data FROM pet_companion WHERE companionid = ? AND citizenid = ?',
                        {update.companionid, update.citizenid})
 
                    if success and result and result[1] then
                        local currentData = json.decode(result[1].data)
                        currentData.stats.dirt = update.dirt
 
                        table.insert(mergedUpdates, {
                            companionid = update.companionid,
                            data = currentData
                        })
                    end
                end
            end
 
            -- Execute batch update
            if #mergedUpdates > 0 then
                local batchSuccess, affectedRows = Database.BatchUpdateCompanions(mergedUpdates)
                if batchSuccess then
                    if Config.Debug then
                        print(string.format('^2[UPDATE QUEUE]^7 Batch update successful: %d rows affected', affectedRows or #mergedUpdates))
                    end
                else
                    -- Fallback to individual updates
                    for _, update in ipairs(mergedUpdates) do
                        pcall(Database.UpdateCompanionData, update.companionid, update.data)
                    end
                end
            end
 
            -- Clear queues
            updateQueue.health = {}
            updateQueue.dirt = {}
        end
    end
end)

----------------------------------
-- Buy & active
----------------------------------
-- PET NAME VALIDATION --Validate pet name (prevent injection and exploits)
---@param name string
---@return boolean isValid
---@return string|nil sanitizedName or errorMessage
local function PetName(name)
    if not name or type(name) ~= "string" then
        return false, locale('sv_validation_name_type')
    end
    
    -- Remove special characters (allow alphanumeric, spaces, hyphens, underscores)
    local sanitized = string.gsub(name, "[^%w%s%-_]", "")
    if #sanitized < 1 then
        return false, locale('sv_validation_name_short')
    end
    
    if #sanitized > 50 then
        return false, locale('sv_validation_name_long')
    end
    
    return true, sanitized
end

-- Callbacks moved to server/core/callbacks.lua
-- Using Database module for queries
RegisterServerEvent('hdrp-pets:server:buy', function(price, model, stable, companionname, gender, category)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    -- SECURITY: Validate pet name using Validation module
    local isValid, sanitizedName = PetName(companionname)
    if not isValid then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_error_invalid_name'), description = sanitizedName or locale('sv_error_invalid_name'), type = 'error', duration = 5000 })
        return
    end

    companionname = sanitizedName

    -- Verificar si el nombre ya existe para este jugador
    if Database.PetNameExists(Player.PlayerData.citizenid, companionname) then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_error_name_exists'), description = locale('sv_error_name_exists_desc') or 'Ya tienes una mascota con ese nombre.', type = 'error', duration = 5000 })
        return
    end

    -- Validate price and funds to avoid nil/invalid comparisons
    if not Validation.Price(price) then return end

    local cash = tonumber(Player.PlayerData.money and Player.PlayerData.money.cash) or 0
    if cash < price then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_error_no_cash'), type = 'error', duration = 5000 })
        return
    end

    local generatedId = Database.GenerateCompanionId()
    if not generatedId then
        return
    end
    local companionid = tostring(os.time()) .. generatedId

    -- Buscar el array de skins correcto según el modelo
    local skin = 0
    for _, pet in ipairs(PetShopPrice) do
        if pet.npcpetmodel == model and pet.skins and #pet.skins > 0 then
            skin = pet.skins[math.random(#pet.skins)]
            break
        end
    end

    local breedable = {true, false}
    local randomIndex1 = math.random(1, #breedable)

    -- VERSION PARA REFACTORIZAR A UNA ESTRUCTURA MÁS COMPLETA
    local datacomp = {
        id = companionid,                -- ID único de la mascota

        info = {
            -- stable  = stable or "valentine",    -- Localizacion del establo  -- duda aquí // merece la pena modificar por la columna stable
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
            dirt        = 100,        -- Suciedad (0-100)
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

            breedable               = breedable[randomIndex1],  -- Puede reproducirse. Se sustituye "No" por false,
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
        version= 1     -- VERSION de la estructura
    }

    local animaldata = json.encode(datacomp)

    if Config.Debug then print("^3[PET] Attempting to insert into database...^7") end
    if Config.Debug then print("^2[PET] Generated companion data for " .. companionid .. ": " .. json.encode(datacomp) .. "^7") end

    local success, result = Database.InsertCompanion({
        stable = stable, -- duda aquí // pensar si merece la pena modificar o no por data.info.stable
        citizenid   = Player.PlayerData.citizenid,
        companionid = companionid,
        data        = animaldata,
        active      = false,
    }) 

    if not success then 
        return 
    end

    if Config.Debug then print("^2[PET] Successfully inserted companion into database. Insert ID: " .. tostring(result) .. "^7") end
    Player.Functions.RemoveMoney('cash', price)

    local discordMessage = string.format(
        locale('sv_log_user')..":** %s \n**"
        ..locale('debug_id')..":** %d \n**"
        ..locale('cl_input_setup_name')..":** %s %s \n**"
        ..locale('sv_log_breed')..":** %s \n**"
        ..locale('sv_log_age')..":** %s \n**"
        ..locale('sv_log_action')..":** %s \n**"
        ..locale('sv_log_value')..":** %.2f**",
        Player.PlayerData.citizenid,
        Player.PlayerData.cid,
        Player.PlayerData.charinfo.firstname,
        Player.PlayerData.charinfo.lastname,
        companionid,
        companionname,
        model,
        price
    )
    
    TriggerEvent('rsg-log:server:CreateLog', Config.WebhookName, Config.WebhookTitle, Config.WebhookColour, discordMessage, false)
    TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_success_pet_owned'), type = 'success', duration = 5000 })
end)

-- active
RegisterServerEvent('hdrp-pets:server:setactive', function(id)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    -- Buscar el registro por companionid para obtener el id numérico
    local companion = Database.GetCompanionByCompanionId(id)
    if not companion or not companion.id then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('cl_error_pet_not_found'), type = 'error', duration = 5000 })
        return
    end
    local breedcompanion = MySQL.scalar.await('SELECT id FROM pet_companion WHERE citizenid = ? AND data LIKE ?', {Player.PlayerData.citizenid, '%"inbreed":true%'})
    if breedcompanion then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_error_breed_duplicate'), type = 'error', duration = 5000 })
        return
    end

    -- SISTEMA MULTI-MASCOTA
    local maxPets = Config.MaxActivePets or 1
    local success, error = Database.ActivateCompanionAtomic(id, Player.PlayerData.citizenid, maxPets)
    if not success then
        if error == "Max pets limit reached" then
            local activeCount = Database.CountActiveCompanions(Player.PlayerData.citizenid)
            TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_error_pet_limit'), description = string.format(locale('sv_error_pet_limit_desc'), activeCount, maxPets), type = 'error', duration = 5000 })
        else
            TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_database_error'), type = 'error', duration = 5000 })
        end
        return
    end
end)

-- Desactivar mascota específica por companionid usando Database module -- store
RegisterServerEvent('hdrp-pets:server:store', function(companionId, stableid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if companionId then
        local success = Database.DeactivateCompanion(companionId, Player.PlayerData.citizenid, stableid)
        if success then
            TriggerClientEvent('ox_lib:notify', src, { title = locale('cl_success_pet_storing'), type = 'success', duration = 5000 })
            if Config.Debug then print(string.format("^2[MULTI-PET] Mascota %s desactivada y guardada en %s^7", companionId, stableid)) end
        else
            TriggerClientEvent('ox_lib:notify', src, { title = locale('cl_error_pet_not_found'), type = 'error', duration = 5000 })
        end
    end
end)

-- move pet between stables
RegisterServerEvent('hdrp-pets:server:movepet', function(petId, newStableId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid

    local pet = MySQL.query.await('SELECT * FROM pet_companion WHERE companionid = ? AND citizenid = ?', {petId, citizenid})
    if not pet or not pet[1] then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_error_not_own_pet'), type = 'error', duration = 5000 })
        return
    end

    -- verify stable exists and get coordinates
    local currentStable = nil
    local newStable = nil
    
    for _, stableConfig in pairs(Config.PetStables) do
        if stableConfig.stableid == pet[1].stable then
            currentStable = stableConfig
        end
        if stableConfig.stableid == newStableId then
            newStable = stableConfig
        end
    end

    if not newStable then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_error_invalid_stable'), type = 'error', duration = 5000 })
        return
    end

    -- check if pet is already at that stable
    if pet[1].stable == newStableId then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_error_pet_already_there'), type = 'error', duration = 5000 })
        return
    end

    -- calculate distance-based fee
    local baseFee = Config.MovePetBasePrice
    local feePerMeter = Config.MoveFeePerMeter
    local distance = 0
    
    if currentStable then
        distance = #(currentStable.coords - newStable.coords)
    end
    
    local moveFee = math.ceil(baseFee + (distance * feePerMeter))    -- Attempt to deduct fee
    if not Player.Functions.RemoveMoney('cash', moveFee) then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_error_insufficient_funds'), description = string.format('Cost: $%d', moveFee), type = 'error', duration = 5000 })
        return
    end

    -- Move pet to new stable
    MySQL.update('UPDATE pet_companion SET stable = ? WHERE companionid = ?', {newStableId, petId})
    TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_success_pet_moved'), description = string.format(locale('sv_success_pet_moved_desc'), pet[1].data.info.name, newStableId, moveFee), type = 'success', duration = 5000 })
end)

-- P0 FIX: Queue updates instead of immediate DB write
RegisterServerEvent('hdrp-pets:server:setdirt', function(companionid, dirt)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
 
    -- Verify ownership (lightweight check without fetching full data)
    local success, result = pcall(MySQL.scalar.await,
        'SELECT COUNT(*) FROM pet_companion WHERE companionid = ? AND citizenid = ? AND active = ?',
        {companionid, Player.PlayerData.citizenid, 1})
 
    if not success or not result or result == 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_error_no_active_pet'),
            type = 'error',
            duration = 5000
        })
        return
    end
 
    -- Queue update instead of immediate write
    updateQueue.dirt[companionid] = {
        dirt = tonumber(dirt) or 0,
        citizenid = Player.PlayerData.citizenid,
        timestamp = os.time()
    }
 
    if Config.Debug then
        print(string.format('^3[DIRT QUEUE]^7 Queued dirt update for %s: %d', companionid, tonumber(dirt) or 0))
    end
end)

-- P0 FIX: Queue updates instead of immediate DB write
RegisterServerEvent('hdrp-pets:server:updatehealth', function(companionid, healthPercent)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
 
    if not companionid or not healthPercent then return end
 
    -- Verify ownership (lightweight check)
    local success, result = pcall(MySQL.scalar.await,
        'SELECT COUNT(*) FROM pet_companion WHERE companionid = ? AND citizenid = ?',
        {companionid, Player.PlayerData.citizenid})
 
    if not success or not result or result == 0 then return end
 
    -- Clamp health value
    local clampedHealth = math.max(0, math.min(100, tonumber(healthPercent) or 100))
 
    -- Queue update instead of immediate write
    updateQueue.health[companionid] = {
        health = clampedHealth,
        citizenid = Player.PlayerData.citizenid,
        timestamp = os.time()
    }
 
    if Config.Debug then
        print(string.format('^2[HEALTH QUEUE]^7 Queued health update for %s: %d%%', companionid, clampedHealth))
    end
end)

-- Update companion data (bonding, stats, etc.)
RegisterServerEvent('hdrp-pets:server:updateanimals', function(companionid, data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if not companionid or not data then
        if Config.Debug then
            print('^1[UPDATEANIMALS ERROR]^7 Missing companionid or data from source:', src)
        end
        return
    end

    -- Verify ownership
    local ownerCheck = pcall(MySQL.query.await, 'SELECT id FROM pet_companion WHERE companionid = ? AND citizenid = ?', {companionid, Player.PlayerData.citizenid})
    if not ownerCheck then
        if Config.Debug then
            print('^1[UPDATEANIMALS ERROR]^7 Ownership verification failed for:', companionid)
        end
        return
    end

    -- Validate data structure and sanitize values
    local function validateAndSanitize(petData)
        if type(petData) ~= 'table' then return false, 'Invalid data type' end

        -- Validate and clamp stats (0-100 range)
        if petData.stats then
            if petData.stats.hunger then petData.stats.hunger = math.max(0, math.min(100, tonumber(petData.stats.hunger) or 100)) end
            if petData.stats.thirst then petData.stats.thirst = math.max(0, math.min(100, tonumber(petData.stats.thirst) or 100)) end
            if petData.stats.happiness then petData.stats.happiness = math.max(0, math.min(100, tonumber(petData.stats.happiness) or 100)) end
            if petData.stats.dirt then petData.stats.dirt = math.max(0, math.min(100, tonumber(petData.stats.dirt) or 100)) end
            if petData.stats.strength then petData.stats.strength = math.max(0, math.min(100, tonumber(petData.stats.strength) or 100)) end
            if petData.stats.health then petData.stats.health = math.max(0, math.min(100, tonumber(petData.stats.health) or 100)) end
            if petData.stats.age then petData.stats.age = math.max(0, tonumber(petData.stats.age) or 1) end
            if petData.stats.scale then petData.stats.scale = math.max(0.1, math.min(2.0, tonumber(petData.stats.scale) or 1.0)) end
        end

        -- Validate progression values
        if petData.progression then
            if petData.progression.xp then petData.progression.xp = math.max(0, tonumber(petData.progression.xp) or 0) end
            if petData.progression.level then petData.progression.level = math.max(1, tonumber(petData.progression.level) or 1) end
            if petData.progression.bonding then petData.progression.bonding = math.max(0, tonumber(petData.progression.bonding) or 0) end
        end

        -- Validate veterinary booleans
        if petData.veterinary then
            if petData.veterinary.dead ~= nil then petData.veterinary.dead = petData.veterinary.dead == true end
            if petData.veterinary.hasdisease ~= nil then petData.veterinary.hasdisease = petData.veterinary.hasdisease == true end
            if petData.veterinary.isvaccinated ~= nil then petData.veterinary.isvaccinated = petData.veterinary.isvaccinated == true end
            if petData.veterinary.breedable ~= nil then petData.veterinary.breedable = petData.veterinary.breedable == true end
            if petData.veterinary.inbreed ~= nil then petData.veterinary.inbreed = petData.veterinary.inbreed == true end
        end

        return true, petData
    end

    -- Validate and sanitize the data
    local isValid, validatedData = validateAndSanitize(data)
    if not isValid then
        if Config.Debug then
            print('^1[UPDATEANIMALS ERROR]^7 Data validation failed:', validatedData)
        end
        TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Failed to update pet data', type = 'error', duration = 3000 })
        return
    end

    -- Update companion data in database with error handling
    local updateSuccess, updateError = pcall(Database.UpdateCompanionData, companionid, validatedData)
    if not updateSuccess then
        if Config.Debug then
            print('^1[UPDATEANIMALS ERROR]^7 Database update failed:', updateError)
        end
        TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Failed to save pet data', type = 'error', duration = 3000 })
        return
    end

    -- Notify client of successful update
    TriggerClientEvent('hdrp-pets:client:refreshPetData', src, companionid, validatedData)

    if Config.Debug then
        print(string.format('^2[UPDATEANIMALS SUCCESS]^7 Updated pet %s for player %s', companionid, Player.PlayerData.citizenid))
    end
end)

-- Rename Companion
RegisterServerEvent('hdrp-pets:server:rename', function(companionid, name)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if not companionid or not name then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_error_name_change'), type = 'error', duration = 5000})
        return
    end

    -- Get specific companion by companionid and citizenid
    local success, result = pcall(MySQL.query.await, 'SELECT data FROM pet_companion WHERE citizenid = ? AND companionid = ?', {Player.PlayerData.citizenid, companionid})
    if not success or not result or #result == 0 then TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_error_no_active_pet'), type = 'error', duration = 5000})  return end
    
    local currentData = json.decode(result[1].data)
    local oldName = currentData.info.name or 'Unknown'
    currentData.info.name = name

    Database.UpdateCompanionData(companionid, currentData)
    
    local discordMessage = string.format(
        locale('sv_log_user')..":** %s \n**"
        ..locale('debug_id')..":** %d \n**"
        ..locale('cl_input_setup_name')..":** %s %s \n**"
        .."Companion ID:** %s \n**"
        .."Old Name:** %s \n**"
        .."New Name:** %s \n**",
        Player.PlayerData.citizenid,
        Player.PlayerData.cid,
        Player.PlayerData.charinfo.firstname,
        Player.PlayerData.charinfo.lastname,
        tostring(companionid),
        oldName,
        name
    )
    TriggerClientEvent('ox_lib:notify', src, {title = oldName .. ' → ' .. name, description = locale('sv_success_name_change'), type = 'success', duration = 5000 })
    TriggerEvent('rsg-log:server:CreateLog', Config.WebhookName, Config.WebhookTitle, Config.WebhookColour, discordMessage, false)
end)

-- companion inventory
RegisterNetEvent('hdrp-pets:server:openinventory', function(companionstash, invWeight, invSlots)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local data = {
        label = locale('sv_pet_inventory'),
        maxweight = invWeight,
        slots = invSlots
    }
    local stashName = companionstash
    exports['rsg-inventory']:OpenInventory(src, stashName, data)
end)

-- COMPANION DIED
RegisterNetEvent('hdrp-pets:server:setrip')
AddEventHandler('hdrp-pets:server:setrip', function(companionid) -- healt
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local success, result = pcall(MySQL.query.await, 'SELECT * FROM pet_companion WHERE citizenid = ? AND companionid = ? AND active = ?', {Player.PlayerData.citizenid, companionid, 1})
    if not success or not result or not result[1] then return end

    local currentData = json.decode(result[1].data)
    currentData.veterinary.dead = true

    if currentData.veterinary.dead == true then
        -- currentData.stats.health = 0
        currentData.stats.hunger = 0
        currentData.stats.thirst = 0
        currentData.stats.happiness = 0
        currentData.stats.strength = 0
        currentData.stats.dirt = tonumber(100)
    end

    Database.UpdateCompanionData(companionid, currentData)

    local discordMessage = string.format(
        locale('sv_log_user')..":** %s \n**"
        ..locale('debug_id')..":** %d \n**"
        ..locale('cl_input_setup_name')..":** %s %s \n**"
        ..locale('sv_log_info').."**",
        Player.PlayerData.citizenid,
        Player.PlayerData.cid,
        Player.PlayerData.charinfo.firstname,
        Player.PlayerData.charinfo.lastname
    )
    TriggerEvent('rsg-log:server:CreateLog', Config.WebhookName, Config.WebhookTitle, Config.WebhookColour, discordMessage, false)
end)
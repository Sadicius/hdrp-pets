
local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- LOAD CORE MODULES
local Validation = lib.load('server.core.validation')
local Database = lib.load('server.core.database')

-- CALLBACKS
-- Get All Companions
RSGCore.Functions.CreateCallback('hdrp-pets:server:getallcompanions', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then cb(nil) return end
    
    local success, companions = pcall(function()
        return Database.GetAllCompanions(Player.PlayerData.citizenid)
    end)
    
    if not success then
        if Config.Debug then print('^1[CALLBACK ERROR]^7 GetAllCompanions failed for ' .. source) end
        cb(nil)
        return
    end
    
    cb(companions)
end)

-- Get Specific Companion by ID (MULTI-PET SYSTEM)
RSGCore.Functions.CreateCallback('hdrp-pets:server:getcompanionbyid', function(source, cb, companionId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then cb(nil) return end
    
    if not companionId then
        if Config.Debug then print('^1[CALLBACK ERROR]^7 GetCompanionById called without companionId') end
        cb(nil)
        return
    end
    
    local success, result = pcall(function()
        return Database.GetCompanionById(companionId)
    end)
    
    if not success then
        if Config.Debug then print('^1[CALLBACK ERROR]^7 GetCompanionById failed for ' .. source .. ' (ID: ' .. tostring(companionId) .. ')') end
        cb(nil)
        return
    end
    
    cb(result)
end)

-- Get Companion
lib.callback.register('hdrp-pets:server:getcompanion', function(source, stable)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local companions = {}
    local success, Result = pcall(MySQL.query.await, 'SELECT * FROM pet_companion WHERE citizenid= ? AND stable= ?', { Player.PlayerData.citizenid, stable})
    if not success or not Result or #Result == 0 then return companions end

    for i = 1, #Result do
        companions[#companions + 1] = Result[i]
    end

    return companions
end)

-- Callback para activar mascota y devolver resultado inmediato
lib.callback.register('hdrp-pets:server:setactive', function(source, companionId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return {success = false, error = 'No player'} end

    -- Comprobar si hay mascota en cría
    local breedcompanion = MySQL.scalar.await('SELECT companionid FROM pet_companion WHERE citizenid = ? AND data LIKE ?', {Player.PlayerData.citizenid, '%"inbreed":true%'})
    if breedcompanion then
        return {success = false, error = 'breed_duplicate'}
    end

    local maxPets = Config.MaxActivePets or 1
    local success, error = Database.ActivateCompanionAtomic(companionId, Player.PlayerData.citizenid, maxPets)
    return {success = success, error = error}
end)

-- Get Active Companions (MULTI-PET SYSTEM)
RSGCore.Functions.CreateCallback('hdrp-pets:server:getactivecompanions', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then cb({}) return end
    
    local success, result = pcall(function()
        cb(Database.GetAllCompanionsActive(Player.PlayerData.citizenid))
        return 
    end)
    
    if not success then
        if Config.Debug then print('^1[CALLBACK ERROR]^7 GetActiveCompanions failed for ' .. source) end
        cb({})
        return
    end
    
    cb(result or {})
end)

-- Callback: obtener estado de reproducción de una mascota
lib.callback.register('hdrp-pets:server:getbreedingstatus', function(source, petId)
    local pet = Database.GetCompanionById(petId)

    if not pet then return {status = 'error', message = 'Mascota no encontrada'} end
    local petData = type(pet.data) == 'string' and json.decode(pet.data)
    -- if not petData then goto continue end
    if petData.veterinary.inbreed then
        return {status = 'pregnant', message = locale('cl_breed_pregnant')}
    elseif petData.veterinary.breedingcooldown and petData.veterinary.breedingcooldown > os.time() then
        local timeRemaining = petData.veterinary.breedingcooldown - os.time()
        return {status = 'cooldown', message = locale('cl_breed_cooldown'), timeRemaining = timeRemaining}
    elseif petData.stats.age < Config.Reproduction.MinAgeForBreeding then
        return {status = 'too_young', message = locale('cl_breed_not_young')}
    elseif petData.stats.age > Config.Reproduction.MaxBreedingAge then
        return {status = 'too_old', message = locale('cl_breed_too_old')}
    elseif petData.stats.health < Config.Reproduction.RequiredHealth then
        return {status = 'requirements_not_met', message = locale('cl_breed_not_heath')}
    else
        return {status = 'ready', message = locale('cl_breed_go')}
    end
end)

lib.callback.register('hdrp-pets:server:getpregnancyprogress', function(source, petId)
    local pet = Database.GetCompanionById(petId)
    local petData = type(pet.data) == 'string' and json.decode(pet.data) or pet.data
    if not pet or not petData.veterinary.inbreed or not petData.veterinary.gestationstart or not petData.veterinary.gestationperiod then return {isPregnant = false} end
    local elapsed = os.time() - petData.veterinary.gestationstart
    local progress = math.max(0, math.min(100, (elapsed / petData.veterinary.gestationperiod) * 100))
    local timeRemaining = petData.veterinary.gestationperiod - elapsed
    return {isPregnant = true, progressPercent = progress, timeRemaining = timeRemaining}
end)

-- Callback: buscar parejas compatibles para reproducción
lib.callback.register('hdrp-pets:server:getavailablepartners', function(source, petId)
    local pet = Database.GetCompanionById(petId)
    if not pet then return {} end
    local petData = type(pet.data) == 'string' and json.decode(pet.data) or pet.data
    if not petData then return {} end
    local partners = {}
    local allActive = Database.GetAllActiveCompanions()
    for _, candidate in pairs(allActive) do
        local candidateData = type(candidate.data) == 'string' and json.decode(candidate.data) or candidate.data
        -- if not candidateData then goto continue end
        if candidate.companionid ~= petId and candidateData.veterinary.breedable == true and petData.veterinary.breedable == true and candidateData.info.gender ~= petData.info.gender then
            if candidateData.stats.age >= Config.Reproduction.MinAgeForBreeding and candidateData.stats.age <= Config.Reproduction.MaxBreedingAge and candidateData.stats.health >= Config.Reproduction.RequiredHealth and not candidateData.veterinary.inbreed and (not candidateData.veterinary.breedingcooldown or candidateData.veterinary.breedingcooldown < os.time()) then
                table.insert(partners, {
                    id = candidate.companionid,
                    name = candidateData.info.name,
                    age = candidateData.stats.age,
                    health = candidateData.stats.health,
                    gender = candidateData.info.gender
                })
            end
        end
    end
    return partners
end)

-- Callback: obtener genealogía de una mascota
lib.callback.register('hdrp-pets:server:getgenealogy', function(source, offspring_id)
    if not offspring_id then return { enabled = false, message = 'No companionid provided' } end
    local genealogy = Database.GetGenealogyByOffspringId(offspring_id)
    if not genealogy then
        return { enabled = false, message = 'No genealogy found' }
    end
    return { enabled = true, genealogy = genealogy }
end)

lib.callback.register('hdrp-pets:server:getbreedinghistory', function(source)
    local src = source
    local Player = RSGCore and RSGCore.Functions.GetPlayer and RSGCore.Functions.GetPlayer(src)
    if not Player then return {} end
    local citizenid = Player.PlayerData and Player.PlayerData.citizenid or Player.citizenid or nil
    if not citizenid then return {} end
    -- Obtener historial robusto de cría por jugador
    local history = Database.GetBreedingHistory(citizenid)
    return history or {}
end)
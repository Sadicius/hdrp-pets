local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- Load core modules
local Database = lib.load('server.core.database')
local Validation = lib.load('server.core.validation')

-- HELPER FUNCTIONS
-- Helper: calcula días desde nacimiento hasta evento y desde evento hasta hoy
local function calcEventDays(born, eventTs)
    if not born or not eventTs or eventTs <= 0 then return nil, nil end
    local daysAtEvent = math.floor((eventTs - born) / 86400)
    local daysSinceEvent = math.floor((os.time() - eventTs) / 86400)
    return daysAtEvent, daysSinceEvent
end
 
local function hasDisease(data)
    return data.veterinary.hasdisease == true or data.veterinary.diseasetype ~= nil
end

local function getRiskFactors(data)
    local risks = {}
    
    if Config.Veterinary.DiseaseSystem.Enabled then
        local riskFactors = Config.Veterinary.DiseaseSystem.RiskFactors
        
        if data.stats.dirt and data.stats.dirt > riskFactors.DirtinessOver then
            table.insert(risks, 'dirtiness')
        end
        
        if data.stats.hunger and data.stats.hunger < riskFactors.HungerBelow then
            table.insert(risks, 'malnourishment')
        end
        
        if data.stats.thirst and data.stats.thirst < riskFactors.ThirstBelow then
            table.insert(risks, 'dehydration')
        end
    end
    
    return risks
end

local function calculateDiseaseChance(data)
    local riskFactors = getRiskFactors(data)
    local baseChance = 0.05 -- 5% base chance
    local chancePerRisk = 0.1 -- +10% per risk factor
    
    local totalChance = baseChance + (chancePerRisk * #riskFactors)
    return math.min(totalChance, 0.8) -- Max 80% chance
end

local function checkAndApplyDisease(petRecord, data)
    if not Config.Veterinary.DiseaseSystem.Enabled then
        return false
    end

    -- Check if vaccination is still active
    if data.veterinary.isvaccinated and data.veterinary.vaccinationdate then
        local daysSinceVaccination = math.floor((os.time() - data.veterinary.vaccinationdate) / (24 * 60 * 60))
        if daysSinceVaccination > 30 then
            data.veterinary.isvaccinated = false
        end
    end
    
    -- If already has disease, don't apply another
    if hasDisease(data) then
        return false
    end
    
    -- If vaccinated, don't contract disease
    if data.veterinary.isvaccinated then
        return false
    end
    
    local riskFactors = getRiskFactors(data)
    if #riskFactors > 0 then
        local diceRoll = math.random()
        local diseaseChance = calculateDiseaseChance(data)
        
        if diceRoll < diseaseChance then
            data.veterinary.hasdisease = true
            data.veterinary.diseasetype = riskFactors[math.random(#riskFactors)]
            data.veterinary.diseaseddate = os.time()
            
            if Config.Debug then print(string.format('^3[DISEASE]^7 %s contracted %s (Chance: %.1f%%)', data.info.name or petRecord.companionid, data.veterinary.diseasetype, diseaseChance * 100)) end
            
            return true
        end
    end
    
    return false
end

local function applyDiseaseEffects(petRecord, data)
    if not hasDisease(data) then
        return false
    end
    
    -- Apply disease effects
    if data.veterinary.diseasetype == 'dirtiness' then
        data.stats.health = math.max(0, (data.stats.health or 100) - 2)
    elseif data.veterinary.diseasetype == 'malnourishment' then
        data.stats.health = math.max(0, (data.stats.health or 100) - 3)
    elseif data.veterinary.diseasetype == 'dehydration' then
        data.stats.health = math.max(0, (data.stats.health or 100) - 3)
    end
    
    data.stats.happiness = math.max(0, (data.stats.happiness or 100) - 2)
    
    return true
end

-- VETERINARY SERVICES
---Full checkup service
RegisterNetEvent('hdrp-pets:server:fullcheckup', function(companionid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Validate ownership
    if not Validation.PetOwnership(Player.PlayerData.citizenid, companionid) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('sv_error_not_owner'), duration = 5000 })
        return
    end
    
    local serviceConfig = Config.Veterinary.Services.FullCheckup
    local playerMoney = Player.PlayerData.money['cash'] or 0
    if playerMoney < serviceConfig.price then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('sv_vet_not_enough_cash') .. serviceConfig.price, duration = 5000 })
        return
    end
    
    -- Get pet data using Database module
    local petRecord = Database.GetCompanionByCompanionId(companionid)
    if not petRecord then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('sv_vet_pet_not_found'), duration = 5000 })
        return
    end

    local currentData = json.decode(petRecord.data)
    
    -- Perform checkup
    currentData.stats.health = math.min(100, (currentData.stats.health or 100) + 30)
    currentData.veterinary.lastcheckup = os.time()
    currentData.veterinary.hasdisease = false
    currentData.veterinary.diseasetype = nil
    currentData.veterinary.dead = false -- Revivir mascota
    if currentData.info.born then
        local daysAt, daysSince = calcEventDays(currentData.info.born, currentData.veterinary.lastcheckup)
        currentData.veterinary.daysatcheckup = daysAt
        currentData.veterinary.dayssincecheckup = daysSince
    end
    
    -- Update database
    Database.UpdateCompanionData(companionid, currentData) 
    -- TriggerClientEvent('hdrp-pets:client:updateanimals', src, companionid, currentData)

    Player.Functions.RemoveMoney('cash', serviceConfig.price)

    if Config.Debug then print(string.format('^2[VETERINARY]^7 Checkup completed for %s (Health: %d%%)', currentData.info.name or companionid, math.floor(currentData.stats.health))) end
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = locale('sv_vet_checkup_success') .. math.floor(currentData.stats.health) .. '%', duration = 5000 })

end)

---Vaccination service
RegisterNetEvent('hdrp-pets:server:vaccination', function(companionid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Validate ownership
    if not Validation.PetOwnership(Player.PlayerData.citizenid, companionid) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('sv_error_not_owner'), duration = 5000 })
        return
    end
    
    local serviceConfig = Config.Veterinary.Services.Vaccination
    local playerMoney = Player.PlayerData.money['cash'] or 0
    if playerMoney < serviceConfig.price then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('sv_vet_not_enough_cash') .. serviceConfig.price, duration = 5000 })
        return
    end
    
    -- Get pet data
    local petRecord = Database.GetCompanionByCompanionId(companionid)
    if not petRecord then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('sv_vet_pet_not_found'), duration = 5000 })
        return
    end
    
    local currentData = json.decode(petRecord.data)
    
    -- Check if already vaccinated
    if currentData.veterinary.isvaccinated and currentData.veterinary.vaccinationdate then
        local daysSinceVaccination = math.floor((os.time() - currentData.veterinary.vaccinationdate) / (24 * 60 * 60))
        if daysSinceVaccination < 30 then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('sv_vet_already_vaccinated') .. ' ' .. (30 - daysSinceVaccination) .. ' days', duration = 5000 })
            return
        end
    end
    
    -- Perform vaccination
    currentData.veterinary.isvaccinated = true
    currentData.veterinary.vaccinationdate = os.time()
    currentData.veterinary.hasdisease = false
    currentData.veterinary.diseasetype = nil
    if currentData.info.born then
        local daysAt, daysSince = calcEventDays(currentData.info.born, currentData.veterinary.vaccinationdate)
        currentData.veterinary.daysatvaccination = daysAt
        currentData.veterinary.dayssincevaccination = daysSince
    end
    
    -- Update database
    Database.UpdateCompanionData(companionid, currentData) 
    -- TriggerClientEvent('hdrp-pets:client:updateanimals', src, companionid, currentData)
    
    Player.Functions.RemoveMoney('cash', serviceConfig.price)
    
    if Config.Debug then print(string.format('^2[VETERINARY]^7 Vaccination completed for %s (Valid for 30 days)', currentData.info.name or companionid)) end
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = locale('sv_vet_vaccine_success'), duration = 5000 })

end)

---Surgery service
RegisterNetEvent('hdrp-pets:server:surgery', function(companionid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Validate ownership
    if not Validation.PetOwnership(Player.PlayerData.citizenid, companionid) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('sv_error_not_owner'), duration = 5000 })
        return
    end
    
    local serviceConfig = Config.Veterinary.Services.Surgery
    local playerMoney = Player.PlayerData.money['cash'] or 0
    if playerMoney < serviceConfig.price then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('sv_vet_not_enough_cash') .. serviceConfig.price, duration = 5000 })
        return
    end
    
    -- Get pet data
    local petRecord = Database.GetCompanionByCompanionId(companionid)
    if not petRecord then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('sv_vet_pet_not_found'), duration = 5000 })
        return
    end

    local currentData = json.decode(petRecord.data)

    -- Surgery only for critical health
    if (currentData.stats.health or 100) >= 50 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('sv_vet_surgery_invalid'), duration = 5000 })
        return
    end
    
    -- Perform surgery
    currentData.stats.health = math.min(100, (currentData.stats.health or 0) + 50)
    currentData.veterinary.lastsurgery = os.time()
    currentData.veterinary.hasdisease = false
    currentData.veterinary.diseasetype = nil
    currentData.veterinary.dead = false -- Revivir mascota
    if currentData.info.born then
        local daysAt, daysSince = calcEventDays(currentData.info.born, currentData.veterinary.lastsurgery)
        currentData.veterinary.daysatsurgery = daysAt
        currentData.veterinary.dayssincesurgery = daysSince
    end
    
    -- Update database
    Database.UpdateCompanionData(companionid, currentData) 

    Player.Functions.RemoveMoney('cash', serviceConfig.price)
    
    -- TriggerClientEvent('hdrp-pets:client:updateanimals', src, companionid, currentData)
    
    if Config.Debug then print(string.format('^2[VETERINARY]^7 Surgery completed for %s (Health: %d%%)', currentData.info.name or companionid, math.floor(currentData.stats.health))) end
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = locale('sv_vet_surgery_success') .. math.floor(currentData.stats.health) .. '%', duration = 5000 })

end)

---Sterilization service
RegisterNetEvent('hdrp-pets:server:sterilization', function(companionid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    if not Player then return end
    -- Validate ownership
    if not Validation.PetOwnership(Player.PlayerData.citizenid, companionid) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('sv_error_not_owner'), duration = 5000 })
        return
    end

    local serviceConfig = Config.Veterinary.Services.Sterilization or { price = 100 }
    local playerMoney = Player.PlayerData.money['cash'] or 0
    if playerMoney < serviceConfig.price then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('sv_vet_not_enough_cash') .. serviceConfig.price, duration = 5000 })
        return
    end

    -- Get pet data
    local petRecord = Database.GetCompanionByCompanionId(companionid)
    if not petRecord then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('sv_vet_pet_not_found'), duration = 5000 })
        return
    end

    local currentData = json.decode(petRecord.data)

    -- Perform sterilization
    currentData.veterinary.breedable = false
    currentData.veterinary.sterilizationdate = os.time()
    if currentData.info.born then
        local daysAt, daysSince = calcEventDays(currentData.info.born, currentData.veterinary.sterilizationdate)
        currentData.veterinary.daysatsterilization = daysAt
        currentData.veterinary.dayssincesterilization = daysSince
    end

    -- Update database
    Database.UpdateCompanionData(companionid, currentData) 

    Player.Functions.RemoveMoney('cash', serviceConfig.price)

    -- TriggerClientEvent('hdrp-pets:client:updateanimals', src, companionid, currentData)

    if Config.Debug then print(string.format('^2[VETERINARY]^7 Surgery completed for %s (%s)', currentData.info.name or companionid, locale('sv_vet_sterilization_success'))) end
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = locale('sv_vet_sterilization_success'), duration = 5000 })

end)

-- DISEASE MANAGEMENT
---Disease check event
RegisterNetEvent('hdrp-pets:server:disease:check', function()
    if not Config.Veterinary.DiseaseSystem.Enabled then
        return
    end
    
    local success, result = pcall(MySQL.query.await, 'SELECT * FROM pet_companion')
    if not success then
        if Config.Debug then print('^1[DISEASE ERROR]^7 Database error: ' .. tostring(result)) end
        return
    end
    
    if not result or #result == 0 then
        return
    end
    
    local diseaseCount = 0
    local updateCount = 0
    
    for i = 1, #result do
        local petRecord = result[i]
        
        local success_decode, currentData = pcall(json.decode, petRecord.data)
        if not success_decode or not currentData then
            goto continue_disease
        end
        
        -- Check and apply diseases
        local diseaseApplied = checkAndApplyDisease(petRecord, currentData)
        if diseaseApplied then
            diseaseCount = diseaseCount + 1
        end

        -- Apply disease effects
        local effectsApplied = applyDiseaseEffects(petRecord, currentData)
        -- Update database if changes occurred
        if diseaseApplied or effectsApplied then
            Database.UpdateCompanionData(petRecord.companionid or companionid, currentData) 
            -- TriggerClientEvent('hdrp-pets:client:updateanimals', src, petRecord.companionid or companionid, currentData)
            updateCount = updateCount + 1
        end

        ::continue_disease::

    end
    
    if Config.Debug and (diseaseCount > 0 or updateCount > 0) then print(string.format('^2[DISEASE]^7 Check complete: %d new diseases, %d updates', diseaseCount, updateCount)) end
end)

-- EXPORTS
exports('HasDisease', function(data)
    return hasDisease(data)
end)

exports('GetDiseaseType', function(data)
    return data.veterinary.diseasetype or 'none'
end)

exports('GetRiskFactors', function(data)
    return getRiskFactors(data)
end)

exports('CalculateDiseaseChance', function(data)
    return calculateDiseaseChance(data)
end)
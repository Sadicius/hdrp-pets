
local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- Load Database module
local Database = lib.load('server.core.database')

--================================
-- LIFECYCLE SYSTEM
--================================

local lifecycleEnabled = Config.Lifecycle and Config.Lifecycle.Enabled
local decayEnabled = Config.AutoDecay and Config.AutoDecay.Enabled

if not lifecycleEnabled and not decayEnabled then
    if Config.Debug then 
        print('^3[LIFECYCLE & DECAY]^7 Both systems disabled') 
    end
    return
end

--================================
-- LIFECYCLE HELPER FUNCTIONS
-- Calcula días desde nacimiento hasta evento y desde evento hasta hoy
local function calcEventDays(born, eventTs)
    if not born or not eventTs or eventTs <= 0 then return nil, nil end
    local daysAtEvent = math.floor((eventTs - born) / 86400)
    local daysSinceEvent = math.floor((os.time() - eventTs) / 86400)
    return daysAtEvent, daysSinceEvent
end
--================================

local function getPetStage(age)
    if not lifecycleEnabled then return 'Adult', {} end
    
    local stages = Config.Lifecycle.PetStages
    
    if age <= stages.Baby.ageMax then
        return 'Baby', stages.Baby
    elseif age <= stages.Young.ageMax then
        return 'Young', stages.Young
    elseif age <= stages.Adult.ageMax then
        return 'Adult', stages.Adult
    else
        return 'Senior', stages.Senior
    end
end

local function getXpMultiplier(age)
    if not lifecycleEnabled then return 1.0 end
    local stageName, stageData = getPetStage(age)
    return stageData.xpMultiplier or 1.0
end

local function getHealthMultiplier(age)
    if not lifecycleEnabled then return 1.0 end
    local stageName, stageData = getPetStage(age)
    return stageData.healthMultiplier or 1.0
end

local function calculateAge(bornTime)
    return math.floor((os.time() - bornTime) / (24 * 60 * 60))
end

local function calculatePetScale(age)
    -- Grows from 0.5 (50%) to 1.0 (100%) over first 5 days
    return math.min(1.0, 0.5 + 0.1 * (age or 0))
end

--================================
-- DECAY HELPER FUNCTIONS
--================================

local function adjustWithinBounds(value, minValue, maxValue)
    return math.min(math.max(value, minValue), maxValue)
end

-- VERSION PARA REFACTORIZAR A UNA ESTRUCTURA MÁS COMPLETA
local function getCriticalStatus(data)
    if not decayEnabled then return {} end
    
    local status = {
        isHungry = data.stats.hunger < Config.AutoDecay.HealthConsequences.CriticalHunger,
        isThirsty = data.stats.thirst < Config.AutoDecay.HealthConsequences.CriticalThirst,
        isDirty = data.stats.dirt < Config.AutoDecay.HealthConsequences.CriticalCleanliness
    }
    return status
end

local function calculateHealthChange(data)
    if not decayEnabled then return 0 end
    
    local healthChange = 0
    local critical = getCriticalStatus(data)
    
    -- Apply health consequences if stats are critical
    if critical.isHungry then
        healthChange = healthChange - (Config.AutoDecay.HealthConsequences.CriticalHunger / 10)
    end
    
    if critical.isThirsty then
        healthChange = healthChange - (Config.AutoDecay.HealthConsequences.CriticalThirst / 10)
    end
    
    if critical.isDirty then
        healthChange = healthChange - (Config.AutoDecay.HealthConsequences.CriticalCleanliness / 10)
    end
    
    -- Health regeneration if pet is well cared for
    if data.stats.hunger >= Config.AutoDecay.HealthRegeneration.RequiredHunger and
       data.stats.thirst >= Config.AutoDecay.HealthRegeneration.RequiredThirst and
       healthChange == 0 then
        healthChange = Config.AutoDecay.HealthRegeneration.RegenAmount
    end
    
    return healthChange
end

local function updateHappiness(data)
    if not decayEnabled then return data.stats.happiness or 100 end
    
    local happiness = data.stats.happiness or 100
    local penalties = 0
    
    -- Penalize if hunger is low
    if data.stats.hunger < 75 then
        penalties = penalties + 1
    end
    
    -- Penalize if thirst is low
    if data.stats.thirst < 75 then
        penalties = penalties + 1
    end
    
    -- Penalize for dirtiness
    if data.stats.dirt then
        if data.stats.dirt < 25 then
            penalties = penalties + 1
        elseif data.stats.dirt < 50 then
            penalties = penalties + 0.5
        end
    end
    
    -- Extra penalties if critical
    if data.stats.hunger == 0 or data.stats.thirst == 0 then
        penalties = penalties + 1
    end
    
    return math.max(0, happiness - penalties)
end

-- LIFECYCLE CHECKING
local function checkPetLifecycleEvents(petRecord, data)
    if not lifecycleEnabled then return false end
    
    if not data.info.born then
        if Config.Debug then print('^3[LIFECYCLE]^7 Pet has no birth time: ' .. (data.info.name or petRecord.id)) end
        data.info.born = os.time()
        return false
    end

    local currentAge = calculateAge(data.info.born)
    local previousAge = data.stats.age or 0
    
    -- Set initial age if new pet
    data.stats.age = currentAge
    
    -- Check if pet died of natural causes (old age)
    if currentAge > Config.Lifecycle.MaxAge then
        return 'dead_age'
    end
    
    -- Check for stage transition
    local oldStageName, oldStageData = getPetStage(previousAge)
    local newStageName, newStageData = getPetStage(currentAge)
    
    if oldStageName ~= newStageName then
        if Config.Debug then
            print(string.format('^2[LIFECYCLE]^7 %s transitioned from %s to %s stage', 
                data.info.name or petRecord.companionid, oldStageName, newStageName))
        end
        -- data.stats.currentStage = newStageName
        return 'stage_change'
    end
    
    return false
end

-- DECAY APPLICATION
local function applyDecay(data)
    if not decayEnabled then return false end

    -- Validate required fields
    if not data.stats.hunger or not data.stats.thirst or not data.stats.happiness or not data.stats.dirt or not data.stats.health or not data.stats.strength then
        if Config.Debug then print('^3[DECAY]^7 Pet missing required stats fields') end
        return false
    end

    local originalHunger = data.stats.hunger or 100
    local originalThirst = data.stats.thirst or 100
    local originalCleanliness = data.stats.dirt or 0
    local originalHealth = data.stats.health or 100
    local originalHappiness = data.stats.happiness or 100
    local originalStrength = data.stats.strength or 50

    -- Reduce hunger and thirst
    data.stats.hunger = adjustWithinBounds( data.stats.hunger - Config.AutoDecay.DecayRates.Hunger, 0, 100 )

    data.stats.thirst = adjustWithinBounds( data.stats.thirst - Config.AutoDecay.DecayRates.Thirst, 0, 100 )

    -- Reduce cleanliness (increase dirt)
    if data.stats.dirt then
        data.stats.dirt = adjustWithinBounds( data.stats.dirt - Config.AutoDecay.DecayRates.Cleanliness, 0, 100 )
    end

    -- Calculate health change
    local healthChange = calculateHealthChange(data)
    data.stats.health = adjustWithinBounds( (data.stats.health or 100) + healthChange, 0, 100 )

    -- Update happiness based on condition
    if data.stats.happiness then
        data.stats.happiness = updateHappiness(data)
    end

    -- Strength decay if pet is neglected (any stat critical)
    if data.stats.strength then
        local critical = getCriticalStatus(data)
        if critical.isHungry or critical.isThirsty or critical.isDirty then
            local strengthDecay = (Config.AutoDecay.DecayRates.Strength or 2)
            data.stats.strength = adjustWithinBounds( data.stats.strength - strengthDecay, 0, 100 )
        end
    end

    -- Check if any real changes occurred
    local hasChanges = (data.stats.hunger ~= originalHunger or
                       data.stats.thirst ~= originalThirst or
                       data.stats.health ~= originalHealth or
                       data.stats.happiness ~= originalHappiness or
                       data.stats.dirt ~= originalCleanliness or
                       data.stats.strength ~= originalStrength)

    return hasChanges
end

-- UNIFIED UPDATE FUNCTION
local function updatePetLifecycleAndDecay()
    -- Process only active pets to reduce load under large datasets
    local success, result = pcall(MySQL.query.await, 'SELECT * FROM pet_companion WHERE active = 1')
    if not success then return end
    if not result or #result == 0 then
        if Config.Debug then print('^3[LIFECYCLE & DECAY]^7 No pets found to process') end
        return
    end
    
    local updateCount = 0
    local deathCount = 0
    local decayCount = 0

    for i = 1, #result do
        local petRecord = result[i]
        
        -- Decode pet data
        local success_decode, currentData = pcall(json.decode, petRecord.data)
        if not success_decode or not currentData then
            if Config.Debug then print('^3[LIFECYCLE & DECAY]^7 Failed to decode pet data: ' .. tostring(petRecord.id)) end
            goto continue_processing
        end
        
        -- Initialize birth time if missing
        if not currentData.info.born then
            currentData.info.born = os.time()
        end
        
        local needsUpdate = false
        
        -- LIFECYCLE: Check lifecycle events
        if lifecycleEnabled then
            local lifecycleEvent = checkPetLifecycleEvents(petRecord, currentData)
            
            if lifecycleEvent == 'dead_age' then
                -- Pet died of natural causes
                if Config.Debug then print(string.format('^1[LIFECYCLE]^7 Pet died of old age: %s (Age: %d days)',  currentData.info.name or petRecord.companionid, calculateAge(currentData.info.born))) end
                
                -- Delete from database
                local deleteSuccess = Database.DeleteCompanion(petRecord.companionid) -- pcall(MySQL.update.await, 'DELETE FROM pet_companion WHERE id = ?', { petRecord.id } )

                if deleteSuccess then
                    deathCount = deathCount + 1
                    
                    -- Log to Discord
                    local discordMessage = string.format(
                        '**PET DEATH - OLD AGE**\n**Citizen ID:** %s\n**Pet ID:** %s\n**Pet Name:** %s\n**Age:** %d days (Max: %d)\n**Time:** %s',
                        petRecord.citizenid,
                        currentData.id or 'Unknown',
                        currentData.info.name or 'Unknown',
                        calculateAge(currentData.info.born),
                        Config.Lifecycle.MaxAge,
                        os.date('%Y-%m-%d %H:%M:%S')
                    )
                    TriggerEvent('rsg-log:server:CreateLog', Config.WebhookName, Config.WebhookTitle, Config.WebhookColour, discordMessage, false)
                    
                    -- Send telegram to owner
                    pcall(MySQL.insert.await,
                        'INSERT INTO telegrams (citizenid, recipient, sender, sendername, subject, sentDate, message) VALUES (?, ?, ?, ?, ?, ?, ?)',
                        {
                            petRecord.citizenid,
                            'Stable Master',
                            '22222222',
                            'Stables',
                            (currentData.info.name or 'Your pet') .. ' has passed away',
                            os.date('%x'),
                            'Your beloved ' .. (currentData.info.name or 'pet') .. ' has reached the end of its natural lifespan and has passed away peacefully.'
                        }
                    )
                    
                    -- TriggerClientEvent('hdrp-pets:client:updateanimals', src)
                end
                
                goto continue_processing
                
            elseif lifecycleEvent == 'stage_change' then
                -- Pet changed life stage
                currentData.stats.scale = calculatePetScale(currentData.stats.age)
                needsUpdate = true
                updateCount = updateCount + 1
                
            elseif currentData.stats.age ~= calculateAge(currentData.info.born) then
                -- Age updated without stage change
                currentData.stats.age = calculateAge(currentData.info.born)
                currentData.stats.scale = calculatePetScale(currentData.stats.age)
                needsUpdate = true
            end
        end
        
        -- DECAY: Apply stat decay (only for active pets if multi-pet enabled)
        if decayEnabled and petRecord.active then
            local decayApplied = applyDecay(currentData)
            if decayApplied then
                needsUpdate = true
                decayCount = decayCount + 1
                
                if Config.Debug then print(string.format('^3[DECAY]^7 %s - Hunger: %d, Thirst: %d, Health: %d, Happiness: %d, Strength: %d', currentData.info.name or 'Pet #' .. currentData.id, math.floor(currentData.stats.hunger), math.floor(currentData.stats.thirst), math.floor(currentData.stats.health), math.floor(currentData.stats.happiness), math.floor(currentData.stats.strength) )) end
                
                -- Notify owner if pet needs critical care
                local Player = RSGCore.Functions.GetPlayerByCitizenId(petRecord.citizenid)
                if Player then
                    local critical = getCriticalStatus(currentData)
                    if critical.isHungry or critical.isThirsty or critical.isDirty then
                        TriggerClientEvent('ox_lib:notify', Player.PlayerData.source, { type = 'warning', title = locale('cl_decay_warning'), description = (currentData.info.name or locale('cl_pet_your')) .. ' ' .. locale('sv_pet_needs_care'), duration = 7000 })
                    end
                end
            end
        end
        
        -- Si la salud es 0 o menos y no está marcado como muerto, marcar como muerto y actualizar
        if (currentData.stats.health or 100) <= 0 and not currentData.veterinary.dead then
            currentData.veterinary.dead = true
            needsUpdate = true
            if Config.Debug then print(string.format('^1[LIFECYCLE]^7 Pet marked as dead due to 0 health: %s (ID: %s)', currentData.info.name or 'Unknown', tostring(petRecord.companionid or currentData.id))) end
        end

        -- Update database if changes occurred
        if needsUpdate then
            -- Debug print para rastrear companionid y dirt
            if Config.Debug then
                print('^5[LIFECYCLE DEBUG]^7 Intentando guardar mascota:')
                print('  companionid:', tostring(currentData.id or currentData.companionid or petRecord.companionid))
                print('  dirt:', type(currentData.stats.dirt), currentData.stats.dirt)
                print('  health:', type(currentData.stats.health), currentData.stats.health)
                print('  data.stats:', json.encode(currentData.stats))
            end
            -- Validación estricta
            local companionid = currentData.id or currentData.companionid or petRecord.companionid
            if not companionid then
                print('^1[LIFECYCLE ERROR]^7 companionid es nil, no se puede guardar')
            elseif not currentData then
                print('^1[LIFECYCLE ERROR]^7 currentData es nil, no se puede guardar')
            else
                local ok, err = pcall(Database.UpdateCompanionData, companionid, currentData)
                if not ok then
                    print('^1[LIFECYCLE ERROR]^7 Fallo al guardar mascota:', err)
                end
                -- No enviar updateanimals aquí, src no está definido en lifecycle
            end
        end
        
        ::continue_processing::
    end
    
    if Config.Debug and (updateCount > 0 or deathCount > 0 or decayCount > 0) then print(string.format('^2[LIFECYCLE & DECAY]^7 Processed: %d updates, %d deaths, %d decays', updateCount, deathCount, decayCount)) end
end

-- CRON JOBS
-- Lifecycle check every 6 hours
if lifecycleEnabled then
    lib.cron.new('0 */6 * * *', function()
        if Config.Debug then print('^2[LIFECYCLE]^7 Running lifecycle check...') end
        updatePetLifecycleAndDecay()
    end)
end

-- Decay check based on config
if decayEnabled then
    lib.cron.new(Config.AutoDecay.CronJob, function()
        if Config.Debug then print('^2[DECAY]^7 Running decay check...') end
        updatePetLifecycleAndDecay()
    end)
end

-- MANUAL TRIGGERS
RegisterNetEvent('hdrp-pets:server:lifecycle:check', function()
    if Config.Debug then print('^2[LIFECYCLE]^7 Manual lifecycle check triggered') end
    updatePetLifecycleAndDecay()
end)

-- EXPORTS
exports('GetXpMultiplier', function(petAge)
    return getXpMultiplier(petAge)
end)

exports('GetHealthMultiplier', function(petAge)
    return getHealthMultiplier(petAge)
end)

exports('GetPetStage', function(petAge)
    local stageName, stageData = getPetStage(petAge)
    return stageName
end)

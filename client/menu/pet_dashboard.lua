--[[
    HDRP-PETS - PET DASHBOARD
    Dashboard principal y lista de mascotas
    Versión: 6.0.0
    
    Estructura:
    - Pet Dashboard List (selección de mascota)
    - Pet Dashboard (vista consolidada con 5 tabs)
]]

local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
--[[
    PET DASHBOARD LIST
    Lista de todas las mascotas activas con metadata
]]
function ShowPetDashboardList()
    RSGCore.Functions.TriggerCallback('hdrp-pets:server:getactivecompanions', function(activePetsData)
        if not activePetsData or #activePetsData == 0 then
            lib.notify({ 
                title = locale('cl_no_active_pets'), 
                type = 'error', 
                duration = 5000 
            })
            return
        end
        
        local options = {}
        
        for _, dbPetData in ipairs(activePetsData) do
            local companionid = dbPetData.companionid
            local pet = State.GetPet(companionid)
            local companionData = pet and pet.data or {}
            local petName = (companionData.info and companionData.info.name) or 'Unknown'
            local xp = (companionData.progression and companionData.progression.xp) or 0
            local level = State.GetPetLevel and State.GetPetLevel(xp) or math.floor(xp / 100) + 1
            local isSpawned = pet and pet.spawned and DoesEntityExist(pet.ped)
            local health = 100
            local healthIcon = '💚'
            if isSpawned and DoesEntityExist(pet.ped) then
                local currentHealth = GetEntityHealth(pet.ped)
                local maxHealth = GetEntityMaxHealth(pet.ped)
                health = math.floor((currentHealth / maxHealth) * 100)
                healthIcon = health > 75 and '💚' or (health > 50 and '💛' or (health > 25 and '🧡' or '❤️'))
            end
            local hunger = (companionData.stats and companionData.stats.hunger) or 0
            local thirst = (companionData.stats and companionData.stats.thirst) or 0
            local availableActions = 10
            local unlockedGames = 0
            if xp >= Config.XP.Trick.Bone then unlockedGames = unlockedGames + 1 end
            if xp >= Config.XP.Trick.BuriedBone then unlockedGames = unlockedGames + 2 end
            if xp >= Config.XP.Trick.digRandom then unlockedGames = unlockedGames + 1 end
            if xp >= Config.XP.Trick.TreasureHunt then unlockedGames = unlockedGames + 1 end
            options[#options + 1] = {
                title = healthIcon .. ' ' .. petName,
                description = ' 💫 Level '.. level ..' XP: ' .. xp,
                metadata = {
                    {label = locale('cl_actions_available'), value = availableActions},
                    {label = locale('cl_games_unlocked'), value = unlockedGames .. '/5'},
                    {label = locale('cl_adoption_date'), value = (companionData.info and companionData.info.born) or 'N/A'},
                    {label = locale('cl_rarity'), value = (companionData.info and companionData.info.rarity) or 'Normal'},
                },
                arrow = true,
                onSelect = function()
                    ShowPetDashboard(companionid)
                end
            }
        end
        
        if #options == 0 then
            options[#options + 1] = {
                title = '❌ ' .. locale('cl_error_pet_no_active'),
                description = locale('cl_error_pet_no_active_desc'),
                -- icon = 'fa-solid fa-exclamation-circle',
                disabled = true
            }
        end
        
        lib.registerContext({
            id = 'pet_dashboard_list',
            title = locale('cl_select_pet'),
            menu = 'pet_main_menu',
            onBack = function() end,
            options = options
        })
        
        lib.showContext('pet_dashboard_list')
    end)
end

--[[
    TRACK MENU
    Sub-menú de rastreo
]]

local function ShowTrackMenu(companionid)
    local pet = State.GetPet(companionid)
    local petPed = pet and pet.ped or nil
    local options = {}
    
    -- TRACK PLAYER
    options[#options + 1] = {
        title = '👤 ' .. locale('cl_track_location'),
        -- description = locale('cl_track_location_desc'),
        -- icon = 'fa-solid fa-user',
        onSelect = function()
            TriggerEvent('hdrp-pets:client:showTableSelectionMenu')
        end
    }
    
    -- TRACK ANIMAL
    options[#options + 1] = {
        title = '🦌 ' .. locale('cl_track_animal'),
        -- description = locale('cl_track_animal_desc'),
        -- icon = 'fa-solid fa-paw',
        onSelect = function()
            TriggerEvent('hdrp-pets:client:trackClosestAnimal')
        end
    }
    
    lib.registerContext({
        id = 'track_menu',
        title = locale('cl_menu_track'),
        menu = 'pet_dashboard',
        onBack = function() end,
        options = options
    })
    
    lib.showContext('track_menu')
end

--[[
    PET DASHBOARD
    Vista consolidada de una mascota específica con 5 tabs
]]
function ShowPetDashboard(companionid)
    local pet = State.GetPet(companionid)
    local companionData = pet.data or {}
    local petName = (companionData.info and companionData.info.name) or 'Unknown'
    local xp = (companionData.progression and companionData.progression.xp) or 0
    local level = State.GetPetLevel and State.GetPetLevel(xp) or math.floor(xp / 100) + 1
    local age = (companionData.stats and companionData.stats.age) or 0
    -- Get life stage
    local lifeStage = 'Adult'
    local lifeStageIcon = '🐕'
    if Config.Lifecycle.Enabled and companionData.stats and companionData.stats.age then
        if age <= Config.Lifecycle.PetStages.Baby.ageMax then
            lifeStage = 'Baby'
            lifeStageIcon = '🐶'
        elseif age <= Config.Lifecycle.PetStages.Young.ageMax then
            lifeStage = 'Young'
            lifeStageIcon = '🐕'
        elseif age <= Config.Lifecycle.PetStages.Adult.ageMax then
            lifeStage = 'Adult'
            lifeStageIcon = '🐕'
        else
            lifeStage = 'Senior'
            lifeStageIcon = '🐕‍🦺'
        end
    end
    -- Calculate health percentage
    local health = 100
    if pet and pet.spawned and DoesEntityExist(pet.ped) then
        local currentHealth = GetEntityHealth(pet.ped)
        local maxHealth = GetEntityMaxHealth(pet.ped)
        health = math.floor((currentHealth / maxHealth) * 100)
    end
    local hunger = (companionData.stats and companionData.stats.hunger) or 0
    local thirst = (companionData.stats and companionData.stats.thirst) or 0
    local happiness = (companionData.stats and companionData.stats.happiness) or 100
    local cleanliness = (companionData.stats and companionData.stats.dirt) or 100
    local strength = (companionData.stats and companionData.stats.strength) or 100
    -- Calculate next decay time (if enabled)
    local nextDecayText = ''
    if Config.AutoDecay.Enabled then
        nextDecayText = '12 min' -- Placeholder
    end
    local options = {}
    local isPetAlive = pet and pet.spawned and DoesEntityExist(pet.ped) and not IsEntityDead(pet.ped)
    local actionsCount = isPetAlive and 9 or 2
        
    -- ========================================
    -- HEADER: PET INFO (con metadata extendida de edad/vida)
    -- ========================================
    local headerMetadata = {}
    -- Experiencia
    if companionData.breed then table.insert(headerMetadata, {label = locale('cl_stat_breed'), value = companionData.breed}) end
    if companionData.color then table.insert(headerMetadata, {label = locale('cl_stat_color'), value = companionData.color}) end

    -- Si LifecycleSystem está activo, añadir metadata extendida de edad/vida
    if Config.Lifecycle.Enabled then
        local maxAge = Config.Lifecycle.MaxAge
        local lifeProgress = math.floor((age / maxAge) * 100)
        local lifeStageMeta = 'Adult'
        local stageInfo = ''
        local xpBonus = '1.0x'
        local healthMod = '1.0x'
        local nextStage = ''
        local daysToNextStage = 0
        local daysRemaining = maxAge - age
        if age <= Config.Lifecycle.PetStages.Baby.ageMax then
            lifeStageMeta = 'Baby'
            xpBonus = Config.Lifecycle.PetStages.Baby.xpMultiplier .. 'x'
            healthMod = Config.Lifecycle.PetStages.Baby.healthMultiplier .. 'x'
            nextStage = 'Young'
            daysToNextStage = Config.Lifecycle.PetStages.Young.ageMin - age
        elseif age <= Config.Lifecycle.PetStages.Young.ageMax then
            lifeStageMeta = 'Young'
            xpBonus = Config.Lifecycle.PetStages.Young.xpMultiplier .. 'x'
            healthMod = Config.Lifecycle.PetStages.Young.healthMultiplier .. 'x'
            nextStage = 'Adult'
            daysToNextStage = Config.Lifecycle.PetStages.Adult.ageMin - age
        elseif age <= Config.Lifecycle.PetStages.Adult.ageMax then
            lifeStageMeta = 'Adult'
            xpBonus = Config.Lifecycle.PetStages.Adult.xpMultiplier .. 'x'
            healthMod = Config.Lifecycle.PetStages.Adult.healthMultiplier .. 'x'
            nextStage = 'Senior'
            daysToNextStage = Config.Lifecycle.PetStages.Senior.ageMin - age
        else
            lifeStageMeta = 'Senior'
            xpBonus = Config.Lifecycle.PetStages.Senior.xpMultiplier .. 'x'
            healthMod = Config.Lifecycle.PetStages.Senior.healthMultiplier .. 'x'
            nextStage = locale('cl_death')
            daysToNextStage = daysRemaining
        end
        stageInfo = lifeStageMeta .. ' (' .. Config.Lifecycle.PetStages[lifeStageMeta].ageMin .. '-' .. Config.Lifecycle.PetStages[lifeStageMeta].ageMax .. ' ' .. locale('cl_stat_days') .. ')'
        -- Metadata extendida
        table.insert(headerMetadata, {label = '🐕', value = petName})
        table.insert(headerMetadata, {label = '🪪 ID', value = companionid})
        -- table.insert(headerMetadata, {label = locale('cl_life_stage'), value = lifeStageMeta})
        table.insert(headerMetadata, {label = locale('cl_life_stage'), value = stageInfo, progress = lifeProgress})
        table.insert(headerMetadata, {label = locale('cl_next_stage'), value = nextStage .. ' ' .. locale('cl_in') .. ' ' .. daysToNextStage .. ' ' .. locale('cl_stat_days')})
        table.insert(headerMetadata, {label = locale('cl_days_to_death'), value = daysRemaining .. ' ' .. locale('cl_stat_days')})

        table.insert(headerMetadata, {label = ' 💫 Level '.. level, value = xp ..' XP' , progress = xp % 100, colorScheme = '#e8a93f'})
        table.insert(headerMetadata, {label = locale('cl_xp_bonus'), value = xpBonus})
        table.insert(headerMetadata, {label = locale('cl_health_modifier'), value = healthMod})
        
        table.insert(headerMetadata, {label = locale('cl_stat_health'), value = health .. '%', progress = health, colorScheme = '#359d93'})
        table.insert(headerMetadata, {label = locale('cl_stat_hunger'), value = hunger .. '%', progress = hunger, colorScheme = hunger < 30 and '#F44336' or '#bfe6ef'})
        table.insert(headerMetadata, {label = locale('cl_stat_thirst'), value = thirst .. '%', progress = thirst, colorScheme = thirst < 30 and '#F44336' or '#447695'})
        table.insert(headerMetadata, {label = locale('cl_stat_happiness'), value = happiness .. '%', progress = happiness, colorScheme = happiness < 30 and '#F44336' or '#ffe066'})
        table.insert(headerMetadata, {label = locale('cl_stat_cleanliness'), value = cleanliness .. '%', progress = cleanliness, colorScheme = cleanliness < 30 and '#F44336' or '#b3e6b3'})
        table.insert(headerMetadata, {label = locale('cl_stat_strength'), value = strength .. '%', progress = strength, colorScheme = strength < 30 and '#F44336' or '#b3e6b3'})

        -- table.insert(headerMetadata, {label = locale('cl_last_activity'), value = companionData.lastActivity or 'N/A'})
        -- table.insert(headerMetadata, {label = locale('cl_last_vet_visit'), value = companionData.lastVetVisit or 'N/A'})
        
        -- if companionData.color then table.insert(headerMetadata, {label = locale('cl_stat_color'), value = companionData.color}) end
        table.insert(headerMetadata, {label = '📋 Veterinario', value = ''})
        table.insert(headerMetadata, {label = locale('cl_past_diseases'), value = companionData.pastDiseases and table.concat(companionData.pastDiseases, ', ') or locale('cl_none')})
        local vetStatus = (companionData.hasDisease and 'Enfermo') or (companionData.isVaccinated and 'Vacunado' or 'Sano')
        table.insert(headerMetadata, {label = 'Estado', value = vetStatus})
        if companionData.isVaccinated and companionData.vaccinationDate then
            table.insert(headerMetadata, {label = 'Vacunación', value = companionData.vaccinationDate })
        end
        if companionData.lastCheckup then
            table.insert(headerMetadata, {label = 'Último chequeo', value = companionData.lastCheckup})
        end
        if companionData.lastSurgery then
            table.insert(headerMetadata, {label = 'Última cirugía', value = companionData.lastSurgery})
        end
        if companionData.breed then table.insert(headerMetadata, {label = locale('cl_stat_breed'), value = companionData.breed}) end
        if companionData.isSterilized and companionData.sterilizationDate then
            table.insert(headerMetadata, {label = 'Esterilizado', value = companionData.sterilizationDate})
        end
    end

    options[#options + 1] = {
        title = 'ID: ' .. petName,
        description = locale('cl_pet_header_desc') .. age .. ' ' .. locale('cl_stat_days'),
        -- icon = 'fa-solid fa-paw',
        arrow = true,
        onSelect = function()
            local Stats = lib.load('client.menu.pet_stats')
            Stats.ShowTab(companionid)
        end,
        metadata = headerMetadata
    }
    -- (Eliminada la opción de edad/lifecycle redundante)

    -- ========================================
    -- STAT 9: COMBAT STATS (READ-ONLY)
    -- ========================================
    local combatVictoriesAnimals = companionData.combatVictoriesAnimals or 0
    local combatVictoriesHumans = companionData.combatVictoriesHumans or 0
    local combatDefeats = companionData.combatDefeats or 0
    local totalCombats = combatVictoriesAnimals + combatVictoriesHumans + combatDefeats
    local winRate = totalCombats > 0 and math.floor(((combatVictoriesAnimals + combatVictoriesHumans) / totalCombats) * 100) or 0
    local xpFromCombat = (combatVictoriesAnimals * Config.XP.Increase.PerCombat) + (combatVictoriesHumans * Config.XP.Increase.PerCombatHuman)
    local personality = 'AVOID_DOG'
    local personalityDesc = locale('cl_personality_avoid')
    local nextPersonality = 'TIMIDGUARDDOG'
    local nextpersonalityDesc = locale('cl_personality_timid_guard')
    local xpToNext = 1000 - xp
    local personalityProgress = 0
    
    if xp >= 2000 then
        personality = 'GUARD_DOG'
        personalityDesc = locale('cl_personality_guard')
        nextPersonality = locale('cl_max_level')
        xpToNext = 0
        personalityProgress = 100
    elseif xp >= 1000 then
        personality = 'TIMIDGUARDDOG'
        personalityDesc = locale('cl_personality_timid_guard')
        nextPersonality = 'GUARD_DOG'
        nextpersonalityDesc = locale('cl_personality_guard')
        xpToNext = 2000 - xp
        personalityProgress = math.floor(((xp - 1000) / 1000) * 100)
    else
        personalityProgress = math.floor((xp / 1000) * 100)
    end

    options[#options + 1] = {
        title = '🧠 ' .. locale('cl_personality') .. ' ' .. personalityDesc,
        -- description = personalityDesc,
        -- icon = 'fa-solid fa-brain',
        colorScheme = '#9C27B0',
        arrow = Config.Reproduction.GenealogyEnabled,
        onSelect = function()
            if Config.Reproduction.GenealogyEnabled then
                local Breeding = lib.load('client.menu.pet_breed')
                Breeding.openGenealogyMenu(companionid)
            end
        end,
        -- disabled = true,
        metadata = {
            -- {label = locale('cl_current'), value = personality},
            {label = '🐕 ' .. locale('cl_behavior'), value = ''},
            {label = locale('cl_current'), value = personalityDesc},
            {label = locale('cl_achievement_progress'), value = companionData.achievementProgress or '0%'},
            {label = locale('cl_progress'), value = nextpersonalityDesc .. ' ' .. locale('cl_at') .. ' ' .. personalityProgress .. '%' },
            {label = locale('cl_next'), value = (xp >= 1000 and '2000' or '1000') .. ' XP'},
        
            {label = '⚔️ ' .. locale('cl_combat_stats'), value = ''},
            {label = locale('cl_win_rate'), value = winRate .. '%', progress = winRate, colorScheme = winRate >= 50 and '#4CAF50' or '#F44336'},
            {label = locale('cl_xp_from_combat'), value = '+' .. xpFromCombat .. ' XP'},
            {label = locale('cl_victories_animals'), value = combatVictoriesAnimals},
            {label = locale('cl_victories_humans'), value = combatVictoriesHumans},
            {label = locale('cl_defeats'), value = combatDefeats},
        }
    }
    -- ========================================
    -- TAB 2: ACTIONS
    -- ========================================
    
    options[#options + 1] = {
        title = '⚡ ' .. locale('cl_label_actions'),
        -- description = locale('cl_tab_actions_desc'):format(actionsCount),
        -- icon = 'fa-solid fa-bolt',
        arrow = true,
        onSelect = function()
            local Actions = lib.load('client.menu.pet_actions')
            Actions.ShowTab(companionid)
        end
    }
    
    -- ========================================
    -- TAB 3: GAMES
    -- ========================================
    local unlockedGames = 0
    if xp >= Config.XP.Trick.Bone then unlockedGames = unlockedGames + 1 end
    if xp >= Config.XP.Trick.BuriedBone then unlockedGames = unlockedGames + 2 end
    if xp >= Config.XP.Trick.digRandom then unlockedGames = unlockedGames + 1 end
    if xp >= Config.XP.Trick.TreasureHunt then unlockedGames = unlockedGames + 1 end
    
    options[#options + 1] = {
        title = '🎮 ' .. locale('cl_tab_games'),
        -- description = locale('cl_tab_games_desc'):format(unlockedGames, 5),
        -- icon = 'fa-solid fa-gamepad',
        arrow = true,
        onSelect = function()
            ShowPetGamesTab(companionid)
        end
    }
    
    local canTrack = xp >= Config.XP.Trick.Track
    options[#options + 1] = {
        title = '📍 ' .. locale('cl_action_track'),
        disabled = not canTrack,
        arrow = canTrack,
        metadata = canTrack and nil or {
            {label = locale('cl_xp_required'), value = Config.XP.Trick.Track .. ' ❌'}
        },
        onSelect = function()
            if xp < Config.XP.Trick.Track then
                lib.notify({ title = locale('cl_error_xp_needed'):format(Config.XP.Trick.Track), type = 'error' })
                return
            end
            ShowTrackMenu(companionid)
        end
    }


    -- TAB 4: INVENTORY
    options[#options + 1] = {
        title = '🎒 ' .. locale('cl_tab_inventory'),
        -- description = locale('cl_tab_inventory_desc'),
        -- icon = 'fa-solid fa-box',
        arrow = true,
        onSelect = function()
            TriggerEvent('hdrp-pets:client:inventoryCompanion', companionid)
        end
    }

    -- TAB 5: ANIMATIONS (XP >= 500)
    local canAnimate = xp >= Config.XP.Trick.Animations
    options[#options + 1] = {
        title = '🎨 ' .. locale('cl_action_animations'),
        -- description = canAnimate and locale('cl_action_animations_desc') or locale('cl_xp_required') .. ': ' .. Config.XP.Trick.Animations .. ' (XP: ' .. xp .. ' ❌)',
        -- icon = 'fa-solid fa-masks-theater',
        disabled = not canAnimate,
        arrow = canAnimate,
        metadata = canAnimate and nil or {
            {label = locale('cl_xp_required'), value = Config.XP.Trick.Animations .. ' ❌'}
        },
        onSelect = function()
            if xp < Config.XP.Trick.Animations then
                lib.notify({ title = locale('cl_error_xp_needed'):format(Config.XP.Trick.Animations), type = 'error' })
                return
            end
            local Actions = lib.load('client.menu.pet_actions')
            Actions.ShowAnimationsMenu(companionid)
        end
    }
    
    -- TAB 6: ACHIEVEMENTS (if enabled)
    if Config.XP.Achievements.Enabled then
        options[#options + 1] = {
            title = '🏆 ' .. locale('cl_tab_achievements'),
            -- description = locale('cl_tab_achievements_desc'),
            -- icon = 'fa-solid fa-trophy',
            arrow = true,
            onSelect = function()
                local Achievements = lib.load('client.menu.pet_achievements')
                Achievements.ShowTab(companionid)
            end
        }
    end
    
    lib.registerContext({
        id = 'pet_dashboard',
        title = petName,
        menu = 'pet_dashboard_list',
        onBack = function() end,
        onExit = function()
        end,
        options = options
    })
    
    lib.showContext('pet_dashboard')

end


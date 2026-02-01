-- HERDING MENUS - Menu UI Functions
-- Parte de Advanced Herding System

local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
local herdingStates = exports['hdrp-pets']:GetHerdingStates()

---------------------------------
-- TOGGLE PET SELECTION FUNCTION
---------------------------------
---Alterna la selección de una mascota en el menú de selección individual
function TogglePetSelection(petData)
    local companionid = petData.companionid
    if not companionid then return end
    if herdingStates.selectedPets[companionid] then
        -- Deseleccionar
        herdingStates.selectedPets[companionid] = nil
        lib.notify({ 
            title = locale('cl_pet_deselected'), 
            description = string.format(locale('cl_pet_deselected_desc'), (petData.data and petData.data.info and petData.data.info.name)),
            type = 'inform',
            duration = 3000
        })
    else
        -- Validar máximo
        local selectedCount = 0
        for _ in pairs(herdingStates.selectedPets) do selectedCount = selectedCount + 1 end
        if selectedCount >= (Config.Herding.MaxAnimals or 10) then
            lib.notify({ 
                title = locale('cl_error_max_pets'), 
                description = string.format(locale('cl_error_max_pets_desc'), Config.Herding.MaxAnimals),
                type = 'error',
                duration = 5000
            })
            OpenIndividualSelectionMenu() -- Refrescar
            return
        end
        -- Seleccionar
        herdingStates.selectedPets[companionid] = petData
        lib.notify({ 
            title = locale('cl_pet_selected'), 
            description = string.format(locale('cl_pet_selected_desc'), (petData.data and petData.data.info and petData.data.info.name) ),
            type = 'success',
            duration = 3000
        })
    end
    -- Refrescar menú
    OpenIndividualSelectionMenu()
end

---------------------------------
-- CLEAR SELECTION FUNCTION
---------------------------------
---Limpia toda la selección de mascotas
function ClearPetSelection()
    local clearedCount = 0
    for _ in pairs(herdingStates.selectedPets) do clearedCount = clearedCount + 1 end
    herdingStates.selectedPets = {}
    lib.notify({ 
        title = locale('cl_selection_cleared'), 
        description = string.format(locale('cl_selection_cleared_desc'), clearedCount),
        type = 'inform',
        duration = 3000
    })
    OpenIndividualSelectionMenu()
end

---------------------------------
-- INDIVIDUAL SELECTION MENU
---------------------------------
function OpenIndividualSelectionMenu()
    local nearbyPets = GetNearbyCompanions()
    
    if #nearbyPets == 0 then
        lib.notify({ 
            title = locale('cl_herding_no_pets'), 
            description = locale('cl_herding_no_pets_near'),
            type = 'error',
            duration = 5000 
        })
        return
    end
    
    local options = {}
    
    -- Header with selection count
    local selectedCount = 0
    for _ in pairs(herdingStates.selectedPets) do
        selectedCount = selectedCount + 1
    end
    
    table.insert(options, {
        title = string.format(locale('cl_herding_selected_count'), selectedCount),
        description = string.format(locale('cl_herding_selected_count_desc'), selectedCount),
        -- icon = 'fa-solid fa-list-check',
        disabled = true
    })
    
    -- Start/Clear buttons if pets are selected
    if selectedCount > 0 then
        table.insert(options, {
            title = locale('cl_herding_start_selected'),
            description = string.format(locale('cl_herding_start_selected_desc'), selectedCount),
            -- icon = 'fa-solid fa-play',
            onSelect = function()
                StartSelectedHerding()
            end
        })
        
        table.insert(options, {
            title = locale('cl_herding_clear_selection'),
            description = locale('cl_herding_clear_selection_desc'),
            -- icon = 'fa-solid fa-times',
            onSelect = function()
                ClearPetSelection()
            end
        })

    end
    
    -- List individual pets with unified metadata
    for i, petData in ipairs(nearbyPets) do
        local isSelected = herdingStates.selectedPets[petData.companionid] ~= nil
        local info = (petData.data and petData.data.info) or petData.info or {}
        local stats = (petData.data and petData.data.stats) or petData.stats or {}
        local progression = (petData.data and petData.data.progression) or petData.progression or {}
        local displayName = info.name or petData.name or 'Pet'
        local distance = math.floor(petData.distance * 10) / 10
        local statusIcon = isSelected and 'fa-solid fa-check-square' or 'fa-regular fa-square'
        local statusText = isSelected and locale('cl_selected') or locale('cl_not_selected')
        local description = locale('cl_herding_toggle_select')
        if Config.Herding.ShowDistance then
            description = string.format(locale('cl_herding_distance_info'), math.floor(distance)) .. ' - ' .. description
        end
        -- Unified metadata (health, happiness, level, gender)
        local metadata = {}
        table.insert(metadata, {label = locale('cl_stat_health'), value = (stats.health or 0) .. '%', progress = stats.health or 0, colorScheme = '#359d93'})
        table.insert(metadata, {label = locale('cl_stat_happiness'), value = (stats.happiness or 0) .. '%', progress = stats.happiness or 0, colorScheme = (stats.happiness or 0) < 30 and '#F44336' or '#ffe066'})
        table.insert(metadata, {label = locale('cl_stat_level'), value = State.GetPetLevel and State.GetPetLevel(progression.xp or 0) or '-'})
        table.insert(metadata, {label = locale('ui_pet_gender'), value = info.gender or '-'})
        table.insert(options, {
            title = displayName .. ' #' .. i .. ' ' .. statusText,
            description = description,
            icon = statusIcon,
            metadata = metadata,
            onSelect = function()
                TogglePetSelection(petData)
            end
        })
    end
    
    lib.registerContext({
        id = 'hdrp_herding_individual',
        title = locale('cl_herding_individual_menu_title'),
        menu = 'hdrp_herding_main',
        options = options
    })
    
    lib.showContext('hdrp_herding_individual')
end

---------------------------------
-- FORMATION SELECTION MENU
---------------------------------
local function OpenFormationSelectionMenu()
    local options = {}
    local activePetsList = State.GetAllPets and State.GetAllPets() or {}
    local petsArray = {}
    for _, petData in pairs(activePetsList) do
        if petData and petData.spawned and DoesEntityExist(petData.ped) then
            table.insert(petsArray, petData)
        end
    end
    local petCount = #petsArray
    -- Experiencia mínima de todas las mascotas
    local minExp = math.huge
    for _, petData in ipairs(petsArray) do
        local xp = petData.companionxp or (petData.data and petData.data.companionxp) or 0
        if xp < minExp then minExp = xp end
    end
    if minExp == math.huge then minExp = 0 end

    -- Formaciones y requisitos
    local formationLabels = {
        formation_line = locale('cl_form_line'),
        formation_column = locale('cl_form_column'),
        formation_diamond = locale('cl_form_diamond'),
        formation_escalonada = locale('cl_form_escalonada'),
        formation_peloton = locale('cl_form_peloton'),
        formation_square = locale('cl_form_square'),
        formation_dispersed = locale('cl_form_dispersed'),
        formation_zigzag = locale('cl_form_zigzag'),
        formation_doublezigzag = locale('cl_form_doublezigzag'),
        formation_stair = locale('cl_form_stair'),
        formation_spiral = locale('cl_form_spiral'),
        formation_snail = locale('cl_form_snail'),
        formation_wave = locale('cl_form_wave'),
        formation_star = locale('cl_form_star'),
        formation_heart = locale('cl_form_heart'),
        formation_s = locale('cl_form_S'),
        formation_h = locale('cl_form_H'),
        formation_v = locale('cl_form_v'),
        formation_circle = locale('cl_form_circle'),
        formation_arc = locale('cl_form_arc')
    }
    local formationMinLimits = Config.Herding.formationMinLimits or {}
    local formationExpLimits = (Config.XP and Config.XP.Trick and Config.XP.Trick.formationExpLimits) or {}
    local patterns = {
        'formation_line','formation_column','formation_diamond','formation_escalonada','formation_peloton','formation_square','formation_dispersed','formation_zigzag','formation_doublezigzag','formation_stair','formation_spiral','formation_snail','formation_wave','formation_star','formation_heart','formation_s','formation_h','formation_v','formation_circle','formation_arc'
    }

    for _, fname in ipairs(patterns) do
        local minCount = formationMinLimits[fname] or 1
        local minExpReq = formationExpLimits[fname] or 0
        local enabled = (petCount >= minCount) and (minExp >= minExpReq)
        local label = formationLabels[fname] or fname
        local meta = {
            { label = locale('cl_form_count_min'), value = tostring(minCount) },
            { label = locale('cl_form_xp_min'), value = tostring(minExpReq) }
        }
        if not enabled then
            local reasons = {}
            if petCount < minCount then table.insert(reasons, locale('cl_form_no_pets')) end
            if minExp < minExpReq then table.insert(reasons, locale('cl_form_no_xp')) end
            for _, reason in ipairs(reasons) do
                table.insert(meta, { label = locale('cl_form_reason'), value = reason })
            end
        end
        table.insert(options, {
            title = label,
            metadata = meta,
            disabled = not enabled,
            onSelect = enabled and function()
                herdingStates.preferredFormation = fname
                -- Registrar formación desbloqueada en cada mascota activa
                for _, petData in ipairs(petsArray) do
                    petData.data = petData.data or {}
                    petData.data.formationsUnlockedList = petData.data.formationsUnlockedList or {}
                    local alreadyUnlocked = false
                    for _, f in ipairs(petData.data.formationsUnlockedList) do
                        if f == fname then alreadyUnlocked = true break end
                    end
                    if not alreadyUnlocked then
                        table.insert(petData.data.formationsUnlockedList, fname)
                    end
                    petData.data.formationsUnlocked = #petData.data.formationsUnlockedList
                end
                lib.notify({title = locale('cl_form_selected'), description = label, type = 'success'})
            end or nil
        })
    end
    lib.registerContext({
        id = 'hdrp_herding_formation',
        title = locale('cl_form_title'),
        menu = 'hdrp_herding_main',
        options = options
    })
    lib.showContext('hdrp_herding_formation')
end

---------------------------------
-- MAIN HERDING MENU
---------------------------------
---Abre el menú principal de herding con opciones dinámicas y robustas
function OpenHerdingMainMenu()
    local options = {}

    -- Toggle herding ON/OFF
    if herdingStates and herdingStates.active then
        table.insert(options, {
            title = locale('cl_herding_stop_title'),
            description = locale('cl_herding_stop_title_desc'),
            icon = 'fa-solid fa-power-off',
            onSelect = function()
                -- Detener herding en todas las mascotas activas
                local allPets = State.GetAllPets and State.GetAllPets() or {}
                for companionid, petData in pairs(allPets) do
                    if State.GetFlag(petData.ped, "isHerding") then
                        if StopPetHerding then StopPetHerding(companionid) end
                        if State.SetPetTrait then State.SetPetTrait(companionid, 'isWandering', true) end
                        if SetupPetWandering and petData.ped then SetupPetWandering(companionid, petData.ped, GetEntityCoords(petData.ped)) end
                    end
                end
                if StopHerding then StopHerding() end
                lib.notify({title = locale('cl_herding_stop_off'), description = locale('cl_herding_stop_off_desc'):format(#herdingStates.pets), type = 'warning'})
                OpenHerdingMainMenu()
            end
        })

        -- Herding por distancia
        if Config.Herding.DistanceSelection then
            table.insert(options, {
                title = locale('cl_herding_distance_title'),
                icon = 'fa-solid fa-ruler',
                description = string.format(locale('cl_herding_distance_desc'), Config.Herding.Distance),
                onSelect = function()
                    TriggerEvent('hdrp-pets:client:StartDistanceHerding')
                end
            })
        end

        -- Toggle modo automático/preferido
        if herdingStates.preferredFormation then
            table.insert(options, {
                title = locale('cl_herding_auto_mode_title'),
                description = locale('cl_herding_auto_mode_title_desc'),
                icon = 'fa-solid fa-random',
                onSelect = function()
                    herdingStates.preferredFormation = nil
                    lib.notify({title = locale('cl_herding_auto_mode_on'), description = locale('cl_herding_auto_mode_on_desc'), type = 'info'})
                    OpenHerdingMainMenu()
                end
            })
        end

        table.insert(options, {
            title = locale('cl_herding_formation_title'),
            description = locale('cl_herding_formation_desc'),
            icon = 'fa-solid fa-shapes',
            arrow = true,
            onSelect = function()
                OpenFormationSelectionMenu()
            end
        })

        -- Selección individual
        if Config.Herding.IndividualSelection then
            table.insert(options, {
                title = locale('cl_herding_individual_title'),
                description = locale('cl_herding_individual_desc'),
                icon = 'fa-solid fa-paw',
                arrow = true,
                onSelect = function()
                    OpenIndividualSelectionMenu()
                end
            })
        end
        
    else
        table.insert(options, {
            title = locale('cl_herding_start'),
            description = locale('cl_herding_start_desc'),
            icon = 'fa-solid fa-play',
            onSelect = function()
                -- Iniciar herding en las mascotas seleccionadas
                for companionid, petData in pairs(herdingStates.selectedPets or {}) do
                    if StopPetWandering then StopPetWandering(companionid) end
                    if State.SetPetTrait then State.SetPetTrait(companionid, 'isHerding', false) end
                    if SetupPetHerding and petData.ped then SetupPetHerding(companionid, petData.ped, {}) end
                end
                if StartHerdingSystem then StartHerdingSystem() end
                lib.notify({title = locale('cl_herding_start_title'), description = locale('cl_herding_start_title_desc'), type = 'success'})
                OpenHerdingMainMenu()
            end
        })
    end

    lib.registerContext({
        id = 'hdrp_herding_main',
        title = locale('cl_herding_menu_title'),
        options = options,
        menu = 'pet_main_menu',
        onExit = function()
            -- Cleanup if needed
        end
    })
    lib.showContext('hdrp_herding_main')
end
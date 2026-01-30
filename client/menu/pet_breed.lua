-- HDRP-PETS: Sistema de reproducción de mascotas (Breeding)
-- Autor: Adaptado de rex-ranch
-- Este archivo gestiona la lógica principal de reproducción en el cliente
local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
local Breeding = {}
local selectedMale, selectedFemale = nil, nil

local function openCustomPairingMenu()
    local options = {}
    local allPets = State.GetAllPets()

    -- Mostrar selección actual
    if selectedMale then
        local pet = allPets[selectedMale]
        local data = pet and pet.data or nil
        local info = data and data.info or {}
        local stats = data and data.stats or {}
        options[#options + 1] = {
            title = locale('cl_breed_selected_male') .. ': ' .. (info.name or selectedMale),
            metadata = {
                {label = locale('cl_stat_breed'), value = info.type or '-'},
            },
            onSelect = function()
                selectedMale = nil; 
                lib.showContext('breed_custom_pairing_menu')
            end,
            arrow = false
        }
    else
        options[#options + 1] = {
            title = locale('cl_breed_select_male'),
            arrow = true,
            onSelect = function()
                openSelectGenderMenu('male')
            end
        }
    end

    if selectedFemale then
        local pet = allPets[selectedFemale]
        local data = pet and pet.data or nil
        local info = data and data.info or {}
        local stats = data and data.stats or {}
        options[#options + 1] = {
            title = locale('cl_breed_selected_female') .. ': ' .. (info.name or selectedFemale),
            metadata = {
                {label = locale('cl_stat_breed'), value = info.type or '-'},
            },
            onSelect = function()
                selectedFemale = nil; 
                lib.showContext('breed_custom_pairing_menu')
            end,
            arrow = false
        }
    else
        options[#options + 1] = {
            title = locale('cl_breed_select_female'),
            arrow = true,
            onSelect = function()
                openSelectGenderMenu('female')
            end
        }
    end

    --[[ -- Confirmar cruce solo si ambos seleccionados
    if selectedMale and selectedFemale then
        options[#options + 1] = {
            title = locale('cl_breed_confirm_pairing'),
            description = locale('cl_breed_confirm_pairing_desc'),
            onSelect = function()
                lib.showContext('breed_custom_pairing_menu')
            end
        }
    end ]]

    -- Confirmar cruce solo si ambos seleccionados
    if selectedMale and selectedFemale then
        options[#options + 1] = {
            title = locale('cl_breed_confirm_pairing'),
            description = locale('cl_breed_confirm_pairing_desc'),
            onSelect = function()
                TriggerServerEvent('hdrp-pets:server:requestbreeding', selectedMale, selectedFemale)
                selectedMale, selectedFemale = nil, nil
                lib.showContext('breed_menu')
            end
        }
    end

    lib.registerContext({
        id = 'breed_custom_pairing_menu',
        title = locale('cl_breed_custom_select'),
        menu = 'breed_menu',
        options = options
    })
    lib.showContext('breed_custom_pairing_menu')
end

function openSelectGenderMenu(gender)
    local options = {}
    local allPets = State.GetAllPets()
    for companionid, pet in pairs(allPets) do
        local data = pet and pet.data or nil
        local info = data and data.info or {}
        local stats = data and data.stats or {}
        local vet = data and data.veterinary or {}
        if info.gender == gender and vet.breedable == true and not (vet.inbreed or false) and not (vet.breedingcooldown or false) then
            options[#options + 1] = {
                title = info.name or (locale('cl_pet_id') .. ': ' .. companionid),
                icon = gender == 'male' and 'mars' or 'venus',
                metadata = {
                    {label = locale('cl_stat_breed'), value = info.type or '-'},
                    {label = locale('cl_stat_bond'), value = (data and data.progression and data.progression.bonding) or '-'}
                },
                onSelect = function()
                    if gender == 'male' then selectedMale = companionid else selectedFemale = companionid end
                    openCustomPairingMenu()
                end
            }
        end
    end
    if #options == 0 then
        options[1] = {
            title = gender == 'male' and locale('cl_breed_no_males') or locale('cl_breed_no_females'),
            description = gender == 'male' and locale('cl_breed_no_males_desc') or locale('cl_breed_no_females_desc'),
            icon = gender == 'male' and 'mars' or 'venus',
            disabled = true
        }
    end
    lib.registerContext({
        id = 'breed_select_' .. gender .. '_menu',
        title = gender == 'male' and locale('cl_breed_select_male') or locale('cl_breed_select_female'),
        menu = 'breed_custom_pairing_menu',
        options = options
    })
    lib.showContext('breed_select_' .. gender .. '_menu')
end

-- Submenú: Parejas recomendadas para reproducción (selección automática de mascota base)
local function openRecommendedPairsMenu()
    local options = {}
    local allPets = State.GetAllPets()
    local candidate = nil
    -- Selecciona automáticamente la mejor mascota base (ejemplo: hembra disponible, si no, macho)
    for companionid, petData in pairs(allPets) do
        if petData and not (petData.data and petData.data.veterinary and petData.data.veterinary.inbreed) and not (petData.data and petData.data.veterinary and petData.data.veterinary.breedingcooldown) and (petData.data and petData.data.stats and petData.data.stats.health) and petData.data.stats.health >= 50 then
            if (petData.data and petData.data.info and petData.data.info.gender) == 'female' then
                candidate = companionid
                break
            elseif not candidate then
                candidate = companionid
            end
        end
    end
    if not candidate then
        options[1] = {
            title = locale('cl_breed_no_pet_available'),
            description = locale('cl_breed_no_pet_available_desc'),
            disabled = true
        }
        lib.registerContext({
            id = 'breed_recommended_menu',
            title = locale('cl_breed_recommended'),
            menu = 'breed_menu',
            options = options
        })
        lib.showContext('breed_recommended_menu')
        return
    end
    lib.callback('hdrp-pets:server:getavailablepartners', candidate, function(partners)
        if not partners or #partners == 0 then
            options[1] = {
                title = locale('cl_breed_no_recommended'),
                description = locale('cl_breed_no_recommended_desc'),
                disabled = true
            }
        else
            for _, partner in ipairs(partners) do
                options[#options + 1] = {
                    title = (partner.name or partner.id) .. (partner.gender == 'male' and ' ♂️' or ' ♀️'),
                    description = locale('cl_breed_partner_stats'):gsub('%%{age}', partner.age or '-')
                        :gsub('%%{health}', partner.health or '-'),
                    icon = partner.gender == 'male' and 'mars' or 'venus',
                    metadata = {
                        {label = locale('cl_stat_breed'), value = partner.breed or '-'},
                        {label = locale('cl_stat_gender'), value = partner.gender or '-'},
                        {label = locale('cl_stat_health'), value = partner.health or '-'},
                    },
                    onSelect = function()
                        TriggerServerEvent('hdrp-pets:server:requestbreeding', candidate, partner.id)
                    end
                }
            end
        end
        lib.registerContext({
            id = 'breed_recommended_menu',
            title = locale('cl_breed_recommended'),
            menu = 'breed_menu',
            options = options
        })
        lib.showContext('breed_recommended_menu')
    end)
end

-- Submenú: Estado y progreso de reproducción
local function openBreedingStatusMenu()
    local options = {}
    local allPets = State.GetAllPets()
    local pending = true
    local count = 0
    for companionid, petData in pairs(allPets) do
        local data = petData and petData.data or nil
        local info = data and data.info or {}
        local vet = data and data.veterinary or {}
        if info.gender == 'female' and vet.inbreed == true then
            count = count + 1
            lib.callback('hdrp-pets:server:getbreedingstatus', companionid, function(statusData)
                local desc = statusData.message or '-'
                local icon = 'fa-baby'
                local progress = nil
                local color = nil
                if statusData.status == 'pregnant' then
                    lib.callback('hdrp-pets:server:getpregnancyprogress', companionid, function(progressData)
                        progress = progressData.progressPercent or 0
                        color = '#4CAF50'
                        options[#options + 1] = {
                            title = (info.name or companionid),
                            description = desc,
                            metadata = {
                                {label = locale('cl_stat_breed'), value = info.type or '-'},
                                {label = locale('cl_stat_gender'), value = info.gender or '-'},
                                {label = locale('cl_stat_level'), value = (data.stats and data.stats.level) or '-'},
                                {label = locale('cl_breed_progress'), value = math.floor(progress) .. '%', progress = progress, colorScheme = color}
                            },
                            disabled = false
                        }
                        if #options == count then
                            lib.registerContext({
                                id = 'breed_status_menu',
                                title = locale('cl_breed_status_progress'),
                                menu = 'breed_menu',
                                options = options
                            })
                            lib.showContext('breed_status_menu')
                        end
                    end)
                    return
                end
                if #options == count then
                    lib.registerContext({
                        id = 'breed_status_menu',
                        title = locale('cl_breed_status_progress'),
                        menu = 'breed_menu',
                        options = options
                    })
                    lib.showContext('breed_status_menu')
                end
            end)
        end
    end
    if count == 0 then
        options[1] = {
            title = locale('cl_breed_no_pets'),
            description = locale('cl_breed_no_pets_desc'),
            -- icon = 'fa-paw',
            disabled = true
        }
        lib.registerContext({
            id = 'breed_status_menu',
            title = locale('cl_breed_status_progress'),
            menu = 'breed_menu',
            options = options
        })
        lib.showContext('breed_status_menu')
    end
end

-- Submenú: Historial de reproducción
local function openBreedingHistoryMenu()
    local options = {}
    lib.callback('hdrp-pets:server:getbreedinghistory', false, function(history)
        if not history or #history == 0 then
            options[1] = {
                title = locale('cl_breed_no_history'),
                description = locale('cl_breed_no_history_desc'),
                disabled = true
            }
        else
            for _, entry in ipairs(history) do
                local offspring = entry.offspring or '-'
                local parentA = entry.petA or '-'
                local parentB = entry.petB or '-'
                local date = entry.date and os.date('%Y-%m-%d %H:%M', entry.date) or '-'
                local action = entry.action or '-'
                local notes = entry.notes or ''
                options[#options + 1] = {
                    title = locale('cl_breed_event_title'):gsub('%%{offspring}', offspring),
                    description = locale('cl_breed_event_desc')
                        :gsub('%%{parentA}', parentA)
                        :gsub('%%{parentB}', parentB)
                        :gsub('%%{date}', date)
                        .. (notes ~= '' and ('\n' .. notes) or ''),
                    metadata = {
                        {label = locale('cl_breed_offspring'), value = offspring},
                        {label = locale('cl_breed_parent_a'), value = parentA},
                        {label = locale('cl_breed_parent_b'), value = parentB},
                        {label = locale('cl_breed_date'), value = date},
                        {label = locale('cl_breed_action'), value = action}
                    },
                    disabled = false
                }
            end
        end
        lib.registerContext({
            id = 'breed_history_menu',
            title = locale('cl_breed_history'),
            menu = 'breed_menu',
            options = options
        })
        lib.showContext('breed_history_menu')
    end)
end

function Breeding.openBreedMenu()
    local options = {}

    options[#options + 1] = {
        title = locale('cl_breed_custom_select'),
        description = locale('cl_breed_custom_select_desc'),
        arrow = true,
        onSelect = function()
            openCustomPairingMenu()
        end
    }

    options[#options + 1] = {
        title = locale('cl_breed_recommended'),
        description = locale('cl_breed_recommended_desc'),
        arrow = true,
        onSelect = function()
            openRecommendedPairsMenu()
        end
    }


    options[#options + 1] = {
        title = locale('cl_breed_status_progress'),
        description = locale('cl_breed_status_progress_desc'),
        arrow = true,
        onSelect = function()
            openBreedingStatusMenu()
        end
    }

    options[#options + 1] = {
        title = locale('cl_breed_history'),
        description = locale('cl_breed_history_desc'),
        arrow = true,
        onSelect = function()
            openBreedingHistoryMenu()
        end
    }

    lib.registerContext({
        id = 'breed_menu',
        title = locale('cl_breed_menu_title'),
        options = options,
        onBack = function() end,
    })

    lib.showContext('breed_menu')
end

RegisterCommand('pet_breed', function()
    Breeding.openBreedMenu()
end, false)

--[[ mostrar linaje en consola o UI ]]
function Breeding.openGenealogyMenu(petId)
    lib.callback('hdrp-pets:server:getgenealogy', petId, function(data)
        local options = {}
        if not data or not data.enabled then
            options[1] = {
                title = locale('cl_genealogy_not_available'),
                description = data and data.message or 'Genealogía no disponible',
                disabled = true
            }
        elseif not data.genealogy then
            options[1] = {
                title = locale('cl_genealogy_no_data'),
                description = data.message or 'Sin datos de linaje',
                disabled = true
            }
        else
            local genealogy = data.genealogy
            local parentA = genealogy.parent_a_data and json.decode(genealogy.parent_a_data) or nil
            local parentB = genealogy.parent_b_data and json.decode(genealogy.parent_b_data) or nil

            -- Helper para metadata
            local function buildParentMetadata(parent)
                if not parent then return {} end
                local meta = {}
                if parent.breed then table.insert(meta, {label = locale('cl_stat_breed'), value = parent.breed}) end
                 if parent.level then table.insert(meta, {label = locale('cl_stat_level'), value = parent.level}) end
                if parent.gender then table.insert(meta, {label = locale('cl_stat_gender'), value = parent.gender == 'female' and '♀️' or '♂️'}) end
                if parent.hasdisease then table.insert(meta, {label = locale('cl_stat_health'), value = '💀'}) end
                if parent.bond then table.insert(meta, {label = locale('cl_stat_bond'), value = parent.bond}) end
                return meta
            end

            options[#options + 1] = {
                title = locale('cl_genealogy_parent_a_label'):gsub('%%{name}', parentA and parentA.name or '-'),
                description = parentA and (parentA.breed and locale('cl_stat_breed') .. ': ' .. parentA.breed or '') or locale('cl_genealogy_no_data'),
                icon = parentA and (parentA.gender == 'female' and 'venus' or 'mars') or 'question',
                metadata = buildParentMetadata(parentA),
                disabled = not parentA
            }
            options[#options + 1] = {
                title = locale('cl_genealogy_parent_b_label'):gsub('%%{name}', parentB and parentB.name or '-'),
                description = parentB and (parentB.breed and locale('cl_stat_breed') .. ': ' .. parentB.breed or '') or locale('cl_genealogy_no_data'),
                icon = parentB and (parentB.gender == 'male' and 'mars' or 'venus') or 'question',
                metadata = buildParentMetadata(parentB),
                disabled = not parentB
            }
        end

        lib.registerContext({
            id = 'genealogy_pet_menu',
            title = locale('cl_genealogy_title'),
            menu = 'pet_dashboard',
            onBack = function() end,
            options = options 
        })
        lib.showContext('genealogy_pet_menu')
    end)
end

return Breeding
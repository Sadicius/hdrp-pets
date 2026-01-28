local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()

local function ShowPetMainMenu()
    local activePets = State.GetAllPets()
    local spawnedCount = State.GetActivePetCount()

    -- Calcular mascotas que requieren atención (needsCare)
    --[[
        local urgentPets = 0
        for _, pet in pairs(activePets) do
            local stats = pet.data and pet.data.stats or {}
            if (stats.hunger and stats.hunger < 30) or (stats.thirst and stats.thirst < 30) or (stats.dirt and stats.dirt > 80) or (stats.health and stats.health < 30) then
                urgentPets = urgentPets + 1
            end
        end
    ]]
    local options = {}

    -- OPTION 1: QUICK ACTIONS
    options[#options + 1] = {
        title = '⚡ ' .. locale('cl_pet_menu_quick_actions'),
        arrow = true,
        onSelect = function()
            local QuickActions = require('client.menu.quick_actions')
            QuickActions.ShowMenu()
        end
    }

    -- OPTION 2: QUICK CARE
    options[#options + 1] = {
        title = '⚡ ' .. locale('cl_pet_menu_quick_care'),
        arrow = true,
        onSelect = function()
            local QuickCare = require('client.menu.quick_care')
            QuickCare.ShowMenu()
        end
    }

    -- OPTION 3: MY PETS (Dashboard)
    local totalPets = 0
    local breedSet = {}
    local happinessSum = 0
    local favoritePet = nil
    local lastActivity = 'N/A'
    for _, pet in pairs(activePets) do
        totalPets = totalPets + 1
        local info = (pet.data and pet.data.info) or {}
        local vet = (pet.data and pet.data.veterinary) or {}
        local stats = (pet.data and pet.data.stats) or {}
        if vet.inbreed then
            breedSet[vet.inbreed] = true
        end
        if stats.happiness then
            happinessSum = happinessSum + stats.happiness
        end
        if pet.favorite then
            favoritePet = info.name
        end
        if pet.lastAction then
            lastActivity = pet.lastAction
        end
    end
    local breedCount = 0
    for _ in pairs(breedSet) do breedCount = breedCount + 1 end
    local avgHappiness = totalPets > 0 and math.floor(happinessSum / totalPets) or 0
    options[#options + 1] = {
        title = '📋 ' .. locale('cl_menu_my_pets'),
        metadata = {
            {label = locale('cl_pet_menu_total_pets'), value = spawnedCount},
            -- {label = locale('cl_pet_menu_breed_count'), value = breedCount},
            -- {label = locale('cl_pet_menu_avg_happiness'), value = avgHappiness .. '%'},
            -- {label = locale('cl_pet_menu_last_activity'), value = lastActivity},
            -- {label = locale('cl_pet_menu_favorite_pet'), value = favoritePet or locale('cl_none')},
        },
        arrow = true,
        onSelect = function()
            ShowPetDashboardList()
        end
    }

    -- TAB: BREEDING / REPRODUCCIÓN
    if Config.Reproduction.Enabled then
        options[#options + 1] = {
            title = locale('cl_tab_breeding'),
            arrow = true,
            onSelect = function()
                local Breeding = require('client.menu.pet_breed')
                Breeding.openBreedMenu()
            end
        }
    end

    -- OPTION 4: HERDING MODE (si multi-pet habilitado y 2+ pets)
    if Config.Herding.Enabled and spawnedCount >= 2 then
        options[#options + 1] = {
            title = '🐄 ' .. locale('cl_herding_menu_title'),
            arrow = true,
            onSelect = function()
                if Config.Herding.RequireTool and type(Config.Herding.ToolItem) == "table" then
                    for k, v in pairs(Config.Herding.ToolItem) do
                        local itemName = v
                        local hasItem = RSGCore.Functions.HasItem(itemName, 1)
                        if not hasItem then
                            lib.notify({ 
                                title = locale('cl_error_missing_tool'), 
                                description = string.format(locale('cl_error_need_tool'), RSGCore.SharedItems[itemName].label),
                                type = 'error',
                                duration = 5000 
                            })
                            return
                        end
                    end
                end
                OpenHerdingMainMenu()
            end
        }
    end

    Wait(100)
    lib.registerContext({
        id = 'pet_main_menu',
        title = locale('cl_pet_menu_title'),
        onExit = function() end,
        options = options
    })
    lib.showContext('pet_main_menu')
end

-- Comando para abrir el menú principal
RegisterCommand('pet_menu', function()
    ShowPetMainMenu()
end, false)
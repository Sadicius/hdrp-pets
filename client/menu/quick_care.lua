--[[
    HDRP-PETS - QUICK ACTIONS MENU
    Acciones rápidas para todas las mascotas
    Versión: 6.0.0
    
    Opciones:
    - Care: Feed All, Water All, Brush All, Store All
]]


local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
local QuickCare = {}

local function createQuickOption(title, statLabel, statValue, statIcon, hasItem, itemLabel, event, item)
    return {
        title = title,
        arrow = true,
        metadata = {
            {label = statLabel, value = statValue .. '%'},
            {label = locale('cl_status'), value = statIcon},
            {label = locale('cl_item_required'), value = hasItem and '✅' or '❌'}
        },
        onSelect = function()
            if not hasItem then
                lib.notify({ title = locale('cl_error_need_item'), type = 'error' })
                return
            end
            TriggerEvent(event, item)
        end
    }
end

function QuickCare.ShowMenu()
    RSGCore.Functions.TriggerCallback('hdrp-pets:server:getactivecompanions', function(serverPets)
        if not serverPets or #serverPets == 0 then
            lib.notify({ 
                title = locale('cl_no_active_pets'), 
                type = 'error', 
                duration = 5000 
            })
            return
        end

        -- Sincronizar State.Pets con los datos del servidor
        State.Pets = State.Pets or {}
        for _, dbPetData in ipairs(serverPets) do
            local companionid = dbPetData.companionid or dbPetData.animalid
            local petData = type(dbPetData.data) == 'string' and json.decode(dbPetData.data) or dbPetData.data or {}
            State.Pets[companionid] = State.Pets[companionid] or {}
            State.Pets[companionid].data = petData
            -- Puedes sincronizar otros campos si es necesario (flags, prompts, etc)
        end

        local pets = State.GetAllPets()
        if not pets or next(pets) == nil then
            lib.notify({ 
                title = locale('cl_no_active_pets'), 
                type = 'error', 
                duration = 5000 
            })
            return
        end

        -- Calcular resumen veterinario y peores stats
        local sick, vaccinated, healthy = 0, 0, 0
        local worstHunger, worstHungerName, worstHungerIcon = 100, '', '💚'
        local worstThirst, worstThirstName, worstThirstIcon = 100, '', '💚'
        local worstClean, worstCleanName, worstCleanIcon = 100, '', '💚'

        for companionid, pet in pairs(pets) do
            local data = pet.data or {}
            local vet = data.veterinary or {}
            local stats = data.stats or {}
            -- Resumen veterinario
            if vet.hasdisease then
                sick = sick + 1
            elseif vet.vaccineexpire and vet.vaccineexpire > os.time() then
                vaccinated = vaccinated + 1
            else
                healthy = healthy + 1
            end
            -- Peores stats
            local name = (data.info and data.info.name) or data.name or 'Unknown'
            local hunger = math.floor(tonumber(stats.hunger) or 100)
            local thirst = math.floor(tonumber(stats.thirst) or 100)
            local dirt = math.floor(tonumber(stats.dirt) or 0)
            local clean = 100 - dirt
            if hunger < worstHunger then
                worstHunger = hunger
                worstHungerName = name
                worstHungerIcon = hunger > 75 and '💚' or (hunger > 50 and '💛' or (hunger > 25 and '🧡' or '❤️'))
            end
            if thirst < worstThirst then
                worstThirst = thirst
                worstThirstName = name
                worstThirstIcon = thirst > 75 and '💚' or (thirst > 50 and '💛' or (thirst > 25 and '🧡' or '❤️'))
            end
            if clean < worstClean then
                worstClean = clean
                worstCleanName = name
                worstCleanIcon = clean > 75 and '💚' or (clean > 50 and '💛' or (clean > 25 and '🧡' or '❤️'))
            end
        end

        local options = {}
        -- Opción de resumen veterinario
        options[#options + 1] = {
            title = '🩺 ' .. locale('cl_vet_summary'),
            metadata = {
                {label = locale('cl_urgent_pets'), value = sick},
                {label = locale('cl_vaccinated_pets'), value = vaccinated},
                {label = locale('cl_healthy_pets'), value = healthy},
            }
        }

        -- Opciones de acciones rápidas
        local itemfoodsend = Config.Items.Food
        local hasItemF = RSGCore.Functions.HasItem(itemfoodsend)
        options[#options + 1] = createQuickOption( '🍖 ' .. locale('cl_action_feed_all'), locale('cl_stat_hunger'), worstHunger, worstHungerIcon, hasItemF, itemfoodsend, 'hdrp-pets:client:feed', itemfoodsend )

        local itemdrinksend = Config.Items.Drink
        local hasItemW = RSGCore.Functions.HasItem(itemdrinksend)
        options[#options + 1] = createQuickOption( '💧 ' .. locale('cl_action_water_all'), locale('cl_stat_thirst'), worstThirst, worstThirstIcon, hasItemW, itemdrinksend, 'hdrp-pets:client:feed', itemdrinksend )

        local itembrushsend = Config.Items.Brush
        local hasItemC = RSGCore.Functions.HasItem(itembrushsend)
        options[#options + 1] = createQuickOption( '🧼 ' .. locale('cl_action_brush_all'), locale('cl_stat_cleanliness'), worstClean, worstCleanIcon, hasItemC, itembrushsend, 'hdrp-pets:client:brush', itembrushsend )

        local itemrevivesend = Config.Items.Revive
        local hasItem = RSGCore.Functions.HasItem(itemrevivesend)
        options[#options + 1] = createQuickOption( '💊 ' .. locale('cl_action_revive'), locale('cl_stat_health'), 0, '❤️', hasItem, itemrevivesend, 'hdrp-pets:client:feed', itemrevivesend )

        lib.registerContext({
            id = 'quick_care_menu',
            title = locale('cl_pet_menu_quick_care'),
            menu = 'pet_main_menu',
            onBack = function() end,
            options = options
        })
        lib.showContext('quick_care_menu')
    end)
end

return QuickCare
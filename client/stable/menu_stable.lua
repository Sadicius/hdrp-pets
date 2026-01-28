-- Helper: muestra 'hace X días' o 'Nunca' para un timestamp

local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
---------------------------------------------------------------------
-- STABLE MAIN MENU
---------------------------------------------------------------------
RegisterNetEvent('hdrp-pets:client:stablemenu', function(stableid)
    if not stableid then return end
    

    local options = {}

    options[#options + 1] = {
        title = locale('cl_menu_pet_management'),
        arrow = true,
        event = 'hdrp-pets:client:petmanagement',
        args = { stableid = stableid },
    }

    options[#options + 1] = {
        title = '🩺 ' .. locale('cl_menu_veterinary_services'),
        arrow = true,
        event = 'hdrp-pets:client:veterinaryservices',
        args = { stableid = stableid },
    }
        
    if Config.EnablePetCustom then
        options[#options + 1] = {
            title = locale('cl_menu_pet_customization'),
            icon = 'fa-solid fa-screwdriver-wrench',
            arrow = true,
            onSelect = function()
                local activePets = State.GetAllPets()
                local petOptions = {}
                for companionid, petData in pairs(activePets) do
                    if petData and petData.data then
                        petOptions[#petOptions+1] = {
                            title = petData.data.info.name or (locale('cl_pet_default')..' #'..tostring(companionid)),
                            icon = 'fa-solid fa-dog',
                            onSelect = function()
                                TriggerEvent('hdrp-pets:client:custShop', {
                                    companionid = companionid,
                                    stableid = stableid
                                })
                            end
                        }
                    end
                end
                if #petOptions == 0 then
                    lib.notify({ title = locale('cl_error_menu_no_pets'), type = 'error', duration = 7000 })
                    return
                end
                lib.registerContext({
                    id = 'select_pet_for_customize',
                    title = locale('cl_menu_pet_customize'),
                    menu = 'pet_customization_menu',
                    options = petOptions
                })
                lib.showContext('select_pet_for_customize')
            end
        }
    end

    -- Otras opciones
    if Config.EnableBuyPetMenu then
        options[#options + 1] = {
            title = locale('cl_menu_buy_pets'),
            event = 'hdrp-pets:client:buypetsmenu',
            args = { stableid = stableid },
            arrow = true,
            -- metadata = { {label = locale('cl_menu_buy_pets'), value = locale('ui_menu_buy')} },
        }
    end
    
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
    
    options[#options + 1] = {
        title = locale('cl_menu_pet_shop'),
        event = 'hdrp-pets:client:shop',
        arrow = true,
        -- metadata = { {label = locale('cl_menu_pet_shop'), value = locale('ui_menu_shop')} },
    }
    
    options[#options + 1] = {
        title = locale('cl_menu_store_pet'),
        onSelect = function()
            ExecuteCommand('pet_store')
        end,
        --event = 'hdrp-pets:client:storecompanion',
        -- args = { stableid = stableid },
        arrow = true,
        -- metadata = { {label = locale('cl_menu_store_pet'), value = locale('ui_stable_pet')} },
    }
    
    lib.registerContext({
        id = 'stable_companions_menu',
        title = locale('cl_menu_pet_stable'),
        options = options
    })
    lib.showContext("stable_companions_menu")
end)

---------------------------------------------------------------------
-- MOVE PETS - Companion menu change stable
---------------------------------------------------------------------
local function SelectDestinationStable(petId, currentStableId)
    local options = {}
    local currentStable = nil
    
    -- Find current stable coordinates
    for _, stableConfig in pairs(Config.PetStables) do
        if stableConfig.stableid == currentStableId then
            currentStable = stableConfig
            break
        end
    end
    
    for _, stableConfig in pairs(Config.PetStables) do
        if stableConfig.stableid ~= currentStableId then
            local baseFee = Config.MovePetBasePrice
            local feePerMeter = Config.MoveFeePerMeter
            local distance = #(currentStable.coords - stableConfig.coords)
            local cost = math.ceil(baseFee + (distance * feePerMeter))
            options[#options + 1] = {
                title = stableConfig.stableid:upper(),
                description = string.format(locale('cl_move_pet_cost'), cost),
                arrow = false,
                onSelect = function()
                    TriggerServerEvent('hdrp-pets:server:movepet', petId, stableConfig.stableid)
                    lib.showContext('stable_companions_menu')
                end
            }
        end
    end

    lib.registerContext({
        id = 'move_destination_pet_menu',
        title = locale('cl_move_select_pet_stable'),
        position = 'top-right',
        menu = 'move_companions_menu',
        onBack = function() end,
        options = options
    })
    lib.showContext('move_destination_pet_menu')
end

RegisterNetEvent('hdrp-pets:client:movepet', function(data)

    local companions = lib.callback.await('hdrp-pets:server:getcompanion', false, data.stableid)
    if not companions or #companions == 0 then
        lib.notify({ title = locale('cl_error_menu_no_pets'), type = 'error', duration = 7000 })
        return
    end

    local options = {}
    for _, v in pairs(companions) do
        local petData = type(v.data) == 'string' and json.decode(v.data) or v.data or {}
        local info = petData.info or {}
        local progression = petData.progression or {}
        local isActive = v.active == true or v.active == 1
        options[#options + 1] = {
            title = info.name or (locale('cl_pet_default')..' #'..tostring(v.companionid)),
            arrow = true,
            metadata = {
                {label = locale('cl_stat_level'), value = State.GetPetLevel and State.GetPetLevel(progression.xp or 0) or '-'},
                {label = locale('ui_pet_gender'), value = info.gender or '-'},
                {label = locale('cl_status'), value = isActive and locale('cl_status_active') or locale('cl_status_inactive')},
                {label = locale('cl_stat_xp'), value = progression.xp or 0},
            },
            onSelect = function()
                SelectDestinationStable(v.companionid, data.stableid)
            end
        }
    end

    lib.registerContext({
        id = 'move_companions_menu',
        title = locale('cl_move_select_pet'),
        position = 'top-right',
        menu = 'stable_companions_menu',
        onBack = function() end,
        options = options
    })
    lib.showContext('move_companions_menu')
end)

---------------------------------------------------------------------
-- VIEW PETS - Companion menu active
---------------------------------------------------------------------
RegisterNetEvent('hdrp-pets:client:menu', function(data)

        local companions = lib.callback.await('hdrp-pets:server:getcompanion', false, data.stableid)
        if not companions or #companions == 0 then
            lib.notify({ title = locale('cl_error_menu_no_pets'), type = 'error', duration = 7000 })
            return
        end

        local options = {}
        for k, v in pairs(companions) do
            local petData = json.decode(v.data) or {}
            local info = petData.info or {}
            local stats = petData.stats or {}
            local vet = petData.veterinary or {}
            local progression = petData.progression or {}
            local isActive = v.active == true or v.active == 1
            local statusIcon = isActive and '✅' or '⬜'
            local statusText = isActive and locale('cl_info_pet_active') or locale('ui_pet_status_stored')
            local isDead = vet.dead == true or (stats.health and stats.health <= 0)
            local healthIcon = isDead and '💀' or '❤️'

            local metadata = {}
            table.insert(metadata, {label = locale('cl_stat_health'), value = (stats.health or 0) .. '%', progress = stats.health or 0, colorScheme = '#359d93' })
            table.insert(metadata, {label = locale('cl_stat_hunger'), value = (stats.hunger or 0) .. '%', progress = stats.hunger or 0, colorScheme = (stats.hunger or 0) < 30 and '#F44336' or '#bfe6ef' })
            table.insert(metadata, {label = locale('cl_stat_thirst'), value = (stats.thirst or 0) .. '%', progress = stats.thirst or 0, colorScheme = (stats.thirst or 0) < 30 and '#F44336' or '#447695' })
            table.insert(metadata, {label = locale('cl_stat_happiness'), value = (stats.happiness or 0) .. '%', progress = stats.happiness or 0, colorScheme = (stats.happiness or 0) < 30 and '#F44336' or '#ffe066' })
            table.insert(metadata, {label = locale('cl_stat_strength'), value = (stats.strength or 0) .. '%', progress = stats.strength or 0, colorScheme = (stats.strength or 0) < 30 and '#F44336' or '#b3e6b3' })
            table.insert(metadata, {label = locale('cl_stat_dirt'), value = (stats.dirt or 0) .. '%', progress = 100 - (stats.dirt or 0), colorScheme = (stats.dirt or 0) > 70 and '#F44336' or '#b3e6b3' })
            table.insert(metadata, {label = locale('cl_stat_age'), value = (stats.age or 0) .. ' ' .. locale('cl_stat_days') })
            table.insert(metadata, {label = locale('cl_stat_level'), value = State.GetPetLevel and State.GetPetLevel(progression.xp or 0) or '-' })
            table.insert(metadata, {label = locale('cl_stat_xp'), value = progression.xp or 0 })
            table.insert(metadata, {label = locale('cl_stat_breed'), value = info.type or '-' })
            -- Estado veterinario
            local vetStatus = (vet.hasdisease and 'Enfermo') or (vet.isvaccinated and vet.vaccinationdate and 'Vacunado' or 'Sano')
            table.insert(metadata, {label = 'Veterinario', value = vetStatus })
            -- Esterilización
            if vet.issterilized and vet.sterilizationdate then
                table.insert(metadata, {label = 'Esterilizado', value = vet.sterilizationdate })
            end
            -- Cría
            if vet.breedable then
                local breedStatus = vet.inbreed and 'En cría' or 'Disponible'
                table.insert(metadata, {label = locale('cl_stat_breed'), value = vet.breedable or '-' })
                table.insert(metadata, {label = 'Estado', value = breedStatus })
            end

            options[#options + 1] = {
                title = statusIcon .. ' ' .. (info.name or (locale('cl_pet_default')..' #'..tostring(v.id))) .. ' ' .. healthIcon,
                description = locale('cl_status') .. ': ' .. statusText .. ' | XP: ' .. (progression.xp or 0) .. ' | ' .. locale('ui_pet_gender') .. ': ' .. (info.gender or 'unknown'),
                metadata = metadata,
                arrow = true,
                onSelect = function()
                    if isActive then
                        lib.notify({ 
                            title = info.name or (locale('cl_pet_default')..' #'..tostring(v.id)),
                            description = locale('cl_info_pet_active'), 
                            type = 'inform', 
                            duration = 3000 
                        })
                    else
                        lib.callback.await('hdrp-pets:server:setactive', false, v.companionid)
                        TriggerEvent('hdrp-pets:client:menu', data)
                    end
                end
            }
        end

        lib.registerContext({
            id = 'companions_view',
            title = locale('cl_menu_my_pets'),
            menu = 'stable_companions_menu',
            options = options
        })
        lib.showContext('companions_view')
end)

---------------------------------------------------------------------
-- SELL PETS
---------------------------------------------------------------------
-- Throttle para callbacks de menú
-- SELL PETS ('hdrp-pets:client:MenuDel')
--================================
local throttleTimestamps = {}
local throttleDelay = 150  -- 150ms throttle window

local function GetThrottleKey(eventName)
    return eventName
end

local function IsThrottled(eventName)
    local key = GetThrottleKey(eventName)
    local lastTime = throttleTimestamps[key] or 0
    local currentTime = GetGameTimer()
    
    if (currentTime - lastTime) >= throttleDelay then
        throttleTimestamps[key] = currentTime
        return false  -- NOT throttled, proceed
    end
    
    if Config.Debug then
        print(string.format('^3[THROTTLE]^7 ' .. locale('cl_info_throttle_event_throttled'), eventName, (throttleDelay - (currentTime - lastTime))))
    end
    return true  -- Throttled, skip
end

-- Reset player state

RegisterNetEvent('hdrp-pets:client:MenuDel', function(data)
    local companions = lib.callback.await('hdrp-pets:server:getcompanion', false, data.stableid)
    if not companions or #companions == 0 then
        lib.notify({ title = locale('cl_error_menu_no_pets'), type = 'error', duration = 7000 })
        return
    end

    local options = {}
    for _, v in pairs(companions) do
        local petData = type(v.data) == 'string' and json.decode(v.data) or v.data or {}
        local info = petData.info or {}
        local progression = petData.progression or {}
        options[#options + 1] = {
            title = info.name or (locale('cl_pet_default')..' #'..tostring(v.companionid)),
            metadata = {
                {label = locale('cl_menu_sell_pet'), value = 'XP: ' .. (progression.xp or 0)},
            },
            onSelect = function()
                if IsThrottled('hdrp-pets:server:delete') then
                    lib.notify({ title = locale('cl_error_wait'), type = 'error', duration = 2000 })
                    return
                end
                TriggerServerEvent('hdrp-pets:server:delete', { companionid = v.companionid })
            end,
            arrow = true
        }
    end
    
    lib.registerContext({
        id = 'sellcompanion_menu',
        title = locale('cl_menu_sell_pet'),
        menu = 'stable_companions_menu',
        options = options
    })
    lib.showContext('sellcompanion_menu')
end)

---------------------------------------------------------------------
-- SHOP SUPPLIES
---------------------------------------------------------------------
AddEventHandler('hdrp-pets:client:shop', function()
    TriggerServerEvent('rsg-shops:server:openstore', 'pets', 'pets', locale('cl_menu_pet_shop'))
end)

---------------------------------------------------------------------
-- BUY PETS MENU
---------------------------------------------------------------------
RegisterNetEvent('hdrp-pets:client:buypetsmenu', function(data)
    local stableid = data.stableid
    if not stableid or not Config.PetShopPrice then return end
    
    -- Filter pets by stable
    local availablePets = {}
    for k, v in pairs(Config.PetShopPrice) do
        if v.stableid == stableid then
            table.insert(availablePets, v)
        end
    end
    
    if #availablePets == 0 then
        lib.notify({ title = locale('cl_error_no_pets_available'), type = 'error', duration = 5000 })
        return
    end
    
    local options = {}
    for k, pet in pairs(availablePets) do
        options[#options + 1] = {
            title = pet.label or pet.npcpetmodel,
            arrow = true,
            metadata = {
                {label = locale('sv_log_price'), value = '$' .. pet.npcpetprice},
                {label = locale('cl_buy_pet_type'), value = table.concat(pet.type or {}, ', ')},
            },
            onSelect = function()
                -- Input dialog for name and gender
                local dialog = lib.inputDialog(locale('cl_input_setup'), {
                    { type = 'input', label = locale('cl_input_setup_name') },
                    {
                        type = 'select',
                        label = locale('cl_input_setup_gender'),
                        options = {
                            { value = 'male',   label = locale('cl_input_setup_gender_a') },
                            { value = 'female', label = locale('cl_input_setup_gender_b') }
                        }
                    }
                })
                
                if not dialog then return end
                
                local setName = dialog[1] or 'Unnamed'
                local setGender = nil
                
                if not dialog[2] then
                    local genderNo = math.random(2)
                    if genderNo == 1 then
                        setGender = 'male'
                    elseif genderNo == 2 then
                        setGender = 'female'
                    end
                else
                    setGender = dialog[2]
                end
                
                -- Trigger server event to buy pet
                if setName and setGender then
                    TriggerServerEvent('hdrp-pets:server:buy', pet.npcpetprice, pet.npcpetmodel, stableid, setName, setGender, pet.type)
                end
            end
        }
    end
    
    lib.registerContext({
        id = 'buy_pets_menu',
        title = locale('cl_menu_buy_pets'),
        menu = 'stable_companions_menu',
        options = options
    })
    lib.showContext('buy_pets_menu')
end)

----------------------------------------------------------------------
-- STORE PETS - Store all active pets in stable
----------------------------------------------------------------------
-- Helper function: Store active pets in stable
--[[ RegisterNetEvent('hdrp-pets:client:storecompanion', function(stableid)
    local activePets = State.GetAllPets()
    local petOptions = {}
    local petDataMap = {}

    for companionid, petData in pairs(activePets) do
        if petData and petData.spawned and DoesEntityExist(petData.ped) then
            local info = petData.data and petData.data.info or {}
            local name = info.name or (locale('cl_pet_default') .. ' ' .. companionid)
            table.insert(petOptions, { value = companionid, label = name })
            petDataMap[companionid] = petData
        end
    end

    if #petOptions == 0 then
        lib.notify({ title = locale('cl_error_pet_no_active'), type = 'error', duration = 7000 })
        return
    end

    local dialog = lib.inputDialog(locale('cl_input_store_pet'), {
        {
            type = 'select',
            label = locale('cl_select_pet_to_store'),
            options = petOptions,
            required = true,
            -- icon = 'fa-solid fa-paw',
            default = petOptions[1].label
        }
    })

    if not dialog or not dialog[1] then return end
    local selectedId = dialog[1]
    local petData = petDataMap[selectedId]
    if not petData then return end

    -- Desactivar en base de datos
    TriggerServerEvent('hdrp-pets:server:store', selectedId, stableid)

    -- Eliminar del cliente si está invocada
    if petData and petData.ped then
        Flee(petData.ped)
    end

    lib.notify({
        title = locale('cl_success_pet_storing'),
        description = locale('cl_success_store_all'):format(1),
        type = 'success',
        duration = 7000
    })
end)
 ]]
----------------------------------------------------------------------
-- PET MANAGEMENT MENU
----------------------------------------------------------------------
RegisterNetEvent('hdrp-pets:client:petmanagement', function(data)
    local stableid = data.stableid
    local gestionOptions = {
        {
            title = locale('cl_menu_view_pets'),
            event = 'hdrp-pets:client:menu',
            args = { stableid = stableid },
            arrow = true,
            metadata = { {label = locale('cl_menu_view_pets'), value = locale('ui_menu_info')} },
        },
        
        {
            title = locale('cl_menu_move_pets'),
            event = 'hdrp-pets:client:movepet',
            args = { stableid = stableid },
            arrow = true,
            metadata = { {label = locale('cl_menu_move_pets'), value = locale('ui_menu_info')} },
        },
        {
            title = locale('cl_menu_trade_pet'),
            onSelect = function()
                ExecuteCommand('pet_trade')
            end,
            arrow = true,
            metadata = {  {label = locale('cl_menu_trade_pet'), value = locale('ui_menu_trade')} },
        },
        {
            title = locale('cl_menu_sell_pet'),
            event = 'hdrp-pets:client:MenuDel',
            args = { stableid = stableid },
            arrow = true,
            metadata = { {label = locale('cl_menu_sell_pet'), value = locale('ui_menu_sell')} },
        }
    }   

    lib.registerContext({
        id = 'pet_management_menu',
        title = locale('cl_menu_pet_management'),
        menu = 'stable_companions_menu',
        options = gestionOptions
    })
    lib.showContext('pet_management_menu')
end)

---------------------------------------------------------------------
-- PET CUSTOMIZATION MENU
---------------------------------------------------------------------
RegisterNetEvent('hdrp-pets:client:petcustomization', function(data)
    local stableid = data.stableid
    local customOptions = {}
    if Config.EnablePetCustom then
        customOptions[#customOptions + 1] = {
            title = locale('cl_menu_pet_customize'),
            arrow = true,
            onSelect = function()
                local activePets = State.GetAllPets()
                local petOptions = {}
                for companionid, petData in pairs(activePets) do
                    if petData and petData.data then
                        petOptions[#petOptions+1] = {
                            title = petData.data.info.name or (locale('cl_pet_default')..' #'..tostring(companionid)),
                            onSelect = function()
                                local d = petData.data or {}
                                TriggerEvent('hdrp-pets:client:custShop', {
                                    player = {
                                        companionid = companionid,
                                        stable = d.stable or petData.stable or data.stableid,
                                        companion = info.model or d.npcpetmodel,
                                        name = info.name,
                                        companionxp = progression.xp,
                                        -- añade aquí otros campos mínimos si los necesitas
                                    }
                                })
                            end
                        }
                    end
                end
                if #petOptions == 0 then
                    lib.notify({ title = locale('cl_error_menu_no_pets'), type = 'error', duration = 7000 })
                    return
                end
                lib.registerContext({
                    id = 'select_pet_for_customize',
                    title = locale('cl_menu_pet_customize'),
                    menu = 'pet_customization_menu',
                    options = petOptions
                })
                lib.showContext('select_pet_for_customize')
            end
        }
    end
    lib.registerContext({
        id = 'pet_customization_menu',
        title = locale('cl_menu_pet_customization'),
        menu = 'stable_companions_menu',
        options = customOptions
    })
    lib.showContext('pet_customization_menu')
end)

---------------------------------------------------------------------
-- VETERINARY SERVICES MENU
---------------------------------------------------------------------
RegisterNetEvent('hdrp-pets:client:veterinaryservices', function(data)
    local stableid = data.stableid
    local companions = lib.callback.await('hdrp-pets:server:getcompanion', false, stableid)
    if not companions or #companions == 0 then
        lib.notify({ title = locale('cl_error_menu_no_pets'), type = 'error', duration = 7000 })
        return
    end
    local vetOptions = {}
    for _, pet in ipairs(companions) do
        local petData = type(pet.data) == 'string' and json.decode(pet.data) or pet.data or {}
        local info = petData.info or {}
        local vet = petData.veterinary or {}
        local status = 'Sano'
        if vet.hasdisease then status = 'Enfermo' end
        if vet.isvaccinated and vet.vaccineexpire and (not vet.vaccineexpire or os.time() < vet.vaccineexpire) then
            status = 'Vacunado'
        end

        local metadata = {}
        table.insert(metadata, 1, {label = locale('cl_status'), value = status})
        table.insert(metadata, {label = locale('cl_stat_health'), value = (vet.dead and '💀' or '❤️') })
        -- Vacunación
        if vet.vaccinationdate and vet.vaccineexpire then
            table.insert(metadata, {label = locale('cl_vet_vaccination'), value = locale('cl_vet_event_format', vet.vaccinationdate, vet.vaccineexpire) })
        else
            table.insert(metadata, {label = locale('cl_vet_vaccination'), value = locale('cl_vet_event_never')})
        end
        -- Último chequeo
        if vet.lastcheckup and vet.daysatcheckup then
            table.insert(metadata, {label = locale('cl_vet_checkup'), value = locale('cl_vet_event_format', vet.lastcheckup, vet.daysatcheckup) })
        else
            table.insert(metadata, {label = locale('cl_vet_checkup'), value = locale('cl_vet_event_never')})
        end
        -- Última cirugía
        if vet.lastsurgery and vet.daysatsurgery then
            table.insert(metadata, {label = locale('cl_vet_surgery'), value = locale('cl_vet_event_format', vet.lastsurgery, vet.daysatsurgery) })
        else
            table.insert(metadata, {label = locale('cl_vet_surgery'), value = locale('cl_vet_event_never')})
        end
        -- Esterilización
        if vet.sterilizationdate and vet.daysatsterilization then
            table.insert(metadata, {label = locale('cl_vet_sterilization'), value = locale('cl_vet_event_format', vet.sterilizationdate, vet.daysatsterilization) })
        else
            table.insert(metadata, {label = locale('cl_vet_sterilization'), value = locale('cl_vet_event_never')})
        end
        vetOptions[#vetOptions+1] = {
            title = info.name or (locale('cl_pet_default')..' #'..tostring(pet.companionid)),
            arrow = true,
            metadata = metadata,
            onSelect = function()
                local actions = {
                    {
                        title = locale('cl_menu_vet_checkup'),
                        onSelect = function()
                            TriggerServerEvent('hdrp-pets:server:fullcheckup', pet.companionid)
                        end
                    },
                    {
                        title = locale('cl_menu_vet_vaccination'),
                        disabled = status == 'Vacunado',
                        onSelect = function()
                            TriggerServerEvent('hdrp-pets:server:vaccination', pet.companionid)
                        end
                    },
                    {
                        title = locale('cl_menu_vet_surgery'),
                        disabled = vet.dead or false,
                        onSelect = function()
                            TriggerServerEvent('hdrp-pets:server:surgery', pet.companionid)
                        end
                    },
                    {
                        title = locale('cl_menu_vet_sterilization'),
                        disabled = vet.sterilizationdate ~= nil,
                        onSelect = function()
                            TriggerServerEvent('hdrp-pets:server:sterilization', pet.companionid)
                        end
                    }
                }
                lib.registerContext({
                    id = 'veterinary_actions_'..tostring(pet.companionid),
                    title = (info.name or (locale('cl_pet_default')..' #'..tostring(pet.companionid))) .. ' - ' .. locale('cl_menu_veterinary_services'),
                    menu = 'veterinary_services_menu',
                    options = actions
                })
                lib.showContext('veterinary_actions_'..tostring(pet.companionid))
            end
        }
    end
    lib.registerContext({
        id = 'veterinary_services_menu',
        title = locale('cl_menu_veterinary_services'),
        menu = 'stable_companions_menu',
        options = vetOptions
    })
    lib.showContext('veterinary_services_menu')
end)

---------------------------------------------------------------------
-- GET LOCATION - STABLE INFO
---------------------------------------------------------------------
RegisterNetEvent('hdrp-pets:client:getlocation', function()
    RSGCore.Functions.TriggerCallback('hdrp-pets:server:getallcompanions', function(results)
        if results then
            local options = {}
            for _, result in ipairs(results) do
                local petData = type(result.data) == 'string' and json.decode(result.data) or result.data or {}
                local info = petData.info or {}
                options[#options + 1] = {
                    title = info.name or (locale('cl_pet_default')..' #'..tostring(result.companionid)),
                    description = locale('cl_info_pet_stable')..' '..(result.stable or '-')..' '..locale('cl_info_pet_active')..': '..tostring(result.active),
                }
            end
            lib.registerContext({
                id = 'showcompanion_menu',
                title = locale('cl_action_find_pet'),
                position = 'top-right',
                options = options
            })
            lib.showContext('showcompanion_menu')
        else
            lib.notify({ title = locale('cl_error_pet_no_active'), type = 'error', duration = 7000 })
        end
    end)
end)
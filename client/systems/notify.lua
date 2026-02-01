local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

----------------------------------
-- Client Decay Display System
-- Sistema de visualización del decaimiento
----------------------------------
-- Variables Locales
local State = exports['hdrp-pets']:GetState()
local lastDecayNotification = 0
local decayNotificationCooldown = 30000 -- 30 segundos

-- Monitoring del estado de mascotas
local function showDecayWarning(petData, petRecord)
    local warnings = {}
    
    if petData.stats.hunger and petData.stats.hunger < 30 then
        table.insert(warnings, locale('cl_decay_very_hungry'))
    end

    if petData.stats.thirst and petData.stats.thirst < 30 then
        table.insert(warnings, locale('cl_decay_very_thirsty'))
    end
    
    if petData.stats.dirt and petData.stats.dirt < 20 then
        table.insert(warnings, locale('cl_decay_very_dirty'))
    end
    
    if petData.stats.happiness and petData.stats.happiness < 20 then
        table.insert(warnings, locale('cl_decay_very_unhappy'))
    end

    if petData.stats.health and petData.stats.health < 50 then
        table.insert(warnings, locale('cl_decay_critical_health'))
    end

    if petData.veterinary.hasdisease == true then
        table.insert(warnings, locale('cl_decay_has_disease') or 'Enfermo')
    end

    if petData.veterinary.isvaccinated == false then
        table.insert(warnings, locale('cl_decay_unvaccinated') or 'No vacunado')
    end

    if petData.stats.hunger < 10 or petData.stats.thirst < 10 then 
        table.insert(warnings, locale('cl_error_retrieve') or 'Esta cansado')
    end
    
    if petData.veterinary.isdead == true then
        table.insert(warnings, locale('cl_error_pet_dead') or 'Muerto')
    end

    if next(warnings) then
        lib.notify({
            type = 'warning',
            title = petData.info.name or locale('cl_pet_your'),
            description = table.concat(warnings, ', '),
            duration = 5000
        })
    end
end

local function checkPetCondition(petData, petRecord)
    local currentTime = GetGameTimer()
    
    -- Verificar si hay cambios significativos
    local isHungry = petData.stats.hunger and petData.stats.hunger < 30
    local isThirsty = petData.stats.thirst and petData.stats.thirst < 30
    local isDirty = petData.stats.dirt and petData.stats.dirt < 20
    local isUnhappy = petData.stats.happiness and petData.stats.happiness < 20
    local isUnhealthy = petData.stats.health and petData.stats.health < 50
    local isDiseased = petData.veterinary.hasdisease == true
    local isUnvaccinated = petData.veterinary.isvaccinated == false
    local isDead = petData.veterinary.isdead == true
    
    -- Mostrar notificación si hay condición crítica
    if (isHungry or isThirsty or isDirty or isUnhappy or isUnhealthy or isDiseased or isUnvaccinated or isDead) then
        if (currentTime - lastDecayNotification) > decayNotificationCooldown then
            showDecayWarning(petData, petRecord)
            lastDecayNotification = currentTime
        end
    end
end

local function monitorPetStatus()
    RSGCore.Functions.TriggerCallback('hdrp-pets:server:getallcompanions', function(results)
        if results then
            for _, result in ipairs(results) do
                local AnimalData = json.decode(result.data) or {}
                if AnimalData then
                    checkPetCondition(AnimalData, result)
                end
                Wait(500) -- Sleep corto entre mascotas para evitar picos de CPU
            end
        end
    end)
end

----------------------------------
-- Monitoring Thread
----------------------------------
--[[
CreateThread(function()
    while true do
        local sleep = Config.Debug and 5000 or 30000 -- Más largo si no está en debug
        Wait(sleep)
        
        if Config.Debug then
            monitorPetStatus()
        end
    end
end)
]]

-------------------------------------
-- Level Up Notification
-------------------------------------
RegisterNetEvent('hdrp-pets:client:levelUp', function(data)
    if not data or not data.petName or not data.newLevel then return end
    
    local cfg = Config.XP and Config.XP.LevelUpNotifications
    if not cfg or not cfg.Enabled then return end
    
    local petName = data.petName
    local oldLevel = data.oldLevel or (data.newLevel - 1)
    local newLevel = data.newLevel
    local companionid = data.companionid
    
    -- Show notification
    lib.notify({
        title = locale('cl_level_up_title'),
        description = locale('cl_level_up_desc'):format(petName, newLevel),
        type = 'success',
        duration = 8000,
        -- icon = 'fa-solid fa-star',
        iconAnimation = 'bounce'
    })
    
    -- Play sound
    if cfg.PlaySound then
        local soundName = cfg.SoundName or 'REWARD_NEW_GUN'
        PlaySoundFrontend('CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true, 0)
    end
    
    -- Particle effect on pet
    if cfg.ShowParticleEffect and companionid then
        local petData = State.GetPet(companionid)
        if petData and petData.spawned and DoesEntityExist(petData.ped) then
            CreateThread(function()
                local dict = 'scr_rcparade1'
                RequestNamedPtfxAsset(dict)
                while not HasNamedPtfxAssetLoaded(dict) do
                    Wait(0)
                end
                
                UseParticleFxAsset(dict)
                local coords = GetEntityCoords(petData.ped)
                StartParticleFxNonLoopedAtCoord('scr_rcparade_confetti_burst', coords.x, coords.y, coords.z + 1.0, 0.0, 0.0, 0.0, 1.0, false, false, false)
                RemoveNamedPtfxAsset(dict)
            end)
        end
    end

end)

-- Comando para dar o quitar experiencia a un companion
RegisterCommand('pet_xp', function()
    local playerData = RSGCore.Functions.GetPlayerData()
    if not playerData or not playerData.group or playerData.group ~= 'admin' then
        lib.notify({
            title = locale('cl_error_access_denied') or 'Acceso denegado',
            description = locale('cl_error_admin_only') or 'Este comando solo puede ser ejecutado por administradores.',
            type = 'error'
        })
        return
    end
    -- Construir opciones para el select de mascotas activas
    local petOptions = {}
    for companionid, petData in pairs(State.GetAllPets()) do
        local name = petData.data and petData.data.info and petData.data.info.name or (locale('cl_pet_id') or 'ID: ')..tostring(companionid)
        table.insert(petOptions, { label = name..' ['..tostring(companionid)..']', value = companionid })
    end
    lib.inputDialog({
        title = locale('cl_manage_pet_xp_title') or 'Gestionar XP de Mascota',
        description = locale('cl_manage_pet_xp_desc') or 'Selecciona o escribe el Companion ID para modificar la experiencia',
        inputs = {
            {
                type = 'input',
                label = locale('cl_input_companionid_manual') or 'Companion ID (manual)',
                name = 'companionid_input',
                required = false
            },
            {
                type = 'select',
                label = locale('cl_input_select_pet') or 'Seleccionar Mascota',
                name = 'companionid_select',
                options = petOptions,
                required = false
            },
            {
                type = 'select',
                label = locale('cl_input_action') or 'Acción',
                name = 'accion',
                options = {
                    {label = locale('cl_action_givexp') or 'Dar XP', value = 'givexp'},
                    {label = locale('cl_action_removexp') or 'Quitar XP', value = 'removexp'}
                },
                required = true
            },
            {
                type = 'input',
                label = locale('cl_input_xp_amount') or 'Cantidad de XP',
                name = 'amount',
                required = true
            }
        }
    }, function(values)
        if not values or not values.accion or not values.amount then return end
        local companionid = values.companionid_input and values.companionid_input ~= '' and values.companionid_input or values.companionid_select
        if not companionid then
            lib.notify({
                title = locale('cl_error') or 'Error',
                description = locale('cl_error_select_companionid') or 'Debes seleccionar o escribir un Companion ID',
                type = 'error'
            })
            return
        end
        local amount = tonumber(values.amount)
        if not amount or amount < 0 then
            lib.notify({
                title = locale('cl_error') or 'Error',
                description = locale('cl_error_invalid_amount') or 'Cantidad inválida',
                type = 'error'
            })
            return
        end
        if values.accion == 'givexp' then
            TriggerServerEvent('hdrp-pets:server:givexp', amount, companionid)
        elseif values.accion == 'removexp' then
            TriggerServerEvent('hdrp-pets:server:removexp', amount, companionid)
        end
    end)
end)
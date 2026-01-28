-- ==========================================
-- TRACKING SYSTEM - CLIENT HANDLERS
-- ==========================================

local trackingBlip = nil
local trackingTarget = nil
local trackingSkillMultiplier = 1.0

-- Recibe ubicaciones rastreables del servidor
RegisterNetEvent('hdrp-pets:client:receiveTrackableLocations')
AddEventHandler('hdrp-pets:client:receiveTrackableLocations', function(locations)
    if not locations or #locations == 0 then
        lib.notify({ title = locale('cl_track_no_locations'), type = 'info' })
        return
    end
    
    -- Mostrar menu con ubicaciones encontradas
    local options = {}
    for i, loc in ipairs(locations) do
        options[#options+1] = {
            title = loc.name or locale('ui_track_unknown'),
            description = string.format('%s - %.1fm', loc.type or '', loc.distance),
            onSelect = function()
                TriggerServerEvent('hdrp-pets:server:starttracking', State.GetActiveCompanionId(), loc.coords)
            end
        }
    end
    
    lib.registerContext({
        id = 'tracking_locations_menu',
        title = locale('cl_track_select_location'),
        options = options
    })
    lib.showContext('tracking_locations_menu')
end)

-- Inicia el tracking visual hacia coordenadas
RegisterNetEvent('hdrp-pets:client:startTracking')
AddEventHandler('hdrp-pets:client:startTracking', function(targetCoords)
    if not targetCoords then return end
    
    -- Limpiar blip anterior si existe
    if trackingBlip and DoesBlipExist(trackingBlip) then
        RemoveBlip(trackingBlip)
    end
    
    trackingTarget = vector3(targetCoords.x, targetCoords.y, targetCoords.z)
    
    -- Crear blip en el mapa
    trackingBlip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, trackingTarget.x, trackingTarget.y, trackingTarget.z)
    SetBlipSprite(trackingBlip, Config.Blip.Track.blipSprite, true)
    SetBlipScale(trackingBlip, Config.Blip.Track.blipScale)
    
    lib.notify({ title = locale('cl_track_started'), type = 'success' })
    
    -- Thread para mostrar direccion
    CreateThread(function()
        while trackingTarget do
            local playerCoords = GetEntityCoords(PlayerPedId())
            local distance = #(playerCoords - trackingTarget)
            
            if distance < 5.0 then
                lib.notify({ title = locale('cl_track_arrived'), type = 'success' })
                TriggerServerEvent('hdrp-pets:server:stoptracking')
                break
            end
            
            Wait(1000)
        end
    end)
end)

-- Detiene el tracking
RegisterNetEvent('hdrp-pets:client:stopTracking')
AddEventHandler('hdrp-pets:client:stopTracking', function()
    trackingTarget = nil
    
    if trackingBlip and DoesBlipExist(trackingBlip) then
        RemoveBlip(trackingBlip)
        trackingBlip = nil
    end
    
    lib.notify({ title = locale('cl_track_stopped'), type = 'info' })
end)

-- Recibe multiplicador de habilidad de tracking
RegisterNetEvent('hdrp-pets:client:receivetrackingskill')
AddEventHandler('hdrp-pets:client:receivetrackingskill', function(multiplier)
    trackingSkillMultiplier = multiplier or 1.0
    if Config.Debug then
        print(string.format('[TRACKING] Skill multiplier: %.2fx', trackingSkillMultiplier))
    end
end)
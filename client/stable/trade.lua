local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
-- COMMAND: Trade Companion
local function TradeCompanion()
    local pets = State.GetAllPets()
    local petOptions = {}
    for companionid, pet in pairs(pets) do
        if pet and pet.spawned and DoesEntityExist(pet.ped) then
            table.insert(petOptions, {
                value = companionid,
                label = (pet.data and pet.data.info and pet.data.info.name) or ("Pet " .. companionid)
            })
        end
    end

    if #petOptions == 0 then
        lib.notify({title = locale('cl_no_active_pets'), type = 'error'})
        return
    end

    -- Buscar todos los jugadores cercanos (dentro de 1.5m)
    local players = GetActivePlayers()
    local nearbyPlayers = {}
    local myPed = cache.ped
    for _, pid in ipairs(players) do
        if pid ~= PlayerId() then
            local targetPed = GetPlayerPed(pid)
            local dist = #(GetEntityCoords(myPed) - GetEntityCoords(targetPed))
            if dist < 3.0 then
                table.insert(nearbyPlayers, { value = GetPlayerServerId(pid), label = GetPlayerName(pid) .. ' [' .. GetPlayerServerId(pid) .. ']' })
            end
        end
    end

    if #nearbyPlayers == 0 then
        lib.notify({ title = locale('cl_error_no_nearby_player'), type = 'error', duration = 7000 })
        return
    end

    local dialog = lib.inputDialog(locale('cl_input_trade_pet'), {
        {
            type = 'select',
            label = locale('cl_select_pet_to_trade'),
            options = petOptions,
            required = true,
            -- icon = 'fa-solid fa-paw',
            default = petOptions[1].label
        },
        {
            type = 'select',
            label = locale('cl_select_player_to_trade'),
            options = nearbyPlayers,
            required = true,
            -- icon = 'fa-solid fa-user',
            default = nearbyPlayers[1].label
        },
        {
            type = 'input',
            label = locale('cl_input_trade_price') or 'Precio (opcional)',
            required = false,
            -- icon = 'fa-solid fa-dollar-sign',
            placeholder = '0'
        }
    })

    if not dialog or not dialog[1] or not dialog[2] then return end
    local selectedId = dialog[1]
    local selectedPlayerId = dialog[2]
    local price = dialog[3] or '0'
    local pet = pets[selectedId]
    if not pet or not DoesEntityExist(pet.ped) then return end

    TriggerServerEvent('hdrp-pets:server:TradeCompanion', selectedPlayerId, selectedId, price)
    lib.notify({ title = locale('cl_success_companion_traded'), type = 'success', duration = 7000 })
end

---------------------------------------------------------------------
-- TRADE PETS
---------------------------------------------------------------------
RegisterNetEvent("hdrp-pets:client:TradeCompanionConfirm", function(Seller, companionId, price)
    local dialog = lib.inputDialog(locale('cl_input_trade_pet_confirm'), {
        {
            type = 'select',
            label = locale('cl_confirm_trade_label'),
            options = {
                { value = 'accept', label = locale('cl_confirm_trade_accept') or 'Aceptar' },
                { value = 'decline', label = locale('cl_confirm_trade_decline') or 'Rechazar' }
            },
            required = true,
            -- icon = 'fa-solid fa-question',
            default = 'accept'
        }
    })
    if not dialog or not dialog[1] then return end
    local choice = dialog[1]
    if choice ~= 'accept' then
        lib.notify({ title = locale('cl_info_trade_declined'), type = 'info', duration = 7000 })
        return
    end
    TriggerServerEvent('hdrp-pets:server:TradeCompanionConfirm', Seller, companionId, price)
end)

RegisterCommand('pet_trade', function()
    if TradeCompanion then
        TradeCompanion()
    else
        lib.notify({ 
            title = locale('cl_menu_trade_pet'), 
            description = 'No se encontró la función de intercambio', 
            type = 'error', 
            duration = 5000 
        })
    end
    Wait(3000)
end, false)
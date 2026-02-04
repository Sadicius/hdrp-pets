local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
-------------------------------------
-- Companion Flee/Store
-------------------------------------
---Dismiss/remove single pet from game (legacy/robust mode)
---@param petPed number|nil Optional specific pet ped to dismiss, defaults to first pet
---@return boolean success True if pet was dismissed successfully
function Flee(petPed)
    if not petPed or not DoesEntityExist(petPed) then
        return false
    end

    -- Obtener companionid a partir del ped
    local petData, companionid = State.GetPetByEntity(petPed)
    if companionid then
        -- Limpieza completa usando State.DismissPet
        State.DismissPet(companionid)
        return true
    else
        -- Fallback: solo limpiar la entidad si no se encuentra companionid
        SetEntityAsMissionEntity(petPed, true, true)
        DeletePed(petPed)
        SetEntityAsNoLongerNeeded(petPed)
        return true
    end
end

RegisterCommand('pet_store', function()
    local activePets = State.GetAllPets()
    local petOptions = {}
    local petDataMap = {}

    for companionid, petData in pairs(activePets) do
        if petData and petData.spawned and DoesEntityExist(petData.ped) then
            local name = (petData.data and petData.data.info and petData.data.info.name) or (locale('cl_pet_default') .. ' ' .. companionid)
            table.insert(petOptions, { value = companionid, label = name })
            petDataMap[companionid] = petData
        end
    end

    if #petOptions == 0 then
        lib.notify({ title = locale('cl_error_pet_no_active'), type = 'error', duration = 5000 })
        return
    end

    local selectedId
    if #petOptions == 1 then
        selectedId = petOptions[1].value
    else
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
        selectedId = dialog[1]
    end

    local petData = petDataMap[selectedId]
    if not petData then
        return
    end

    -- Desactivar en base de datos
    TriggerServerEvent('hdrp-pets:server:store', selectedId)

    -- Eliminar del cliente si está invocada
    Flee(petData.ped)

    lib.notify({
        title = locale('cl_success_pet_storing'),
        description = locale('cl_success_store_all'):format(1),
        type = 'success',
        duration = 5000
    })
end, false)

-- Helper function: Flee active pets
local function FleePets()
    local activePets = State.GetAllPets()
    local petOptions = {}
    local petDataMap = {}

    for companionid, petData in pairs(activePets) do
        if petData and petData.spawned and DoesEntityExist(petData.ped) then
            local name = (petData.data and petData.data.info and petData.data.info.name) or (locale('cl_pet_default') .. ' ' .. companionid)
            table.insert(petOptions, { value = companionid, label = name })
            petDataMap[companionid] = petData
        end
    end

    if #petOptions == 0 then
        lib.notify({ title = locale('cl_error_pet_no_active'), type = 'error', duration = 5000 })
        return
    end

    local selectedId
    if #petOptions == 1 then
        selectedId = petOptions[1].value
    else
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
        selectedId = dialog[1]
    end

    if not petDataMap[selectedId] then
        return
    end
    
    -- Eliminar del cliente si está invocada
    Flee(petDataMap[selectedId].ped)

    lib.notify({
        title = locale('cl_success_pet_storing'),
        description = locale('cl_success_store_all'):format(1),
        type = 'success',
        duration = 5000
    })
end

RegisterCommand('pet_flee', function()
    FleePets()
    Wait(1000)
end, false)
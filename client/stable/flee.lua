local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
-------------------------------------
-- Companion Flee/Store
-------------------------------------
---Dismiss/remove single pet from game (legacy/robust mode)
---@param entity number|nil Optional specific pet ped to dismiss, defaults to first pet
---@return boolean success True if pet was dismissed successfully
function Flee(entity)
    if not entity or not DoesEntityExist(entity) then
        return false
    end

    local _, companionid = State.GetPetByEntity(entity)
    if companionid then
        State.DismissPet(companionid)
        return true
    else
        SetEntityAsMissionEntity(entity, true, true)
        DeletePed(entity)
        SetEntityAsNoLongerNeeded(entity)
        return true
    end
end

local function SelectActivePet()
    local activePets = State.GetAllPets()
    local petOptions, petDataMap = {}, {}

    for companionid, petData in pairs(activePets) do
        if petData and petData.spawned and DoesEntityExist(petData.ped) then
            local name = (petData.data and petData.data.info and petData.data.info.name) or (locale('cl_pet_default') .. ' ' .. companionid)
            table.insert(petOptions, { value = companionid, label = name })
            petDataMap[companionid] = petData
        end
    end

    if #petOptions == 0 then
        lib.notify({ title = locale('cl_error_pet_no_active'), type = 'error', duration = 5000 })
        return nil, nil
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
                default = petOptions[1].label
            }
        })
        if not dialog or not dialog[1] then return nil, nil end
        selectedId = dialog[1]
    end

    return selectedId, petDataMap[selectedId]
end

local function StoreOrFleePet(action)
    local selectedId, petData = SelectActivePet()
    if not selectedId or not petData then return end

    if action == "store" then
        TriggerServerEvent('hdrp-pets:server:store', selectedId)
        lib.notify({
            title = locale('cl_success_pet_storing'),
            description = locale('cl_success_store_all'):format(1),
            type = 'success',
            duration = 5000
        })
    end

    Flee(petData.ped)
end

RegisterCommand('pet_store', function()
    StoreOrFleePet("store")
end, false)

RegisterCommand('pet_flee', function()
    StoreOrFleePet("flee")
end, false)
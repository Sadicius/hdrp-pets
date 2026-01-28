local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
-------------------------------------
-- Companion Rename
-------------------------------------
-- Companion Rename Command
RegisterCommand('pet_name', function()
    -- Get all active spawned pets
    local activePets = State.GetAllPets()
    local spawnedPets = {}
    
    for companionid, petData in pairs(activePets) do
        if petData and petData.spawned and DoesEntityExist(petData.ped) then
            table.insert(spawnedPets, {id = companionid, data = petData})
        end
    end
    
    if #spawnedPets == 0 then
        lib.notify({ title = locale('cl_error_pet_no_active'), type = 'error', duration = 5000 })
        return
    end
    
    -- Get pet data from database
    RSGCore.Functions.TriggerCallback('hdrp-pets:server:getactivecompanions', function(activePetsData)
        if not activePetsData or #activePetsData == 0 then
            lib.notify({ title = locale('cl_error_pet_no_active'), type = 'error', duration = 5000 })
            return
        end
        
        -- Build pet selection options
        local petOptions = {}
        local petDataMap = {}
        
        for _, pet in ipairs(spawnedPets) do
            for _, dbPet in ipairs(activePetsData) do
                if dbPet.companionid == pet.id then
                    local companionData = json.decode(dbPet.data) or {}
                    local petName = companionData.info.name or 'Unknown'
                    
                    table.insert(petOptions, {
                        value = pet.id,
                        label = petName
                    })
                    
                    petDataMap[pet.id] = {
                        name = petName,
                        data = dbPet
                    }
                    break
                end
            end
        end
        
        if #petOptions == 0 then
            lib.notify({ title = locale('cl_error_pet_no_active'), type = 'error', duration = 5000 })
            return
        end
        
        -- Multiple pets: show select + input dialog
        local dialog = lib.inputDialog(locale('cl_input_companion_rename'), {
            {
                type = 'select',
                label = locale('cl_select_pet_to_rename'),
                options = petOptions,
                required = true,
                -- icon = 'fa-solid fa-paw',
                default = petDataMap[petOptions[1].value].name
            },
            {
                type = 'input',
                label = locale('cl_input_companion_setname'),
                required = true,
                -- icon = 'fa-solid fa-pencil'
            }
        })
        
        if dialog and dialog[1] and dialog[2] then
            TriggerServerEvent('hdrp-pets:server:rename', dialog[1], dialog[2])
        end
    end)
end, false)

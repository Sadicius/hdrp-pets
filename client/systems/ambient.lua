-- Ambient dog resting logic

local State = exports['hdrp-pets']:GetState()
local canDoAction = false
local isBusy = false

CreateThread(function()
    while true do
        Wait(100)
        local sleep = 5000
        local pets = State.GetAllPets()
        local playerCoords = GetEntityCoords(cache.ped)
        local ZoneTypeId = 1
        local x, y, z = table.unpack(playerCoords)
        local town = Citizen.InvokeNative(0x43AD8FC02B429D33, x, y, z, ZoneTypeId)
        local canDoAction = not town

        for companionid, pet in pairs(pets) do
            if pet and DoesEntityExist(pet.ped) then
                local dist = #(playerCoords - GetEntityCoords(pet.ped))
                isBusy = isBusy or false

                if isBusy and dist < 12 then
                    if Citizen.InvokeNative(0x57AB4A3080F85143, pet.ped) then -- IsPedUsingAnyScenario
                        ClearPedTasks(pet.ped)
                        -- State.SetPetTrait(companionid, 'isBusy', false)
                        isBusy = false
                    end
                end
                if not isBusy and dist > 12 and pet.spawned and canDoAction then
                    Citizen.InvokeNative(0x524B54361229154F, pet.ped, joaat('WORLD_ANIMAL_DOG_RESTING'), -1, true, 0, GetEntityHeading(pet.ped), false)
                    isBusy = true
                end
            end
        end
        Wait(sleep)
    end
end)
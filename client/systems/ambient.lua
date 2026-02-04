-- Ambient dog resting logic

local State = exports['hdrp-pets']:GetState()
local canDoAction = false
local isBusy = false
local animations = Config.Animations or {}

local function ambientLogic()
    local pets = State.GetAllPets()
    local playerCoords = GetEntityCoords(cache.ped)
    local ZoneTypeId = 1
    local x, y, z = table.unpack(playerCoords)
    local town = Citizen.InvokeNative(0x43AD8FC02B429D33, x, y, z, ZoneTypeId)
    local canDoTown = not town

    for companionid, pet in pairs(pets) do
        if pet and DoesEntityExist(pet.ped) then
            local canDoAction = not (pet.flag and pet.flag.isHunting) and not (pet.flag and pet.flag.isRace)
            local XP = (pet.data and pet.data.progression and pet.data.progression.xp) or 0
            local canXP

            for _, anim in ipairs(animations) do
                if anim.dict == 'amb_creature_mammal@world_dog_resting@base' then
                    canXP = XP >= (anim.experience or 0)
                end
            end

            isBusy = isBusy or false

            local dist = #(playerCoords - GetEntityCoords(pet.ped))

            if isBusy and dist < 12 then
                if Citizen.InvokeNative(0x57AB4A3080F85143, pet.ped) then -- IsPedUsingAnyScenario
                    ClearPedTasks(pet.ped)
                    -- State.SetPetTrait(companionid, 'isBusy', false)
                    isBusy = false
                end
            end
            if not isBusy and dist > 12 and pet.spawned and canDoTown and canDoAction and canXP then
                Citizen.InvokeNative(0x524B54361229154F, pet.ped, joaat('WORLD_ANIMAL_DOG_RESTING'), -1, true, 0, GetEntityHeading(pet.ped), false)
                isBusy = true
            end
        end
    end

    local sleep = 5000
    Wait(sleep)
end

CreateThread(function()
    while true do
        Wait(100)
        if not State.HasActivePets() then
            Wait(10000)
        else
            ambientLogic()
        end
    end
end)
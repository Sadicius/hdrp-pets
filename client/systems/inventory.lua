local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
--------------------------------------
-- companion inventory
--------------------------------------
local function getLevelAttributes(xp)
    for _, level in ipairs(Config.PetAttributes.levelAttributes) do
        if xp >= level.xpMin and xp <= level.xpMax then
            return level.invWeight, level.invSlots
        end
    end
    return 0, 0
end

RegisterNetEvent('hdrp-pets:client:inventoryCompanion', function(companionid)
    local petData = State.GetPet(companionid)
    if not petData then return end
    local companionstash =  'pet_inv_' .. companionid
    local xp = (petData.data and petData.data.progression and petData.data.progression.xp) or 0
    local invWeight, invSlots = getLevelAttributes(xp)
    TriggerServerEvent('hdrp-pets:server:openinventory', companionstash, invWeight, invSlots)
end)
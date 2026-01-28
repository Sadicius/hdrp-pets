
local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()
local State = exports['hdrp-pets']:GetState()
local Database = lib.load('server.core.database')

-- Evento para dar experiencia manualmente
RegisterServerEvent('hdrp-pets:server:givexp', function(amount, companionid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if not amount or type(amount) ~= 'number' then return end

    local activeCompanion = nil
    if companionid then
        activeCompanion = Database.GetCompanionByCompanionId(companionid)
        if not activeCompanion or activeCompanion.citizenid ~= Player.PlayerData.citizenid then
            TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_error_no_active_pet'), type = 'error', duration = 5000 })
            return
        end
    else
        activeCompanion = Database.GetAllCompanionsActive(Player.PlayerData.citizenid)
        if not activeCompanion then
            TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_error_no_active_pet'), type = 'error', duration = 5000 })
            return
        end
    end

    local currentData = json.decode(activeCompanion.data or '{}')

    local oldXP = currentData.progression.xp or 0
    local newXP = oldXP + amount
    local oldLevel = State.GetPetLevel(oldXP)
    local newLevel = State.GetPetLevel(newXP)
    currentData.progression.xp = newXP

    Database.UpdateCompanionData(companionid, currentData)

    -- TriggerClientEvent('hdrp-pets:client:updateanimals', src, companionid, currentData)

    if newLevel > oldLevel and Config.XP and Config.XP.LevelUpNotifications and Config.XP.LevelUpNotifications.Enabled then
        TriggerClientEvent('hdrp-pets:client:levelUp', src, {
            petName = currentData.info.name,
            oldLevel = oldLevel,
            newLevel = newLevel,
            companionid = companionid
        })
    end

end)

-- Evento para quitar experiencia manualmente
RegisterServerEvent('hdrp-pets:server:removexp', function(amount, companionid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if not amount or type(amount) ~= 'number' then return end

    local activeCompanion = nil
    if companionid then
        activeCompanion = Database.GetCompanionByCompanionId(companionid)
        if not activeCompanion or activeCompanion.citizenid ~= Player.PlayerData.citizenid then
            TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_error_no_active_pet'), type = 'error', duration = 5000 })
            return
        end
    else
        activeCompanion = Database.GetAllCompanionsActive(Player.PlayerData.citizenid)
        if not activeCompanion then
            TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_error_no_active_pet'), type = 'error', duration = 5000 })
            return
        end
    end

    local currentData = json.decode(activeCompanion.data or '{}')

    local oldXP = currentData.progression.xp or 0
    local newXP = math.max(0, oldXP - amount)
    local oldLevel = State.GetPetLevel(oldXP)
    local newLevel = State.GetPetLevel(newXP)
    currentData.progression.xp = newXP

    Database.UpdateCompanionData(companionid, currentData)

    -- TriggerClientEvent('hdrp-pets:client:updateanimals', src, companionid, currentData)

    if newLevel < oldLevel and Config.XP and Config.XP.LevelUpNotifications and Config.XP.LevelUpNotifications.Enabled then
        TriggerClientEvent('hdrp-pets:client:levelUp', src, {
            petName = currentData.info.name,
            oldLevel = oldLevel,
            newLevel = newLevel,
            companionid = companionid
        })
    end
end)

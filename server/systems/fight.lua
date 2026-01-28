-- server/systems/fight.lua
-- Backend para apuestas y gestión de peleas de mascotas

local RSGCore = exports['rsg-core']:GetCoreObject()
local Database = lib.load('server.core.database')
local GameConfig = lib.load('shared.game.games')
local DogFightConfig = GameConfig.Gdogfight

local bets = {}
local activeFights = {}
local petFightQueue = {} -- Para mascotas de jugadores esperando luchar contra NPC
local playerVsPlayerQueue = {} -- Para luchas entre mascotas de diferentes jugadores

local achievementsComp = {
    fight = {
        victories = 0,
        defeats = 0,
        winrate = 0,
        combatxp = 0,
        streak = 0,
        maxStreak = 0,
        ko = 0,
        fights = 0
    },
    unlocked = {}
}

local function checkAchievements(src, petId)

    local xpBonus = 0
    local companionid = petId
    local companion = Database.GetCompanionByCompanionId(companionid)
    if not companion then return end

    local data = companion and json.decode(companion.data or '{}') or {}
    local achievements = companion and json.decode(companion.achievements or '{}') or achievementsComp

    -- Solo desbloquear logros y XP según estadísticas persistentes
    achievements.unlocked = achievements.unlocked or {}
    for key, ach in pairs(Config.XP.Achievements.List) do
        if ach.requirement and ach.requirement.type and ach.requirement.value then
            local achieved = false
            if ach.requirement.type == 'fight' and (achievements.fight.victories or 0) >= ach.requirement.value then
                achieved = true
            elseif ach.requirement.type == 'fight_streak' and (achievements.fight.streak or 0) >= ach.requirement.value then
                achieved = true
            --[[
            -- ejemplos a trasladar a los correspondientes sistemas si se desea
            elseif ach.requirement.type == 'combat' and (achievements.combat.victories or 0) >= ach.requirement.value then
                achieved = true
            elseif ach.requirement.type == 'level' and (data.progression.level or 0) >= ach.requirement.value then
                achieved = true
            elseif ach.requirement.type == 'formation' and (achievements.combat.streak or 0) >= ach.requirement.value then
                achieved = true
            elseif ach.requirement.type == 'treasure' and (achievements.combat.streak or 0) >= ach.requirement.value then
                achieved = true
                ]]
            end
            if achieved and not achievements.unlocked[key] then
                achievements.unlocked[key] = true
                xpBonus = xpBonus + (ach.xpBonus or 0)
                TriggerClientEvent('hdrp-pets:client:achievement', src, ach.name, ach.description .. ' +' .. tostring(ach.xpBonus or 0) .. ' XP')
            end
        end
    end

    data.progression.xp = (data.progression.xp or 0) + (xpBonus or 0)

    Database.UpdateCompanionAchievements(companionid, achievements)
    Database.UpdateCompanionData(companionid, data)
    TriggerClientEvent('hdrp-pets:client:updateanimals', src, companionid, data)
    TriggerClientEvent('hdrp-pets:client:updateCombatAchievements', src, petId, achievements, xpBonus)
end

-- Comando: /mascota_ranking
RegisterCommand('pet_ranking', function(src)
    local companions = Database.GetAllCompanionsForRanking() -- Debe devolver todas las mascotas con achievements
    local ranking = {}

    for _, companion in ipairs(companions or {}) do
        local achievements = companion.achievements and json.decode(companion.achievements) or achievementsComp
        ranking[#ranking+1] = {
            petId = companion.id or companion.PetId or "N/A",
            wins = achievements.fight.victories or 0,
            ko = achievements.fight.ko or 0,
            winrate = achievements.fight.winrate or 0,
            fights = achievements.fight.fights or 0,
            streak = achievements.fight.maxStreak or 0
        }
    end

    table.sort(ranking, function(a, b) return a.wins > b.wins end)

    local msg = locale('cl_ranking_fight') .. ':'

    for i, r in ipairs(ranking) do
        msg = msg .. i .. '. ' .. r.petId .. ' - ' .. locale('cl_ranking_fight_wins') .. ': ' .. r.wins .. ', ' .. locale('cl_ranking_fight_fights') .. ': ' .. r.fights .. ', ' .. locale('cl_ranking_fight_ko') .. ': ' .. r.ko .. ', ' .. locale('cl_ranking_fight_streak') .. ': ' .. r.streak .. '\n'
        if i >= 10 then break end
    end

    TriggerClientEvent('ox_lib:notify', src, { title = locale('cl_ranking_fight'), description = msg, type = 'inform', duration = 10000 })
end, false)

-- Utilidad para actualizar estadísticas
local function updateStatsFight(winnerPet, loserPet, winnerSrc, loserSrc, isKO, betWinner)
    -- Mascota ganadora
    local wid = winnerPet.PetId or winnerPet.Name
    local wcompanion = Database.GetCompanionByCompanionId(wid)
    local wach = wcompanion and json.decode(wcompanion.achievements or '{}') or achievementsComp

    wach.fight.victories = (wach.fight.victories or 0) + 1
    wach.fight.streak = (wach.fight.streak or 0) + 1
    wach.fight.maxStreak = math.max(wach.fight.maxStreak or 0, wach.fight.streak)
    wach.fight.ko = (wach.fight.ko or 0) + (isKO and 1 or 0)
    wach.fight.fights = (wach.fight.fights or 0) + 1

    local totalFightsW = (wach.fight.victories or 0) + (wach.fight.defeats or 0)
    wach.fight.winrate = totalFightsW > 0 and math.floor((wach.fight.victories / totalFightsW) * 100) or 0

    Database.UpdateCompanionAchievements(wid, wach)
    -- TriggerClientEvent('hdrp-pets:client:updateanimals', src, wid, wach)

    -- Mascota perdedora
    local lid = loserPet.PetId or loserPet.Name
    local lcompanion = Database.GetCompanionByCompanionId(lid)
    local lach = lcompanion and json.decode(lcompanion.achievements or '{}') or achievementsComp

    lach.fight.defeats = (lach.fight.defeats or 0) + 1
    lach.fight.streak = 0
    lach.fight.fights = (lach.fight.fights or 0) + 1
    lach.fight.maxStreak = lach.fight.maxStreak or 0
    lach.fight.ko = lach.fight.ko or 0

    local totalFightsL = (lach.fight.victories or 0) + (lach.fight.defeats or 0)
    lach.fight.winrate = totalFightsL > 0 and math.floor((lach.fight.victories / totalFightsL) * 100) or 0

    Database.UpdateCompanionAchievements(lid, lach)
    -- TriggerClientEvent('hdrp-pets:client:updateanimals', src, lid, lach)
end

-- Utilidad: obtener atributos de una mascota (puede ser NPC o mascota de jugador)
local function getPetAttributes(pet)
    -- Si es una mascota NPC (tabla DogFightConfig.Dogs)
    if pet.NPC then
        return pet
    end
    -- Si es una mascota de jugador (estructura personalizada)
    -- Espera que tenga campos: Name, Health, Strength, etc.
    return {
        Name = pet.Name,
        Health = pet.Health,
        Strength = pet.Strength,
        Owner = pet.Owner,
        PetId = pet.PetId,
        NPC = false
    }
end

local function startFlexibleFight(participant1, participant2, coords, initiatorSrc, fightType)
    local fightId = "fight_" .. os.time() .. "_" .. (initiatorSrc or math.random(1000,9999))
    local pet1 = getPetAttributes(participant1)
    local pet2 = getPetAttributes(participant2)

    activeFights[fightId] = {
        dog1 = pet1,
        dog2 = pet2,
        coords = coords,
        initiator = initiatorSrc,
        startTime = os.time(),
        fightType = fightType or "custom"
    }

    -- Notificar a todos los clientes para mostrar la pelea
    TriggerClientEvent('hdrp-pets:client:startFightForAll', -1, fightId, pet1, pet2, coords)

    -- Resolución automática tras 30s (puede personalizarse por tipo)
    SetTimeout(30000, function()
        if activeFights[fightId] then
            local pet1Score = (pet1.Health or 0) + (pet1.Strength or 0) + math.random(1, 50)
            local pet2Score = (pet2.Health or 0) + (pet2.Strength or 0) + math.random(1, 50)
            local winner
            if pet1Score > pet2Score then
                winner = pet1.Name
            else
                winner = pet2.Name
            end
            TriggerEvent('hdrp-pets:server:endFight', fightId, pet1, pet2, winner, outlawstatus)
        end
    end)
    return fightId
end

-- EVENTO: Inscripción de mascota para luchar contra NPC
RegisterNetEvent('hdrp-pets:server:registerPetForNpcFight')
AddEventHandler('hdrp-pets:server:registerPetForNpcFight', function(petData, outlawstatus)
    local src = source
    -- petData debe contener: Name, Health, Strength, Owner, PetId
    table.insert(petFightQueue, {pet = petData, src = src})
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('cl_fight_registed'),
        description = locale('cl_fight_registed_desc'),
        type = 'success',
        duration = 5000
    })
    -- Intentar emparejar si hay alguien en la cola
    if #petFightQueue > 0 then
        local entry = table.remove(petFightQueue, 1)
        local npcDog = DogFightConfig.Dogs[math.random(#DogFightConfig.Dogs)]
        local playerPed = GetPlayerPed(entry.src)
        local playerCoords = GetEntityCoords(playerPed)
        startFlexibleFight(entry.pet, npcDog, playerCoords, entry.src, "pet_vs_npc")

        local Player = RSGCore.Functions.GetPlayer(entry.src)
        if not Player then return end
        local citizenid = Player.PlayerData.citizenid
        local newoutlawstatus = (outlawstatus + DogFightConfig.OutlawStatusAdd)
        MySQL.update('UPDATE players SET outlawstatus = ? WHERE citizenid = ?', { newoutlawstatus, citizenid })
    end
end)

-- EVENTO: Inscripción de mascota para luchar contra otra mascota de otro jugador
RegisterNetEvent('hdrp-pets:server:registerPetForPlayerFight')
AddEventHandler('hdrp-pets:server:registerPetForPlayerFight', function(petData, outlawstatus)
    local src = source
    table.insert(playerVsPlayerQueue, {pet = petData, src = src})
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('cl_fight_registed'),
        description = locale('cl_fight_registed_desc'),
        type = 'success',
        duration = 5000
    })
    -- Intentar emparejar si hay dos en la cola
    if #playerVsPlayerQueue >= 2 then
        local entry1 = table.remove(playerVsPlayerQueue, 1)
        local entry2 = table.remove(playerVsPlayerQueue, 1)
        -- Usar la posición del primero como referencia
        local playerPed = GetPlayerPed(entry1.src)

        local playerCoords = GetEntityCoords(playerPed)
        startFlexibleFight(entry1.pet, entry2.pet, playerCoords, entry1.src, "pet_vs_pet")

        local Player = RSGCore.Functions.GetPlayer(entry1.src)
        if not Player then return end
        local citizenid = Player.PlayerData.citizenid
        local newoutlawstatus = (outlawstatus + DogFightConfig.OutlawStatusAdd)
        MySQL.update('UPDATE players SET outlawstatus = ? WHERE citizenid = ?', { newoutlawstatus, citizenid })
    end
end)

-- EVENTO: Lucha entre dos mascotas del mismo jugador (sin cola)
RegisterNetEvent('hdrp-pets:server:startOwnPetsFight')
AddEventHandler('hdrp-pets:server:startOwnPetsFight', function(petData1, petData2)
    local src = source
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    startFlexibleFight(petData1, petData2, playerCoords, src, "own_pets")
end)

RegisterNetEvent('hdrp-pets:server:placeBet')
AddEventHandler('hdrp-pets:server:placeBet', function(dogName, amount, outlawstatus)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    if amount < DogFightConfig.MinBet or amount > DogFightConfig.MaxBet then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('cl_bet_invalid'),
            description = string.format(locale('cl_bet_invalid_desc'), DogFightConfig.MinBet, DogFightConfig.MaxBet),
            type = 'error',
            duration = 5000
        })
        return
    end
    
    if Player.PlayerData.money.cash < amount then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('cl_bet_insufficient_funds'),
            description = locale('cl_bet_insufficient_funds_desc'),
            type = 'error',
            duration = 5000
        })
        return
    end
    
    local dog1 = nil
    for _, dog in ipairs(DogFightConfig.Dogs) do
        if dog.Name == dogName then
            dog1 = dog
            break
        end
    end
    
    if not dog1 then
        return
    end
    
    local dog2 = DogFightConfig.Dogs[math.random(#DogFightConfig.Dogs)]
    while dog2.Name == dog1.Name do
        dog2 = DogFightConfig.Dogs[math.random(#DogFightConfig.Dogs)]
    end
    
    Player.Functions.RemoveMoney('cash', amount)

    local citizenid = Player.PlayerData.citizenid
    local newoutlawstatus = (outlawstatus + DogFightConfig.OutlawStatusBet)
    MySQL.update('UPDATE players SET outlawstatus = ? WHERE citizenid = ?', { newoutlawstatus, citizenid })

    bets[src] = {
        dogName = dogName,
        amount = amount,
        fightDogs = {dog1 = dog1.Name, dog2 = dog2.Name}
    }
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('cl_bet_placed'),
        description = string.format(locale('cl_bet_placed_desc'), amount, dogName),
        type = 'success',
        duration = 5000
    })
    
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    local fightId = "fight_" .. os.time() .. "_" .. src
    
    activeFights[fightId] = {
        dog1 = dog1,
        dog2 = dog2,
        coords = playerCoords,
        initiator = src,
        startTime = os.time()
    }
    
    TriggerClientEvent('hdrp-pets:client:startFightForAll', -1, fightId, dog1, dog2, playerCoords)
    
    SetTimeout(30000, function()
        if activeFights[fightId] then
            
            local dog1Score = dog1.Health + dog1.Strength + math.random(1, 50)
            local dog2Score = dog2.Health + dog2.Strength + math.random(1, 50)
            local winner
            
            if dog1Score > dog2Score then
                winner = dog1.Name
            else
                winner = dog2.Name
            end
            
            TriggerEvent('hdrp-pets:server:endFight', fightId, dog1, dog2, winner, outlawstatus)
        end
    end)
end)

RegisterNetEvent('hdrp-pets:server:endFight')
AddEventHandler('hdrp-pets:server:endFight', function(fightId, dog1, dog2, winner, outlawstatus)
    local fight = activeFights[fightId]
    if not fight then return end

    -- Determinar perdedor
    local loser = (winner == dog1.Name) and dog2 or dog1
    local winnerSrc = fight.initiator
    local loserSrc = nil -- Si es PvP, podrías guardar el src del segundo jugador
    local isKO = true -- Puedes mejorar esto con lógica real de KO
    local betWinner = nil

    -- Actualizar historial y rankings
    updateStatsFight((winner == dog1.Name) and dog1 or dog2, loser, winnerSrc, loserSrc, isKO, betWinner)
    -- Logros para la mascota ganadora
    if (winner == dog1.Name) and dog1.PetId then checkAchievements(winnerSrc, dog1.PetId) end
    if (winner == dog2.Name) and dog2.PetId then checkAchievements(winnerSrc, dog2.PetId) end
    
    TriggerClientEvent('hdrp-pets:client:endFightForAll', -1, fightId, winner)
    
    if bets then
        for src, bet in pairs(bets) do
            if bet and bet.fightDogs and bet.fightDogs.dog1 == dog1.Name and bet.fightDogs.dog2 == dog2.Name then
                local Player = RSGCore.Functions.GetPlayer(src)
                if not Player then return end
                if Player then
                    local payout = 0
                    if bet.dogName == winner then
                        payout = bet.amount * 5 -- 5x rewards
                        Player.Functions.AddMoney('cash', payout)
                        
                        local citizenid = Player.PlayerData.citizenid
                        local newoutlawstatus = (outlawstatus + DogFightConfig.OutlawStatusBet)
                        MySQL.update('UPDATE players SET outlawstatus = ? WHERE citizenid = ?', { newoutlawstatus, citizenid })

                        betWinner = true
                    else
                        betWinner = false
                    end
                    TriggerClientEvent('hdrp-pets:client:showBetResult', src, winner, payout)
                end
                bets[src] = nil
            end
        end
    end
    activeFights[fightId] = nil
end)

RegisterNetEvent('hdrp-pets:server:requestActiveFights')
AddEventHandler('hdrp-pets:server:requestActiveFights', function()
    local src = source    
    if activeFights then
        for fightId, fight in pairs(activeFights) do            
            if os.time() - fight.startTime < 25 then
                TriggerClientEvent('hdrp-pets:client:startFightForAll', src, fightId, fight.dog1, fight.dog2, fight.coords)
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if bets then
        bets[src] = nil
    end
end)
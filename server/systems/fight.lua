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

local pvpChallenges = {}
local pvpFights = {}
local spectatorBets = {}

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
    achievements.fight = achievements.fight or { victories = 0, defeats = 0, winrate = 0, combatxp = 0, streak = 0, maxStreak = 0, ko = 0, fights = 0 }
    achievements.formation = achievements.formation or { unlocked = 0 }
    achievements.treasure = achievements.treasure or { completed = 0 }

    -- Calcular nivel basado en XP
    local xp = (data.progression and data.progression.xp) or 0
    local level = math.floor(xp / 100) + 1

    for key, ach in pairs(Config.XP.Achievements.List) do
        if ach.requirement and ach.requirement.type and ach.requirement.value then
            local achieved = false
            if ach.requirement.type == 'fight' and (achievements.fight.victories or 0) >= ach.requirement.value then
                achieved = true
            elseif ach.requirement.type == 'fight_streak' and (achievements.fight.streak or 0) >= ach.requirement.value then
                achieved = true
            -- FIX: Habilitada verificación de logros de nivel
            elseif ach.requirement.type == 'level' and level >= ach.requirement.value then
                achieved = true
            -- FIX: Habilitada verificación de logros de formación
            elseif ach.requirement.type == 'formation' and (achievements.formation.unlocked or 0) >= ach.requirement.value then
                achieved = true
            -- FIX: Habilitada verificación de logros de tesoro
            elseif ach.requirement.type == 'treasure' and (achievements.treasure.completed or 0) >= ach.requirement.value then
                achieved = true
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
    if wcompanion then
        local wach = wcompanion and json.decode(wcompanion.achievements or '{}') or achievementsComp
        wach.fight = wach.fight or { victories = 0, defeats = 0, winrate = 0, combatxp = 0, streak = 0, maxStreak = 0, ko = 0, fights = 0 }
        wach.fight.victories = (wach.fight.victories or 0) + 1
        wach.fight.streak = (wach.fight.streak or 0) + 1
        wach.fight.maxStreak = math.max(wach.fight.maxStreak or 0, wach.fight.streak)
        wach.fight.ko = (wach.fight.ko or 0) + (isKO and 1 or 0)
        wach.fight.fights = (wach.fight.fights or 0) + 1
        local totalFightsW = (wach.fight.victories or 0) + (wach.fight.defeats or 0)
        wach.fight.winrate = totalFightsW > 0 and math.floor((wach.fight.victories / totalFightsW) * 100) or 0
        Database.UpdateCompanionAchievements(wid, wach)
        -- TriggerClientEvent('hdrp-pets:client:updateanimals', src, wid, wach)
    end

    -- Mascota perdedora
    local lid = loserPet.PetId or loserPet.Name
    local lcompanion = Database.GetCompanionByCompanionId(lid)
    if lcompanion then
        local lach = lcompanion and json.decode(lcompanion.achievements or '{}') or achievementsComp
        lach.fight = lach.fight or { victories = 0, defeats = 0, winrate = 0, combatxp = 0, streak = 0, maxStreak = 0, ko = 0, fights = 0 }
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
        Model = pet.Model,
        Health = pet.Health,
        Strength = pet.Strength,
        Owner = pet.Owner,
        PetId = pet.PetId,
        NPC = pet.NPC or false
    }
end

local function startFlexibleFight(participant1, participant2, coords, initiatorSrc, fightType, outlawstatus)
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
    -- Aplanar la estructura si viene anidada desde el cliente
    local flatPet = petData
    if petData.data and petData.data.info then
        local companionid = petData.companionid or petData.PetId
        -- Si companionid no está en la raíz, intenta buscarlo en data
        if not companionid and petData.data.id then
            companionid = petData.data.id
        end
        flatPet = {
            Name = petData.data.info.name,
            Model = petData.data.info.model,
            Health = (petData.data.stats and petData.data.stats.health) or 100,
            Strength = (petData.data.stats and petData.data.stats.strength) or 50,
            Owner = src,
            PetId = companionid
        }
    end
    table.insert(petFightQueue, {pet = flatPet, src = src})
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
        print("[DEBUG][SERVER] pet_vs_npc: npcDog.Name:", npcDog.Name, "npcDog.Model:", npcDog.Model)
        local playerPed = GetPlayerPed(entry.src)
        local playerCoords = GetEntityCoords(playerPed)
 
        local Player = RSGCore.Functions.GetPlayer(entry.src)
        if not Player then return end
        local citizenid = Player.PlayerData.citizenid
        local newoutlawstatus = (outlawstatus + DogFightConfig.OutlawStatusAdd)
        MySQL.update('UPDATE players SET outlawstatus = ? WHERE citizenid = ?', { newoutlawstatus, citizenid })

        startFlexibleFight(entry.pet, npcDog, playerCoords, entry.src, "pet_vs_npc", newoutlawstatus)
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

        local Player = RSGCore.Functions.GetPlayer(entry1.src)
        if not Player then return end
        local citizenid = Player.PlayerData.citizenid
        local newoutlawstatus = (outlawstatus + DogFightConfig.OutlawStatusAdd)
        MySQL.update('UPDATE players SET outlawstatus = ? WHERE citizenid = ?', { newoutlawstatus, citizenid })

        startFlexibleFight(entry1.pet, entry2.pet, playerCoords, entry1.src, "pet_vs_pet", newoutlawstatus)
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
                -- if not Player then return end
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
    -- Clean up PvP challenges
    if pvpChallenges then
        pvpChallenges[src] = nil
        for challengerId, challenge in pairs(pvpChallenges) do
            if challenge.targetSrc == src then
                pvpChallenges[challengerId] = nil
            end
        end
    end
    -- Clean up spectator bets
    if spectatorBets then
        spectatorBets[src] = nil
    end
end)

-- ============================================
-- PVP DIRECT CHALLENGE SYSTEM
-- ============================================

-- Get PvP config with fallback defaults
local function getPvPConfig()
    return DogFightConfig.PvP or {
        Enabled = true,
        ChallengeTimeout = 60,
        NearbyRadius = 50.0,
        NotifyRadius = 100.0,
        OwnerBets = { Enabled = true, MinBet = 50, MaxBet = 5000, WinMultiplier = 2.0 },
        SpectatorBets = { Enabled = true, MinBet = 10, MaxBet = 500, WinMultiplier = 1.8, BettingWindow = 15 },
        XPRewards = { Winner = 25, Loser = 5, KOBonus = 10 }
    }
end

-- Get nearby players for challenge selection
RSGCore.Functions.CreateCallback('hdrp-pets:server:getNearbyPlayers', function(source, cb)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return cb({}) end

    local pvpConfig = getPvPConfig()
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    local nearbyPlayers = {}

    local players = RSGCore.Functions.GetPlayers()
    for _, playerId in ipairs(players) do
        if playerId ~= src then
            local targetPed = GetPlayerPed(playerId)
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(playerCoords - targetCoords)

            if distance <= pvpConfig.NearbyRadius then
                local TargetPlayer = RSGCore.Functions.GetPlayer(playerId)
                if not TargetPlayer then return end
                table.insert(nearbyPlayers, {
                    id = playerId,
                    name = TargetPlayer.PlayerData.charinfo.firstname .. ' ' .. TargetPlayer.PlayerData.charinfo.lastname,
                    distance = math.floor(distance)
                })
            end
        end
    end

    cb(nearbyPlayers)
end)

-- Send PvP challenge to another player
RegisterNetEvent('hdrp-pets:server:sendPvPChallenge')
AddEventHandler('hdrp-pets:server:sendPvPChallenge', function(targetId, petData, betAmount)
    local src = source
    local pvpConfig = getPvPConfig()

    if not pvpConfig.Enabled then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('cl_pvp_disabled'), type = 'error' })
        return
    end

    local Player = RSGCore.Functions.GetPlayer(src)
    local TargetPlayer = RSGCore.Functions.GetPlayer(targetId)

    if not Player or not TargetPlayer then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('cl_pvp_player_not_found'), type = 'error' })
        return
    end

    -- Validate bet amount if betting is enabled
    if pvpConfig.OwnerBets.Enabled and betAmount > 0 then
        if betAmount < pvpConfig.OwnerBets.MinBet or betAmount > pvpConfig.OwnerBets.MaxBet then
            TriggerClientEvent('ox_lib:notify', src, {
                title = locale('cl_bet_invalid'),
                description = string.format(locale('cl_bet_invalid_desc'), pvpConfig.OwnerBets.MinBet, pvpConfig.OwnerBets.MaxBet),
                type = 'error'
            })
            return
        end

        if Player.PlayerData.money.cash < betAmount then
            TriggerClientEvent('ox_lib:notify', src, { title = locale('cl_bet_insufficient_funds'), type = 'error' })
            return
        end
    end

    -- Check if already has a pending challenge
    if pvpChallenges[src] then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('cl_pvp_already_challenging'), type = 'error' })
        return
    end

    -- Store the challenge
    pvpChallenges[src] = {
        challengerSrc = src,
        challengerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
        challengerPet = petData,
        targetSrc = targetId,
        betAmount = betAmount or 0,
        timestamp = os.time()
    }

    -- Notify the target player
    local challengerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    TriggerClientEvent('hdrp-pets:client:receivePvPChallenge', targetId, src, challengerName, petData, betAmount, pvpConfig.ChallengeTimeout)

    -- Notify the challenger
    local targetName = TargetPlayer.PlayerData.charinfo.firstname .. ' ' .. TargetPlayer.PlayerData.charinfo.lastname
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('cl_pvp_challenge_sent'),
        description = string.format(locale('cl_pvp_challenge_sent_desc'), targetName),
        type = 'success',
        duration = 5000
    })

    -- Auto-expire challenge after timeout
    SetTimeout(pvpConfig.ChallengeTimeout * 1000, function()
        if pvpChallenges[src] and pvpChallenges[src].targetSrc == targetId then
            pvpChallenges[src] = nil
            TriggerClientEvent('ox_lib:notify', src, { title = locale('cl_pvp_challenge_expired'), type = 'error' })
            TriggerClientEvent('hdrp-pets:client:challengeExpired', targetId)
        end
    end)
end)

-- Accept PvP challenge
RegisterNetEvent('hdrp-pets:server:acceptPvPChallenge')
AddEventHandler('hdrp-pets:server:acceptPvPChallenge', function(challengerSrc, defenderPetData)
    local src = source
    local pvpConfig = getPvPConfig()

    local challenge = pvpChallenges[challengerSrc]
    if not challenge or challenge.targetSrc ~= src then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('cl_pvp_no_challenge'), type = 'error' })
        return
    end

    local Player = RSGCore.Functions.GetPlayer(src)
    local ChallengerPlayer = RSGCore.Functions.GetPlayer(challengerSrc)

    if not Player or not ChallengerPlayer then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('cl_pvp_player_not_found'), type = 'error' })
        pvpChallenges[challengerSrc] = nil
        return
    end

    local betAmount = challenge.betAmount or 0

    -- Validate bet money for defender
    if pvpConfig.OwnerBets.Enabled and betAmount > 0 then
        if Player.PlayerData.money.cash < betAmount then
            TriggerClientEvent('ox_lib:notify', src, {
                title = locale('cl_bet_insufficient_funds'),
                description = string.format(locale('cl_pvp_need_money'), betAmount),
                type = 'error'
            })
            return
        end

        -- Remove money from both players
        Player.Functions.RemoveMoney('cash', betAmount)
        ChallengerPlayer.Functions.RemoveMoney('cash', betAmount)
    end

    -- Get fight location (defender's position)
    local defenderPed = GetPlayerPed(src)
    local fightCoords = GetEntityCoords(defenderPed)

    -- Create the PvP fight
    local fightId = "pvp_" .. os.time() .. "_" .. challengerSrc .. "_" .. src

    pvpFights[fightId] = {
        fightId = fightId,
        challengerSrc = challengerSrc,
        challengerPet = challenge.challengerPet,
        defenderSrc = src,
        defenderPet = defenderPetData,
        betAmount = betAmount,
        coords = fightCoords,
        startTime = os.time(),
        spectatorBetsOpen = true
    }

    -- Clear the challenge
    pvpChallenges[challengerSrc] = nil

    -- Notify both players
    local challengerName = ChallengerPlayer.PlayerData.charinfo.firstname
    local defenderName = Player.PlayerData.charinfo.firstname

    TriggerClientEvent('ox_lib:notify', challengerSrc, {
        title = locale('cl_pvp_challenge_accepted'),
        description = string.format(locale('cl_pvp_fight_starting'), defenderName),
        type = 'success'
    })

    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('cl_pvp_challenge_accepted'),
        description = string.format(locale('cl_pvp_fight_starting'), challengerName),
        type = 'success'
    })

    -- Notify nearby players about the fight
    notifyNearbyPlayersOfFight(fightId, fightCoords, challenge.challengerPet, defenderPetData, challengerName, defenderName)

    -- Start the fight for all nearby players
    TriggerClientEvent('hdrp-pets:client:startPvPFightForAll', -1, fightId, challenge.challengerPet, defenderPetData, fightCoords, challengerSrc, src)

    -- Close betting window after configured time
    if pvpConfig.SpectatorBets.Enabled then
        SetTimeout(pvpConfig.SpectatorBets.BettingWindow * 1000, function()
            if pvpFights[fightId] then
                pvpFights[fightId].spectatorBetsOpen = false
                -- Notify spectators that betting is closed
                local players = RSGCore.Functions.GetPlayers()
                for _, playerId in ipairs(players) do
                    if playerId ~= challengerSrc and playerId ~= src then
                        TriggerClientEvent('hdrp-pets:client:bettingClosed', playerId, fightId)
                    end
                end
            end
        end)
    end

    -- Auto-resolve fight after 30 seconds
    SetTimeout(30000, function()
        if pvpFights[fightId] then
            resolvePvPFight(fightId)
        end
    end)
end)

-- Decline PvP challenge
RegisterNetEvent('hdrp-pets:server:declinePvPChallenge')
AddEventHandler('hdrp-pets:server:declinePvPChallenge', function(challengerSrc)
    local src = source

    local challenge = pvpChallenges[challengerSrc]
    if not challenge or challenge.targetSrc ~= src then
        return
    end

    pvpChallenges[challengerSrc] = nil

    local Player = RSGCore.Functions.GetPlayer(src)
    local defenderName = Player and (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname) or "Unknown"

    TriggerClientEvent('ox_lib:notify', challengerSrc, {
        title = locale('cl_pvp_challenge_declined'),
        description = string.format(locale('cl_pvp_declined_by'), defenderName),
        type = 'error'
    })

    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('cl_pvp_challenge_declined'),
        description = locale('cl_pvp_you_declined'),
        type = 'inform'
    })
end)

-- Notify nearby players of a fight
function notifyNearbyPlayersOfFight(fightId, coords, pet1, pet2, owner1Name, owner2Name)
    local pvpConfig = getPvPConfig()
    local players = RSGCore.Functions.GetPlayers()

    for _, playerId in ipairs(players) do
        local playerPed = GetPlayerPed(playerId)
        local playerCoords = GetEntityCoords(playerPed)
        local distance = #(playerCoords - coords)

        if distance <= pvpConfig.NotifyRadius then
            TriggerClientEvent('hdrp-pets:client:pvpFightNearby', playerId, fightId, pet1, pet2, owner1Name, owner2Name, coords)
        end
    end
end

-- Spectator places bet on PvP fight
RegisterNetEvent('hdrp-pets:server:placeSpectatorBet')
AddEventHandler('hdrp-pets:server:placeSpectatorBet', function(fightId, betOnOwner, amount)
    local src = source
    local pvpConfig = getPvPConfig()

    if not pvpConfig.SpectatorBets.Enabled then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('cl_pvp_spectator_bets_disabled'), type = 'error' })
        return
    end

    local fight = pvpFights[fightId]
    if not fight then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('cl_pvp_fight_not_found'), type = 'error' })
        return
    end

    -- Can't bet on your own fight
    if src == fight.challengerSrc or src == fight.defenderSrc then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('cl_pvp_cant_bet_own_fight'), type = 'error' })
        return
    end

    -- Check if betting is still open
    if not fight.spectatorBetsOpen then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('cl_pvp_betting_closed'), type = 'error' })
        return
    end

    -- Validate amount
    if amount < pvpConfig.SpectatorBets.MinBet or amount > pvpConfig.SpectatorBets.MaxBet then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('cl_bet_invalid'),
            description = string.format(locale('cl_bet_invalid_desc'), pvpConfig.SpectatorBets.MinBet, pvpConfig.SpectatorBets.MaxBet),
            type = 'error'
        })
        return
    end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or Player.PlayerData.money.cash < amount then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('cl_bet_insufficient_funds'), type = 'error' })
        return
    end

    -- Already has a bet on this fight?
    if spectatorBets[src] and spectatorBets[src][fightId] then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('cl_pvp_already_bet'), type = 'error' })
        return
    end

    -- Remove money and store bet
    Player.Functions.RemoveMoney('cash', amount)

    if not spectatorBets[src] then spectatorBets[src] = {} end
    spectatorBets[src][fightId] = {
        amount = amount,
        betOnOwner = betOnOwner, -- 'challenger' or 'defender'
        timestamp = os.time()
    }

    local betOnName = betOnOwner == 'challenger' and fight.challengerPet.Name or fight.defenderPet.Name
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('cl_bet_placed'),
        description = string.format(locale('cl_pvp_spectator_bet_placed'), amount, betOnName),
        type = 'success'
    })
end)

-- Resolve PvP fight and distribute rewards
function resolvePvPFight(fightId)
    local fight = pvpFights[fightId]
    if not fight then return end

    local pvpConfig = getPvPConfig()

    -- Calculate winner based on pet stats + randomness
    local pet1 = fight.challengerPet
    local pet2 = fight.defenderPet

    local score1 = (pet1.Health or 100) + (pet1.Strength or 50) + math.random(1, 60)
    local score2 = (pet2.Health or 100) + (pet2.Strength or 50) + math.random(1, 60)

    local winnerOwner, loserOwner, winnerPet, loserPet
    local isKO = math.random(1, 100) <= 30 -- 30% chance of KO

    if score1 > score2 then
        winnerOwner = 'challenger'
        loserOwner = 'defender'
        winnerPet = pet1
        loserPet = pet2
    else
        winnerOwner = 'defender'
        loserOwner = 'challenger'
        winnerPet = pet2
        loserPet = pet1
    end

    local winnerSrc = winnerOwner == 'challenger' and fight.challengerSrc or fight.defenderSrc
    local loserSrc = winnerOwner == 'challenger' and fight.defenderSrc or fight.challengerSrc

    -- Distribute owner bets
    if pvpConfig.OwnerBets.Enabled and fight.betAmount > 0 then
        local WinnerPlayer = RSGCore.Functions.GetPlayer(winnerSrc)
        if WinnerPlayer then
            local winnings = math.floor(fight.betAmount * 2 * pvpConfig.OwnerBets.WinMultiplier)
            WinnerPlayer.Functions.AddMoney('cash', winnings)
            TriggerClientEvent('ox_lib:notify', winnerSrc, {
                title = locale('cl_pvp_bet_won'),
                description = string.format(locale('cl_pvp_won_amount'), winnings),
                type = 'success'
            })
        end

        TriggerClientEvent('ox_lib:notify', loserSrc, {
            title = locale('cl_pvp_bet_lost'),
            description = string.format(locale('cl_pvp_lost_amount'), fight.betAmount),
            type = 'error'
        })
    end

    -- Distribute spectator bets
    if pvpConfig.SpectatorBets.Enabled then
        for spectatorSrc, bets in pairs(spectatorBets) do
            local bet = bets[fightId]
            if bet then
                local SpectatorPlayer = RSGCore.Functions.GetPlayer(spectatorSrc)
                if SpectatorPlayer then
                    if bet.betOnOwner == winnerOwner then
                        local winnings = math.floor(bet.amount * pvpConfig.SpectatorBets.WinMultiplier)
                        SpectatorPlayer.Functions.AddMoney('cash', winnings)
                        TriggerClientEvent('ox_lib:notify', spectatorSrc, {
                            title = locale('cl_pvp_spectator_won'),
                            description = string.format(locale('cl_pvp_won_amount'), winnings),
                            type = 'success'
                        })
                    else
                        TriggerClientEvent('ox_lib:notify', spectatorSrc, {
                            title = locale('cl_pvp_spectator_lost'),
                            description = string.format(locale('cl_pvp_lost_amount'), bet.amount),
                            type = 'error'
                        })
                    end
                end
                bets[fightId] = nil
            end
        end
    end

    -- Award XP
    local xpWinner = pvpConfig.XPRewards.Winner + (isKO and pvpConfig.XPRewards.KOBonus or 0)
    local xpLoser = pvpConfig.XPRewards.Loser

    -- Update pet stats and achievements
    updateStatsFight(winnerPet, loserPet, winnerSrc, loserSrc, isKO, true)

    if winnerPet.PetId then checkAchievements(winnerSrc, winnerPet.PetId) end
    if loserPet.PetId then checkAchievements(loserSrc, loserPet.PetId) end

    -- Update XP for pets
    if winnerPet.PetId then
        local wcompanion = Database.GetCompanionByCompanionId(winnerPet.PetId)
        if wcompanion then
            local wdata = json.decode(wcompanion.data or '{}')
            wdata.progression = wdata.progression or {}
            wdata.progression.xp = (wdata.progression.xp or 0) + xpWinner
            Database.UpdateCompanionData(winnerPet.PetId, wdata)
            TriggerClientEvent('hdrp-pets:client:updateanimals', winnerSrc, winnerPet.PetId, wdata)
        end
    end

    if loserPet.PetId then
        local lcompanion = Database.GetCompanionByCompanionId(loserPet.PetId)
        if lcompanion then
            local ldata = json.decode(lcompanion.data or '{}')
            ldata.progression = ldata.progression or {}
            ldata.progression.xp = (ldata.progression.xp or 0) + xpLoser
            Database.UpdateCompanionData(loserPet.PetId, ldata)
            TriggerClientEvent('hdrp-pets:client:updateanimals', loserSrc, loserPet.PetId, ldata)
        end
    end

    -- Notify all players about the result
    TriggerClientEvent('hdrp-pets:client:endPvPFightForAll', -1, fightId, winnerPet.Name, loserPet.Name, isKO, xpWinner)

    -- Clean up
    pvpFights[fightId] = nil
end

-- Manual fight resolution (called from client when fight ends naturally)
RegisterNetEvent('hdrp-pets:server:resolvePvPFight')
AddEventHandler('hdrp-pets:server:resolvePvPFight', function(fightId)
    resolvePvPFight(fightId)
end)

-- Get active PvP fights for client synchronization
RSGCore.Functions.CreateCallback('hdrp-pets:server:getActivePvPFights', function(source, cb)
    local activeFightsList = {}
    for fightId, fight in pairs(pvpFights) do
        table.insert(activeFightsList, {
            fightId = fightId,
            pet1 = fight.challengerPet,
            pet2 = fight.defenderPet,
            coords = fight.coords,
            spectatorBetsOpen = fight.spectatorBetsOpen
        })
    end
    cb(activeFightsList)
end)
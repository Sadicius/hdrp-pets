-- server/systems/race.lua
-- Backend for pet racing system
-- Handles: Solo, NPC, and PvP race modes

local RSGCore = exports['rsg-core']:GetCoreObject()
local Database = lib.load('server.core.database')
local GameConfig = lib.load('shared.game.games')
local RaceConfig = GameConfig.Gpetracing

-- Active races and queues
local activeRaces = {}
local pvpRaceQueue = {}
local spectatorBets = {}

-- Racing achievements structure
local achievementsComp = {
    race = {
        wins = 0,
        races = 0,
        podiums = 0,    -- Top 3 finishes
        winrate = 0,
        bestTime = nil, -- Best race time in ms
    },
    unlocked = {}
}

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

RegisterNetEvent('hdrp-pets:server:startRaceShot', function()
    -- Envía a todos los clientes la orden de iniciar la carrera
    TriggerClientEvent('hdrp-pets:client:triggerRaceShot', -1)
end)

-- Get pet data flattened for racing
local function getPetRacingData(petData, owner)
    if not petData then return nil end

    local data = petData.data or petData
    local info = data.info or {}
    local stats = data.stats or {}
    local progression = data.progression or {}

    -- Calculate racing stats
    local speed = (stats.happiness or 50) + (progression.xp or 0) / 100 -- cambio agility por felicidad
    local stamina = (stats.health or 50) + (stats.happiness or 50) / 2

    return {
        Name = info.name or 'Unknown',
        Model = info.model or 'a_c_doghusky_01',
        Speed = math.min(100, speed),
        Stamina = math.min(100, stamina),
        Owner = owner,
        PetId = petData.companionid or petData.PetId
    }
end

-- Update race achievements for a pet
local function updateRaceAchievements(petId, position, raceTime, totalRacers)
    local companion = Database.GetCompanionByCompanionId(petId)
    if not companion then return end

    local data = json.decode(companion.data or '{}')
    local achievements = json.decode(companion.achievements or '{}')

    achievements.race = achievements.race or {
        wins = 0,
        races = 0,
        podiums = 0,
        winrate = 0,
        bestTime = nil
    }

    -- Update stats
    achievements.race.races = (achievements.race.races or 0) + 1

    if position == 1 then
        achievements.race.wins = (achievements.race.wins or 0) + 1
    end

    if position <= 3 then
        achievements.race.podiums = (achievements.race.podiums or 0) + 1
    end

    -- Update best time
    if raceTime and (not achievements.race.bestTime or raceTime < achievements.race.bestTime) then
        achievements.race.bestTime = raceTime
    end

    -- Calculate winrate
    local totalRaces = achievements.race.races or 1
    achievements.race.winrate = math.floor((achievements.race.wins / totalRaces) * 100)

    Database.UpdateCompanionAchievements(petId, achievements)

    return achievements
end

-- Award XP to a pet
local function awardPetXP(src, petId, xpAmount)
    local companion = Database.GetCompanionByCompanionId(petId)
    if not companion then return end

    local data = json.decode(companion.data or '{}')
    data.progression = data.progression or {}
    data.progression.xp = (data.progression.xp or 0) + xpAmount

    Database.UpdateCompanionData(petId, data)
    TriggerClientEvent('hdrp-pets:client:updateanimals', src, petId, data)

    return data.progression.xp
end

-- ============================================
-- SOLO RACE HANDLING
-- ============================================

RegisterNetEvent('hdrp-pets:server:raceFinished')
AddEventHandler('hdrp-pets:server:raceFinished', function(raceType, raceData)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if raceType == 'solo' then
        -- Solo race: Award XP to winner
        if raceData.winner then
            local xp = awardPetXP(src, raceData.winner, RaceConfig.Solo.XPReward.Winner)
            updateRaceAchievements(raceData.winner, 1, nil, 1)

            TriggerClientEvent('ox_lib:notify', src, {
                title = locale('sv_race_xp_awarded') or 'XP Awarded',
                description = string.format('+%d XP', RaceConfig.Solo.XPReward.Winner),
                type = 'success'
            })
        end

        -- Award participation XP to others
        for _, petId in ipairs(raceData.participants or {}) do
            if petId ~= raceData.winner then
                awardPetXP(src, petId, RaceConfig.Solo.XPReward.Participant)
            end
        end

    elseif raceType == 'npc' then
        -- NPC race: Award prizes based on position
        local petId = raceData.petId
        local position = raceData.position
        local prize = raceData.prize or 0

        if position and petId then
            -- Award XP based on position
            local xpReward = 0
            if position == 1 then
                xpReward = RaceConfig.NPC.XPReward.Winner
            elseif position == 2 then
                xpReward = RaceConfig.NPC.XPReward.Second
            elseif position == 3 then
                xpReward = RaceConfig.NPC.XPReward.Third
            else
                xpReward = RaceConfig.NPC.XPReward.Participant
            end

            awardPetXP(src, petId, xpReward)
            updateRaceAchievements(petId, position, nil, RaceConfig.NPC.NPCCount + 1)

            -- Award cash prize
            if prize > 0 then
                Player.Functions.AddMoney('cash', prize)
                TriggerClientEvent('ox_lib:notify', src, {
                    title = locale('sv_race_prize') or 'Race Prize',
                    description = string.format(locale('sv_race_won_prize') or 'Won $%d!', prize),
                    type = 'success'
                })
            end
        end
    end
end)

-- ============================================
-- PVP RACE SYSTEM
-- ============================================

-- Join PvP race queue
RegisterNetEvent('hdrp-pets:server:joinPvPRace')
AddEventHandler('hdrp-pets:server:joinPvPRace', function(petId, locationIndex, entryFee)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Validate entry fee
    if RaceConfig.PvP.EntryFee.Enabled and entryFee > 0 then
        if entryFee < RaceConfig.PvP.EntryFee.MinFee or entryFee > RaceConfig.PvP.EntryFee.MaxFee then
            TriggerClientEvent('ox_lib:notify', src, {
                title = locale('sv_race_invalid_fee') or 'Invalid Fee',
                type = 'error'
            })
            return
        end

        if Player.PlayerData.money.cash < entryFee then
            TriggerClientEvent('ox_lib:notify', src, {
                title = locale('sv_race_insufficient_funds') or 'Insufficient Funds',
                type = 'error'
            })
            return
        end

        Player.Functions.RemoveMoney('cash', entryFee)
    end

    -- Get pet data from database
    local companion = Database.GetCompanionByCompanionId(petId)
    if not companion then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_race_pet_not_found') or 'Pet Not Found',
            type = 'error'
        })
        return
    end

    local petData = json.decode(companion.data or '{}')
    local petInfo = petData.info or {}
    local petStats = petData.stats or {}
    local petProgression = petData.progression or {}

    -- Calculate racing stats
    local speed = (petStats.happiness or 50) + (petProgression.xp or 0) / 100 -- cambio agility por felicidad
    local stamina = (petStats.health or 50) + (petStats.happiness or 50) / 2

    -- Check if queue exists for this location
    local queueKey = 'race_' .. locationIndex
    if not pvpRaceQueue[queueKey] then
        pvpRaceQueue[queueKey] = {
            locationIndex = locationIndex,
            racers = {},
            prizePool = 0,
            createdAt = os.time(),
            entryFee = entryFee
        }
    end

    local queue = pvpRaceQueue[queueKey]

    -- Check if player already in queue
    for _, racer in ipairs(queue.racers) do
        if racer.owner == src then
            TriggerClientEvent('ox_lib:notify', src, {
                title = locale('sv_race_already_queued') or 'Already in Queue',
                type = 'error'
            })
            -- Refund entry fee
            if entryFee > 0 then
                Player.Functions.AddMoney('cash', entryFee)
            end
            return
        end
    end

    -- Add to queue
    table.insert(queue.racers, {
        owner = src,
        ownerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
        petId = petId,
        petName = petInfo.name or 'Unknown',
        model = petInfo.model or 'a_c_doghusky_01',
        speed = math.min(100, speed),
        stamina = math.min(100, stamina)
    })

    queue.prizePool = queue.prizePool + entryFee

    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('sv_race_joined_queue') or 'Joined Race',
        description = string.format(locale('sv_race_waiting') or 'Waiting for players: %d/%d', #queue.racers, RaceConfig.PvP.MaxPlayers),
        type = 'success'
    })

    -- Notify other players in queue
    for _, racer in ipairs(queue.racers) do
        if racer.owner ~= src then
            TriggerClientEvent('ox_lib:notify', racer.owner, {
                title = locale('sv_race_player_joined') or 'Player Joined',
                description = string.format('%s joined the race!', Player.PlayerData.charinfo.firstname),
                type = 'inform'
            })
        end
    end

    -- Check if enough players to start
    if #queue.racers >= RaceConfig.PvP.MinPlayers then
        -- Start countdown to race
        SetTimeout(10000, function()
            if pvpRaceQueue[queueKey] and #pvpRaceQueue[queueKey].racers >= RaceConfig.PvP.MinPlayers then
                StartPvPRace(queueKey)
            end
        end)

        -- Notify all players
        for _, racer in ipairs(queue.racers) do
            TriggerClientEvent('ox_lib:notify', racer.owner, {
                title = locale('sv_race_starting_soon') or 'Race Starting',
                description = locale('sv_race_starts_in_10') or 'Race starts in 10 seconds!',
                type = 'inform'
            })
        end
    end

    -- Auto-timeout queue after join timeout
    SetTimeout(RaceConfig.PvP.JoinTimeout * 1000, function()
        if pvpRaceQueue[queueKey] and #pvpRaceQueue[queueKey].racers < RaceConfig.PvP.MinPlayers then
            -- Not enough players, refund and cancel
            for _, racer in ipairs(pvpRaceQueue[queueKey].racers) do
                local RacerPlayer = RSGCore.Functions.GetPlayer(racer.owner)
                if RacerPlayer and pvpRaceQueue[queueKey].entryFee > 0 then
                    RacerPlayer.Functions.AddMoney('cash', pvpRaceQueue[queueKey].entryFee)
                end
                TriggerClientEvent('ox_lib:notify', racer.owner, {
                    title = locale('sv_race_cancelled') or 'Race Cancelled',
                    description = locale('sv_race_not_enough_players') or 'Not enough players',
                    type = 'error'
                })
            end
            pvpRaceQueue[queueKey] = nil
        end
    end)
end)

-- Start PvP race
function StartPvPRace(queueKey)
    local queue = pvpRaceQueue[queueKey]
    if not queue then return end

    local raceId = 'pvp_race_' .. os.time() .. '_' .. math.random(1000, 9999)

    activeRaces[raceId] = {
        raceId = raceId,
        locationIndex = queue.locationIndex,
        racers = queue.racers,
        prizePool = queue.prizePool,
        startTime = os.time(),
        results = {},
        spectatorBetsOpen = true
    }

    -- Clear queue
    pvpRaceQueue[queueKey] = nil

    -- Notify all racers and start race on their clients
    for _, racer in ipairs(activeRaces[raceId].racers) do
        TriggerClientEvent('hdrp-pets:client:startPvPRace', racer.owner, raceId, activeRaces[raceId].racers, queue.locationIndex, activeRaces[raceId].prizePool)
    end

    -- Notify nearby players for spectator betting
    if RaceConfig.PvP.SpectatorBets.Enabled then
        local location = RaceConfig.Location[queue.locationIndex]
        if location then
            notifyNearbyPlayersOfRace(raceId, location.Coords, activeRaces[raceId].racers, activeRaces[raceId].prizePool)
        end
    end

    -- Close betting window
    SetTimeout(RaceConfig.PvP.SpectatorBets.BettingWindow * 1000, function()
        if activeRaces[raceId] then
            activeRaces[raceId].spectatorBetsOpen = false
        end
    end)

    -- Auto-end race after max time
    SetTimeout(RaceConfig.MaxRaceTime * 1000, function()
        if activeRaces[raceId] and #activeRaces[raceId].results < #activeRaces[raceId].racers then
            EndPvPRace(raceId)
        end
    end)
end

-- Racer finished
RegisterNetEvent('hdrp-pets:server:pvpRacerFinished')
AddEventHandler('hdrp-pets:server:pvpRacerFinished', function(raceId, petId, position, finishTime)
    local src = source
    local race = activeRaces[raceId]
    if not race then return end

    -- Find racer
    local racer = nil
    for _, r in ipairs(race.racers) do
        if r.owner == src and r.petId == petId then
            racer = r
            break
        end
    end

    if not racer then return end

    -- Check if already finished
    for _, result in ipairs(race.results) do
        if result.owner == src then
            return
        end
    end

    -- Add to results
    table.insert(race.results, {
        owner = src,
        ownerName = racer.ownerName,
        petId = petId,
        petName = racer.petName,
        position = #race.results + 1,
        finishTime = finishTime
    })

    -- Check if all racers finished
    if #race.results >= #race.racers then
        EndPvPRace(raceId)
    end
end)

-- End PvP race and distribute prizes
function EndPvPRace(raceId)
    local race = activeRaces[raceId]
    if not race then return end

    local results = race.results
    local prizePool = race.prizePool

    -- Sort results by finish time (already ordered by position)
    table.sort(results, function(a, b)
        if a.finishTime and b.finishTime then
            return a.finishTime < b.finishTime
        end
        return a.position < b.position
    end)

    -- Update positions after sorting
    for i, result in ipairs(results) do
        result.position = i
    end

    -- Distribute prizes
    local distribution = RaceConfig.PvP.PrizeDistribution

    for i, result in ipairs(results) do
        local Player = RSGCore.Functions.GetPlayer(result.owner)
        if Player then
            local prize = 0
            local xpReward = RaceConfig.PvP.XPRewards.Participant

            if i == 1 then
                prize = math.floor(prizePool * distribution.First / 100)
                xpReward = RaceConfig.PvP.XPRewards.Winner
            elseif i == 2 then
                prize = math.floor(prizePool * distribution.Second / 100)
                xpReward = RaceConfig.PvP.XPRewards.Second
            elseif i == 3 then
                prize = math.floor(prizePool * distribution.Third / 100)
                xpReward = RaceConfig.PvP.XPRewards.Third
            end

            -- Award cash
            if prize > 0 then
                Player.Functions.AddMoney('cash', prize)
            end

            -- Award XP
            awardPetXP(result.owner, result.petId, xpReward)
            updateRaceAchievements(result.petId, i, result.finishTime, #race.racers)

            -- Notify player
            TriggerClientEvent('ox_lib:notify', result.owner, {
                title = string.format(locale('sv_race_position') or 'Position: %d', i),
                description = prize > 0 and string.format(locale('sv_race_won_prize') or 'Won $%d!', prize) or '+' .. xpReward .. ' XP',
                type = i <= 3 and 'success' or 'inform'
            })
        end
    end

    -- Distribute spectator bets
    distributeSpectatorBets(raceId, results)

    -- Notify all clients that race ended
    TriggerClientEvent('hdrp-pets:client:endPvPRace', -1, raceId, results, nil)

    -- Cleanup
    activeRaces[raceId] = nil
end

-- Notify nearby players of race for spectator betting
function notifyNearbyPlayersOfRace(raceId, coords, racers, prizePool)
    local players = RSGCore.Functions.GetPlayers()

    for _, playerId in ipairs(players) do
        -- Check if player is not a racer
        local isRacer = false
        for _, racer in ipairs(racers) do
            if racer.owner == playerId then
                isRacer = true
                break
            end
        end

        if not isRacer then
            local playerPed = GetPlayerPed(playerId)
            local playerCoords = GetEntityCoords(playerPed)
            local distance = #(playerCoords - coords)

            if distance <= RaceConfig.PvP.NearbyRadius then
                TriggerClientEvent('hdrp-pets:client:pvpRaceNearby', playerId, raceId, racers, prizePool)
            end
        end
    end
end

-- ============================================
-- SPECTATOR BETTING
-- ============================================

RegisterNetEvent('hdrp-pets:server:placeRaceSpectatorBet')
AddEventHandler('hdrp-pets:server:placeRaceSpectatorBet', function(raceId, betOnOwner, amount)
    local src = source
    local race = activeRaces[raceId]
    if not race then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_race_not_found') or 'Race not found', type = 'error' })
        return
    end

    if not race.spectatorBetsOpen then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_race_betting_closed') or 'Betting closed', type = 'error' })
        return
    end

    -- Validate amount
    local betConfig = RaceConfig.PvP.SpectatorBets
    if amount < betConfig.MinBet or amount > betConfig.MaxBet then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_race_invalid_bet') or 'Invalid Bet',
            description = string.format('Min: $%d, Max: $%d', betConfig.MinBet, betConfig.MaxBet),
            type = 'error'
        })
        return
    end

    -- Can't bet on your own race
    for _, racer in ipairs(race.racers) do
        if racer.owner == src then
            TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_race_cant_bet_own') or "Can't bet on own race", type = 'error' })
            return
        end
    end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or Player.PlayerData.money.cash < amount then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_race_insufficient_funds') or 'Insufficient funds', type = 'error' })
        return
    end

    -- Check if already bet
    if not spectatorBets[src] then spectatorBets[src] = {} end
    if spectatorBets[src][raceId] then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_race_already_bet') or 'Already bet', type = 'error' })
        return
    end

    -- Take money and store bet
    Player.Functions.RemoveMoney('cash', amount)

    spectatorBets[src][raceId] = {
        amount = amount,
        betOnOwner = betOnOwner
    }

    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('sv_race_bet_placed') or 'Bet Placed',
        description = string.format('$%d', amount),
        type = 'success'
    })
end)

-- Distribute spectator bets after race
function distributeSpectatorBets(raceId, results)
    if not results or #results == 0 then return end

    local winner = results[1]
    local betConfig = RaceConfig.PvP.SpectatorBets

    for spectatorSrc, bets in pairs(spectatorBets) do
        local bet = bets[raceId]
        if bet then
            local SpectatorPlayer = RSGCore.Functions.GetPlayer(spectatorSrc)
            if SpectatorPlayer then
                if bet.betOnOwner == winner.owner then
                    local winnings = math.floor(bet.amount * betConfig.WinMultiplier)
                    SpectatorPlayer.Functions.AddMoney('cash', winnings)
                    TriggerClientEvent('ox_lib:notify', spectatorSrc, {
                        title = locale('sv_race_bet_won') or 'Bet Won!',
                        description = string.format('+$%d', winnings),
                        type = 'success'
                    })
                else
                    TriggerClientEvent('ox_lib:notify', spectatorSrc, {
                        title = locale('sv_race_bet_lost') or 'Bet Lost',
                        description = string.format('-$%d', bet.amount),
                        type = 'error'
                    })
                end
            end
            bets[raceId] = nil
        end
    end
end

-- ============================================
-- RANKING COMMAND
-- ============================================

RegisterCommand('pet_race_ranking', function(src)
    local companions = Database.GetAllCompanionsForRanking()
    local ranking = {}

    for _, companion in ipairs(companions or {}) do
        local achievements = companion.achievements and json.decode(companion.achievements) or {}
        if achievements.race and achievements.race.races and achievements.race.races > 0 then
            ranking[#ranking + 1] = {
                petId = companion.companionid or companion.id or "N/A",
                wins = achievements.race.wins or 0,
                races = achievements.race.races or 0,
                podiums = achievements.race.podiums or 0,
                winrate = achievements.race.winrate or 0,
                bestTime = achievements.race.bestTime
            }
        end
    end

    table.sort(ranking, function(a, b) return a.wins > b.wins end)

    local msg = (locale('sv_race_ranking') or 'Race Ranking') .. ':\n'

    for i, r in ipairs(ranking) do
        local timeStr = r.bestTime and string.format('%.2fs', r.bestTime / 1000) or 'N/A'
        msg = msg .. string.format('%d. %s - Wins: %d, Races: %d, Podiums: %d, Best: %s\n',
            i, r.petId, r.wins, r.races, r.podiums, timeStr)
        if i >= 10 then break end
    end

    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('sv_race_ranking') or 'Race Ranking',
        description = msg,
        type = 'inform',
        duration = 15000
    })
end, false)

-- ============================================
-- CLEANUP
-- ============================================

AddEventHandler('playerDropped', function()
    local src = source

    -- Cleanup spectator bets
    spectatorBets[src] = nil

    -- Remove from queues
    for queueKey, queue in pairs(pvpRaceQueue) do
        for i = #queue.racers, 1, -1 do
            if queue.racers[i].owner == src then
                -- Refund entry fee
                local Player = RSGCore.Functions.GetPlayer(src)
                -- if not Player then return end
                if Player and queue.entryFee > 0 then
                    Player.Functions.AddMoney('cash', queue.entryFee)
                end
                queue.prizePool = queue.prizePool - (queue.entryFee or 0)
                table.remove(queue.racers, i)
            end
        end
    end
end)

-- Export for external use
exports('GetActiveRaces', function()
    return activeRaces
end)

exports('GetRaceQueue', function()
    return pvpRaceQueue
end)

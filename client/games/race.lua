-- client/games/race.lua
-- Pet Racing System for hdrp-pets
-- Three race modes: Solo (own pets), NPC (vs AI), PvP (multiplayer)

local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
local GameConfig = lib.load('shared.game.games')
local ManageSpawn = lib.load('client.stable.utils_spawn')

local RaceConfig = GameConfig.Gpetracing

-- Local state variables
local currentRace = nil
local isRacing = false
local recentlyRaced = 0
local raceCheckpoints = {}
local spawnedNPCs = {}
local checkpointBlips = {}
local checkpointProps = {}

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

-- Create race prompt
local function CreateRacePrompt(name, key, holdDuration)
    local prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, RSGCore.Shared.Keybinds[key] or 0xF3830D8E)
    PromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', name))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    PromptSetHoldMode(prompt, holdDuration or 1000)
    local group = GetRandomIntInRange(0, 0xffffff)
    PromptSetGroup(prompt, group)
    PromptRegisterEnd(prompt)
    return prompt, group
end

-- Get pet racing stats from data
local function GetPetRacingStats(petData)
    local stats = petData.data and petData.data.stats or {}
    local progression = petData.data and petData.data.progression or {}

    -- Calculate speed and stamina from pet attributes
    local speed = (stats.agility or 50) + (progression.xp or 0) / 100
    local stamina = (stats.health or 50) + (stats.happiness or 50) / 2

    return {
        Speed = math.min(100, speed),
        Stamina = math.min(100, stamina)
    }
end

-- Calculate checkpoints for a track
local function CalculateCheckpoints(startCoords, track)
    local checkpoints = {}
    for i, point in ipairs(track) do
        local worldCoords = vector3(
            startCoords.x + point.offset.x,
            startCoords.y + point.offset.y,
            startCoords.z + point.offset.z
        )
        -- Adjust Z coordinate to ground level
        local _, groundZ = GetGroundZAndNormalFor_3dCoord(worldCoords.x, worldCoords.y, worldCoords.z + 10)
        if groundZ == 0 then groundZ = startCoords.z end

        checkpoints[i] = vector3(worldCoords.x, worldCoords.y, groundZ)
    end
    return checkpoints
end

-- Spawn checkpoint props and blips
local function SpawnCheckpointMarkers(checkpoints)
    for i, coords in ipairs(checkpoints) do
        -- Create blip
        local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, coords.x, coords.y, coords.z)
        SetBlipSprite(blip, RaceConfig.CheckpointBlipSprite, true)
        SetBlipScale(blip, 0.6)
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, "Checkpoint " .. i)
        table.insert(checkpointBlips, blip)

        -- Create prop (optional visual marker)
        if RaceConfig.CheckpointModel then
            local model = RaceConfig.CheckpointModel
            if lib.requestModel(model, 5000) then
                local prop = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
                PlaceObjectOnGroundProperly(prop)
                SetEntityAlpha(prop, 200, false)
                table.insert(checkpointProps, prop)
            end
        end
    end
end

-- Cleanup checkpoint markers
local function CleanupCheckpointMarkers()
    for _, blip in ipairs(checkpointBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    checkpointBlips = {}

    for _, prop in ipairs(checkpointProps) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end
    checkpointProps = {}
end

-- Cleanup spawned NPCs
local function CleanupNPCs()
    for _, npc in ipairs(spawnedNPCs) do
        if npc.ped and DoesEntityExist(npc.ped) then
            DeleteEntity(npc.ped)
        end
        if npc.blip and DoesBlipExist(npc.blip) then
            RemoveBlip(npc.blip)
        end
    end
    spawnedNPCs = {}
end

-- Spawn NPC dog for racing
local function SpawnNPCRacer(npcData, coords, heading)
    local model = GetHashKey(npcData.Model)
    if not lib.requestModel(model, 5000) then
        return nil
    end

    local ped = CreatePed(model, coords.x, coords.y, coords.z, heading, false, false, false, false)
    if not ped or not DoesEntityExist(ped) then
        return nil
    end

    PlacePedOnGroundProperly(ped)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)
    FreezeEntityPosition(ped, true)

    -- Create blip for NPC
    local blip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, -1230993421, ped)
    SetBlipSprite(blip, 1966442364, true)
    SetBlipScale(blip, 0.8)
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, npcData.Name)

    local npcRacer = {
        ped = ped,
        blip = blip,
        data = npcData,
        currentCheckpoint = 1,
        finished = false,
        finishTime = nil
    }

    table.insert(spawnedNPCs, npcRacer)
    return npcRacer
end

-- Move pet/NPC to next checkpoint
local function MovePetToCheckpoint(ped, targetCoords, speed)
    if not DoesEntityExist(ped) then return end

    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)

    -- Use run speed based on pet's Speed stat
    local moveSpeed = 1.5 + (speed / 100) * 1.5  -- Range: 1.5 to 3.0

    TaskGoToCoordAnyMeans(ped, targetCoords.x, targetCoords.y, targetCoords.z, moveSpeed, 0, 0, 786603, 0xbf800000)
end

-- Check if pet reached checkpoint
local function HasReachedCheckpoint(ped, checkpointCoords)
    if not DoesEntityExist(ped) then return false end

    local pedCoords = GetEntityCoords(ped)
    local dist = #(pedCoords - checkpointCoords)

    return dist <= RaceConfig.CheckpointRadius
end

-- ============================================
-- SOLO RACE MODE (Player's own pets compete)
-- ============================================

local function StartSoloRace(locationIndex)
    local location = RaceConfig.Location[locationIndex]
    if not location then
        lib.notify({ title = locale('cl_race_error') or 'Error', description = locale('cl_race_invalid_location') or 'Invalid location', type = 'error' })
        return
    end

    -- Get all active pets
    local activePets = {}
    for companionid, petData in pairs(State.GetAllPets()) do
        if petData and petData.spawned and DoesEntityExist(petData.ped) and not IsEntityDead(petData.ped) then
            local stats = GetPetRacingStats(petData)
            table.insert(activePets, {
                id = companionid,
                ped = petData.ped,
                name = (petData.data and petData.data.info and petData.data.info.name) or 'Unknown',
                speed = stats.Speed,
                stamina = stats.Stamina,
                currentCheckpoint = 1,
                finished = false,
                finishTime = nil
            })
        end
    end

    if #activePets < RaceConfig.Solo.MinPets then
        lib.notify({
            title = locale('cl_race_not_enough_pets') or 'Not Enough Pets',
            description = string.format(locale('cl_race_need_pets') or 'Need at least %d pets to race', RaceConfig.Solo.MinPets),
            type = 'error'
        })
        return
    end

    if #activePets > RaceConfig.Solo.MaxPets then
        activePets = {table.unpack(activePets, 1, RaceConfig.Solo.MaxPets)}
    end

    isRacing = true
    currentRace = {
        type = 'solo',
        locationIndex = locationIndex,
        racers = activePets,
        startTime = nil,
        finished = false
    }

    -- Calculate checkpoints
    raceCheckpoints = CalculateCheckpoints(location.Coords, location.Track)
    SpawnCheckpointMarkers(raceCheckpoints)

    -- Move pets to starting positions
    local startCoords = location.Coords
    for i, racer in ipairs(activePets) do
        local offsetX = (i - 1) * 2 - (#activePets - 1)
        local startPos = vector3(startCoords.x + offsetX, startCoords.y - 5, startCoords.z)

        TaskGoToCoordAnyMeans(racer.ped, startPos.x, startPos.y, startPos.z, 2.0, 0, 0, 786603, 0xbf800000)
    end

    -- Wait for pets to reach starting positions
    Wait(3000)

    -- Freeze pets at start
    for _, racer in ipairs(activePets) do
        FreezeEntityPosition(racer.ped, true)
        ClearPedTasks(racer.ped)
    end

    -- Countdown
    for i = RaceConfig.CountdownTime, 1, -1 do
        lib.notify({
            title = locale('cl_race_countdown') or 'Race Starting',
            description = tostring(i),
            type = 'inform',
            duration = 900
        })
        Wait(1000)
    end

    lib.notify({
        title = locale('cl_race_go') or 'GO!',
        description = locale('cl_race_started') or 'The race has begun!',
        type = 'success',
        duration = 2000
    })

    currentRace.startTime = GetGameTimer()

    -- Start all pets racing
    for _, racer in ipairs(currentRace.racers) do
        FreezeEntityPosition(racer.ped, false)
        MovePetToCheckpoint(racer.ped, raceCheckpoints[1], racer.speed)
    end

    -- Race loop
    CreateThread(function()
        local finishedCount = 0
        local results = {}

        while isRacing and finishedCount < #currentRace.racers do
            Wait(100)

            -- Check timeout
            if GetGameTimer() - currentRace.startTime > RaceConfig.MaxRaceTime * 1000 then
                lib.notify({ title = locale('cl_race_timeout') or 'Timeout', type = 'error' })
                break
            end

            for _, racer in ipairs(currentRace.racers) do
                if not racer.finished and DoesEntityExist(racer.ped) then
                    local currentCp = racer.currentCheckpoint

                    if HasReachedCheckpoint(racer.ped, raceCheckpoints[currentCp]) then
                        racer.currentCheckpoint = currentCp + 1

                        if racer.currentCheckpoint > #raceCheckpoints then
                            -- Pet finished the race
                            racer.finished = true
                            racer.finishTime = GetGameTimer() - currentRace.startTime
                            finishedCount = finishedCount + 1
                            table.insert(results, racer)

                            lib.notify({
                                title = racer.name,
                                description = string.format(locale('cl_race_finished_position') or 'Finished in position %d!', finishedCount),
                                type = 'success'
                            })
                        else
                            -- Move to next checkpoint
                            MovePetToCheckpoint(racer.ped, raceCheckpoints[racer.currentCheckpoint], racer.speed)
                        end
                    end
                end
            end
        end

        -- Race finished - show results
        isRacing = false
        currentRace.finished = true

        if #results > 0 then
            local winner = results[1]
            lib.notify({
                title = locale('cl_race_winner') or 'Winner!',
                description = string.format(locale('cl_race_winner_announce') or '%s wins the race!', winner.name),
                type = 'success',
                duration = 7000
            })

            -- Award XP
            TriggerServerEvent('hdrp-pets:server:raceFinished', 'solo', {
                winner = winner.id,
                participants = {}
            })
        end

        -- Cleanup
        Wait(5000)
        CleanupCheckpointMarkers()

        -- Return pets to player
        local playerCoords = GetEntityCoords(cache.ped)
        for _, racer in ipairs(currentRace.racers) do
            if DoesEntityExist(racer.ped) then
                ManageSpawn.moveCompanionToPlayer(racer.ped, cache.ped)
            end
        end

        currentRace = nil
        recentlyRaced = RaceConfig.RaceCooldown
    end)
end

-- ============================================
-- NPC RACE MODE (Player's pet vs NPCs)
-- ============================================

local function StartNPCRace(petId, locationIndex)
    local location = RaceConfig.Location[locationIndex]
    if not location then
        lib.notify({ title = locale('cl_race_error') or 'Error', type = 'error' })
        return
    end

    local petData = State.GetPet(petId)
    if not petData or not petData.spawned or not DoesEntityExist(petData.ped) then
        lib.notify({ title = locale('cl_race_pet_not_found') or 'Pet not found', type = 'error' })
        return
    end

    -- Check XP requirement
    local xp = (petData.data and petData.data.progression and petData.data.progression.xp) or 0
    if xp < RaceConfig.NPC.MinXP then
        lib.notify({
            title = locale('cl_race_xp_required') or 'XP Required',
            description = string.format(locale('cl_race_need_xp') or 'Need %d XP to race', RaceConfig.NPC.MinXP),
            type = 'error'
        })
        return
    end

    isRacing = true

    -- Setup player's pet
    local playerStats = GetPetRacingStats(petData)
    local playerRacer = {
        id = petId,
        ped = petData.ped,
        name = (petData.data and petData.data.info and petData.data.info.name) or 'Your Pet',
        speed = playerStats.Speed,
        stamina = playerStats.Stamina,
        currentCheckpoint = 1,
        finished = false,
        finishTime = nil,
        isPlayer = true
    }

    local racers = { playerRacer }

    -- Spawn NPC racers
    local startCoords = location.Coords
    local usedNPCs = {}

    for i = 1, RaceConfig.NPC.NPCCount do
        local npcData
        repeat
            npcData = RaceConfig.NPCDogs[math.random(#RaceConfig.NPCDogs)]
        until not usedNPCs[npcData.Name]
        usedNPCs[npcData.Name] = true

        local offsetX = i * 2
        local spawnPos = vector3(startCoords.x + offsetX, startCoords.y - 5, startCoords.z)

        local npc = SpawnNPCRacer(npcData, spawnPos, 0.0)
        if npc then
            npc.currentCheckpoint = 1
            npc.speed = npcData.Speed
            npc.stamina = npcData.Stamina
            npc.name = npcData.Name
            npc.isPlayer = false
            table.insert(racers, npc)
        end
    end

    currentRace = {
        type = 'npc',
        locationIndex = locationIndex,
        racers = racers,
        startTime = nil,
        finished = false,
        playerPetId = petId
    }

    -- Calculate checkpoints
    raceCheckpoints = CalculateCheckpoints(location.Coords, location.Track)
    SpawnCheckpointMarkers(raceCheckpoints)

    -- Move player's pet to start
    local playerStartPos = vector3(startCoords.x, startCoords.y - 5, startCoords.z)
    TaskGoToCoordAnyMeans(playerRacer.ped, playerStartPos.x, playerStartPos.y, playerStartPos.z, 2.0, 0, 0, 786603, 0xbf800000)

    Wait(3000)

    -- Freeze all at start
    for _, racer in ipairs(racers) do
        FreezeEntityPosition(racer.ped, true)
        ClearPedTasks(racer.ped)
    end

    -- Countdown
    for i = RaceConfig.CountdownTime, 1, -1 do
        lib.notify({
            title = locale('cl_race_countdown') or 'Race Starting',
            description = tostring(i),
            type = 'inform',
            duration = 900
        })
        Wait(1000)
    end

    lib.notify({
        title = locale('cl_race_go') or 'GO!',
        description = locale('cl_race_started') or 'The race has begun!',
        type = 'success'
    })

    currentRace.startTime = GetGameTimer()

    -- Start all racers
    for _, racer in ipairs(currentRace.racers) do
        FreezeEntityPosition(racer.ped, false)
        MovePetToCheckpoint(racer.ped, raceCheckpoints[1], racer.speed)
    end

    -- Race loop with NPC AI
    CreateThread(function()
        local finishedCount = 0
        local results = {}

        while isRacing and finishedCount < #currentRace.racers do
            Wait(100)

            if GetGameTimer() - currentRace.startTime > RaceConfig.MaxRaceTime * 1000 then
                break
            end

            for _, racer in ipairs(currentRace.racers) do
                if not racer.finished and DoesEntityExist(racer.ped) then
                    local currentCp = racer.currentCheckpoint

                    if HasReachedCheckpoint(racer.ped, raceCheckpoints[currentCp]) then
                        racer.currentCheckpoint = currentCp + 1

                        if racer.currentCheckpoint > #raceCheckpoints then
                            racer.finished = true
                            racer.finishTime = GetGameTimer() - currentRace.startTime
                            finishedCount = finishedCount + 1
                            racer.position = finishedCount
                            table.insert(results, racer)

                            local title = racer.isPlayer and locale('cl_race_your_pet') or racer.name
                            lib.notify({
                                title = title,
                                description = string.format(locale('cl_race_finished_position') or 'Finished %d!', finishedCount),
                                type = racer.isPlayer and 'success' or 'inform'
                            })
                        else
                            -- Add slight randomness to NPC movement
                            local speedMod = racer.isPlayer and 0 or (math.random(-5, 5))
                            MovePetToCheckpoint(racer.ped, raceCheckpoints[racer.currentCheckpoint], racer.speed + speedMod)
                        end
                    end
                end
            end
        end

        isRacing = false
        currentRace.finished = true

        -- Calculate player position
        local playerPosition = nil
        for i, racer in ipairs(results) do
            if racer.isPlayer then
                playerPosition = i
                break
            end
        end

        if playerPosition then
            local prizeConfig = RaceConfig.NPC.Prizes
            local prize = 0
            if playerPosition == 1 then prize = prizeConfig.First
            elseif playerPosition == 2 then prize = prizeConfig.Second
            elseif playerPosition == 3 then prize = prizeConfig.Third
            end

            TriggerServerEvent('hdrp-pets:server:raceFinished', 'npc', {
                petId = petId,
                position = playerPosition,
                prize = prize
            })
        end

        -- Cleanup
        Wait(5000)
        CleanupCheckpointMarkers()
        CleanupNPCs()

        if DoesEntityExist(playerRacer.ped) then
            ManageSpawn.moveCompanionToPlayer(playerRacer.ped, cache.ped)
        end

        currentRace = nil
        recentlyRaced = RaceConfig.RaceCooldown
    end)
end

-- ============================================
-- PVP RACE MODE (Multiplayer)
-- ============================================

local pvpRaceQueue = {}
local currentPvPRace = nil

-- Open PvP race menu
function OpenPvPRaceMenu(locationIndex)
    if not RaceConfig.PvP.Enabled then
        lib.notify({ title = locale('cl_race_pvp_disabled') or 'PvP Disabled', type = 'error' })
        return
    end

    local petList = {}
    for id, pet in pairs(State.GetAllPets()) do
        if pet and pet.spawned and DoesEntityExist(pet.ped) then
            local petName = (pet.data and pet.data.info and pet.data.info.name) or 'Unknown'
            local stats = GetPetRacingStats(pet)

            petList[#petList + 1] = {
                title = petName .. ' (ID: ' .. id .. ')',
                metadata = {
                    { label = locale('cl_race_speed') or 'Speed', value = math.floor(stats.Speed) .. '%' },
                    { label = locale('cl_race_stamina') or 'Stamina', value = math.floor(stats.Stamina) .. '%' },
                },
                icon = 'fa-solid fa-dog',
                args = { petId = id, pet = pet, locationIndex = locationIndex },
                onSelect = function(data)
                    if RaceConfig.PvP.EntryFee.Enabled then
                        local input = lib.inputDialog(locale('cl_race_entry_fee') or 'Entry Fee', {
                            {
                                type = 'number',
                                label = locale('cl_race_fee_amount') or 'Fee Amount',
                                description = string.format('Min: $%d, Max: $%d', RaceConfig.PvP.EntryFee.MinFee, RaceConfig.PvP.EntryFee.MaxFee),
                                required = true,
                                min = RaceConfig.PvP.EntryFee.MinFee,
                                max = RaceConfig.PvP.EntryFee.MaxFee,
                                default = RaceConfig.PvP.EntryFee.MinFee
                            }
                        })

                        if input and input[1] then
                            TriggerServerEvent('hdrp-pets:server:joinPvPRace', data.petId, data.locationIndex, input[1])
                        end
                    else
                        TriggerServerEvent('hdrp-pets:server:joinPvPRace', data.petId, data.locationIndex, 0)
                    end
                end
            }
        end
    end

    if #petList == 0 then
        lib.notify({ title = locale('cl_race_no_pets') or 'No pets available', type = 'error' })
        return
    end

    lib.registerContext({
        id = 'pvp_race_pet_selection',
        title = locale('cl_race_select_pet') or 'Select Pet for Race',
        options = petList
    })
    lib.showContext('pvp_race_pet_selection')
end

-- Receive PvP race start from server
RegisterNetEvent('hdrp-pets:client:startPvPRace')
AddEventHandler('hdrp-pets:client:startPvPRace', function(raceId, racers, locationIndex, prizePool)
    local location = RaceConfig.Location[locationIndex]
    if not location then return end

    isRacing = true
    currentPvPRace = {
        raceId = raceId,
        locationIndex = locationIndex,
        prizePool = prizePool,
        racers = {},
        startTime = nil
    }

    -- Calculate checkpoints
    raceCheckpoints = CalculateCheckpoints(location.Coords, location.Track)
    SpawnCheckpointMarkers(raceCheckpoints)

    -- Setup racers
    local myServerId = GetPlayerServerId(PlayerId())
    local startCoords = location.Coords

    for i, racerData in ipairs(racers) do
        local racer = {
            owner = racerData.owner,
            ownerName = racerData.ownerName,
            petId = racerData.petId,
            name = racerData.petName,
            speed = racerData.speed,
            stamina = racerData.stamina,
            currentCheckpoint = 1,
            finished = false,
            finishTime = nil,
            ped = nil,
            isMyPet = racerData.owner == myServerId
        }

        local offsetX = (i - 1) * 2 - (#racers - 1)
        local startPos = vector3(startCoords.x + offsetX, startCoords.y - 5, startCoords.z)

        if racer.isMyPet then
            local petData = State.GetPet(racerData.petId)
            if petData and petData.ped then
                racer.ped = petData.ped
                TaskGoToCoordAnyMeans(racer.ped, startPos.x, startPos.y, startPos.z, 2.0, 0, 0, 786603, 0xbf800000)
            end
        else
            -- Spawn NPC representation for other players' pets
            local npcData = { Model = racerData.model, Name = racerData.petName }
            local npc = SpawnNPCRacer(npcData, startPos, 0.0)
            if npc then
                racer.ped = npc.ped
            end
        end

        table.insert(currentPvPRace.racers, racer)
    end

    -- Notify about race
    lib.notify({
        title = locale('cl_race_pvp_starting') or 'PvP Race Starting',
        description = string.format(locale('cl_race_prize_pool') or 'Prize Pool: $%d', prizePool),
        type = 'inform',
        duration = 5000
    })

    Wait(3000)

    -- Freeze all at start
    for _, racer in ipairs(currentPvPRace.racers) do
        if racer.ped and DoesEntityExist(racer.ped) then
            FreezeEntityPosition(racer.ped, true)
            ClearPedTasks(racer.ped)
        end
    end

    -- Countdown
    for i = RaceConfig.CountdownTime, 1, -1 do
        lib.notify({ title = tostring(i), type = 'inform', duration = 900 })
        Wait(1000)
    end

    lib.notify({ title = locale('cl_race_go') or 'GO!', type = 'success' })

    currentPvPRace.startTime = GetGameTimer()

    -- Start all racers
    for _, racer in ipairs(currentPvPRace.racers) do
        if racer.ped and DoesEntityExist(racer.ped) then
            FreezeEntityPosition(racer.ped, false)
            MovePetToCheckpoint(racer.ped, raceCheckpoints[1], racer.speed)
        end
    end

    -- Race loop
    CreateThread(function()
        local finishedCount = 0
        local results = {}

        while isRacing and finishedCount < #currentPvPRace.racers do
            Wait(100)

            if GetGameTimer() - currentPvPRace.startTime > RaceConfig.MaxRaceTime * 1000 then
                break
            end

            for _, racer in ipairs(currentPvPRace.racers) do
                if not racer.finished and racer.ped and DoesEntityExist(racer.ped) then
                    local currentCp = racer.currentCheckpoint

                    if HasReachedCheckpoint(racer.ped, raceCheckpoints[currentCp]) then
                        racer.currentCheckpoint = currentCp + 1

                        if racer.currentCheckpoint > #raceCheckpoints then
                            racer.finished = true
                            racer.finishTime = GetGameTimer() - currentPvPRace.startTime
                            finishedCount = finishedCount + 1
                            racer.position = finishedCount
                            table.insert(results, racer)

                            -- Report finish to server
                            if racer.isMyPet then
                                TriggerServerEvent('hdrp-pets:server:pvpRacerFinished', raceId, racer.petId, finishedCount, racer.finishTime)
                            end

                            lib.notify({
                                title = racer.name,
                                description = string.format(locale('cl_race_finished_position') or 'Finished %d!', finishedCount),
                                type = racer.isMyPet and 'success' or 'inform'
                            })
                        else
                            local speedMod = racer.isMyPet and 0 or math.random(-5, 5)
                            MovePetToCheckpoint(racer.ped, raceCheckpoints[racer.currentCheckpoint], racer.speed + speedMod)
                        end
                    end
                end
            end
        end

        isRacing = false
    end)
end)

-- Handle PvP race end from server
RegisterNetEvent('hdrp-pets:client:endPvPRace')
AddEventHandler('hdrp-pets:client:endPvPRace', function(raceId, results, prizes)
    if not currentPvPRace or currentPvPRace.raceId ~= raceId then return end

    isRacing = false

    -- Show final results
    if results and #results > 0 then
        local winner = results[1]
        lib.notify({
            title = locale('cl_race_winner') or 'Winner!',
            description = string.format('%s wins the race!', winner.petName),
            type = 'success',
            duration = 7000
        })
    end

    -- Cleanup
    Wait(5000)
    CleanupCheckpointMarkers()

    -- Cleanup non-owned pets (NPCs representing other players)
    for _, racer in ipairs(currentPvPRace.racers) do
        if not racer.isMyPet and racer.ped and DoesEntityExist(racer.ped) then
            DeleteEntity(racer.ped)
        elseif racer.isMyPet and racer.ped and DoesEntityExist(racer.ped) then
            ManageSpawn.moveCompanionToPlayer(racer.ped, cache.ped)
        end
    end

    CleanupNPCs()
    currentPvPRace = nil
    recentlyRaced = RaceConfig.RaceCooldown
end)

-- ============================================
-- MAIN RACE MENU
-- ============================================

RegisterNetEvent('hdrp-pets:client:openRaceMenu')
AddEventHandler('hdrp-pets:client:openRaceMenu', function(locationIndex)
    if recentlyRaced > 0 then
        lib.notify({
            title = locale('cl_race_cooldown') or 'Cooldown',
            description = string.format(locale('cl_race_cooldown_desc') or 'Wait %d seconds', recentlyRaced),
            type = 'error'
        })
        return
    end

    if isRacing then
        lib.notify({ title = locale('cl_race_already_racing') or 'Already in a race', type = 'error' })
        return
    end

    local options = {
        {
            title = locale('cl_race_solo') or 'Solo Race',
            description = locale('cl_race_solo_desc') or 'Race your own pets against each other',
            icon = 'fa-solid fa-dog',
            metadata = {
                { label = locale('cl_race_min_pets') or 'Min Pets', value = RaceConfig.Solo.MinPets },
                { label = locale('cl_race_xp_winner') or 'Winner XP', value = RaceConfig.Solo.XPReward.Winner },
            },
            onSelect = function()
                StartSoloRace(locationIndex)
            end
        },
        {
            title = locale('cl_race_npc') or 'Race vs NPCs',
            description = locale('cl_race_npc_desc') or 'Race your selected pet against AI opponents',
            icon = 'fa-solid fa-robot',
            metadata = {
                { label = locale('cl_race_npc_count') or 'Opponents', value = RaceConfig.NPC.NPCCount },
                { label = locale('cl_race_min_xp') or 'Min XP', value = RaceConfig.NPC.MinXP },
                { label = locale('cl_race_first_prize') or '1st Prize', value = '$' .. RaceConfig.NPC.Prizes.First },
            },
            onSelect = function()
                -- Open pet selection for NPC race
                local petList = {}
                for id, pet in pairs(State.GetAllPets()) do
                    if pet and pet.spawned and DoesEntityExist(pet.ped) then
                        local petName = (pet.data and pet.data.info and pet.data.info.name) or 'Unknown'
                        local stats = GetPetRacingStats(pet)
                        local xp = (pet.data and pet.data.progression and pet.data.progression.xp) or 0

                        petList[#petList + 1] = {
                            title = petName,
                            metadata = {
                                { label = 'XP', value = xp },
                                { label = locale('cl_race_speed') or 'Speed', value = math.floor(stats.Speed) .. '%' },
                            },
                            args = { petId = id },
                            onSelect = function(data)
                                StartNPCRace(data.petId, locationIndex)
                            end
                        }
                    end
                end

                if #petList == 0 then
                    lib.notify({ title = locale('cl_race_no_pets') or 'No pets', type = 'error' })
                    return
                end

                lib.registerContext({
                    id = 'npc_race_pet_selection',
                    title = locale('cl_race_select_pet') or 'Select Pet',
                    menu = 'race_main_menu',
                    options = petList
                })
                lib.showContext('npc_race_pet_selection')
            end
        }
    }

    -- PvP option if enabled
    if RaceConfig.PvP.Enabled then
        options[#options + 1] = {
            title = locale('cl_race_pvp') or 'PvP Race',
            description = locale('cl_race_pvp_desc') or 'Race against other players',
            icon = 'fa-solid fa-users',
            metadata = {
                { label = locale('cl_race_min_players') or 'Min Players', value = RaceConfig.PvP.MinPlayers },
                { label = locale('cl_race_max_players') or 'Max Players', value = RaceConfig.PvP.MaxPlayers },
            },
            onSelect = function()
                OpenPvPRaceMenu(locationIndex)
            end
        }
    end

    lib.registerContext({
        id = 'race_main_menu',
        title = locale('cl_race_menu_title') or 'Pet Racing',
        options = options
    })
    lib.showContext('race_main_menu')
end)

-- ============================================
-- PROMPT SYSTEM
-- ============================================

local RacePrompts = {}
local RacePromptGroups = {}
local RaceBlips = {}

-- Create prompts and blips for race locations
CreateThread(function()
    for i, loc in pairs(RaceConfig.Location) do
        local prompt, group = CreateRacePrompt(loc.PromptName, loc.PromptKey, loc.HoldDuration)
        RacePrompts[i] = prompt
        RacePromptGroups[i] = group

        if loc.ShowBlip then
            local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, loc.Coords.x, loc.Coords.y, loc.Coords.z)
            SetBlipSprite(blip, loc.Blip.blipSprite, true)
            SetBlipScale(blip, loc.Blip.blipScale)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, loc.Blip.blipName)
            Citizen.InvokeNative(0x662D364ABF16DE2F, blip, GetHashKey("BLIP_MODIFIER_MP_COLOR_32"))
            Citizen.InvokeNative(0x9029B2F3DA924928, blip, true)
            table.insert(RaceBlips, blip)
        end
    end
end)

-- Prompt handling loop
CreateThread(function()
    while true do
        Wait(1)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local anyPromptShown = false

        for i, loc in pairs(RaceConfig.Location) do
            local distance = #(playerCoords - loc.Coords)
            local prompt = RacePrompts[i]
            local group = RacePromptGroups[i]

            if distance <= loc.PromptDistance then
                anyPromptShown = true
                local promptName = CreateVarString(10, 'LITERAL_STRING', loc.PromptName)
                PromptSetActiveGroupThisFrame(group, promptName)
                PromptSetEnabled(prompt, true)
                PromptSetVisible(prompt, true)

                if PromptHasHoldModeCompleted(prompt) then
                    TriggerEvent('hdrp-pets:client:openRaceMenu', i)
                    Wait(1000)
                end
            else
                PromptSetEnabled(prompt, false)
                PromptSetVisible(prompt, false)
            end
        end

        if not anyPromptShown then
            Wait(500)
        end
    end
end)

-- Cooldown timer
CreateThread(function()
    while true do
        Wait(1000)
        if recentlyRaced > 0 then
            recentlyRaced = recentlyRaced - 1
        end
    end
end)

-- ============================================
-- COMMANDS
-- ============================================

RegisterCommand('pet_race', function()
    -- Find nearest race location
    local playerCoords = GetEntityCoords(cache.ped)
    local nearestIdx = nil
    local nearestDist = 999999

    for i, loc in pairs(RaceConfig.Location) do
        local dist = #(playerCoords - loc.Coords)
        if dist < nearestDist then
            nearestDist = dist
            nearestIdx = i
        end
    end

    if nearestIdx and nearestDist <= 50.0 then
        TriggerEvent('hdrp-pets:client:openRaceMenu', nearestIdx)
    else
        lib.notify({ title = locale('cl_race_not_at_track') or 'Not at track', description = locale('cl_race_go_to_track') or 'Go to a race track', type = 'error' })
    end
end, false)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        CleanupCheckpointMarkers()
        CleanupNPCs()
    end
end)

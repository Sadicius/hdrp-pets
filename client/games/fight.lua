
-- philsdogfight.lua
-- Juego de apuestas de peleas de perros, inspirado en phils-dogfights
-- Integración para hdrp-pets (carpeta games)

local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
local GameConfig = lib.load('shared.game.games')
local ManageSpawn = lib.load('client.stable.utils_spawn')
local DogFightConfig = GameConfig.Gdogfight
local currentFights = {}
local DogFightPrompts = {}
local PromptGroups = {}
local SpawnedBlips = {}
local recentlyFought = 0
local isFighting = false

--- Agrega una pelea activa al estado
---@param fightId string identificador de la pelea
---@param data table datos de la pelea (dog1, dog2, ped1, ped2)
function AddFight(fightId, data)
    currentFights = currentFights or {}
    currentFights[fightId] = data
end

--- Limpia una pelea activa del estado (ahora local)
---@param fightId string identificador de la pelea
function CleanupFight(fightId)
    if currentFights[fightId] then
        local fight = currentFights[fightId]
        -- Elimina entidades si existen
        if fight.ped1 and DoesEntityExist(fight.ped1) then
            DeleteEntity(fight.ped1)
        end
        if fight.ped2 and DoesEntityExist(fight.ped2) then
            DeleteEntity(fight.ped2)
        end
        currentFights[fightId] = nil
    end
end

-- Create Dog Fight Prompt
local function CreateDogFightPrompt(name, key, holdDuration)
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

-- Make Dogs Fight
function MakeDogsFight(ped1, ped2, dog1, dog2)
    if not DoesEntityExist(ped1) or not DoesEntityExist(ped2) then
        return
    end
    
    local _, group1 = AddRelationshipGroup("dogfight_ped1_" .. math.random(9999))
    local _, group2 = AddRelationshipGroup("dogfight_ped2_" .. math.random(9999))
    SetPedRelationshipGroupHash(ped1, group1)
    SetPedRelationshipGroupHash(ped2, group2)
    
    SetRelationshipBetweenGroups(5, group1, group2)
    SetRelationshipBetweenGroups(5, group2, group1)
    
    SetPedCombatAttributes(ped1, 46, true)  -- Always fight
    SetPedCombatAttributes(ped2, 46, true)
    SetPedCombatAttributes(ped1, 5, true)   -- Fight armed peds
    SetPedCombatAttributes(ped2, 5, true)
    SetPedCombatAttributes(ped1, 17, true)  -- Always attack
    SetPedCombatAttributes(ped2, 17, true)
    SetPedCombatAttributes(ped1, 58, true)  -- Aggressive stance
    SetPedCombatAttributes(ped2, 58, true)
    
    SetPedCombatMovement(ped1, 3)  -- Aggressive
    SetPedCombatMovement(ped2, 3)
    
    SetPedFleeAttributes(ped1, 0, false)
    SetPedFleeAttributes(ped2, 0, false)
    
    Citizen.InvokeNative(0x9238A3D970BBB0A9, ped1, -1663301869)  
    Citizen.InvokeNative(0x9238A3D970BBB0A9, ped2, -1663301869)
    
    SetPedCombatRange(ped1, 1)  
    SetPedCombatRange(ped2, 1)
    
    SetPedKeepTask(ped1, true)
    SetPedKeepTask(ped2, true)
    
    Citizen.InvokeNative(0x5240864E847C691C, ped1, false)
    Citizen.InvokeNative(0x5240864E847C691C, ped2, false)
    
    if dog1 and dog1.Health and dog1.Owner ~= GetPlayerServerId(PlayerId()) then
        local health1 = dog1.Health + math.random(-20, 20)
        SetEntityHealth(ped1, health1)
        Citizen.InvokeNative(0x166E7CF68597D8B5, ped1, health1)
    end

    if dog2 and dog2.Health and dog2.Owner ~= GetPlayerServerId(PlayerId()) then
        local health2 = dog2.Health + math.random(-10, 20)
        SetEntityHealth(ped2, health2)
        Citizen.InvokeNative(0x166E7CF68597D8B5, ped2, health2)
    end

    SetEntityInvincible(ped1, false)
    SetEntityInvincible(ped2, false)

    local ped1Coords = GetEntityCoords(ped1)
    local ped2Coords = GetEntityCoords(ped2)
    TaskTurnPedToFaceCoord(ped1, ped2Coords.x, ped2Coords.y, ped2Coords.z, 500)
    TaskTurnPedToFaceCoord(ped2, ped1Coords.x, ped1Coords.y, ped1Coords.z, 500)

    Wait(500)
    TaskGoToEntityWhileAimingAtEntity(ped1, ped2, ped2, 2.0, true, 0, 0, 0, 0)
    TaskGoToEntityWhileAimingAtEntity(ped2, ped1, ped1, 2.0, true, 0, 0, 0, 0)

    Wait(500)
    ClearPedTasks(ped1)
    ClearPedTasks(ped2)
    TaskCombatPed(ped1, ped2, 0, 16)
    TaskCombatPed(ped2, ped1, 0, 16)
   
    CreateThread(function()
        if not DogFightConfig.Enabled then return end
        local fightStartTime = GetGameTimer()
        local lastTaskRefresh = 0
        local noAttackTime = 0
        local lastDamageTime1 = 0
        local lastDamageTime2 = 0
        local distanceChecks = 0
        local startHealth1 = GetEntityHealth(ped1)
        local startHealth2 = GetEntityHealth(ped2)
        
        while DoesEntityExist(ped1) and DoesEntityExist(ped2) and 
              not IsEntityDead(ped1) and not IsEntityDead(ped2) do
            
            local currentTime = GetGameTimer()
            if currentTime - lastTaskRefresh > 1000 then
                
                local pos1 = GetEntityCoords(ped1)
                local pos2 = GetEntityCoords(ped2)
                local distance = #(pos1 - pos2)

                if not IsPedInMeleeCombat(ped1) or not IsPedInMeleeCombat(ped2) or distance > 3.0 then
                    noAttackTime = noAttackTime + 1
                    
                   
                    if noAttackTime >= 1 or distance > 3.0 then
                       
                        ClearPedTasks(ped1)
                        ClearPedTasks(ped2)

                        if distance > 3.0 then
                            distanceChecks = distanceChecks + 1

                            if distanceChecks >= 3 then
                                local midpoint = vector3(
                                    (pos1.x + pos2.x) / 2, 
                                    (pos1.y + pos2.y) / 2, 
                                    (pos1.z + pos2.z) / 2
                                )
                                
                                SetEntityCoords(ped1, midpoint.x - 0.75, midpoint.y, midpoint.z, false, false, false, false)
                                SetEntityCoords(ped2, midpoint.x + 0.75, midpoint.y, midpoint.z, false, false, false, false)
                                
                                distanceChecks = 0
                            else
                                
                                TaskGoToEntityWhileAimingAtEntity(ped1, ped2, ped2, 2.0, true, 0, 0, 0, 0)
                                TaskGoToEntityWhileAimingAtEntity(ped2, ped1, ped1, 2.0, true, 0, 0, 0, 0)
                                Citizen.Wait(500)
                            end
                        end

                        TaskCombatPed(ped1, ped2, 0, 16)
                        TaskCombatPed(ped2, ped1, 0, 16)
                        
                        noAttackTime = 0
                    end
                else
                    
                    noAttackTime = 0
                    distanceChecks = 0
                end
                
                lastTaskRefresh = currentTime
            end

            local elapsedSeconds = math.floor((currentTime - fightStartTime) / 1000)
            local damageMultiplier = 1.0 + (math.floor(elapsedSeconds / 15) * 0.2) -- +20% cada 15s

            if currentTime - lastDamageTime1 > 1500 + math.random(0, 1000) then
                local currentHealth2 = GetEntityHealth(ped2)
                if currentHealth2 > startHealth2 * 0.1 then
                    local damage = ManageSpawn.CalculateDogDamage(dog1, dog2, 3, 8)
                    ManageSpawn.ApplyDogDamage(ped2, ped1, damage)
                    lastDamageTime1 = currentTime
                else 
                    local baseDamage = ManageSpawn.CalculateDogDamage(dog1, dog2, 3, 8)
                    local damage = math.floor(baseDamage * damageMultiplier)
                    ManageSpawn.ApplyDogDamage(ped2, ped1, damage)
                    lastDamageTime1 = currentTime
                end
            end

            if currentTime - lastDamageTime2 > 1500 + math.random(0, 1000) then
                local currentHealth1 = GetEntityHealth(ped1)
                if currentHealth1 > startHealth1 * 0.1 then
                    local damage = ManageSpawn.CalculateDogDamage(dog2, dog1, 3, 8)
                    ManageSpawn.ApplyDogDamage(ped1, ped2, damage)
                    lastDamageTime2 = currentTime
                else
                    local baseDamage = ManageSpawn.CalculateDogDamage(dog2, dog1, 3, 8)
                    local damage = math.floor(baseDamage * damageMultiplier)
                    ManageSpawn.ApplyDogDamage(ped1, ped2, damage)
                    lastDamageTime2 = currentTime
                end
            end
            
            Wait(500)
        end
    end)
end

-- Start Fight Event
RegisterNetEvent('hdrp-pets:client:startFight')
AddEventHandler('hdrp-pets:client:startFight', function(dog1, dog2)
    if isFighting then return end
    isFighting = true
    recentlyFought = DogFightConfig.FightCooldown
    
    local player = PlayerPedId()
    local x, y, z = table.unpack(GetOffsetFromEntityInWorldCoords(player, 0.0, DogFightConfig.SpawnOffset or 15.0, 0.3))
    local _, groundZ = GetGroundZAndNormalFor_3dCoord(x, y, z + 10)

    local ped1 = ManageSpawn.spawnDog(dog1.Model, vector3(x - 0.75, y, groundZ), 90.0, dog1.Health)
    local ped2 = ManageSpawn.spawnDog(dog2.Model, vector3(x + 0.75, y, groundZ), 270.0, dog2.Health)
    if not ped1 or not ped2 then
        lib.notify({ title = locale('cl_fight_failed'), description = locale('cl_fight_failed_desc'), type = 'error', duration = 5000 })
        isFighting = false
        return
    end

    AddFight('local', { dog1 = dog1, dog2 = dog2, ped1 = ped1, ped2 = ped2})
    MakeDogsFight(ped1, ped2, dog1, dog2)

    lib.notify({ title = locale('cl_fight_started'), description = dog1.Name .. ' vs ' .. dog2.Name .. '! ' .. locale('cl_fight_instructions'), type = 'inform',  duration = 7000 })

    Citizen.CreateThread(function()
        Citizen.Wait(60000)
        local fight = currentFights and currentFights['local']
        if not fight or not DoesEntityExist(ped1) or not DoesEntityExist(ped2) then
            isFighting = false
            return
        end
        local health1 = GetEntityHealth(ped1)
        local health2 = GetEntityHealth(ped2)
        local winner, loser
        if health1 > health2 then
            winner = dog1.Name
            loser = ped2
        elseif health2 > health1 then
            winner = dog2.Name
            loser = ped1
        else
            if math.random() < 0.5 then
                winner = dog1.Name
                loser = ped2
            else
                winner = dog2.Name
                loser = ped1
            end
        end
        if DoesEntityExist(loser) then
            SetEntityHealth(loser, 0)
            Citizen.InvokeNative(0x5E3BDDBCB83F3D84, loser, true, true, false, true, false)
        end
        isFighting = false
        RSGCore.Functions.TriggerCallback('hud:server:getoutlawstatus', function(result)
            outlawstatus = result[1].outlawstatus
            TriggerServerEvent('hdrp-pets:server:endFight', dog1, dog2, winner, outlawstatus)
        end)
        CleanupFight('local')
    end)
end)

-- Show Bet Result
RegisterNetEvent('hdrp-pets:client:showBetResult')
AddEventHandler('hdrp-pets:client:showBetResult', function(winner, payout)
    local description = payout > 0 and (string.format(locale('cl_bet_won'), payout, winner)) or (string.format(locale('cl_bet_winner'), winner))
    lib.notify({ title = locale('cl_bet_result'), description = description, type = payout > 0 and 'success' or 'inform', duration = 7000 })
end)

-- Request active fights on load
CreateThread(function()
    if not DogFightConfig.Enabled then return end
    Wait(2000)
    TriggerServerEvent('hdrp-pets:server:requestActiveFights')
end)

-- Fight for all players (multiplayer sync) 
RegisterNetEvent('hdrp-pets:client:startFightForAll')
AddEventHandler('hdrp-pets:client:startFightForAll', function(fightId, dog1, dog2, coords)
    if currentFights and currentFights[fightId] then return end
    local x, y, z = table.unpack(coords)
    local _, groundZ = GetGroundZAndNormalFor_3dCoord(x, y, z + 10)

    local ped1, ped2
    if dog1.Owner == GetPlayerServerId(PlayerId()) and dog1.PetId then
        local myPet = State.GetPet(dog1.PetId)
        ped1 = myPet and myPet.ped
    else
        ped1 = ManageSpawn.spawnDog(dog1.Model, vector3(x - 0.75, y, groundZ), 90.0, dog1.Health)
    end

    if dog2.Owner == GetPlayerServerId(PlayerId()) and dog2.PetId then
        local myPet = State.GetPet(dog2.PetId)
        ped2 = myPet and myPet.ped
    else
        ped2 = ManageSpawn.spawnDog(dog2.Model, vector3(x + 0.75, y, groundZ), 270.0, dog2.Health)
    end

    if not ped1 or not ped2 then
        return
    end

    AddFight(fightId, { dog1 = dog1, dog2 = dog2, ped1 = ped1, ped2 = ped2 })
    MakeDogsFight(ped1, ped2, dog1, dog2)

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    if #(playerCoords - coords) < 50.0 then
        lib.notify({ title = locale('cl_fight_started'), description = dog1.Name .. ' vs ' .. dog2.Name .. '! ' .. locale('cl_fight_watch'), type = 'inform', duration = 5000 })
    end
end)

RegisterNetEvent('hdrp-pets:client:endFightForAll')
AddEventHandler('hdrp-pets:client:endFightForAll', function(fightId, winner)
    local fight = currentFights and currentFights[fightId]
    if not fight then return end
    local myId = GetPlayerServerId(PlayerId())
    local isPetVsNpc = (fight.dog1.Owner == myId and fight.dog1.PetId) or (fight.dog2.Owner == myId and fight.dog2.PetId)
    if isPetVsNpc then
        -- Siempre eliminar solo el NPC (el que NO es mi mascota), sin importar quién gane
        local npcPed
        if fight.dog1.Owner == myId and fight.dog1.PetId then
            npcPed = fight.ped2
        else
            npcPed = fight.ped1
        end
        if DoesEntityExist(npcPed) then
            SetEntityHealth(npcPed, 0)
            Citizen.InvokeNative(0x5E3BDDBCB83F3D84, npcPed, true, true, false, true, false)
        end
    else
        -- Pelea normal: eliminar el perdedor
        local loserPed
        if winner == fight.dog1.Name then
            loserPed = fight.ped2
        else
            loserPed = fight.ped1
        end
        if DoesEntityExist(loserPed) then
            SetEntityHealth(loserPed, 0)
            Citizen.InvokeNative(0x5E3BDDBCB83F3D84, loserPed, true, true, false, true, false)
        end
    end
    local playerPed = PlayerPedId()
    local fightCoords = GetEntityCoords(fight.ped1)
    if #(GetEntityCoords(playerPed) - fightCoords) < 50.0 then
        lib.notify({ title = locale('cl_fight_result'), description = string.format(locale('cl_fight_result_desc'), winner), type = 'inform', duration = 5000 })
    end
    Citizen.SetTimeout(5000, function()
        if isPetVsNpc then
            -- Solo eliminar el NPC
            if fight.dog1.Owner == myId and fight.dog1.PetId then
                if DoesEntityExist(fight.ped2) then DeleteEntity(fight.ped2) end
            else
                if DoesEntityExist(fight.ped1) then DeleteEntity(fight.ped1) end
            end
            -- No borres el ped de mi mascota
            currentFights[fightId] = nil
        else
            CleanupFight(fightId)
        end
    end)
end)

-- Prompt Handling Thread
CreateThread(function()
    if not DogFightConfig.Enabled then return end
    for i, loc in pairs(DogFightConfig.Location) do
        local prompt, group = CreateDogFightPrompt(loc.PromptName, Config.KeyBind, loc.HoldDuration)
        DogFightPrompts[i] = prompt
        PromptGroups[i] = group

        if Config.Blip.Fight.ShowBlip then
            local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, loc.Coords.x, loc.Coords.y, loc.Coords.z)
            SetBlipSprite(blip, Config.Blip.Fight.blipSprite, true)
            SetBlipScale(blip, Config.Blip.Fight.blipScale)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, Config.Blip.Fight.blipName)
            Citizen.InvokeNative(0x662D364ABF16DE2F, blip, Config.Blip.ColorModifier)
            Citizen.InvokeNative(0x9029B2F3DA924928, blip, true)
            table.insert(SpawnedBlips, blip)
        end
    end
end)

CreateThread(function()
    if not DogFightConfig.Enabled then return end
    while true do
        Wait(1)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local anyPromptShown = false
        for i, loc in pairs(DogFightConfig.Location) do
            local distance = #(playerCoords - loc.Coords)
            local prompt = DogFightPrompts[i]
            local group = PromptGroups[i]
            if distance <= loc.PromptDistance then
                anyPromptShown = true
                local promptName = CreateVarString(10, 'LITERAL_STRING', loc.PromptName)
                PromptSetActiveGroupThisFrame(group, promptName)
                PromptSetEnabled(prompt, true)
                PromptSetVisible(prompt, true)
                if PromptHasHoldModeCompleted(prompt) then
                    TriggerEvent('hdrp-pets:client:openBettingMenu')
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

-- Actualiza logros de combate en el cliente
RegisterNetEvent('hdrp-pets:client:updateCombatAchievements')
AddEventHandler('hdrp-pets:client:updateCombatAchievements', function(petId, achievements, xpBonus)
    if not petId or not achievements then return end
    
    -- Actualizar achievements en State local
    local pet = State.GetPet(petId)
    if pet and pet.data then
        pet.data.achievements = achievements
    end
    
    -- Notificar XP ganado
    if xpBonus and xpBonus > 0 then
        lib.notify({ title = locale('cl_fight_xp_gained') or 'Combat XP', description = '+' .. xpBonus .. ' XP', type = 'success' })
    end

end)

-- Cooldown Timer Thread
CreateThread(function()
    if not DogFightConfig.Enabled then return end
    while true do
        Wait(1000)
        if recentlyFought > 0 then
            recentlyFought = recentlyFought - 1
            TriggerEvent('hdrp-pets:client:updateFightCooldown', recentlyFought)
        end
    end
end)

-- Cleanup on Resource Stop
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        -- State.CleanupAllFights()
    end
end)

-- ============================================
-- PVP DIRECT CHALLENGE SYSTEM - CLIENT
-- ============================================
-- Open menu to select a player to challenge
-- Select pet and bet amount to send challenge
-- Send the challenge to the server
-- Receive a PvP challenge from another player
-- Menu to accept or decline challenge
-- Select pet to accept challenge
-- Accept the challenge with selected pet
-- Challenge expired

-- Start PvP fight for all nearby players
RegisterNetEvent('hdrp-pets:client:startPvPFightForAll')
AddEventHandler('hdrp-pets:client:startPvPFightForAll', function(fightId, pet1, pet2, coords, challengerSrc, defenderSrc)
    if activePvPFights[fightId] then return end

    local x, y, z = coords.x, coords.y, coords.z
    local _, groundZ = GetGroundZAndNormalFor_3dCoord(x, y, z + 10)
    if groundZ == 0 then groundZ = z end

    local ped1 = ManageSpawn.spawnDog(pet1.Model, vector3(x - 1.0, y, groundZ), 90.0, pet1.Health or 100)
    local ped2 = ManageSpawn.spawnDog(pet2.Model, vector3(x + 1.0, y, groundZ), 270.0, pet2.Health or 100)

    if not ped1 or not ped2 then
        if Config.Debug then print("startPvPFightForAll: Failed to spawn one or both pets") end
        return
    end

    activePvPFights[fightId] = {
        fightId = fightId,
        pet1 = pet1,
        pet2 = pet2,
        ped1 = ped1,
        ped2 = ped2,
        coords = coords,
        challengerSrc = challengerSrc,
        defenderSrc = defenderSrc
    }
    TriggerEvent('hdrp-pets:client:updateActiveFights', activePvPFights)
    MakeDogsFight(ped1, ped2, pet1, pet2)

    -- Notify player
    local playerCoords = GetEntityCoords(cache.ped)
    if #(playerCoords - coords) < 50.0 then
        lib.notify({ title = locale('cl_pvp_fight_started'), description = string.format('%s vs %s!', pet1.Name, pet2.Name), type = 'inform', duration = 7000 })
    end
end)

-- End PvP fight for all players
RegisterNetEvent('hdrp-pets:client:endPvPFightForAll')
AddEventHandler('hdrp-pets:client:endPvPFightForAll', function(fightId, winnerName, loserName, isKO, xpReward)
    local fight = activePvPFights[fightId]
    if not fight then return end

    -- Kill the loser pet
    local loserPed
    if winnerName == fight.pet1.Name then
        loserPed = fight.ped2
    else
        loserPed = fight.ped1
    end

    if DoesEntityExist(loserPed) then
        SetEntityHealth(loserPed, 0)
        Citizen.InvokeNative(0x5E3BDDBCB83F3D84, loserPed, true, true, false, true, false)
    end

    -- Notify nearby players
    local playerCoords = GetEntityCoords(cache.ped)
    if #(playerCoords - fight.coords) < 50.0 then
        local koText = isKO and ' (KO!)' or ''
        lib.notify({ title = locale('cl_pvp_fight_ended'), description = string.format(locale('cl_pvp_winner_announcement'), winnerName, loserName) .. koText, type = 'success', duration = 7000 })
    end

    -- Cleanup after delay
    Citizen.SetTimeout(5000, function()
        if activePvPFights[fightId] then
            if DoesEntityExist(activePvPFights[fightId].ped1) then
                DeleteEntity(activePvPFights[fightId].ped1)
            end
            if DoesEntityExist(activePvPFights[fightId].ped2) then
                DeleteEntity(activePvPFights[fightId].ped2)
            end
            activePvPFights[fightId] = nil
            TriggerEvent('hdrp-pets:client:updateActiveFights', activePvPFights)
        end
    end)
end)

-- Notification of nearby PvP fight (for spectators)
-- Open spectator betting menu
-- Place spectator bet
-- Betting closed notification
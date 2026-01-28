
-- philsdogfight.lua
-- Juego de apuestas de peleas de perros, inspirado en phils-dogfights
-- Integración para hdrp-pets (carpeta games)

local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
local GameConfig = lib.load('shared.game.games')
local ManageSpawn = lib.load('client.stable.utils_spawn')

local DogFightConfig = GameConfig.Gdogfight
-- Estado migrado a State.Games.fights y helpers de state_helpers.lua
local recentlyFought = 0
local isFighting = false

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

-- Apply Effective Dog Damage
function ApplyForcedDamage(ped1, ped2, dog1, dog2)
    
    local damage1 = ManageSpawn.CalculateDogDamage(dog2, dog1) * 0.5 
    local damage2 = ManageSpawn.CalculateDogDamage(dog1, dog2) * 0.5
    
    ApplyEffectiveDogDamage(ped1, ped2, damage1)
    ApplyEffectiveDogDamage(ped2, ped1, damage2)
    
    
    local animDict = "creatures@dog@move"
    if IsPedInMeleeCombat(ped1) and not IsEntityPlayingAnim(ped1, animDict, "attack", 3) then
        Citizen.InvokeNative(0xEF0D582CBF2D9B0F, ped1, 1, GetPedBoneCoords(ped1, 0, 0.0, 0.0, 0.0), 0.0, 0.0)
    end
    
    if IsPedInMeleeCombat(ped2) and not IsEntityPlayingAnim(ped2, animDict, "attack", 3) then
        Citizen.InvokeNative(0xEF0D582CBF2D9B0F, ped2, 1, GetPedBoneCoords(ped2, 0, 0.0, 0.0, 0.0), 0.0, 0.0)
    end
end

-- Make Dogs Fight
function MakeDogsFight(ped1, ped2, dog1, dog2)
    if not DoesEntityExist(ped1) or not DoesEntityExist(ped2) then
        if Config.Debug then print("MakeDogsFight: One or both peds do not exist") end
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
    
    if dog1 and dog1.Health then
        local health1 = Config.PetAttributes.Starting.Health + (dog1.Health * 10) + math.random(-20, 20)
        SetEntityHealth(ped1, health1)
        Citizen.InvokeNative(0x166E7CF68597D8B5, ped1, health1)
        if Config.Debug then print("MakeDogsFight: Set ped1 health to " .. health1) end
    end
    
    if dog2 and dog2.Health then
        local health2 = Config.PetAttributes.Starting.Health + (dog2.Health * 10) + math.random(-20, 20)
        SetEntityHealth(ped2, health2)
        Citizen.InvokeNative(0x166E7CF68597D8B5, ped2, health2)
        if Config.Debug then print("MakeDogsFight: Set ped2 health to " .. health2) end
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
                                
                                if Config.Debug then print("MakeDogsFight: Dogs teleported closer after separation") end
                                distanceChecks = 0
                            else
                                
                                TaskGoToEntityWhileAimingAtEntity(ped1, ped2, ped2, 2.0, true, 0, 0, 0, 0)
                                TaskGoToEntityWhileAimingAtEntity(ped2, ped1, ped1, 2.0, true, 0, 0, 0, 0)
                                Citizen.Wait(500)
                            end
                        end

                        TaskCombatPed(ped1, ped2, 0, 16)
                        TaskCombatPed(ped2, ped1, 0, 16)
                        
                        if Config.Debug then print("MakeDogsFight: Forced combat reset. Distance: " .. distance) end
                        noAttackTime = 0
                    end
                else
                    
                    noAttackTime = 0
                    distanceChecks = 0
                end
                
                lastTaskRefresh = currentTime
            end

            if currentTime - lastDamageTime1 > 1500 + math.random(0, 1000) then
                local currentHealth2 = GetEntityHealth(ped2)
                if currentHealth2 > startHealth2 * 0.1 then
                    local damage = ManageSpawn.CalculateDogDamage(dog1, dog2, 3, 8)
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
                end
            end
            
            Wait(500)
        end
    end)
end

-- Open Betting Menu
RegisterNetEvent('hdrp-pets:client:openBettingMenu')
AddEventHandler('hdrp-pets:client:openBettingMenu', function()
    if recentlyFought > 0 then
        lib.notify({
            title = locale('cl_fight_cooldown'),
            description = string.format(locale('cl_fight_cooldown_desc'), recentlyFought),
            type = 'error',
            duration = 5000
        })
        return
    end

    local options = {}
    if Config.EnabledBetsFight then
        options[#options + 1] = {
            title = locale('cl_bet'),
            -- description = locale('cl_bet_desc'),
            metadata = {
                { label = 'Info', value = locale('cl_bet_desc')},
            },
            icon = 'fa-solid fa-dog',
            onSelect = function()
                local petList = {}
                -- Opción clásica: apostar a pelea NPC vs NPC
                for _, dog in ipairs(DogFightConfig.Dogs) do
                    petList[#petList+1] = {
                        title = string.format(locale('cl_bet_for'), dog.Name),
                        -- description = dog.Desc .. ' | Salud: ' .. dog.Health .. ' | Fuerza: ' .. dog.Strength,
                        icon = 'fa-solid fa-paw',
                        metadata = {
                            {label = locale('cl_buy_pet_type'), value = dog.Desc},
                            { label = locale('cl_stat_health'), value = dog.Health .. '%'},
                            { label = locale('cl_stat_strength'), value = dog.Strength .. '%'},
                        },
                        args = { dog = dog },
                        onSelect = function(data)
                            local input = lib.inputDialog(string.format(locale('cl_bet_for'), data.dog.Name), {
                                { type = 'number', label = locale('cl_bet_amount'), description = 'Mín: $' .. DogFightConfig.MinBet .. ' Máx: $' .. DogFightConfig.MaxBet, required = true, min = DogFightConfig.MinBet, max = DogFightConfig.MaxBet }
                            })
                            if input and input[1] then
    
                                RSGCore.Functions.TriggerCallback('hud:server:getoutlawstatus', function(result)
                                    if Config.LawAlertActive then
                                        local random = math.random(100)
                                        if random <= Config.LawAlertChance then
                                            local pcoords = GetEntityCoords(cache.ped)
                                            TriggerEvent('rsg-lawman:client:lawmanAlert', pcoords, locale('cl_lang_4'))
                                        end
                                    end
                                    
                                    outlawstatus = result[1].outlawstatus
                                    TriggerServerEvent('hdrp-pets:server:placeBet', data.dog.Name, input[1], outlawstatus)
                        
                                end)

                            end
                        end
                    }
                end
                lib.registerContext({
                    id = 'dogfight_bet',
                    title = locale('cl_select_pet'),
                    options = petList
                })
                lib.showContext('dogfight_bet')
            end
        }
    end

    -- Opción: inscribir mascota para pelea contra NPC
    options[#options + 1] = {
        title = locale('cl_fight_npc'),
        -- description = string.format(locale('cl_fight_npc_desc'), Config.XP.Trick.pet_vs_npc),
        metadata = {
            { label = 'Info', value = string.format(locale('cl_fight_npc_desc'), Config.XP.Trick.pet_vs_npc)},
        },
        icon = 'fa-solid fa-dog',
        onSelect = function()
            local petList = {}
            for id, pet in pairs(State.GetAllPets()) do
                local xp = pet.companionxp or 0
                petList[#petList+1] = {
                    title = pet.Name .. ' (ID: ' .. id .. ')',
                    -- description = 'ID: ' .. id,
                    metadata = {
                            {label = 'XP', value = xp},
                            { label = locale('cl_stat_health'), value = pet.Health .. '%'},
                            { label = locale('cl_stat_strength'), value = pet.Strength .. '%'},
                        },
                    args = { pet = pet },
                    onSelect = function(data)
                        local xp = data.pet.companionxp or 0
                        if xp < Config.XP.Trick.pet_vs_npc then
                            lib.notify({ title = locale('cl_restriction'), description = string.format(locale('cl_restriction_desc'), Config.XP.Trick.pet_vs_npc), type = 'error' })
                            return
                        end
                        RSGCore.Functions.TriggerCallback('hud:server:getoutlawstatus', function(result)
                            if Config.LawAlertActive then
                                local random = math.random(100)
                                if random <= Config.LawAlertChance then
                                    local pcoords = GetEntityCoords(cache.ped)
                                    TriggerEvent('rsg-lawman:client:lawmanAlert', pcoords, locale('cl_lang_4'))
                                end
                            end

                            outlawstatus = result[1].outlawstatus
                            TriggerServerEvent('hdrp-pets:server:registerPetForNpcFight', data.pet,  outlawstatus)

                        end)
                    end
                }
            end
            lib.registerContext({
                id = 'dogfight_pet_vs_npc',
                title = locale('cl_select_pet'),
                options = petList
            })
            lib.showContext('dogfight_pet_vs_npc')
        end
    }

    -- Opción: inscribir mascota para pelea contra otra mascota de jugador
    options[#options + 1] = {
        title = locale('cl_fight_player'),
        -- description = string.format(locale('cl_fight_player_desc'), Config.XP.Trick.pet_vs_player),
        metadata = {
            { label = 'Info', value = string.format(locale('cl_fight_player_desc'), Config.XP.Trick.pet_vs_player)},
        },
        icon = 'fa-solid fa-user-friends',
        onSelect = function()
            local petList = {}
            for id, pet in pairs(State.GetAllPets()) do
                local xp = pet.companionxp or 0
                petList[#petList+1] = {
                    title = pet.Name .. ' (ID: ' .. id .. ')',
                    -- description = 'ID: ' .. id,
                    metadata = {
                        { label = 'XP', value = xp},
                        { label = locale('cl_stat_health'), value = pet.Health .. '%'},
                        { label = locale('cl_stat_strength'), value = pet.Strength .. '%'},
                    },
                    args = { pet = pet },
                    onSelect = function(data)
                        local xp = data.pet.companionxp or 0
                        if xp < Config.XP.Trick.pet_vs_player then
                            lib.notify({ title = locale('cl_restriction'), description = string.format(locale('cl_restriction_desc'), Config.XP.Trick.pet_vs_player), type = 'error' })
                            return
                        end
                        RSGCore.Functions.TriggerCallback('hud:server:getoutlawstatus', function(result)
                            if Config.LawAlertActive then
                                local random = math.random(100)
                                if random <= Config.LawAlertChance then
                                    local pcoords = GetEntityCoords(cache.ped)
                                    TriggerEvent('rsg-lawman:client:lawmanAlert', pcoords, locale('cl_lang_4'))
                                end
                            end
                            
                            outlawstatus = result[1].outlawstatus
                            TriggerServerEvent('hdrp-pets:server:registerPetForPlayerFight', data.pet,  outlawstatus)

                        end)
                    end
                }
            end
            lib.registerContext({
                id = 'dogfight_pet_vs_player',
                title = locale('cl_select_pet'),
                options = petList
            })
            lib.showContext('dogfight_pet_vs_player')
        end
    }

    -- Opción: pelea entre dos mascotas propias
    options[#options + 1] = {
        title = locale('cl_fight_two_pets'),
        -- description = string.format(locale('cl_fight_two_pets_desc'), Config.XP.Trick.own_pets),
        metadata = {
            { label = 'Info', value = string.format(locale('cl_fight_two_pets_desc'), Config.XP.Trick.own_pets)},
        },
        icon = 'fa-solid fa-dog',
        onSelect = function()
            local petList = {}
            for id, pet in pairs(State.Pets or {}) do
                local xp = pet.companionxp or 0
                petList[#petList+1] = {
                    title = pet.Name .. ' (ID: ' .. id .. ')',
                    -- description = 'ID: ' .. id,
                    metadata = {
                        {label = 'XP', value = xp},
                        { label = locale('cl_stat_health'), value = pet.Health .. '%'},
                        { label = locale('cl_stat_strength'), value = pet.Strength .. '%'},
                    },
                    args = { pet = pet, id = id }
                }
            end
            lib.inputDialog(locale('cl_fight_two_selected'), {
                { type = 'input', label = locale('cl_fight_id'), description = locale('cl_fight_id_desc'), required = true }
            }, function(input)
                if input and input[1] then
                    local ids = {}
                    for id in string.gmatch(input[1], '([^,]+)') do
                        ids[#ids+1] = tonumber(id)
                    end
                    local pet1 = State.Pets[ids[1]]
                    local pet2 = State.Pets[ids[2]]
                    local xp1 = pet1 and (pet1.companionxp or 0) or 0
                    local xp2 = pet2 and (pet2.companionxp or 0) or 0
                    if #ids == 2 and pet1 and pet2 then
                        if xp1 < Config.XP.Trick.own_pets or xp2 < Config.XP.Trick.own_pets then
                            lib.notify({ title = locale('cl_restriction'), description = string.format(locale('cl_restriction_desc'), Config.XP.Trick.own_pets), type = 'error' })
                            return
                        end
                        TriggerServerEvent('hdrp-pets:server:startOwnPetsFight', pet1, pet2)
                    else
                        lib.notify({ title = locale('cl_error_select_pet'), description = locale('cl_error_select_pet'), type = 'error' })
                    end
                end
            end)
        end
    }

    -- Opción: vender mascota (redirige al menú de venta del establo)
    options[#options + 1] = {
        title = locale('cl_menu_sell_pet'),
        -- description = locale('cl_menu_sell_pet_fight'),
        metadata = {
            { label = 'Info', value = locale('cl_menu_sell_pet_fight')},
        },
        icon = 'fa-solid fa-dollar-sign',
        onSelect = function()
            local petList = {}
            for id, pet in pairs(State.GetAllPets()) do
                if pet.stableid then
                    petList[#petList+1] = {
                        title = pet.Name .. ' (ID ' .. id .. ')',
                        -- description = 'ID: ' .. id .. ' | Salud: ' .. (pet.Health or '?'),
                        metadata = {
                            { label = locale('cl_stat_health'), value = pet.Health .. '%'},
                            { label = locale('cl_stat_strength'), value = pet.Strength .. '%'},
                        },
                        args = { stableid = pet.stableid },
                        onSelect = function(data)
                            TriggerEvent('hdrp-pets:client:MenuDel', { stableid = data.stableid })
                        end
                    }
                end
            end
            if #petList == 0 then
                lib.notify({ title = locale('cl_error_no_stableid'), description = locale('cl_error_no_stableid_des'), type = 'error' })
                return
            end
            lib.registerContext({
                id = 'dogfight_sell_pet',
                title = locale('cl_select_pet'),
                options = petList
            })
            lib.showContext('dogfight_sell_pet')
        end
    }

    lib.registerContext({
        id = 'dogfight_betting_menu',
        title = locale('cl_menu_fight'),
        options = options
    })
    lib.showContext('dogfight_betting_menu')
end)

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
        lib.notify({
            title = locale('cl_fight_failed'),
            description = locale('cl_fight_failed_desc'),
            type = 'error',
            duration = 5000
        })
        isFighting = false
        return
    end
    State.AddFight('local', {
        dog1 = dog1,
        dog2 = dog2,
        ped1 = ped1,
        ped2 = ped2
    })
    MakeDogsFight(ped1, ped2, dog1, dog2)
    lib.notify({
        title = locale('cl_fight_started'),
        description = dog1.Name .. ' vs ' .. dog2.Name .. '! ' .. locale('cl_fight_instructions'),
        type = 'inform',
        duration = 7000
    })
    Citizen.CreateThread(function()
        Citizen.Wait(120000)
        local fight = State.Games.fights and State.Games.fights['local']
        if not fight or not DoesEntityExist(fight.ped1) or not DoesEntityExist(fight.ped2) then
            isFighting = false
            return
        end
        local health1 = GetEntityHealth(fight.ped1)
        local health2 = GetEntityHealth(fight.ped2)
        local winner, loser
        if health1 > health2 then
            winner = dog1.Name
            loser = fight.ped2
        elseif health2 > health1 then
            winner = dog2.Name
            loser = fight.ped1
        else
            if math.random() < 0.5 then
                winner = dog1.Name
                loser = fight.ped2
            else
                winner = dog2.Name
                loser = fight.ped1
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
        State.CleanupFight('local')
    end)
end)

-- Show Bet Result
RegisterNetEvent('hdrp-pets:client:showBetResult')
AddEventHandler('hdrp-pets:client:showBetResult', function(winner, payout)
    local description = payout > 0 and (string.format(locale('cl_bet_won'), payout, winner)) or (string.format(locale('cl_bet_winner'), winner))
    lib.notify({
        title = locale('cl_bet_result'),
        description = description,
        type = payout > 0 and 'success' or 'inform',
        duration = 7000
    })
end)

-- Request active fights on load
CreateThread(function()
    Wait(2000)
    TriggerServerEvent('hdrp-pets:server:requestActiveFights')
end)

-- Fight for all players (multiplayer sync) 
RegisterNetEvent('hdrp-pets:client:startFightForAll')
AddEventHandler('hdrp-pets:client:startFightForAll', function(fightId, dog1, dog2, coords)
    if State.Games.fights and State.Games.fights[fightId] then return end
    local x, y, z = table.unpack(coords)
    local _, groundZ = GetGroundZAndNormalFor_3dCoord(x, y, z + 10)
    local ped1 = ManageSpawn.spawnDog(dog1.Model, vector3(x - 0.75, y, groundZ), 90.0, dog1.Health)
    local ped2 = ManageSpawn.spawnDog(dog2.Model, vector3(x + 0.75, y, groundZ), 270.0, dog2.Health)
    if not ped1 or not ped2 then
        if Config.Debug then print("startFightForAll: Failed to spawn one or both dogs") end
        return
    end
    State.AddFight(fightId, {
        dog1 = dog1,
        dog2 = dog2,
        ped1 = ped1,
        ped2 = ped2
    })
    MakeDogsFight(ped1, ped2, dog1, dog2)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    if #(playerCoords - coords) < 50.0 then
        lib.notify({
            title = locale('cl_fight_started'),
            description = dog1.Name .. ' vs ' .. dog2.Name .. '! ' .. locale('cl_fight_watch'),
            type = 'inform',
            duration = 5000
        })
    end
end)

RegisterNetEvent('hdrp-pets:client:endFightForAll')
AddEventHandler('hdrp-pets:client:endFightForAll', function(fightId, winner)
    local fight = State.Games.fights and State.Games.fights[fightId]
    if not fight then return end
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
    local playerPed = PlayerPedId()
    local fightCoords = GetEntityCoords(fight.ped1)
    if #(GetEntityCoords(playerPed) - fightCoords) < 50.0 then
        lib.notify({
            title = locale('cl_fight_result'),
            description = string.format(locale('cl_fight_result_desc'), winner),
            type = 'inform',
            duration = 5000
        })
    end
    Citizen.SetTimeout(5000, function()
        State.CleanupFight(fightId)
    end)
end)

local DogFightPrompts = {}
local PromptGroups = {}
local SpawnedBlips = {}

-- Prompt Handling Thread
CreateThread(function()
    for i, loc in pairs(DogFightConfig.Location) do
        local prompt, group = CreateDogFightPrompt(loc.PromptName, loc.PromptKey, loc.HoldDuration)
        DogFightPrompts[i] = prompt
        PromptGroups[i] = group

        if loc.ShowBlip then
            local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, loc.Coords.x, loc.Coords.y, loc.Coords.z)
            SetBlipSprite(blip, loc.Blip.blipSprite, true)
            SetBlipScale(blip, loc.Blip.blipScale)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, loc.Blip.blipName)
            Citizen.InvokeNative(0x662D364ABF16DE2F, blip, GetHashKey("BLIP_MODIFIER_MP_COLOR_32"))
            Citizen.InvokeNative(0x9029B2F3DA924928, blip, true)
            table.insert(SpawnedBlips, blip)
        end
    end
end)

CreateThread(function()
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
        lib.notify({
            title = locale('cl_fight_xp_gained') or 'Combat XP',
            description = '+' .. xpBonus .. ' XP',
            type = 'success'
        })
    end
    
    if Config.Debug then
        print(string.format('[FIGHT] Updated achievements for %s: Wins=%d, Fights=%d', 
            petId, 
            achievements.fight and achievements.fight.victories or 0,
            achievements.fight and achievements.fight.fights or 0
        ))
    end
end)

RegisterCommand('pet_fight', function()
    TriggerEvent('hdrp-pets:client:openBettingMenu')
end)

-- Cooldown Timer Thread
CreateThread(function()
    while true do
        Wait(1000)
        if recentlyFought > 0 then
            recentlyFought = recentlyFought - 1
        end
    end
end)

-- Cleanup on Resource Stop
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        -- State.CleanupAllFights()
    end
end)
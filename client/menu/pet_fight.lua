
local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
local GameConfig = lib.load('shared.game.games')
local DogFightConfig = GameConfig.Gdogfight

local recentlyFought = 0
local pendingChallenge = nil
local activePvPFights = {}

-- Recibir actualizaciones de peleas activas desde fight.lua
RegisterNetEvent('hdrp-pets:client:updateActiveFights')
AddEventHandler('hdrp-pets:client:updateActiveFights', function(fights)
    activePvPFights = fights
end)

RegisterNetEvent('hdrp-pets:client:updateFightCooldown')
AddEventHandler('hdrp-pets:client:updateFightCooldown', function(cooldown)
    recentlyFought = cooldown
end)

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
    if DogFightConfig.Enabled then
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
                local petName = (pet.data and pet.data.info and pet.data.info.name) or 'Unknown'
                local petHealth = (pet.data and pet.data.stats and pet.data.stats.health) or 100
                local petStrength = (pet.data and pet.data.stats and pet.data.stats.strength) or 50
                local xp = (pet.data and pet.data.progression and pet.data.progression.xp) or 0
                petList[#petList+1] = {
                    title = petName .. ' (ID: ' .. id .. ')',
                    metadata = {
                            {label = 'XP', value = xp},
                            { label = locale('cl_stat_health'), value = petHealth .. '%'},
                            { label = locale('cl_stat_strength'), value = petStrength .. '%'},
                        },
                    args = { pet = pet, companionid = id },
                    onSelect = function(data)
                        local petXp = (data.pet.data and data.pet.data.progression and data.pet.data.progression.xp) or 0
                        if petXp < Config.XP.Trick.pet_vs_npc then
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

    -- Opción: inscribir mascota para pelea contra otra mascota de jugador (cola de espera)
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
                local petName = (pet.data and pet.data.info and pet.data.info.name) or 'Unknown'
                local petHealth = (pet.data and pet.data.stats and pet.data.stats.health) or 100
                local petStrength = (pet.data and pet.data.stats and pet.data.stats.strength) or 50
                local xp = (pet.data and pet.data.progression and pet.data.progression.xp) or 0
                petList[#petList+1] = {
                    title = petName .. ' (ID: ' .. id .. ')',
                    metadata = {
                        { label = 'XP', value = xp},
                        { label = locale('cl_stat_health'), value = petHealth .. '%'},
                        { label = locale('cl_stat_strength'), value = petStrength .. '%'},
                    },
                    args = { pet = pet, companionid = id },
                    onSelect = function(data)
                        local petXp = (data.pet.data and data.pet.data.progression and data.pet.data.progression.xp) or 0
                        if petXp < Config.XP.Trick.pet_vs_player then
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
        metadata = {
            { label = 'Info', value = string.format(locale('cl_fight_two_pets_desc'), Config.XP.Trick.own_pets)},
        },
        icon = 'fa-solid fa-dog',
        onSelect = function()
            local petList = {}
            for id, pet in pairs(State.Pets or {}) do
                local petName = (pet.data and pet.data.info and pet.data.info.name) or 'Unknown'
                local petHealth = (pet.data and pet.data.stats and pet.data.stats.health) or 100
                local petStrength = (pet.data and pet.data.stats and pet.data.stats.strength) or 50
                local xp = (pet.data and pet.data.progression and pet.data.progression.xp) or 0
                petList[#petList+1] = {
                    title = petName .. ' (ID: ' .. id .. ')',
                    metadata = {
                        {label = 'XP', value = xp},
                        { label = locale('cl_stat_health'), value = petHealth .. '%'},
                        { label = locale('cl_stat_strength'), value = petStrength .. '%'},
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
                        ids[#ids+1] = id
                    end
                    local pet1 = State.Pets[ids[1]]
                    local pet2 = State.Pets[ids[2]]
                    local xp1 = pet1 and (pet1.data and pet1.data.progression and pet1.data.progression.xp) or 0
                    local xp2 = pet2 and (pet2.data and pet2.data.progression and pet2.data.progression.xp) or 0
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
        metadata = {
            { label = 'Info', value = locale('cl_menu_sell_pet_fight')},
        },
        icon = 'fa-solid fa-dollar-sign',
        onSelect = function()
            local petList = {}
            for id, pet in pairs(State.GetAllPets()) do
                if pet.stable then
                    local petName = (pet.data and pet.data.info and pet.data.info.name) or 'Unknown'
                    local petHealth = (pet.data and pet.data.stats and pet.data.stats.health) or 100
                    local petStrength = (pet.data and pet.data.stats and pet.data.stats.strength) or 50
                    petList[#petList+1] = {
                        title = petName .. ' (ID ' .. id .. ')',
                        metadata = {
                            { label = locale('cl_stat_health'), value = petHealth .. '%'},
                            { label = locale('cl_stat_strength'), value = petStrength .. '%'},
                        },
                        onSelect = function(data)
                            TriggerEvent('hdrp-pets:client:MenuDel', { pet.stable })
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

RegisterNetEvent('hdrp-pets:client:bettingClosed')
AddEventHandler('hdrp-pets:client:bettingClosed', function(fightId)
    lib.notify({ title = locale('cl_pvp_betting_closed'), description = locale('cl_pvp_betting_closed_desc'), type = 'inform' })
end)

local function SendPvPChallenge(targetId, petData, companionid, betAmount)
    local petHealth = (petData.data and petData.data.stats and petData.data.stats.health) or 100
    local petStrength = (petData.data and petData.data.stats and petData.data.stats.strength) or 50
    local petModel = (petData.data and petData.data.info and petData.data.info.model) or ''
    local petName = (petData.data and petData.data.info and petData.data.info.name) or 'Unknown'
    
    local pet = {
        Name = petName,
        Model = petModel,
        Health = petHealth,
        Strength = petStrength,
        companionid = companionid
    }
    
    TriggerServerEvent('hdrp-pets:server:sendPvPChallenge', targetId, pet, betAmount)
    lib.notify({ title = locale('cl_pvp_challenge_sent'), type = 'success' })
end

local function AcceptPvPChallenge(petData, companionid)
    if not pendingChallenge then return end
    
    local petHealth = (petData.data and petData.data.stats and petData.data.stats.health) or 100
    local petStrength = (petData.data and petData.data.stats and petData.data.stats.strength) or 50
    local petModel = (petData.data and petData.data.info and petData.data.info.model) or ''
    local petName = (petData.data and petData.data.info and petData.data.info.name) or 'Unknown'
    
    local pet = {
        Name = petName,
        Model = petModel,
        Health = petHealth,
        Strength = petStrength,
        companionid = companionid
    }
    
    TriggerServerEvent('hdrp-pets:server:acceptPvPChallenge', pendingChallenge.challengerSrc, pet)
    pendingChallenge = nil
    lib.notify({ title = locale('cl_pvp_challenge_accepted'), type = 'success' })
end

local function PlaceSpectatorBet(fightId, betOnOwner, petName)
    local pvpConfig = DogFightConfig.PvP or {}
    local spectatorBets = pvpConfig.SpectatorBets or {}
    
    local input = lib.inputDialog(string.format(locale('cl_pvp_betting_on'), petName), {
        {
            type = 'number',
            label = locale('cl_pvp_bet_amount'),
            description = string.format('Min: $%d, Max: $%d', spectatorBets.MinBet or 10, spectatorBets.MaxBet or 1000),
            required = true,
            min = spectatorBets.MinBet or 10,
            max = spectatorBets.MaxBet or 1000
        }
    })
    
    if input and input[1] then
        TriggerServerEvent('hdrp-pets:server:placeSpectatorBet', fightId, betOnOwner, input[1])
    end
end

local function OpenPetSelectionForChallenge(targetPlayerId, targetPlayerName)
    local petList = {}

    for id, pet in pairs(State.GetAllPets()) do
        local petName = (pet.data and pet.data.info and pet.data.info.name) or 'Unknown'
        local petModel = (pet.data and pet.data.info and pet.data.info.model) or ''
        local petHealth = (pet.data and pet.data.stats and pet.data.stats.health) or 100
        local petStrength = (pet.data and pet.data.stats and pet.data.stats.strength) or 50
        local xp = (pet.data and pet.data.progression and pet.data.progression.xp) or 0
        petList[#petList + 1] = {
            title = petName .. ' (ID: ' .. id .. ')',
            metadata = {
                { label = 'XP', value = xp },
                { label = locale('cl_stat_health'), value = petHealth .. '%' },
                { label = locale('cl_stat_strength'), value = petStrength .. '%' },
            },
            icon = 'fa-solid fa-dog',
            args = { pet = pet, companionid = id, targetId = targetPlayerId, targetName = targetPlayerName },
            onSelect = function(data)
                -- Ask for bet amount
                local pvpConfig = DogFightConfig.PvP or {}
                local ownerBets = pvpConfig.OwnerBets or {}

                if ownerBets.Enabled then
                    local input = lib.inputDialog(locale('cl_pvp_bet_title'), {
                        {
                            type = 'number',
                            label = locale('cl_pvp_bet_amount'),
                            description = string.format(locale('cl_pvp_bet_range'), ownerBets.MinBet or 50, ownerBets.MaxBet or 5000),
                            required = false,
                            min = 0,
                            max = ownerBets.MaxBet or 5000,
                            default = 0
                        }
                    })

                    local betAmount = (input and input[1]) or 0
                    SendPvPChallenge(data.targetId, data.pet, data.companionid, betAmount)
                else
                    SendPvPChallenge(data.targetId, data.pet, data.companionid, 0)
                end
            end
        }
    end

    if #petList == 0 then
        lib.notify({ title = locale('cl_error_no_pets'), type = 'error' })
        return
    end

    lib.registerContext({
        id = 'pvp_pet_selection',
        title = string.format(locale('cl_pvp_challenge_to'), targetPlayerName),
        menu = 'pvp_player_selection',
        options = petList
    })
    lib.showContext('pvp_pet_selection')
end

local function OpenPvPChallengeMenu()
    RSGCore.Functions.TriggerCallback('hdrp-pets:server:getNearbyPlayers', function(players)
        if not players or #players == 0 then
            lib.notify({ title = locale('cl_pvp_no_players'), description = locale('cl_pvp_no_players_desc'), type = 'error' })
            return
        end

        local playerList = {}
        for _, player in ipairs(players) do
            playerList[#playerList + 1] = {
                title = player.name,
                description = string.format(locale('cl_pvp_player_distance'), player.distance),
                icon = 'fa-solid fa-user',
                args = { playerId = player.id, playerName = player.name },
                onSelect = function(data)
                    OpenPetSelectionForChallenge(data.playerId, data.playerName)
                end
            }
        end

        lib.registerContext({
            id = 'pvp_player_selection',
            title = locale('cl_pvp_select_player'),
            options = playerList
        })
        lib.showContext('pvp_player_selection')
    end)
end

local function OpenPetSelectionForAccept()
    if not pendingChallenge then return end

    local petList = {}

    for id, pet in pairs(State.GetAllPets()) do
        local petName = (pet.data and pet.data.info and pet.data.info.name) or 'Unknown'
        local petHealth = (pet.data and pet.data.stats and pet.data.stats.health) or 100
        local petStrength = (pet.data and pet.data.stats and pet.data.stats.strength) or 50
        local xp = (pet.data and pet.data.progression and pet.data.progression.xp) or 0
        petList[#petList + 1] = {
            title = petName .. ' (ID: ' .. id .. ')',
            metadata = {
                { label = 'XP', value = xp },
                { label = locale('cl_stat_health'), value = petHealth .. '%' },
                { label = locale('cl_stat_strength'), value = petStrength .. '%' },
            },
            icon = 'fa-solid fa-dog',
            args = { pet = pet, companionid = id },
            onSelect = function(data)
                AcceptPvPChallenge(data.pet, data.companionid)
            end
        }
    end

    if #petList == 0 then
        lib.notify({ title = locale('cl_error_no_pets'), type = 'error' })
        return
    end

    lib.registerContext({
        id = 'pvp_accept_pet_selection',
        title = locale('cl_pvp_select_your_pet'),
        menu = 'pvp_challenge_response',
        options = petList
    })
    lib.showContext('pvp_accept_pet_selection')
end

local function OpenChallengeResponseMenu()
    if not pendingChallenge then
        lib.notify({ title = locale('cl_pvp_no_challenge'), type = 'error' })
        return
    end

    local betText = pendingChallenge.betAmount > 0 and string.format(' - $%d', pendingChallenge.betAmount) or ''

    local options = {
        {
            title = locale('cl_pvp_accept_challenge'),
            description = locale('cl_pvp_select_your_pet'),
            icon = 'fa-solid fa-check',
            onSelect = function()
                OpenPetSelectionForAccept()
            end
        },
        {
            title = locale('cl_pvp_decline_challenge'),
            description = locale('cl_pvp_decline_desc'),
            icon = 'fa-solid fa-times',
            onSelect = function()
                TriggerServerEvent('hdrp-pets:server:declinePvPChallenge', pendingChallenge.challengerSrc)
                pendingChallenge = nil
            end
        }
    }

    lib.registerContext({
        id = 'pvp_challenge_response',
        title = string.format(locale('cl_pvp_challenge_from'), pendingChallenge.challengerName) .. betText,
        options = options
    })
    lib.showContext('pvp_challenge_response')
end

local function OpenSpectatorBetMenu(fightId, pet1, pet2, owner1Name, owner2Name)
    local pvpConfig = DogFightConfig.PvP or {}
    local spectatorBets = pvpConfig.SpectatorBets or {}

    local options = {
        {
            title = string.format(locale('cl_pvp_bet_on'), pet1.Name),
            description = string.format(locale('cl_pvp_owner'), owner1Name),
            metadata = {
                { label = locale('cl_stat_health'), value = (pet1.Health or 100) .. '%' },
                { label = locale('cl_stat_strength'), value = (pet1.Strength or 50) .. '%' },
            },
            icon = 'fa-solid fa-dog',
            onSelect = function()
                PlaceSpectatorBet(fightId, 'challenger', pet1.Name)
            end
        },
        {
            title = string.format(locale('cl_pvp_bet_on'), pet2.Name),
            description = string.format(locale('cl_pvp_owner'), owner2Name),
            metadata = {
                { label = locale('cl_stat_health'), value = (pet2.Health or 100) .. '%' },
                { label = locale('cl_stat_strength'), value = (pet2.Strength or 50) .. '%' },
            },
            icon = 'fa-solid fa-dog',
            onSelect = function()
                PlaceSpectatorBet(fightId, 'defender', pet2.Name)
            end
        },
        {
            title = locale('cl_pvp_no_bet'),
            description = locale('cl_pvp_just_watch'),
            icon = 'fa-solid fa-eye',
            onSelect = function()
                lib.notify({ title = locale('cl_pvp_watching'), type = 'inform' })
            end
        }
    }

    lib.registerContext({
        id = 'pvp_spectator_bet',
        title = locale('cl_pvp_place_spectator_bet'),
        options = options
    })
    lib.showContext('pvp_spectator_bet')
end

-- Receive a PvP challenge from another player
RegisterNetEvent('hdrp-pets:client:receivePvPChallenge')
AddEventHandler('hdrp-pets:client:receivePvPChallenge', function(challengerSrc, challengerName, challengerPet, betAmount, timeout)
    pendingChallenge = {
        challengerSrc = challengerSrc,
        challengerName = challengerName,
        challengerPet = challengerPet,
        betAmount = betAmount,
        timeout = timeout
    }

    -- Show challenge notification
    local betText = betAmount > 0 and string.format(' ($%d)', betAmount) or ''
    lib.notify({ title = locale('cl_pvp_challenge_received'), description = string.format(locale('cl_pvp_challenge_received_desc'), challengerName, challengerPet.Name, betText), type = 'inform', duration = timeout * 1000 })

    -- Open accept/decline menu
    OpenChallengeResponseMenu()
end)

RegisterNetEvent('hdrp-pets:client:challengeExpired')
AddEventHandler('hdrp-pets:client:challengeExpired', function()
    if pendingChallenge then
        lib.notify({ title = locale('cl_pvp_challenge_expired'), description = locale('cl_pvp_challenge_expired_desc'), type = 'error' })
        pendingChallenge = nil
    end
end)

RegisterNetEvent('hdrp-pets:client:pvpFightNearby')
AddEventHandler('hdrp-pets:client:pvpFightNearby', function(fightId, pet1, pet2, owner1Name, owner2Name, coords)
    local myId = GetPlayerServerId(PlayerId())
    if activePvPFights[fightId] then return end    -- Don't notify the participants

    lib.notify({ title = locale('cl_pvp_fight_nearby'), description = string.format(locale('cl_pvp_fight_nearby_desc'), pet1.Name, owner1Name, pet2.Name, owner2Name), type = 'inform', duration = 10000 })

    -- Offer to place spectator bet
    if DogFightConfig.PvP and DogFightConfig.PvP.SpectatorBets and DogFightConfig.PvP.SpectatorBets.Enabled then
        Citizen.SetTimeout(2000, function()
            OpenSpectatorBetMenu(fightId, pet1, pet2, owner1Name, owner2Name)
        end)
    end
end)

RegisterCommand('pet_fight', function()
    if not DogFightConfig.Enabled then return end
    TriggerEvent('hdrp-pets:client:openBettingMenu')
end)

-- Command to open PvP challenge menu directly
RegisterCommand('pet_pvpchallenge', function()
    if DogFightConfig.PvP and DogFightConfig.PvP.Enabled then
        OpenPvPChallengeMenu()
    else
        lib.notify({ title = locale('cl_pvp_disabled'), type = 'error' })
    end
end)

-- Command to accept pending challenge
RegisterCommand('pet_acceptchallenge', function()
    if pendingChallenge then
        OpenChallengeResponseMenu()
    else
        lib.notify({ title = locale('cl_pvp_no_challenge'), type = 'error' })
    end
end)
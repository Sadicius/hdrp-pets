
local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
local GameConfig = lib.load('shared.game.games')
local RaceConfig = GameConfig.Gpetracing
local recentlyRaced = 0
local isRacing = false

-- Recibir actualizaciones de estado desde race.lua
RegisterNetEvent('hdrp-pets:client:updateRaceState')
AddEventHandler('hdrp-pets:client:updateRaceState', function(racing, cooldown)
    isRacing = racing
    recentlyRaced = cooldown
end)

local function GetPetRacingStats(petData)
    local stats = petData.data and petData.data.stats or {}
    local progression = petData.data and petData.data.progression or {}
    
    local speed = (stats.agility or 50) + (progression.xp or 0) / 100
    local stamina = (stats.health or 50) + (stats.happiness or 50) / 2
    
    return {
        Speed = math.min(100, speed),
        Stamina = math.min(100, stamina)
    }
end

-- Open PvP race menu
local function OpenPvPRaceMenu(locationIndex)
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

-- Open
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
                TriggerEvent('hdrp-pets:client:StartSoloRace', locationIndex)
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
                                TriggerEvent('hdrp-pets:client:StartNPCRace', data.petId, locationIndex)

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
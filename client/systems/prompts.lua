local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-----------------------------------------
-- PROMPTS SETUP AND HANDLING FOR AMBIENT ACTIONS
-----------------------------------------
local State = exports['hdrp-pets']:GetState()
local isObjectInteracting = false
-- Local prompt tables for each type
local TrackPrompts = {}
local AttackPrompts = {}
local HuntAnimalsPrompts = {}
local SearchDatabasePrompt = {}
local petPrompts = {} -- { [entityId] = { actions = prompt, flee = prompt, saddlebag = prompt, hunt = prompt } }
local ActionCompanionDrink = nil
local ActionCompanionEat = nil
local DrinkPrompt = GetRandomIntInRange(0, 0xffffff)
local EatPrompt = GetRandomIntInRange(0, 0xffffff)

local function TaskStopLeadingHorse(ped)
    return Citizen.InvokeNative(0xED27560703F37258, ped)
end

local function GetLedHorseFromPed(ped)
    return Citizen.InvokeNative(0xED1F514AF4732258, ped) -- 
end

local function IsPedLeadingHorse(ped)
    return Citizen.InvokeNative(0xEFC4303DDC6E60D3, ped)
end

function SetupActionPrompt()
    local str1 = locale('cl_action_drink')
    ActionCompanionDrink = PromptRegisterBegin()
    PromptSetControlAction(ActionCompanionDrink, Config.Prompt.CompanionDrink)
    str1 = CreateVarString(10, 'LITERAL_STRING', str1)
    PromptSetText(ActionCompanionDrink, str1)
    PromptSetEnabled(ActionCompanionDrink, 1)
    PromptSetVisible(ActionCompanionDrink, 1)
    PromptSetStandardMode(ActionCompanionDrink,1)
    PromptSetGroup(ActionCompanionDrink, DrinkPrompt)
    Citizen.InvokeNative(0xC5F428EE08FA7F2C,ActionCompanionDrink,true)
    PromptRegisterEnd(ActionCompanionDrink)

    local str2 = locale('cl_action_eat')
    ActionCompanionEat = PromptRegisterBegin()
    PromptSetControlAction(ActionCompanionEat, Config.Prompt.CompanionEat)
    str2 = CreateVarString(10, 'LITERAL_STRING', str2)
    PromptSetText(ActionCompanionEat, str2)
    PromptSetEnabled(ActionCompanionEat, 1)
    PromptSetVisible(ActionCompanionEat, 1)
    PromptSetStandardMode(ActionCompanionEat,1)
    PromptSetGroup(ActionCompanionEat, EatPrompt)
    Citizen.InvokeNative(0xC5F428EE08FA7F2C,ActionCompanionEat,true)
    PromptRegisterEnd(ActionCompanionEat)
end

local function GetNearestInteractableObject(forward)
    for _, v in pairs(Config.Ambient.ObjectActionList) do
        local obj = GetClosestObjectOfType(forward.x, forward.y, forward.z, 0.9, v[1], 0, 1, 1)
        if obj ~= 0 then
            return obj, v[2]
        end
    end
    return nil, nil
end

local function PerformCompanionAction(entity, anim, obj, forward)
    isObjectInteracting = true
    TaskStopLeadingHorse(cache.ped)
    Wait(500)

    if obj then
        TaskGoStraightToCoord(entity, forward.x, forward.y, forward.z, 1.0, -1, -1, 0)
        Wait(1000)
        TaskTurnPedToFaceEntity(entity, obj, 1000)
        Wait(1000)
    end

    -- Obtener companionid por entidad
    local _, companionid = State.GetPetByEntity(entity)
    if not companionid then isObjectInteracting = false return end

    -- Usar helper centralizado para animación
    local duration = anim.duration and anim.duration * 1000 or -1
    State.PlayPetAnimation(companionid, anim.dict, anim.anim, false, duration)
    if duration and duration > 0 then Wait(duration) end

    if obj then ClearPedTasks(entity) end

    local companionHealth = Citizen.InvokeNative(0x36731AC041289BB1, entity, 0)
    -- local companionStamina = Citizen.InvokeNative(0x36731AC041289BB1, entity, 1)

    Citizen.InvokeNative(0xC6258F41D86676E0, entity, 0, companionHealth + Config.Ambient.BoostAction.Health)
    -- Citizen.InvokeNative(0xC6258F41D86676E0, entity, 1, companionStamina + Config.Ambient.BoostAction.Stamina)

    isObjectInteracting = false
end

function HandleWaterInteraction(entity)
    if not IsPedStill(entity) or IsPedSwimming(entity) then return end

    DisableControlAction(0, 0x7914A3DD, true)
    local label = CreateVarString(10, 'LITERAL_STRING', locale('cl_action_companions'))
    PromptSetActiveGroupThisFrame(DrinkPrompt, label)

    if Citizen.InvokeNative(0xC92AC953F0A982AE, ActionCompanionDrink) then
        PerformCompanionAction(entity, Config.Ambient.Anim.Drink)
    end
end

function HandleObjectInteraction(entity)
    local forward = GetOffsetFromEntityInWorldCoords(entity, 0.0, 0.8, -0.5)
    local obj, type = GetNearestInteractableObject(forward)

    if obj == nil then return end

    local promptGroup, action, anim
    if type == "drink" then
        promptGroup, action = DrinkPrompt, ActionCompanionDrink
        anim = Config.Ambient.Anim.Drink2
    elseif type == "feed" then
        promptGroup, action = EatPrompt, ActionCompanionEat
        anim = Config.Ambient.Anim.Eat
    else
        return
    end

    local label = CreateVarString(10, 'LITERAL_STRING', locale('cl_action_companions'))
    PromptSetActiveGroupThisFrame(promptGroup, label)

    if Citizen.InvokeNative(0xC92AC953F0A982AE, action) then
        PerformCompanionAction(entity, anim, obj, forward)
    end
end

-- MAIN LOOP TO HANDLE AMBIENT ACTIONS
CreateThread(function()
    if not Config.EnablePrompts then return end
    SetupActionPrompt()
    
    -- FIX: Add timeout protection to prevent infinite wait loop
    local loginTimeout = 0
    repeat 
        Wait(1000)
        loginTimeout = loginTimeout + 1
        -- Timeout after 5 minutes to prevent memory leak if player never logs in
        if loginTimeout > 300 then
            if Config.Debug then
                print('^3[PROMPTS]^7 ' .. locale('cl_debug_prompts_login_timeout'))
            end
            return
        end
    until LocalPlayer.state.isLoggedIn
    
    while true do
        ::continue::
        -- FIX: Changed from Wait(1) to Wait(100) to reduce CPU usage
        Wait(100)
        local closestPet, _, _ = State.GetClosestPet()
        local companion = closestPet and closestPet.ped or nil
        if cache.ped == nil or companion == nil then goto continue end

        if not IsPedLeadingHorse(cache.ped) or isObjectInteracting then
            Wait(1000)
            goto continue
        end

        if IsEntityInWater(companion) then
            HandleWaterInteraction(companion)
        elseif Config.Ambient.ObjectAction then
            HandleObjectInteraction(companion)
        end
    end
end)

------------------------------------------------
-- PROMPTS SETUP AND HANDLING FOR TARGETTING
------------------------------------------------

-- Helper para validar si un target es válido para una acción
local function IsValidTargetForAction(entity, actionType)
    local pedType = GetPedType(entity)
    local isPlayer = IsPedAPlayer(entity)
    local cfg = Config.TablesTrack and Config.TablesTrack[actionType]
    if not cfg or not cfg.Active then return false end
    if actionType == 'TrackOnly' then
        return (cfg.Animals and pedType == 28)
            or (cfg.NPC and not isPlayer)
            or (cfg.Players and isPlayer)
    elseif actionType == 'AttackOnly' then
        return (cfg.NPC and not isPlayer)
            or (cfg.Players and isPlayer)
    elseif actionType == 'HuntAnimalsOnly' then
        return pedType == 28
    end
    return false
end

function RegisterCompanionPrompt(controlAction, localeKey, group)
    local txt = locale(localeKey)
    local prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, controlAction)
    PromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', txt))
    PromptSetEnabled(prompt, 1)
    PromptSetVisible(prompt, 1)
    PromptSetStandardMode(prompt, 1)
    PromptSetGroup(prompt, group)
    Citizen.InvokeNative(0xC5F428EE08FA7F2C, prompt, true)
    PromptRegisterEnd(prompt)
    return prompt
end

function SetupEntityPrompt(entity, controlAction, localeKey, promptsTable)
    local group = Citizen.InvokeNative(0xB796970BD125FCE8, entity, Citizen.ResultAsLong())
    local prompt = RegisterCompanionPrompt(controlAction, localeKey, group)
    promptsTable[entity] = prompt
end

-- LEGACY-STYLE PROMPT REGISTRATION: Agrupa y muestra todos los prompts principales por mascota
function SetupPromptsForPet(companionid, petEntity, petXp)
    if not petEntity or not DoesEntityExist(petEntity) then
        if Config.Debug then
            print('^1[PROMPTS]^7 ' .. locale('cl_error_prompts_invalid_entity'))
        end
        return false
    end

    -- Obtener el prompt group para esta mascota
    local promptGroup = PromptGetGroupIdForTargetEntity(petEntity)
    if not promptGroup or promptGroup == 0 then
        if Config.Debug then
            print('^1[PROMPTS]^7 ' .. locale('cl_error_prompts_failed_group'))
        end
        return false
    end

    for cid, petData in pairs(State.GetAllPets()) do
        if petData.spawned and petData.ped == petEntity then
            companionid = cid
            break
        end
    end

    -- Registrar prompts principales agrupados
    local prompts = {}
    prompts.saddlebag = RegisterCompanionPrompt(Config.Prompt.CompanionSaddleBag, 'cl_action_saddlebag', promptGroup)
    prompts.flee = RegisterCompanionPrompt(Config.Prompt.CompanionFlee, 'cl_action_flee', promptGroup)
    prompts.actions = RegisterCompanionPrompt(Config.Prompt.CompanionActions, 'cl_action_actions', promptGroup)
    --[[ if petXp and petXp >= Config.XP.Trick.Hunt then
        prompts.hunt = RegisterCompanionPrompt(Config.Prompt.CompanionHunt, 'cl_action_hunt', promptGroup)
    end ]]
    prompts.petId = companionid
    petPrompts[petEntity] = prompts

    if Config.Debug then
        print('^2[PROMPTS]^7 ' .. locale('cl_info_prompts_configured') .. ' ' .. tostring(petEntity))
        print('^2[PROMPTS]^7 - ' .. locale('cl_label_actions') .. ': ' .. tostring(prompts.actions))
        print('^2[PROMPTS]^7 - ' .. locale('cl_label_flee') .. ': ' .. tostring(prompts.flee))
        print('^2[PROMPTS]^7 - ' .. locale('cl_label_saddlebag') .. ': ' .. tostring(prompts.saddlebag))
        -- print('^2[PROMPTS]^7 - ' .. locale('cl_label_hunt') .. ': ' .. tostring(prompts.hunt))
    end

    return true
end

function RemovePromptsForPet(petEntity)
    if petPrompts[petEntity] then
        -- Buscar companionid por entidad
        local companionid = nil
        for cid, petData in pairs(State.GetAllPets()) do
            if petData.spawned and petData.ped == petEntity then
                companionid = cid
                break
            end
        end
        State.SetPetTrait(companionid, 'isHunting', false)
        petPrompts[petEntity] = nil
    end
    if Config.Debug then
        print('^3[PROMPTS]^7 ' .. locale('cl_info_prompts_removed') .. ' ' .. tostring(companionid))
    end
end

function SetupCompanionTrackPrompts(entity)
    SetupEntityPrompt(entity, Config.Prompt.CompanionTrack, 'cl_action_track', TrackPrompts)
end
function SetupCompanionAttackPrompts(entity)
    SetupEntityPrompt(entity, Config.Prompt.CompanionAttack, 'cl_action_attack', AttackPrompts)
end
function SetupCompanionHuntAnimalsPrompts(entity)
    SetupEntityPrompt(entity, Config.Prompt.CompanionAttack, 'cl_action_attack', HuntAnimalsPrompts)
end
function SetupCompanionSearchDatabasePrompts(entity)
    SetupEntityPrompt(entity, Config.Prompt.CompanionSearch, 'cl_action_track', SearchDatabasePrompt)
end

CreateThread(function()
    local sleep = 1000
    if not Config.EnablePrompts then return end
    while true do
        Wait(sleep)
        sleep = 1

        local hasActivePets = false
        local targetedEntity = nil

        -- Get what the player is targeting/aiming at
        local playerId = PlayerId()
        if IsPlayerTargettingAnything(playerId) then
            local _, entity = GetPlayerTargetEntity(playerId)
            if entity and DoesEntityExist(entity) then
                targetedEntity = entity
            end
        end

        -- If targeting an entity, check if it's one of our pets
        if targetedEntity then
            local prompts = petPrompts[targetedEntity]                    
            -- Buscar companionid por entidad
            local companionid = nil
            local isHunting
            for cid, petData in pairs(State.GetAllPets()) do
                if petData.spawned and petData.ped == targetedEntity then
                    companionid = cid
                    isHunting = State.GetFlag(petData.ped, "isHunting")
                    break
                end
            end
            if prompts then
                hasActivePets = true

                -- Check actions prompt for THIS pet
                if prompts.actions and Citizen.InvokeNative(0xC92AC953F0A982AE, prompts.actions) then
                    if companionid then
                        ShowPetDashboard(companionid)
                    end
                    Wait(1500)
                    sleep = 500
                    goto continue
                end

                -- Check flee prompt for THIS pet
                if prompts.flee and Citizen.InvokeNative(0xC92AC953F0A982AE, prompts.flee) then
                    Flee(targetedEntity)
                    Wait(1500)
                    sleep = 500
                    goto continue
                end

                -- Check saddlebag prompt for THIS pet
                if prompts.saddlebag and Citizen.InvokeNative(0xC92AC953F0A982AE, prompts.saddlebag) then
                    if companionid then
                        TriggerEvent('hdrp-pets:client:inventoryCompanion', companionid)
                    end
                    Wait(1500)
                    sleep = 500
                    goto continue
                end
                -- Check hunt prompt for THIS pet
                --[[ if prompts.hunt and Citizen.InvokeNative(0xC92AC953F0A982AE, prompts.hunt) then
                    if not IsEntityDead(targetedEntity) then
                        if companionid then
                            if not isHunting then
                                lib.notify({ title = locale('cl_info_retrieve'), type = 'info', duration = 7000 })
                                State.SetPetTrait(companionid, 'isHunting', true)
                            else
                                State.SetPetTrait(companionid, 'isHunting', false)
                                lib.notify({ title = locale('cl_info_hunt_disabled'), type = 'info', duration = 7000 })
                            end
                        end
                    end
                    Wait(1500)
                    sleep = 500
                    goto continue
                end ]]
            end
        end

        -- Clean up non-existent pets
        for petEntity, _ in pairs(petPrompts) do
            if not DoesEntityExist(petEntity) then
                petPrompts[petEntity] = nil
            end
        end

        if not hasActivePets and not next(petPrompts) then
            sleep = 500
        end

        ::continue::
    end
end)

-- TARGETTING PROMPTS (Attack, Track, etc.)
--[[ CreateThread(function()
    local sleep = 1000
    if not Config.EnablePrompts then return end
    while true do
        sleep = 1000
        local closestPet, _, _ = State.GetClosestPet()
        local petPed = closestPet and closestPet.ped or nil
        local petXp = (closestPet and closestPet.data and closestPet.data.progression and closestPet.data.progression.xp) or 0
        if not petPed or petPed == 0 then 
            Wait(1000) 
        else
            if Config.EnablePrompts then
                local playerId = PlayerId()
                if IsPlayerTargettingAnything(playerId) then
                    local _, entity = GetPlayerTargetEntity(playerId)
                    if entity and entity ~= petPed then
                        sleep = 200
                        if IsEntityDead(entity) then
                            CleanUpRelationshipGroup()
                            sleep = 1000
                        else
                            local pedType = GetPedType(entity)
                            local isPlayer = IsPedAPlayer(entity)
                            -- SEARCH DATABASE
                            if Config.TablesTrack.SearchData and petXp >= Config.XP.Trick.SearchData then
                                SetupCompanionSearchDatabasePrompts(entity)
                                if Citizen.InvokeNative(0xC92AC953F0A982AE, SearchDatabasePrompt[entity]) then
                                    local playerCoords = GetEntityCoords(PlayerPedId())
                                    TriggerServerEvent('hdrp-pets:server:searchDatabase', playerCoords, nil)
                                    sleep = 2000
                                end
                            end
                            -- TRACK
                            if IsValidTargetForAction(entity, 'TrackOnly') and petXp >= Config.XP.Trick.Track then
                                if not TrackPrompts[entity] then
                                    SetupCompanionTrackPrompts(entity)
                                    TrackPrompts[entity] = true
                                    sleep = 2000
                                end
                                if TrackPrompts[entity] and Citizen.InvokeNative(0xC92AC953F0A982AE, TrackPrompts[entity]) then
                                    TrackTarget(entity)
                                    sleep = 2000
                                end
                            end
                            -- ATTACK
                            if IsValidTargetForAction(entity, 'AttackOnly') and petXp >= Config.XP.Trick.Attack then
                                if not AttackPrompts[entity] then
                                    SetupCompanionAttackPrompts(entity)
                                    AttackPrompts[entity] = true
                                    sleep = 2000
                                end
                                if AttackPrompts[entity] and Citizen.InvokeNative(0xC92AC953F0A982AE, AttackPrompts[entity]) then
                                    AttackTarget(entity)
                                    sleep = 2000
                                end
                            end
                            -- HUNT
                            if IsValidTargetForAction(entity, 'HuntAnimalsOnly') and petXp >= Config.XP.Trick.HuntAnimals then
                                if not HuntAnimalsPrompts[entity] then
                                    SetupCompanionHuntAnimalsPrompts(entity)
                                    HuntAnimalsPrompts[entity] = true
                                    sleep = 2000
                                end
                                if HuntAnimalsPrompts[entity] and Citizen.InvokeNative(0xC92AC953F0A982AE, HuntAnimalsPrompts[entity]) then
                                    HuntAnimals(entity)
                                    sleep = 2000
                                end
                            end
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end) ]]

-- Limpieza de prompts al parar el recurso
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    -- State.CleanupAllTablePrompts()
    for petEntity, _ in pairs(petPrompts) do
        RemovePromptsForPet(petEntity)
    end

    if ActionCompanionDrink then
        PromptSetEnabled(ActionCompanionDrink, false)
        PromptSetVisible(ActionCompanionDrink, false)
    end
    if ActionCompanionEat then
        PromptSetEnabled(ActionCompanionEat, false)
        PromptSetVisible(ActionCompanionEat, false)
    end
end)
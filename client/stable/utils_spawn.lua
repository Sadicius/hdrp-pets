local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
local M = lib.load('shared.stable.shop_helpers')
local ManageSpawn = {}

------------------------------------------
-- PET ANIMATION AND BEHAVIOR FUNCTIONS
------------------------------------------
-- Crouch inspect animation
function ManageSpawn.crouchInspectAnim()
    local anim1 = `WORLD_HUMAN_CROUCH_INSPECT`
    if not IsPedMale(cache.ped) then anim1 = `WORLD_HUMAN_CROUCH_INSPECT` end
    SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)
    FreezeEntityPosition(cache.ped, true)
    TaskStartScenarioInPlace(cache.ped, anim1, 3000, true, false, false, false)
    Wait(3000)
    State.ResetPlayerState(true)
    SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)
end

---Move companion pet to player location
---@param entity number Pet entity to move
---@param playerPed number|nil Target player ped, defaults to cache.ped
---@return boolean success True if command was successful
function ManageSpawn.moveCompanionToPlayer(entity, playerPed)
    if not entity or not DoesEntityExist(entity) then
        return false
    end
    
    if not playerPed or not DoesEntityExist(playerPed) then
        playerPed = cache.ped
    end

    State.petUnfreeze(entity)

    TaskGoToEntity(entity, playerPed, -1, 2.0, 2.0, 1073741824, 0)

    local _, petId = State.GetPetByEntity(entity)
    if petId then
        State.SetPetTrait(petId, 'isCall', true)
        TriggerServerEvent('hdrp-pets:server:useitem', 'no-item', petId)
    end
    
    return true
end

------------------------------------------
-- FIGHTING PET SPAWN AND MANAGEMENT FUNCTIONS
------------------------------------------
-- Set Pet Attributes Fighting
local function SetPetAttributes(entity)
    if not entity or not DoesEntityExist(entity) then return end
    
    SetEntityHealth(entity, Config.PetAttributes.Starting.Health or 300)
    Citizen.InvokeNative(0x166E7CF68597D8B5, entity, Config.PetAttributes.Starting.Health or 300)
    
    SetEntityInvincible(entity, false)
    SetEntityCanBeDamaged(entity, true)
    
    SetPedCombatAttributes(entity, 46, true) -- Always fight
    SetPedCombatAttributes(entity, 5, true)  -- Fight armed peds
    SetPedCombatAttributes(entity, 0, true)  -- Can use weapons
    SetPedCombatAttributes(entity, 1, true)  -- Can use cover
    SetPedCombatAttributes(entity, 17, true) -- Always attack
    SetPedCombatAttributes(entity, 58, true) -- Aggressive stance
    
    SetPedCombatMovement(entity, 3) 
    SetPedFleeAttributes(entity, 0, false) 
    
    Citizen.InvokeNative(0x9238A3D970BBB0A9, entity, -1663301869) 
    SetPedCombatRange(entity, 0) 
    
    SetPedKeepTask(entity, true)
    Citizen.InvokeNative(0x5240864E847C691C, entity, false) 
end

-- Spawn Dog for Dog Fight
function ManageSpawn.spawnDog(model, coords, heading, baseHealth)
    local modelHash = GetHashKey(model)
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 30 do
        Wait(100)
        timeout = timeout + 1
    end
    if not HasModelLoaded(modelHash) then return nil end
    local ped = CreatePed(modelHash, coords.x, coords.y, coords.z, heading, false, true, false, false)
    if not DoesEntityExist(ped) then SetModelAsNoLongerNeeded(modelHash) return nil end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
    SetPetAttributes(ped, baseHealth or 300)
    SetModelAsNoLongerNeeded(modelHash)
    return ped
end

-- Apply effective damage considering attacker's strength vs defender's strength
function ManageSpawn.CalculateDogDamage(attacker, defender, minDamage, maxDamage)
    if not attacker or not defender then
        return math.random(minDamage or 3, maxDamage or 8)
    end
    
    local baseRoll = math.random(minDamage or 3, maxDamage or 8)
    local strengthFactor = attacker.Strength / math.max(30, defender.Strength)
    local damage = baseRoll * (1 + strengthFactor * 0.4)
    
    return math.max(minDamage or 3, math.min(maxDamage or 8, math.floor(damage)))
end

-- Apply effective damage from attacker to defender
function ManageSpawn.ApplyForcedDamage(ped1, ped2, dog1, dog2)
    
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

-- Apply damage to target ped, ensuring it doesn't die instantly
function ManageSpawn.ApplyDogDamage(targetPed, attackerPed, damageAmount)
    if not DoesEntityExist(targetPed) or not DoesEntityExist(attackerPed) then return end
    local currentHealth = GetEntityHealth(targetPed)
    if currentHealth <= damageAmount then
        damageAmount = math.floor(currentHealth * 0.4)
        if damageAmount <= 0 then damageAmount = 1 end
    end
    Citizen.InvokeNative(0x697157CED63F18D4, targetPed, damageAmount, false, false, true)
    SetEntityHealth(targetPed, currentHealth - damageAmount)
    if math.random() < 0.4 then
        Citizen.InvokeNative(0xEF0D582CBF2D9B0F, targetPed, 1, GetPedBoneCoords(targetPed, 0, 0.0, 0.0, 0.0), 0.0, 0.0)
    end
end

------------------------------------------
-- PET SPAWN AND SETUP FUNCTIONS
------------------------------------------
-- Colocar ped correctamente en el suelo
function ManageSpawn.PlacePedOnGroundProperly(entity)
    if not entity or not DoesEntityExist(entity) then return end
    local howfar = math.random(15, 30)
    local x, y, z = table.unpack(GetEntityCoords(cache.ped))
    local found, groundz, normal = GetGroundZAndNormalFor_3dCoord(x - howfar, y, z)
    if found then SetEntityCoordsNoOffset(entity, x - howfar, y, groundz + normal.z, true) end
end 

-- Configurar flags de companion para IA y comportamiento
function ManageSpawn.SetCompanionFlags(entity)
    if not entity or not DoesEntityExist(entity) then return end
    local companionFlags = {
        [6] = true, -- No influye en tu nivel de búsqueda WantedLevel
        [217] = true, -- Evita "shock" por explosiones/disparos
        [136] = true, -- No se monta ni permite montarlo
        [412] = true, -- PCF_BlockHorsePromptsForTargetPed                
        [279] = true, -- Siempre te sigue sin perderte
        [154] = true, -- Reacciona a amenazas al seguirte
        [540] = true, -- Corre para subirse al coche contigo
        [269] = true, -- Se queda dentro si asaltan el vehículo
        [180] = true,   -- PCF_PreventDraggedOutOfCarThreatResponse
        [265] = false, -- No se ahoga ni muere en el agua
        [266] = false, -- PCF_DiesInstantlyWhenSwimming
        [267] = false, -- PCF_DrownsInSinkingVehicle
        [211] = true, -- Tareas ambientales y seguimiento de mirada
        [259] = true,   -- PCF_CanAmbientHeadtrack
        [157] = true, -- Desactiva arrastre forzado (si aplica)
        [313] = false,  -- Permite que busque transporte para seguirte
        [499] = false,  -- Silbido funciona correctamente
        [113] = false, -- PCF_DisableShockingEvents
        -- [297] = true, --  PCF_ForceInteractionLockonOnTargetPed
        -- [155] = true, --  PCF_EnableCompanionAIAnalysis
        -- [156] = true, --  PCF_EnableCompanionAISupport
        -- [125] = true, --  PCF_ForcePoseCharacterCloth
        -- [79] = true, --  PCF_ForcedToStayInCover
        -- [194] = true, --  PCF_ShouldPedFollowersIgnoreWaypointMBR
        -- [50]  = true,   -- PCF_WillFollowLeaderAnyMeans
        -- [208] = true,
        -- [209] = true,
        -- [277] = true,
        -- [300] = false, -- PCF_DisablePlayerHorseLeading
        -- [301] = false, -- PCF_DisableInteractionLockonOnTargetPed
        -- [312] = false, -- PCF_DisableHorseGunshotFleeResponse
        -- [319] = true, -- PCF_EnableAsVehicleTransitionDestination
        -- [419] = false, -- PCF_BlockMountHorsePromptç
        -- [438] = false,
        -- [439] = false,
        -- [440] = false,
        -- [561] = true
    }
    for flag, val in pairs(companionFlags) do Citizen.InvokeNative(0x1913FE4CBF41C463, entity, flag, val); end

    local companionTunings = { 24, 25, 48 }
    for _, flag in ipairs(companionTunings) do Citizen.InvokeNative(0x1913FE4CBF41C463, entity, flag, false); end
end

local function IsPedReadyToRender(...)
    return Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ...)
end

-- Actualizar variación de ped (ropa, accesorios, etc)
function ManageSpawn.UpdatePedVariation(entity)
    if not entity or not DoesEntityExist(entity) then return end
    Citizen.InvokeNative(0x704C908E9C405136, entity)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, entity, false, true, true, true, false)
    while not IsPedReadyToRender(entity) do 
        Wait(50) 
    end
end

-- Aplicar niveles de bonding según XP
function ManageSpawn.ApplyBonding(entity, xp)
    if not entity or not DoesEntityExist(entity) then return end

    local bond = Config.PetAttributes.Starting.MaxBonding
    local bond1 = bond * 0.25
    local bond2 = bond * 0.50
    local bond3 = bond * 0.75
    local bondingLevel = 1
    if xp <= bond * 0.25 then bondingLevel = 1 end
    if xp > bond1 and xp <= bond2 then bondingLevel = 817 end
    if xp > bond2 and xp <= bond3 then bondingLevel = 1634 end
    if xp > bond3 then bondingLevel = 2450 end
    Citizen.InvokeNative(0x09A59688C26D88DF, entity, 7, bondingLevel)
    -- pet.data.bonding = bondingLevel
end

-- Aplicar niveles de bonding según XP
function ManageSpawn.ApplyPersonality(entity, xp)
    if not entity or not DoesEntityExist(entity) then return end
    for _, p in ipairs(Config.PetAttributes.personalities) do
        if xp >= p.xp then Citizen.InvokeNative(0xB8B6430EAD2D2437, entity, GetHashKey(p.hash)) break end
    end
end

--- Calculate pet scale based on age (growth system)
--- Grows from 0.5 (50%) at birth to 1.0 (100%) at 5 days old
--- After 5 days, remains at 100%
---@param age number Pet age in days
---@return number scale Scale value between 0.5 and 1.0
function ManageSpawn.CalculateScaleFromAge(age)
    age = age or 0
    return math.min(1.0, 0.5 + 0.1 * age)
end

-- PET STATS UPDATE FUNCTION
function ManageSpawn.UpdatePetStats(entity, xp, dirt)
    if not entity or not DoesEntityExist(entity) then return end
    
    -- 13. APLICAR NO MIEDO
    if Config.PetAttributes.NoFear then
        Citizen.InvokeNative(0x013A7BA5015C1372, entity, true)
        Citizen.InvokeNative(0x3B005FF0538ED2A9, entity)
    end

    -- 11. APLICAR INVENCIBILIDAD
    if Config.PetAttributes.Invincible then
        SetEntityInvincible(entity, true)
    end

    xp = xp or 0
    State.statsCompanion = State.statsCompanion or {}
    
    -- Find if this pet already exists in statsCompanion
    local existingIndex = nil
    for i, stat in ipairs(State.statsCompanion) do
        if stat.ped == entity then
            existingIndex = i
            break
        end
    end

    -- Set dirt level
    Citizen.InvokeNative(0x5DA12E025D47D4E5, entity, 16, dirt) -- set dirt
    
    -- Calculate hValue based on XP (same logic as hdrp-companion and SpawnAnimal)
    local hValue = 0
    for i, level in ipairs(Config.PetAttributes.levelAttributes) do
        if xp >= level.xpMin and xp <= level.xpMax then
            hValue = level.xpMax + 1
            break
        end
    end
    
    -- Calculate attributes using hdrp-companion formulas
    local baseSTAMINA = hValue * Config.PetAttributes.AttributeRatios.Stamina
    local baseAGILITY = hValue * Config.PetAttributes.AttributeRatios.Agility
    -- local baseCOURAGE = hValue * Config.PetAttributes.AttributeRatios.Courage
    local baseSPEED = hValue * Config.PetAttributes.AttributeRatios.Speed
    local baseACCELERATION = hValue * Config.PetAttributes.AttributeRatios.Acceleration
    
    -- stats data table
    local statData = {
        ped = entity,
        STAMINA = math.floor(baseSTAMINA),
        AGILITY = math.floor(baseAGILITY),
        -- COURAGE = math.floor(baseCOURAGE),
        SPEED = math.floor(baseSPEED),
        ACCELERATION = math.floor(baseACCELERATION)
    }

    -- Set attributes using native
    Citizen.InvokeNative(0x09A59688C26D88DF, entity, 0, hValue) -- HEALTH (0-2000) SetAttributePoints
    Citizen.InvokeNative(0x09A59688C26D88DF, entity, 1, baseSTAMINA) -- STAMINA (0-2000)
    -- Citizen.InvokeNative(0x09A59688C26D88DF, entity, 3, baseCOURAGE) -- COURAGE (0-2000) valentia
    Citizen.InvokeNative(0x09A59688C26D88DF, entity, 4, baseAGILITY) -- AGILITY (0-2000)
    Citizen.InvokeNative(0x09A59688C26D88DF, entity, 5, baseSPEED) -- SPEED (0-2000)
    Citizen.InvokeNative(0x09A59688C26D88DF, entity, 6, baseACCELERATION) -- ACCELERATION (0-2000)

    local companionCombat = {
        [0] = true,
        [1] = true,
        [5] = true,
        [17] = true,
        [46] = true,
        [58] = true, 
    }
    for flag, val in pairs(companionCombat) do SetPedCombatAttributes(entity, flag, val); end
    SetPedCombatMovement(entity, 3)
    SetPedFleeAttributes(entity, 0, false)
    Citizen.InvokeNative(0x9238A3D970BBB0A9, entity, -1663301869)
    SetPedCombatRange(entity, 0)

    --[[ 
    -- POSSIBLE ADD
    if Config.Debug then print("Suciedad: " .. companionDirtPercent .. "%") end

    -- | ADD_ATTRIBUTE_POINTS | --
    AddAttributePoints(entity, 0, hValue ) -- Citizen.InvokeNative(0x75415EE0CB583760,
    AddAttributePoints(entity, 1, baseSTAMINA )

    -- | SET_ATTRIBUTE_BASE_RANK | --
    local baserank = hValue * 0.01
    Citizen.InvokeNative(0x5DA12E025D47D4E5, entity, 0, baserank )
    Citizen.InvokeNative(0x5DA12E025D47D4E5, entity, 1, baserank )
    Citizen.InvokeNative(0x5DA12E025D47D4E5, entity, 2, baserank )
    -- | SET_ATTRIBUTE_BONUS_RANK | --
    local bonusrank = hValue * 0.01
    Citizen.InvokeNative(0x920F9488BD115EFB, entity, 0, bonusrank )
    Citizen.InvokeNative(0x920F9488BD115EFB, entity, 1, bonusrank)
    ]]

    -- overpower settings
    if overPower then
        EnableAttributeOverpower(entity, 0, Config.PetAttributes.Starting.MaxBonding)                       -- health overpower
        EnableAttributeOverpower(entity, 1, Config.PetAttributes.Starting.MaxBonding)                       -- stamina overpower
        local setoverpower = xp + .0                    -- convert overpower to float value
        Citizen.InvokeNative(0xF6A7C08DF2E28B28, entity, 0, setoverpower) -- set health with overpower
        Citizen.InvokeNative(0xF6A7C08DF2E28B28, entity, 1, setoverpower) -- set stamina with overpower
    end

    if existingIndex then
        -- Update existing entry
        State.statsCompanion[existingIndex] = statData
    else
        -- Add new entry
        table.insert(State.statsCompanion, statData)
    end
end

--------------------------------------------
-- PET CUSTOMIZATION AND PROPS FUNCTIONS
--------------------------------------------
-- Función global para obtener el hash de un componente de customización
function ManageSpawn.getComponentHash(category, value)
    if Config.PetShopComp and Config.PetShopComp[category] then
        local item = Config.PetShopComp[category][value]
        if item and item.hash then
            return item.hash
        end
    end
    return 0
end

-- Aplicar customización visual y props al pet
function ManageSpawn.GetCustomize(entity, components)
    if not entity or not DoesEntityExist(entity) then return end
    if components and (components.custom or components.props) then
        -- Aplicar customización visual (componentes con hash_name)
        if Config.EnablePetCustom and type(components.custom) == "table" then
            for k, v in pairs(components.custom) do
                if type(v) == "table" and v.hash_name and v.hash_name ~= '' then
                    local componentHash = joaat(v.hash_name)
                    Citizen.InvokeNative(0xD3A7B003ED343FD9, entity, componentHash, true, true, true)
                elseif type(v) == "number" and v > 0 then
                    if PetComponents_IsValid and PetComponents_IsValid(k, v) then
                        local hash = ManageSpawn.getComponentHash(k, v)
                        if hash ~= 0 then
                            Citizen.InvokeNative(0xD3A7B003ED343FD9, entity, hash, true, true, true)
                        end
                    else
                        print(string.format('[hdrp-pets] Componente visual inválido: %s=%s', tostring(k), tostring(v)))
                    end
                end
            end
        end
        -- Aplicar props/accesorios
        if Config.EnablePetProps and type(components.props) == "table" then
            for category, value in pairs(components.props) do
                if type(value) == "number" and value > 0 then
                    if PetProps_IsValid and PetProps_IsValid(category, value) then
                        local hash = ManageSpawn.getComponentHash(category, value)
                        if hash ~= 0 then
                            local config = hashToConfig and hashToConfig[hash] or nil
                            if config and type(AttachObjectToPet) == "function" then
                                AttachObjectToPet(entity, config)
                            end
                        end
                    else
                        print(string.format('[hdrp-pets] Prop inválido: %s=%s', tostring(category), tostring(value)))
                    end
                end
            end
        end
    end
end

return ManageSpawn
local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState() -- Asegura acceso a State
local ManageSpawn = lib.load('client.stable.utils_spawn')
local ClaimedAnimals = {}
local RetrievedEntities = {}
local fetchedObj = {} -- Debe ser tabla para multipet
local isRetrieving = false

----------------------------
-- hunt mode-- target pet
----------------------------
---Return a retrieved kill to the player (multipet hunt mode)
---@param petId string Pet identifier
---@param fetchedKill number Entity of the kill
---@param player number Player ped
local function ReturnKillToPlayer(petId, fetchedKill, player)
    local petData = State.GetPet(petId)
    if not petData or not petData.spawned or not DoesEntityExist(petData.ped) then return end
    
    local petPed = petData.ped
    local coords = GetEntityCoords(player)
    TaskGoToCoordAnyMeans(petPed, coords.x, coords.y, coords.z, 1.5, 0, 0, 786603, 0xbf800000)
    
    while true do
        coords = GetEntityCoords(player)
        local coords2 = GetEntityCoords(petPed)
        local dist = #(coords - coords2)
        local sleep = dist > 15.0 and 3000 or (dist > 5.0 and 1500 or 500)
        Wait(sleep)
        TaskGoToCoordAnyMeans(petPed, coords.x, coords.y, coords.z, 1.5, 0, 0, 786603, 0xbf800000)
        
        if dist <= 2.0 then
            if fetchedObj[petId] then
                DetachEntity(fetchedObj[petId])
                Wait(100)
                SetEntityAsMissionEntity(fetchedObj[petId], true)
                PlaceObjectOnGroundProperly(fetchedObj[petId])
                Wait(1000)
                FreezeEntityPosition(fetchedObj[petId], true)
                SetModelAsNoLongerNeeded(fetchedObj[petId])
                
                -- Release claim when animal is successfully retrieved
                if ClaimedAnimals and ClaimedAnimals[fetchedObj[petId]] == petId then
                    ClaimedAnimals[fetchedObj[petId]] = nil
                end
                
                fetchedObj[petId] = nil
            end
            
            isRetrieving = false
            ManageSpawn.moveCompanionToPlayer(petPed, player)
            break
        end
    end
end

---Command pet to retrieve a dead animal (multipet hunt mode)
---@param petId string Pet identifier
---@param ClosestPed number Dead animal entity to retrieve
local function RetrieveKill(petId, ClosestPed)
    local petData = State.GetPet(petId)
    if not petData or not petData.spawned or not DoesEntityExist(petData.ped) or IsEntityDead(petData.ped) then 
        lib.notify({ title = locale('cl_error_no_pet'), type = 'error', duration = 7000 }) 
        return 
    end
    
    local petPed = petData.ped
	fetchedObj[petId] = ClosestPed
	local coords = GetEntityCoords(fetchedObj[petId])

    -- RSGCore.Functions.TriggerCallback('hdrp-pets:server:getactivecompanions', function(petData)
    --     if petData and petData.active ~= 0 then
    --         local companionsDada = json.decode(petData.data) or {}
    --         -- if petData.stats.hunger < 30 or petData.stats.thirst < 30 then return end
    --     else
    --         lib.notify({ title = locale('cl_error_retrieve_no_companions'), type = 'error', duration = 7000 })
    --     end

    -- end)
            
    if #(coords - GetEntityCoords(petPed)) > Config.PetAttributes.SearchRadius then 
        lib.notify({ title = locale('cl_error_retrieve_distance'), type = 'error', duration = 7000 }) 
        return 
    end
    
    TaskGoToCoordAnyMeans(petPed, coords.x, coords.y, coords.z, 2.0, 0, 0, 786603, 0xbf800000)

    isRetrieving = true
    if Config.Debug then
        print(locale('cl_print_retrieve'))
    end
    
    while true do
        local petCoords = GetEntityCoords(petPed)
        coords = GetEntityCoords(fetchedObj[petId])
        local dist = #(coords - petCoords)
        local sleep = dist > 10.0 and 2000 or 1000
        Wait(sleep)
        
        if dist <= 2.5 then
            AttachEntityToEntity(fetchedObj[petId], petPed, GetPedBoneIndex(petPed, 21030), 0.14, 0.14, 0.09798, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
            if not RetrievedEntities[petId] then
                RetrievedEntities[petId] = {}
            end
            RetrievedEntities[petId][fetchedObj[petId]] = true
            -- Remove claim since this pet successfully picked it up
            if ClaimedAnimals[fetchedObj[petId]] then
                ClaimedAnimals[fetchedObj[petId]] = nil
            end
            ReturnKillToPlayer(petId, fetchedObj[petId], cache.ped)
            break
        else
            local taskStatus = GetScriptTaskStatus(petPed, 0x8AA1593C) -- TASK_GO_TO_COORD_ANY_MEANS
            if taskStatus ~= 1 and taskStatus ~= 0 then
                TaskGoToCoordAnyMeans(petPed, coords.x, coords.y, coords.z, 2.0, 0, 0, 786603, 0xbf800000)
            end
        end
    end
end

local function GetClosestAnimalPed(playerPed, radius)
	local playerCoords = GetEntityCoords(playerPed)
	local itemset = CreateItemset(true)
	local size = Citizen.InvokeNative(0x59B57C4B06531E1E, playerCoords, radius, itemset, 1, Citizen.ResultAsInteger())
	local closestPed
	local minDist = radius
	if size > 0 then
		for i = 0, size - 1 do
			local ped = GetIndexedItemInItemset(i, itemset)
			if playerPed ~= ped then
				local pedType = GetPedType(ped)
				local model = GetEntityModel(ped)
				if pedType == 28 and IsEntityDead(ped) and not RetrievedEntities[ped] and Config.RetrievableAnimals[model] then
					local pedCoords = GetEntityCoords(ped)
					local distance = #(playerCoords - pedCoords)
					if distance < minDist then
						closestPed = ped
						minDist = distance
					end
				end
			end
		end
	end
	if IsItemsetValid(itemset) then
		DestroyItemset(itemset)
	end
	return closestPed
end

local function GetClosestFightingPed(playerPed, radius)
	local playerCoords = GetEntityCoords(playerPed)
	local itemset = CreateItemset(true)
	local size = Citizen.InvokeNative(0x59B57C4B06531E1E, playerCoords, radius, itemset, 1, Citizen.ResultAsInteger())
	local closestPed
	local minDist = radius
	
	-- Get all active pet entities to exclude them
	local activePets = State.GetAllActivePets()
	
	if size > 0 then
		for i = 0, size - 1 do
			local ped = GetIndexedItemInItemset(i, itemset)
			
			-- Check if ped is player or any active pet
			local isPet = false
			for _, petInfo in ipairs(activePets) do
				if ped == petInfo.ped then
					isPet = true
					break
				end
			end
			
			if playerPed ~= ped and not isPet then
				local pedType = GetPedType(ped)
				local model = GetEntityModel(ped)
				local pedCoords = GetEntityCoords(ped)
				local distance = #(playerCoords - pedCoords)
				if IsPedInCombat(playerPed, ped) then
					closestPed = ped
					minDist = distance
				end
			end
		end
	end
	
	if IsItemsetValid(itemset) then
		DestroyItemset(itemset)
	end
	return closestPed
end

-- Main Thread - Auto-Hunt Mode for Multiple Pets
-- Monitors for dead animals and commands pets to retrieve them
CreateThread(function()
    while true do
        local sleep = 5000
        -- Get all active pets
        local activePets = State.GetAllActivePets()
        if #activePets == 0 then 
            Wait(10000)
            goto continue
        end
        -- Debug: mostrar flags de todas las mascotas
        for _, petInfo in ipairs(activePets) do
            local petId = petInfo.id
            local petPed = petInfo.ped
            local petData = State.GetPet(petId)
        end
        -- Check hunt mode for each pet
        for _, petInfo in ipairs(activePets) do
            local petId = petInfo.id
            local petPed = petInfo.ped
            local petData = State.GetPet(petId)
            if not petPed or not DoesEntityExist(petPed) then
                goto next_pet
            end
            -- Solo actuar si el modo principal es hunting y no está retrieving
            if not isRetrieving and (petData and petData.flag and petData.flag.isHunting) then
                if Config.Debug then print("[HUNT DEBUG] Entrando en modo caza para mascota:", petId) end
                local petXp = tonumber(petData and petData.progression and petData.progression.xp) or 0
                if Config.PetAttributes.RaiseAnimal and petXp < Config.XP.Trick.Hunt then
                    goto next_pet
                end
                local ClosestPed = GetClosestAnimalPed(cache.ped, Config.PetAttributes.SearchRadius)
                local pedType = ClosestPed and GetPedType(ClosestPed) or nil
                local alreadyRetrieved = RetrievedEntities[petId] and RetrievedEntities[petId][ClosestPed]
                local claimedByAnother = ClaimedAnimals[ClosestPed] and ClaimedAnimals[ClosestPed] ~= petId
                if pedType == 28 and IsEntityDead(ClosestPed) and not alreadyRetrieved and not claimedByAnother then
                    local whoKilledPed = GetPedSourceOfDeath(ClosestPed)
                    if cache.ped == whoKilledPed then
                        local model = GetEntityModel(ClosestPed)
                        for k, v in pairs(Config.RetrievableAnimals) do
                            if model == k then
                                if Config.Debug then print("[HUNT DEBUG] Mascota:", petId, "reclama animal:", ClosestPed) end
                                ClaimedAnimals[ClosestPed] = petId
                                RetrieveKill(petId, ClosestPed)
                                sleep = 1000
                                break
                            end
                        end
                    else
                        if not RetrievedEntities[petId] then
                            RetrievedEntities[petId] = {}
                        end
                        RetrievedEntities[petId][ClosestPed] = true
                        if Config.Debug then print("[HUNT DEBUG] Mascota:", petId, "animal no matado por jugador, marcado como recuperado") end
                    end
                end
            end
            ::next_pet::
        end
        -- Cleanup stale animal claims
        if ClaimedAnimals then
            for entity, claimedBy in pairs(ClaimedAnimals) do
                if not DoesEntityExist(entity) or not IsEntityDead(entity) then
                    ClaimedAnimals[entity] = nil
                end
            end
        end
        -- Defensive mode: pet auto-attacks threats
        --[[ if Config.PetAttributes.DefensiveMode then
            for _, petInfo in ipairs(activePets) do
                local petId = petInfo.id
                local petPed = petInfo.ped
                local petData = State.GetPet(petId)
                if not petPed or not DoesEntityExist(petPed) then goto next_def_pet end
                petData.timers = petData.timers or {}
                petData.timers.recentlyCombatTime = petData.timers.recentlyCombatTime or 0
                if petData.timers.recentlyCombatTime <= 0 then
                    local enemyPed = GetClosestFightingPed(cache.ped, 10.0)
                    local playerCoords = GetEntityCoords(cache.ped)
                    if enemyPed then
                        ClearPedTasks(petPed)
                        local targetCoords = GetEntityCoords(enemyPed)
                        local distance = #(playerCoords - targetCoords)
                        if distance <= 10.0 then
                            lib.notify({ title = locale('cl_defensive_attack'), type = 'info', duration = 7000 })
                            AttackTarget(enemyPed)
                            petData.timers.recentlyCombatTime = 10
                        end
                    end
                else
                    petData.timers.recentlyCombatTime = petData.timers.recentlyCombatTime - 1
                end
                ::next_def_pet::
            end
        end ]]
        ::continue::
        Wait(sleep)
    end
end)

RegisterCommand('pet_hunt', function()
    RSGCore.Functions.TriggerCallback('hdrp-pets:server:getactivecompanions', function(serverPets)
        State.Pets = State.Pets or {}
        for _, dbPetData in ipairs(serverPets or {}) do
            local companionid = dbPetData.companionid or nil
            local petData = type(dbPetData.data) == 'string' and json.decode(dbPetData.data) or dbPetData.data or {}
            State.Pets[companionid] = State.Pets[companionid] or {}
            State.Pets[companionid].data = petData
            -- Puedes sincronizar otros campos si es necesario
        end
        local activePets = State.GetAllPets()
        local spawnedPets = {}
        for companionid, petData in pairs(activePets) do
            if petData and petData.spawned and DoesEntityExist(petData.ped) then
                spawnedPets[companionid] = petData
            end
        end

        for companionid, petData in pairs(spawnedPets) do
            local xp = (petData.progression and petData.progression.xp) or 0
            local isHunting = (petData and petData.flag and petData.flag.isHunting) or false
            if xp < Config.XP.Trick.Hunt then
                lib.notify({ title = locale('cl_error_xp_needed'):format(Config.XP.Trick.Hunt), type = 'error' })
                return
            end
            if petData.ped and DoesEntityExist(petData.ped) and not IsEntityDead(petData.ped) and companionid then
                if not isHunting then
                    lib.notify({ title = locale('cl_info_retrieve'), type = 'info', duration = 7000 })
                    State.SetPetTrait(companionid, 'isHunting', true)
                else
                    State.SetPetTrait(companionid, 'isHunting', false)
                    lib.notify({ title = locale('cl_info_hunt_disabled'), type = 'info', duration = 7000 })
                end
            end
        end

    end)
end, false)

-- Limpieza de grupo de relación al parar el recurso
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
end)
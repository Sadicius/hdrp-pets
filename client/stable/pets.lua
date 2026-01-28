local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
local PetShopPrice = Config.PetShopPrice
local spawnedPaidPeds = {}

--  BUY NPC SYSTEM - PETS STABLES
-- NPC Pet
local function NearBuyPetNPC(npcpetmodel, npcpetcoords, heading, stableid, price, category, label)
    -- Resolve model hash and ensure it is available
    local modelHash = type(npcpetmodel) == 'number' and npcpetmodel or joaat(npcpetmodel)
    if not IsModelInCdimage(modelHash) then
        lib.notify({ title = locale('cl_error_model_not_found'), type = 'error', duration = 4000 })
        return nil
    end
    -- Request model with timeout; bail out if it doesn't load
    local loaded = lib.requestModel(modelHash, 5000)
    if not loaded or not HasModelLoaded(modelHash) then
        lib.notify({ title = locale('cl_error_model_timeout'), type = 'error', duration = 4000 })
        return nil
    end
    -- Spawn NPC
    local spawnedPetPed = CreatePed(modelHash, npcpetcoords.x, npcpetcoords.y, npcpetcoords.z - 1.0, heading, false, false, 0, 0)
    SetEntityAlpha(spawnedPetPed, 0, false)
    SetRandomOutfitVariation(spawnedPetPed, true)
    SetEntityCanBeDamaged(spawnedPetPed, false)
    SetEntityInvincible(spawnedPetPed, true)
    FreezeEntityPosition(spawnedPetPed, true)
    SetBlockingOfNonTemporaryEvents(spawnedPetPed, true)
    SetPedCanBeTargetted(spawnedPetPed, false)
    -- Set scale
    local scale = math.random(50, 110) / 100.0
    SetPedScale(spawnedPetPed, scale)
    -- Start scenario
    -- TaskStartScenarioInPlace(spawnedPetPed, 'WORLD_HUMAN_WRITE_NOTEBOOK', 0, true)
    -- Fade in
    if Config.FadeIn then
        for i = 0, 255, 51 do
            Wait(50)
            SetEntityAlpha(spawnedPetPed, i, false)
        end
    end

    -- Targeting
    if Config.EnableTarget then -- and not Config.EnableBuyPetMenu or not Config.EnableBuyPetMenu or Config.EnableTarget 
        exports.ox_target:addLocalEntity(spawnedPetPed, {
            {   name = 'npc_pet_input_buy',
                icon = 'far fa-eye',
                label = label..' $'..price,

                onSelect = function()
                    -- Input dialog
                    local dialog = lib.inputDialog(locale('cl_input_setup'), {
                        { type = 'input', label = locale('cl_input_setup_name') },
                        {
                            type = 'select',
                            label = locale('cl_input_setup_gender'),
                            options = {
                                { value = 'male',   label = locale('cl_input_setup_gender_a') },
                                { value = 'female', label = locale('cl_input_setup_gender_b') }
                            }
                        }
                    })

                    if not dialog then return end

                    local setName = dialog[1] or 'Unnamed'
                    local setGender = nil

                    if not dialog[2] then
                        local genderNo = math.random(2)
                        if genderNo == 1 then
                            setGender = 'male'
                        elseif genderNo == 2 then
                            setGender = 'female'
                        end
                    else
                        setGender = dialog[2]
                    end

                    -- Trigger server event to buy pet
                    if setName and setGender then
                        local numericPrice = tonumber(price)
                        if not numericPrice then
                            lib.notify({ title = locale('cl_error_pet_no_active'), description = locale('cl_error_pet_price_invalid'), type = 'error', duration = 4000 })
                            return
                        end
                        if not stableid then
                            lib.notify({ title = locale('cl_error_pet_no_active'), description = locale('cl_error_stable_id_invalid'), type = 'error', duration = 4000 })
                            return
                        end
                        TriggerServerEvent('hdrp-pets:server:buy', numericPrice, npcpetmodel, stableid, setName, setGender, category)
                    else
                        return
                    end
                end,

                canInteract = function(_, distance)
                    return distance < 2.0
                end
            }
        })
    end
    return spawnedPetPed
end

-- Spawn Buy Pet NPCs
local function SpawnBuyPet()
    if not PetShopPrice then return end
    for k,v in pairs(PetShopPrice) do
        if not v or not v.npcpetcoords or not v.npcpetmodel then
            goto continue
        end 
        local petcoords = v.npcpetcoords
        -- Validate coordinates are valid before creating point
        if not petcoords or not petcoords.x or not petcoords.y or not petcoords.z then
            goto continue
        end
        local pointCoords = vec3(petcoords.x, petcoords.y, petcoords.z)
        local pointHeading = petcoords.w or 0.0
        local newpoint = lib.points.new({
            coords = pointCoords,
            heading = pointHeading,
            -- NPC Pet
            label = v.label,
            petcoords = petcoords,
            petheading = petcoords.w,
            petmodel = v.npcpetmodel,
            petprice = v.npcpetprice,
            category = v.type,
            petped = nil,
            -- Other
            distance = Config.DistanceSpawn,
            stableid = v.stableid
        })
        
        newpoint.onEnter = function(self)
            if not self.petped or not DoesEntityExist(self.petped) then
                -- Spawn with robust model handling inside NearBuyPetNPC
                self.petped = NearBuyPetNPC(self.petmodel, self.petcoords, self.petheading, self.stableid, self.petprice, self.category, self.label)
            end
        end

        newpoint.onExit = function(self)
            exports.ox_target:removeEntity(self.petped, 'npc_pet_input_buy')
            if self.petped and DoesEntityExist(self.petped) then
                if Config.FadeIn then
                    for i = 255, 0, -51 do
                        Wait(50)
                        SetEntityAlpha(self.petped, i, false)
                    end
                end
                SetEntityAsNoLongerNeeded(self.petped)  -- FIX v5.8.56: Memory leak prevention
                DeleteEntity(self.petped)
                self.petped = nil
            end
        end

        spawnedPaidPeds[k] = newpoint
        ::continue::
    end
end

-- Spawn vendor after a short delay to ensure everything is loaded
CreateThread(function()
    Wait(2000)  
    SpawnBuyPet()   
end)

-- Watchdog: cleanup invalid NPC references to avoid leaked handles
CreateThread(function()
    while true do
        local hasNPCs = next(spawnedPaidPeds) ~= nil
        local sleep = hasNPCs and 15000 or 60000
        Wait(sleep)
        for k, v in pairs(spawnedPaidPeds) do
            if v.petped and not DoesEntityExist(v.petped) then
                exports.ox_target:removeEntity(v.petped, 'npc_pet_input_buy')
                v.petped = nil
            end
        end
    end
end)

-- cleanup
AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    for k, v in pairs(spawnedPaidPeds) do
        exports.ox_target:removeEntity(v.petped, 'npc_pet_input_buy')
        if v.petped and DoesEntityExist(v.petped) then
            SetEntityAsNoLongerNeeded(v.petped)  -- FIX v5.8.56: Memory leak prevention
            DeleteEntity(v.petped)
        end
        spawnedPaidPeds[k] = nil
    end
    spawnedPaidPeds = {}
    -- print('^3[HDRP-AdvancedPets]^7 Cleaned up vendor resources')
end)

-- print('^2[HDRP-AdvancedPets]^7 Vendor client loaded!')
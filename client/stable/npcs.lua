local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()
local PetStableSettings = Config.PetStables
local BlipShop = Config.Blip.Shop
local spawnedPeds = {}
local petStablesBlip = nil

--  VENDOR NPC SYSTEM - PETS STABLES
CreateThread(function()
    if not PetStableSettings then return end
    for k,v in pairs(PetStableSettings) do
        if Config.EnablePrompts then
            -- exports['rsg-core']:createPrompt(v.id, v.coords, RSGCore.Shared.Keybinds[Config.KeyBind], locale('cl_menu_pet_shop'), {
            --     type = 'client',
            --     event = 'hdrp-pets:client:stablemenu',
            --     args = {v.stableid}
            -- })
        end
        -- Create blip
        if v.showblip then
            petStablesBlip = BlipAddForCoords(1664425300, v.coords)
            SetBlipSprite(petStablesBlip, joaat(BlipShop.blipSprite), true)
            SetBlipScale(petStablesBlip, BlipShop.blipScale)
            SetBlipName(petStablesBlip, BlipShop.blipName)
        end
    end
end)

-- NPC Human
local function NearNPC(npcmodel, npccoords, heading, stableid)
    -- Spawn NPC
    local spawnedPed = CreatePed(npcmodel, npccoords.x, npccoords.y, npccoords.z - 1.0, heading, false, false, 0, 0)
    SetEntityAlpha(spawnedPed, 0, false)
    SetRandomOutfitVariation(spawnedPed, true)
    SetEntityCanBeDamaged(spawnedPed, false)
    SetEntityInvincible(spawnedPed, true)
    FreezeEntityPosition(spawnedPed, true)
    SetBlockingOfNonTemporaryEvents(spawnedPed, true)
    SetPedCanBeTargetted(spawnedPed, false)
    -- Start scenario
    TaskStartScenarioInPlace(spawnedPed, 'WORLD_HUMAN_WRITE_NOTEBOOK', 0, true)
    -- Fade in
    if Config.FadeIn then
        for i = 0, 255, 51 do
            Wait(50)
            SetEntityAlpha(spawnedPed, i, false)
        end
    end
    -- Targeting
    if Config.EnableTarget then
        exports.ox_target:addLocalEntity(spawnedPed, {
            {
                name = 'npc_petstablehand',
                icon = 'far fa-eye',
                label = locale('cl_menu_pet_shop'),
                onSelect = function()
                    TriggerEvent('hdrp-pets:client:stablemenu', stableid)
                end,
                distance = 2.0
            }
        })
    end
    return spawnedPed
end

local function SpawnVendor()
    if not PetStableSettings then return end
    for k,v in pairs(PetStableSettings) do
        local coords = v.npccoords
        local petcoords = v.npcpetcoords
        local newpoint = lib.points.new({
            -- NPC Human
            coords = coords,
            heading = coords.w,
            model = v.npcmodel,
            ped = nil,
            -- Other
            distance = Config.DistanceSpawn,
            stableid = v.stableid
        })
        
        newpoint.onEnter = function(self)
            if not self.ped or not DoesEntityExist(self.ped) then
                local model = joaat(self.model)
                -- Request model using ox_lib
                lib.requestModel(self.model, 5000)
                self.ped = NearNPC(self.model, self.coords, self.heading, self.stableid)
                if not self.ped or not DoesEntityExist(self.ped) then
                    return
                end
            end
        end

        newpoint.onExit = function(self)
            exports.ox_target:removeEntity(self.ped, 'npc_petstablehand')
            if self.ped and DoesEntityExist(self.ped) then
                if Config.FadeIn then
                    for i = 255, 0, -51 do
                        Wait(50)
                        SetEntityAlpha(self.ped, i, false)
                    end
                end
                SetEntityAsNoLongerNeeded(self.ped)
                DeleteEntity(self.ped)
                self.ped = nil
            end
        end

        spawnedPeds[k] = newpoint
    end
end

-- Spawn vendor after a short delay to ensure everything is loaded
CreateThread(function()
    Wait(2000)  
    SpawnVendor()   
end)

-- cleanup
AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    for k, v in pairs(spawnedPeds) do
        exports.ox_target:removeEntity(v.ped, 'npc_petstablehand')
        if v.ped and DoesEntityExist(v.ped) then
            SetEntityAsNoLongerNeeded(v.ped)
            DeleteEntity(v.ped)
        end
        spawnedPeds[k] = nil
    end

    if petStablesBlip then
        RemoveBlip(petStablesBlip)
    end
    -- print('^3[HDRP-Advanced Pets]^7 Cleaned up vendor resources')
end)

-- print('^2[HDRP-Advanced Pets]^7 Vendor client loaded!')
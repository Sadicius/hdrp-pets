local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()
local State = exports['hdrp-pets']:GetState()
local entities = {}
local attachedProps = {}

-- Helpers de componentes y props
local M = lib.load('shared.stable.shop_helpers')

PetComponents_Clear = M.PetComponents_Clear
PetComponents_Merge = M.PetComponents_Merge
PetComponents_IsValid = M.PetComponents_IsValid
PetProps_Clear = M.PetProps_Clear
PetProps_Merge = M.PetProps_Merge
PetProps_IsValid = M.PetProps_IsValid

local Customize = false
local isCustom = false
local Camera = nil
local RotatePrompt = nil
local CustomizePrompt = GetRandomIntInRange(0, 0xffffff)
local CurrentPrice = 0
local closestStable = nil

MenuData = {}
TriggerEvent('rsg-menubase:getData', function(call)
    MenuData = call
end)

------------------------------------
-- menu horse components
------------------------------------
local function PromptCustom()
    local str
    str = VarString(10, 'LITERAL_STRING', locale('cl_custom_rotate_pet'))
    RotatePrompt = PromptRegisterBegin()
    PromptSetControlAction(RotatePrompt, Config.Prompt.Rotate[1])
    PromptSetControlAction(RotatePrompt, Config.Prompt.Rotate[2])
    PromptSetText(RotatePrompt, str)
    PromptSetEnabled(RotatePrompt, true)
    PromptSetVisible(RotatePrompt, true)
    PromptSetStandardMode(RotatePrompt, 1)
    PromptSetGroup(RotatePrompt, CustomizePrompt)
    PromptRegisterEnd(RotatePrompt)
end

local DisableCamera = function()
    RenderScriptCams(false, true, 1000, 1, 0)
    if Camera ~= nil and DoesCamExist(Camera) then
        DestroyCam(Camera, false)
        Camera = nil
    end
    DestroyAllCams(true)
    DisplayHud(true)
    DisplayRadar(true)
    Citizen.InvokeNative(0x4D51E59243281D80, PlayerId(), true, 0, false) -- ENABLE PLAYER CONTROLS
    Customize = false
    for k, v in pairs(entities) do
        TriggerServerEvent('hdrp-pets:server:setbucket', false, v.ped)
        if v.ped and DoesEntityExist(v.ped) then
            DeleteEntity(v.ped)
        end
        entities[k] = nil
    end
end

-- Comando de emergencia para restaurar cámara y bucket
RegisterCommand('pet_fixcustom', function()
    print('[hdrp-pets] Ejecutando fixcustom: restaurando cámara y bucket')
    DisableCamera()
end)

local function CameraPromptPet(pets)
    local promptLabel = locale('cl_custom_price') .. ' : $'
    local lightRange, lightIntensity = 15.0, 50.0
    local rotateLeft, rotateRight = Config.Prompt.Rotate[1], Config.Prompt.Rotate[2]

    CreateThread(function()
        PromptCustom()
        while Customize do
            Wait(0)

            local crds = GetEntityCoords(pets)
            DrawLightWithRange(crds.x - 5.0, crds.y - 5.0, crds.z + 1.0, 255, 255, 255, lightRange, lightIntensity)

            local label = VarString(10, 'LITERAL_STRING', promptLabel .. CurrentPrice)
            PromptSetActiveGroupThisFrame(CustomizePrompt, label)

            local heading = GetEntityHeading(pets)
            if IsControlPressed(2, rotateLeft) then
                SetEntityHeading(pets, heading - 1)
            elseif IsControlPressed(2, rotateRight) then
                SetEntityHeading(pets, heading + 1)
            end
        end
    end)
end

local function createCamera(ped, companionid)
    local Coords = GetOffsetFromEntityInWorldCoords(ped, 0, 1.5, 0)
    RenderScriptCams(false, false, 0, 1, 0)
    DestroyCam(Camera, false)
    if not DoesCamExist(Camera) then
        Camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamActive(Camera, true)
        RenderScriptCams(true, false, 3000, true, true)
        SetCamCoord(Camera, Coords.x, Coords.y, Coords.z + 0.5)
        SetCamRot(Camera, -15.0, 0.0, GetEntityHeading(ped) + 180)
        Customize = true
        CameraPromptPet(ped)

        TriggerEvent('hdrp-pets:client:menucustomize', ped, companionid)
        Citizen.InvokeNative(0x4D51E59243281D80, PlayerId(), false, 0, true) -- DISABLE PLAYER CONTROLS
        DisplayHud(false)
        DisplayRadar(false)
    end
end

RegisterNetEvent('hdrp-pets:client:custShop', function(data)
    local companionid = data.companionid
    local stableid = data.stableid
    if not companionid or not stableid then
        lib.notify({ title = locale('cl_error_menu_no_pets'), type = 'error', duration = 7000 })
        return
    end
    local petState = State and State.GetPet and State.GetPet(companionid) or nil
    if not petState or not petState.data or not petState.data.info then
        lib.notify({ title = locale('cl_error_menu_no_pets'), type = 'error', duration = 7000 })
        return
    end
    local foundStable = false
    for k, v in pairs(Config.PetStables) do
        if stableid == v.stableid then
            foundStable = true
            DoScreenFadeOut(0)
            repeat Wait(0) until IsScreenFadedOut()

            -- Leer modelo y customización visual desde State
            local customize = petState.customize or { custom = {}, props = {} }
            isCustom = true
            local companionData = petState.data
            local components = customize.custom or {}
            local xp = companionData.progression and companionData.progression.xp or 0
            local spawnCoords, spawnHeading
            if v.petcustom and type(v.petcustom) == "vector4" then
                spawnCoords = vector3(v.petcustom.x, v.petcustom.y, v.petcustom.z)
                spawnHeading = v.petcustom.w or 0.0
            else
                spawnCoords = v.petcustom
                spawnHeading = (v.petcustom and v.petcustom.w) or 0.0
            end
            local model = companionData.info.model
            local ped, blip = SpawnAnimal(
                companionid,
                companionData,
                components,
                xp,
                spawnCoords,
                spawnHeading,
                { petName = companionData.info.name or 'Unknown', model = model }
            )

            -- Aplicar props visuales si existen
            local props = customize.props or {}
            for category, value in pairs(props) do
                if value and value > 0 and Config.PetShopProps[category] then
                    local propData = Config.PetShopProps[category][value]
                    if propData then
                        AttachPropToPet(ped, propData)
                    end
                end
            end

            -- Eliminar cualquier entidad previa de la sesión de customización
            if entities[k] and entities[k].ped and DoesEntityExist(entities[k].ped) then
                DeleteEntity(entities[k].ped)
            end
            entities[k] = { ped = ped }
            TriggerServerEvent('hdrp-pets:server:setbucket', true, ped)
            TaskStandStill(ped, -1) -- Bloquear mascota en el sitio
            createCamera(ped, companionid)
            DoScreenFadeIn(1000)
            repeat Wait(0) until IsScreenFadedIn()
        end
    end
    if not foundStable then
        lib.notify({ title = locale('cl_error_menu_no_pets'), type = 'error', duration = 7000 })
    end
end)

------------------------------------
-- menu components rsg-menubase
------------------------------------
local function MainMenu(ped, companionid)
    MenuData.CloseAll()
    -- State.SetTargetedPet eliminado (ya no existe ni es necesario)
    local petState = State and State.GetPet and State.GetPet(companionid) or nil
    if not petState then return end
    petState.customize = petState.customize or { custom = {}, props = {} }
    local customize = petState.customize
    local initialCustom = table.copy(customize.custom)
    local initialProps = table.copy(customize.props)
    -- Aplicar componentes actuales a la mascota
    for category, value in pairs(customize.custom) do
        local hash = ManageSpawn.getComponentHash(category, value)
        if hash ~= 0 then
            Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, tonumber(hash), true, true, true)
        end
    end
    local elements = {
        { label = locale('cl_menu_pet_customization_component'), value = 'component' },
        { label = locale('cl_menu_pet_props_component'), value = 'props' },
        { label = locale('cl_customize_reset_label'), value = 'reset' },
        { label = locale('cl_menu_pet_customization_buy'),   value = 'buy', },
    }
    MenuData.Open('default', GetCurrentResourceName(), 'pet_menu_customization',
        {
            title = locale('cl_menu_pet_customization'),
            subtext = '',
            align = 'top-left',
            elements = elements,
            itemHeight = "4vh",
            onExit = function()
                isCustom = false
                DisableCamera()
            end
        }, function(data, menu)
            if data.current.value == 'component' then
                CustomPet(ped, companionid)
            elseif data.current.value == 'props' then
                OpenPetPropsMenu(ped, companionid)
            elseif data.current.value == 'reset' then
                petState.customize.custom = {}
                local componentsToSave = {
                    custom = {},
                    props = customize.props
                }
                TriggerServerEvent('hdrp-pets:server:savecomponent', componentsToSave, companionid, 0)
                lib.notify({ title = locale('cl_customize_reset'), type = 'success', duration = 3000 })
                MainMenu(ped, companionid)
            elseif data.current.value == 'buy' then
                local componentsToSave = {
                    custom = customize.custom,
                    props = customize.props
                }
                TriggerServerEvent('hdrp-pets:server:savecomponent', componentsToSave, companionid, CurrentPrice)
                isCustom = false
                DisableCamera()
                for hashid, obj in pairs(attachedProps) do
                    if DoesEntityExist(obj) then
                        DeleteObject(obj)
                    end
                    attachedProps[hashid] = nil
                end
                CurrentPrice = 0
                menu.close()
            end
        end,
        function(_, menu)
            isCustom = false
            DisableCamera()
            for hashid, obj in pairs(attachedProps) do
                if DoesEntityExist(obj) then
                    DeleteObject(obj)
                end
                attachedProps[hashid] = nil
            end
            CurrentPrice = 0
            menu.close()
            -- State.ClearTargetedPet eliminado (ya no existe ni es necesario)
        end)
end

function CustomPet(ped, companionid)
    local ManageSpawn = lib.load('client.stable.utils_spawn')
    MenuData.CloseAll()
    CurrentPrice = 0
    local petState = State and State.GetPet and State.GetPet(companionid) or nil
    if not petState then return end
    petState.customize = petState.customize or { custom = {}, props = {} }
    local customize = petState.customize
    local initialCustom = table.copy(customize.custom)
    local elements = {}
    for k, v in pairs(Config.PetShopComp) do
        local categoryHashes = {}
        for i, item in ipairs(v) do
            categoryHashes[i] = item.hash
            print('[DEBUG][CustomPet]  item', i, 'hash:', item.hash, 'label:', item.label or 'nil')
        end
        elements[#elements + 1] = {
            label = k,
            value = customize.custom[k] or 0,
            type = 'slider',
            min = 0,
            max = #v,
            category = k,
            hashes = categoryHashes,
            equipLabel = (customize.custom[k] or 0) > 0 and 'Desequipar' or 'Equipar',
        }
    end
    local resource = GetCurrentResourceName()
    MenuData.Open('default', resource, 'pet_menu_customization_components',
        {
            title    = locale('cl_menu_pet_customization'),
            subtext  = '',
            align    = 'top-left',
            elements = elements,
        }, function(data, _)
            if customize.custom[data.current.category] == data.current.value and data.current.value > 0 then
                customize.custom[data.current.category] = 0
                local hash = Config.ComponentHash[data.current.category]
                print('[DEBUG][CustomPet] Hash para limpiar:', hash, 'Tipo:', type(hash))
                if hash then
                    print('[DEBUG][CustomPet] Modelo de la mascota:', GetEntityModel(ped), 'Esperado:', GetHashKey(State.GetPet(companionid).companion))
                    Citizen.InvokeNative(0xD710A5007C2AC539, ped, hash, 0)
                    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, 0)
                    ManageSpawn.UpdatePedVariation(ped)
                end
            else
                local isValid = PetComponents_IsValid(data.current.category, data.current.value)
                if isValid then
                    customize.custom[data.current.category] = data.current.value
                    if data.current.value > 0 then
                        local currentHash = data.current.hashes[data.current.value]
                        print('[DEBUG][CustomPet] Aplicando hash:', currentHash, 'Tipo:', type(currentHash), 'a entidad:', ped)
                        print('[DEBUG][CustomPet] Modelo de la mascota:', GetEntityModel(ped), 'Esperado:', GetHashKey(State.GetPet(companionid).companion))
                        print('[DEBUG][Native] Llamando a 0xD3A7B003ED343FD9 con hash:', currentHash, 'entidad:', ped)
                        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, tonumber(currentHash), true, true, true)
                        ManageSpawn.UpdatePedVariation(ped)
                    end
                else
                    print('[DEBUG][CustomPet] Valor no válido:', data.current.category, data.current.value)
                end
            end
            local newPrice = M.CalculatePrice(customize.custom, initialCustom)
            print('[DEBUG][CustomPet] Precio nuevo:', newPrice, 'Precio actual:', CurrentPrice)
            if CurrentPrice ~= newPrice then
                CurrentPrice = newPrice
            end
        end,
        function(_, menu)
            MainMenu(ped, companionid)
        end)
end

-- Atacha un prop a un hueso del ped
function AttachPropToPet(petEntity, propData)

    if not petEntity or not propData or not propData.model or not propData.bone then return end

    -- Elimina prop anterior si existe para este hashid
    if attachedProps[propData.hashid] and DoesEntityExist(attachedProps[propData.hashid]) then
        DeleteObject(attachedProps[propData.hashid])
        attachedProps[propData.hashid] = nil
    end

    local modelHash = GetHashKey(propData.model)
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do Wait(10) end
    local propObj = CreateObject(modelHash, 0.0, 0.0, 0.0, true, true, false, false, false)

    -- Buscar el bone index
    local boneIndex = GetPedBoneIndex(petEntity, GetHashKey(propData.bone))
    local boneCoords = GetWorldPositionOfEntityBone(petEntity, boneIndex)
    local offset = GetObjectOffsetFromCoords(boneCoords.x, boneCoords.y, boneCoords.z, heading,0.0,0.15,0.0)
    -- Atachar con offsets
    -- Helper para imprimir hueso y dimensiones
    local min, max = GetModelDimensions(modelHash)
    print('[DEBUG][AttachPropToPet] Modelo:', propData.model, 'Hash:', modelHash)
    print('[DEBUG][AttachPropToPet] Dimensiones min:', min, 'max:', max)
    print('[DEBUG][BonePet] Bone:', propData.bone, 'Index:', boneIndex, 'Coords:', boneCoords, 'Offset:', offset)

    AttachEntityToEntity(propObj, petEntity, boneIndex,
        (offset.x or propData.offset.x or 0.0), (offset.y or propData.offset.y or 0.0), (offset.z or propData.offset.z or 0.0),
        (propData.offset.pitch or 0.0), (propData.offset.roll or 0.0), (propData.offset.yaw or 0.0),
        false, false, false, false, 2, true)
    SetModelAsNoLongerNeeded(modelHash)
    attachedProps[propData.hashid] = propObj
end

function OpenPetPropsMenu(ped, companionid)
    local ManageSpawn = lib.load('client.stable.utils_spawn')
    MenuData.CloseAll()
    CurrentPrice = 0
    local petState = State and State.GetPet and State.GetPet(companionid) or nil
    if not petState then return end
    petState.customize = petState.customize or { custom = {}, props = {} }
    local customize = petState.customize
    local initialProps = table.copy(customize.props)
    local elements = {}
    for k, v in pairs(Config.PetShopProps) do
        local categoryHashes = {}
        for i, item in ipairs(v) do
            categoryHashes[i] = item.hash
        end
        elements[#elements + 1] = {
            label = k,
            value = customize.props[k] or 0,
            type = 'slider',
            min = 0,
            max = #v,
            category = k,
            hashes = categoryHashes,
            equipLabel = (customize.props[k] or 0) > 0 and 'Desequipar' or 'Equipar',
        }
    end
    local resource = GetCurrentResourceName()
    MenuData.Open('default', resource, 'pet_menu_customization_props',
        {
            title    = locale('cl_menu_pet_props_customize'),
            subtext  = '',
            align    = 'top-left',
            elements = elements,
        }, function(data, _)
            if data.current.value == 0 then
                customize.props[data.current.category] = 0
                local propList = Config.PetShopProps[data.current.category]
                if propList then
                    for i, propData in ipairs(propList) do
                        if propData and attachedProps[propData.hashid] and DoesEntityExist(attachedProps[propData.hashid]) then
                            DeleteObject(attachedProps[propData.hashid])
                            attachedProps[propData.hashid] = nil
                        end
                    end
                end
            else
                if PetProps_IsValid(data.current.category, data.current.value) then
                    local propList = Config.PetShopProps[data.current.category]
                    if propList then
                        for i, propData in ipairs(propList) do
                            if propData and attachedProps[propData.hashid] and DoesEntityExist(attachedProps[propData.hashid]) then
                                DeleteObject(attachedProps[propData.hashid])
                                attachedProps[propData.hashid] = nil
                            end
                        end
                    end
                    customize.props[data.current.category] = data.current.value
                    if data.current.value > 0 then
                        local propData = propList and propList[data.current.value]
                        if propData then
                            print('[DEBUG][OpenPetPropsMenu] Atachando prop manualmente:', propData.model, 'a bone:', propData.bone)
                            AttachPropToPet(ped, propData)
                        end
                    end
                else
                    lib.notify({ title = locale('cl_customize_error'), type = 'error', duration = 3000 })
                end
            end
            local newPrice = M.CalculatePrice(customize.props, initialProps)
            if CurrentPrice ~= newPrice then
                CurrentPrice = newPrice
            end
        end,
        function(_, menu)
            MainMenu(ped, companionid)
        end)
end

-- Helper function to create a deep copy of a table
function table.copy(t)
    local u = {}
    for k, v in pairs(t) do
        u[k] = type(v) == "table" and table.copy(v) or v
    end
    return setmetatable(u, getmetatable(t))
end

RegisterNetEvent('hdrp-pets:client:menucustomize', function(ped, companionid)
    MainMenu(ped, companionid)
end)

-- Comando para equipar todos los componentes de customización
RegisterCommand('petcustom_equipall', function(source, args)
    local companionid = args[1]
    if not companionid then
        local petData, _, closestId = State.GetClosestPet()
        if closestId then
            companionid = closestId
            print('[hdrp-pets] Usando mascota más cercana: '..companionid)
        else
            print('[hdrp-pets] Debes especificar el companionid o tener una mascota cerca. Uso: /petcustom_equipall <companionid>')
            return
        end
    end
    local petState = State and State.GetPet and State.GetPet(companionid) or nil
    if not petState then return end
    petState.customize = petState.customize or { custom = {}, props = {} }
    for k, v in pairs(Config.PetShopComp) do
        local maxValue = #v
        if PetComponents_IsValid(k, maxValue) then
            petState.customize.custom[k] = maxValue
        else
            petState.customize.custom[k] = 0
        end
    end
    local componentsToSave = {
        custom = petState.customize.custom,
        props = petState.customize.props
    }
    TriggerServerEvent('hdrp-pets:server:savecomponent', componentsToSave, companionid, 0)
    print('[hdrp-pets] Todos los componentes equipados para ' .. companionid)
end)

RegisterCommand('pet_custom_reset', function(source, args)
    local companionid = args[1]
    if not companionid then
        local petData, _, closestId = State.GetClosestPet()
        if closestId then
            companionid = closestId
            print('[hdrp-pets] Usando mascota más cercana: '..companionid)
        else
            print('[hdrp-pets] Debes especificar el companionid o tener una mascota cerca. Uso: /pet_custom_reset <companionid>')
            return
        end
    end
    local petState = State and State.GetPet and State.GetPet(companionid) or nil
    if not petState then return end
    petState.customize = { custom = {}, props = {} }
    local componentsToSave = {
        custom = {},
        props = {}
    }
    TriggerServerEvent('hdrp-pets:server:savecomponent', componentsToSave, companionid, 0)
    print('[hdrp-pets] Todos los componentes de customización han sido quitados para ' .. companionid)
end)

-- Limpieza al parar recurso
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    -- Eliminar entidades de customización
    for k, v in pairs(entities) do
        if v.ped and DoesEntityExist(v.ped) then
            DeleteEntity(v.ped)
        end
        entities[k] = nil
    end
    -- Eliminar props atachados
    for hashid, obj in pairs(attachedProps) do
        if DoesEntityExist(obj) then
            DeleteObject(obj)
        end
        attachedProps[hashid] = nil
    end
    -- Restaurar cámara si es necesario
    if Camera ~= nil and DoesCamExist(Camera) then
        DestroyCam(Camera, false)
        Camera = nil
    end
    DestroyAllCams(true)
    DisplayHud(true)
    DisplayRadar(true)
    Customize = false
end)
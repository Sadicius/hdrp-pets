local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()
local Database = lib.load('server.core.database')
local PetShopPrice = Config.PetShopPrice

-- Estructura de datos para reproducción (añadir a cada mascota):
-- pet.pregnant: bool
-- pet.gestationStart: timestamp
-- pet.gestationPeriod: segundos
-- pet.breedingCooldown: timestamp
-- HDRP-PETS: Sistema de reproducción de mascotas (Server)
-- Autor: Adaptado de rex-ranch
-- Este archivo gestiona la lógica principal de reproducción en el servidor
-- Callback para consultar genealogía por offspring_id


-- Función para validar si una mascota puede reproducirse
local function CanBreed(pet)
    if not pet then return false end
    if (pet.stats and pet.stats.age) < Config.Reproduction.MinAgeForBreeding then return false end
    if (pet.stats and pet.stats.age) > Config.Reproduction.MaxBreedingAge then return false end
    if (pet.stats and pet.stats.health) < Config.Reproduction.RequiredHealth then return false end
    if (pet.veterinary and pet.veterinary.inbreed) then return false end
    if (pet.veterinary and pet.veterinary.breedingcooldown) and pet.veterinary.breedingcooldown > os.time() then return false end
    return true
end

RegisterNetEvent('hdrp-pets:server:requestbreeding', function(petAId, petBId)
    local src = source
    local petA = Database.GetCompanionByCompanionId(petAId)
    local petB = Database.GetCompanionByCompanionId(petBId)
    if not petA or not petB then return end

    petA.data = type(petA.data) == 'string' and json.decode(petA.data) or {}
    petB.data = type(petB.data) == 'string' and json.decode(petB.data) or {}

    if not petA.data.info or not petB.data.info then return end
    if petA.data.info.gender == petB.data.info.gender then return end
    if not CanBreed(petA.data) or not CanBreed(petB.data) then return end

    -- Inicia gestación en la mascota hembra
    local femaleId = petA.data.info.gender == 'female' and petAId or petBId
    local female = Database.GetCompanionByCompanionId(femaleId)
    female.data = type(female.data) == 'string' and json.decode(female.data) or {}

    TriggerClientEvent('ox_lib:notify', src, { title = locale('cl_breed_started_title'), description = locale('cl_breed_started_desc'), type = 'info', duration = 6000 })

    female.data.veterinary.inbreed = true
    female.data.veterinary.gestationstart = os.time()
    female.data.veterinary.gestationperiod = Config.Reproduction.GestationPeriod

    -- Aplica cooldown a ambos
    petA.data.veterinary.breedingcooldown = os.time() + Config.Reproduction.CooldownMale
    petB.data.veterinary.breedingcooldown = os.time() + Config.Reproduction.CooldownFemale

    -- Persistencia en base de datos
    Database.UpdateCompanionData(petAId, petA.data)
    Database.UpdateCompanionData(petBId, petB.data)
    Database.UpdateCompanionData(femaleId, female.data)

    -- Notifica al cliente
    TriggerClientEvent('hdrp-pets:client:breedingstarted', src, petAId, petBId)
end)

-- Obtener los skins posibles de ambos modelos
local function getSkinsForModel(model)
    if not PetShopPrice or type(PetShopPrice) ~= 'table' then return {} end
    for _, v in ipairs(PetShopPrice) do
        if v.npcpetmodel == model and v.skins and #v.skins > 0 then
            return v.skins
        end
    end
    return {}
end

-- Recibe ambos padres: petA y petB
local function snapshotOffspring(petA, petB)
    local breedable = {true, false}
    local randomIndex1 = math.random(1, #breedable)
    -- Elegir aleatoriamente el modelo de la cría (padre o madre)
    local parentModels = {petA.data.info.model, petB.data.info.model}
    local chosenModelIndex = math.random(1, 2)
    local chosenModel = parentModels[chosenModelIndex]
    local skinsA = getSkinsForModel(petA.data.info.model)
    local skinsB = getSkinsForModel(petB.data.info.model)
    -- Unir ambos arrays de skins, evitando duplicados
    local allSkins = {}
    local seen = {}
    for _, s in ipairs(skinsA) do seen[s] = true; table.insert(allSkins, s) end
    for _, s in ipairs(skinsB) do if not seen[s] then table.insert(allSkins, s) end end
    -- Elegir skin aleatorio de la lista combinada
    local skin = 0
    if #allSkins > 0 then skin = allSkins[math.random(#allSkins)] end

    local offspring = {
        id = tostring(os.time()) .. Database.GenerateCompanionId(),

        info = {
            name    = ((chosenModelIndex == 1 and petA.data.info.name) or petB.data.info.name) .. ' Jr.',
            model   = chosenModel,
            skin    = skin or 0,
            gender  = math.random(1,2) == 1 and 'male' or 'female',
            type    = ((chosenModelIndex == 1 and petA.data.info.type) or petB.data.info.type),
            born    = os.time(),
        },

        stats = {
            hunger      = Config.PetAttributes.Starting.Hunger or 100,
            thirst      = Config.PetAttributes.Starting.Thirst or 100,
            happiness   = Config.PetAttributes.Starting.Happiness or 100,
            dirt        = 100,
            strength    = Config.PetAttributes.Starting.Strength or 100,
            health      = Config.PetAttributes.Starting.Health or 100,
            age         = 1.0,
            scale       = 0.5
        },

        progression = {
            xp      = 0.0,
            level   = 1,
            bonding = 0,
        },

        veterinary = {
            dead            = false,
            hasdisease      = false,
            diseasetype     = nil,
            diseaseddate    = nil,
            
            isvaccinated    = false,
            vaccineexpire   = nil,
            vaccinationdate = nil,
            
            lastcheckup     = nil,
            daysatcheckup   = 0,
            dayssincecheckup = 0,
            
            lastsurgery     = nil,
            daysatsurgery   = 0,
            dayssincesurgery = 0,

            breedable               = breedable[randomIndex1],
            sterilizationdate       = nil,
            daysatsterilization     = 0,
            dayssincesterilization  = 0,
            
            inbreed                 = false,
            breedingcooldown        = nil,
            gestationstart          = nil,
            gestationperiod         = nil
        },

        personality = {
            wild = false,
            type = nil,
            progress = 0
        },

        genealogy = {
            parents = nil,
            offspring = {}
        },

        history = {},
        version= 1
    }

    return offspring
end

local function loopGestation()
    for companionid, pet in ipairs(Database.GetAllActiveCompanions()) do
        if (pet.data and pet.data.veterinary and pet.data.veterinary.inbreed) and pet.data.veterinary.gestationstart and pet.data.veterinary.gestationperiod then
            local elapsed = os.time() - pet.data.veterinary.gestationstart
            if elapsed >= pet.data.veterinary.gestationperiod then
                -- Buscar padres (padre y madre) para snapshot de genealogía
                local parentA, parentB = pet, pet -- fallback por defecto
                local foundA, foundB = nil, nil
                local allactive = Database.GetAllActiveCompanions()
                for id, candidate in pairs(allactive) do
                    if id ~= companionid and (candidate.data and candidate.data.veterinary and candidate.data.veterinary.breedable) == true and (pet.data and pet.data.veterinary and pet.data.veterinary.breedable) == true and (candidate.data.info and candidate.data.info.gender) ~= (pet.data.info and pet.data.info.gender) and candidate.data.veterinary.gestationstart == pet.data.veterinary.gestationstart then
                        if (candidate.data and candidate.data.veterinary and candidate.data.veterinary.breedable) == false or (candidate.data and candidate.data.veterinary and candidate.data.veterinary.breedable) == nil then
                            if (pet.data and pet.data.info and pet.data.info.gender) == 'female' then
                                foundA = pet
                                foundB = candidate
                            else
                                foundA = candidate
                                foundB = pet
                            end
                            break
                        end
                    end
                end
                if foundA and foundB then parentA, parentB = foundA, foundB end

                -- Estructura de datos para la cría
                local offspring = snapshotOffspring(parentA, parentB)
                -- Persistir la nueva cría correctamente en SQL (igual que compra)
                local citizenid = pet.citizenid or nil
                if citizenid then
                    local stable = pet.stable or 'valentine'
                    local active = true

                    -- Comprobar límite de mascotas activas
                    local maxActive = Config.MaxActivePets or 2
                    local currentActive = Database.CountActiveCompanions(citizenid)
                    if currentActive >= maxActive then
                        active = false
                        TriggerClientEvent('ox_lib:notify', -1, { title = locale('cl_breed_born_title'), description = locale('cl_breed_born_descripton') .. ' ' .. locale('cl_breed_no_active_slot', maxActive), type = 'info', duration = 8000})
                    end
                    Database.InsertCompanion({
                        stable = stable,
                        citizenid = citizenid,
                        companionid = offspring.id,
                        data = json.encode(offspring),
                        active = active
                    })

                    -- Preparar snapshot de padres
                    local function snapshotParent(pet)
                        return json.encode({
                            id = (pet.data and pet.data.id) or pet.companionid,
                            info = (pet.data and pet.data.info) or {},
                            progression = (pet.data and pet.data.progression) or {},
                            veterinary = (pet.data and pet.data.veterinary) or {}
                        })
                    end

                    -- Guardar genealogía en pet_breeding (tabla unificada)
                    if Database.AddOffspringGenealogy then
                        local parentAData = {
                            name = (parentA.data and parentA.data.info and parentA.data.info.name) or 'Unknown',
                            breed = (parentA.data and parentA.data.info and parentA.data.info.type) or 'Unknown',
                            gender = (parentA.data and parentA.data.info and parentA.data.info.gender) or 'unknown',
                            level = (parentA.data and parentA.data.progression and parentA.data.progression.level) or 1,
                            bond = (parentA.data and parentA.data.progression and parentA.data.progression.bonding) or 0,
                            hasdisease = (parentA.data and parentA.data.veterinary and parentA.data.veterinary.hasdisease) or false
                        }
                        local parentBData = {
                            name = (parentB.data and parentB.data.info and parentB.data.info.name) or 'Unknown',
                            breed = (parentB.data and parentB.data.info and parentB.data.info.type) or 'Unknown',
                            gender = (parentB.data and parentB.data.info and parentB.data.info.gender) or 'unknown',
                            level = (parentB.data and parentB.data.progression and parentB.data.progression.level) or 1,
                            bond = (parentB.data and parentB.data.progression and parentB.data.progression.bonding) or 0,
                            hasdisease = (parentB.data and parentB.data.veterinary and parentB.data.veterinary.hasdisease) or false
                        }
                        Database.AddOffspringGenealogy(citizenid, {
                            petid = offspring.id,
                            companionid = offspring.id,
                            parent_a = (parentA.data and parentA.data.id) or parentA.companionid,
                            parent_b = (parentB.data and parentB.data.id) or parentB.companionid,
                            parent_a_data = parentAData,
                            parent_b_data = parentBData,
                            date = os.time()
                        })
                    end

                else
                    if Config.Debug then print('^1[BREEDING ERROR]^7 No se pudo determinar el dueño (citizenid) para la cría, no se insertó en SQL.') end
                end

                -- Limpia estado de gestación
                pet.data.veterinary.inbreed = false
                pet.data.veterinary.gestationstart = nil
                pet.data.veterinary.gestationperiod = nil

                Database.UpdateCompanionData((pet.data and pet.data.id) or companionid, pet.data)
                TriggerClientEvent('hdrp-pets:client:newoffspring', -1, offspring.companionid, offspring)
            end
        end
    end
end

CreateThread(function()
    while true do
        Wait(60000) -- cada minuto
        loopGestation()
    end
end)
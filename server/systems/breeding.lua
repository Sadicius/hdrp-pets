local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()
local Database = lib.load('server.core.database')

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

    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('cl_breed_started_title'),
        description = locale('cl_breed_started_desc'),
        type = 'info',
        duration = 6000
    })

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
    -- TriggerClientEvent('hdrp-pets:client:updateanimals', src, petAId, petA.data)
    -- TriggerClientEvent('hdrp-pets:client:updateanimals', src, petBId, petB.data)
    -- TriggerClientEvent('hdrp-pets:client:updateanimals', src, femaleId, female.data)

    -- Notifica al cliente
    TriggerClientEvent('hdrp-pets:client:breedingstarted', src, petAId, petBId)
end)

local function snapshotOffspring(pet)
    local breedable = {true, false}
    local randomIndex1 = math.random(1, #breedable)

    local offspring = {
        id = tostring(os.time()) .. Database.GenerateCompanionId(),                -- ID único de la mascota

        info = {
            -- stable  = stable or "valentine",                         -- Localizacion del establo  -- duda aquí // merece la pena modificar por la columna stable
            name    = (pet.data.info.name .. ' Jr.') or nil,                   -- Nombre personalizado
            model   = pet.data.info.model or nil,                            -- Modelo o especie
            skin    = math.floor(math.random(0, 2)) or 0,                                        -- Skin/variante visual
            gender  = math.random(0,1) == 0 and 'male' or 'female',                   -- Género
            type    = pet.data.info.type or nil,                             -- Tipo o raza
            born    = os.time(),                                        -- Fecha de nacimiento (timestamp)
        },

        stats = {
            hunger      = Config.PetAttributes.Starting.Hunger or 100,      -- Hambre (0-100)
            thirst      = Config.PetAttributes.Starting.Thirst or 100,      -- Sed (0-100)
            happiness   = Config.PetAttributes.Starting.Happiness or 100,   -- Felicidad (0-100)
            dirt        = 100,        -- Suciedad (0-100)
            strength    = Config.PetAttributes.Starting.Strength or 100,    -- Fortaleza (0-100)
            health      = Config.PetAttributes.Starting.Health or 100,      -- Salud actual
            age         = 1.0,                                              -- Edad en días
            scale       = 0.5                                               -- Escala visual
        },

        progression = {
            xp      = 0.0,  -- Experiencia total
            level   = 1,    -- Nivel calculado
            bonding = 0,    -- Nivel de vínculo
        },

        veterinary = {
            dead            = false,                    -- Estado de vida
            hasdisease      = false,                    -- Enfermedad activa
            diseasetype     = nil,                      -- Tipo de enfermedad
            diseaseddate    = nil,                      -- Fecha de diagnóstico
            
            isvaccinated    = false,                    -- Estado de vacunación
            vaccineexpire   = nil,                      -- Fecha de expiración de vacuna
            vaccinationdate = nil,                      -- Fecha de vacunación
            
            lastcheckup     = nil,                      -- Último chequeo veterinario
            daysatcheckup   = 0,                        -- Días transcurridos desde el último chequeo
            dayssincecheckup = 0,                       -- Días transcurridos desde el último chequeo
            
            lastsurgery     = nil,                      -- Fecha de la última cirugía
            daysatsurgery   = 0,                        -- Días transcurridos desde la última cirugía
            dayssincesurgery = 0,                       -- Días transcurridos desde la última cirugía

            breedable               = breedable[randomIndex1],  -- Puede reproducirse. Se sustituye "No" por false,
            sterilizationdate       = nil,                  -- Fecha de esterilización
            daysatsterilization     = 0,                    -- Días desde esterilización
            dayssincesterilization  = 0,                   -- Días desde esterilización
            
            inbreed                 = false,                    -- Esta preñada. Se sustituye "No" por false
            breedingcooldown        = nil,                  -- Fecha de cooldown de reproducción
            gestationstart          = nil,                      -- Fecha de inicio de gestación
            gestationperiod         = nil                       -- Periodo de gestación en segundos
        },

        personality = {
            wild = false,       -- Si es salvaje o domesticado
            type = nil,         -- Tipo de personalidad
            progress = 0        -- Progreso de personalidad
        },

        genealogy = {
            parents = nil,   -- Se asignará justo después de identificar a los padres
            offspring = {}  -- IDs de descendencia
        },

        history = {},  -- Historial de eventos relevantes
        version= 1     -- VERSION de la estructura
    }

    return offspring
end

-- Preparar snapshot de padres
--[[ 
local function snapshotParent(pet)
    local offspring = {
        id = pet.id,                -- ID único de la mascota

        info = {
            -- stable  = stable or "valentine",        -- Localizacion del establo  -- duda aquí // merece la pena modificar por la columna stable
            name    = pet.info.name or nil,            -- Nombre personalizado
            model   = pet.info.model or nil,           -- Modelo o especie
            skin    = pet.info.skin or 0,              -- Skin/variante visual
            gender  = pet.info.gender,                 -- Género
            type    = pet.info.type or nil,            -- Tipo o raza
            born    = pet.info.born,                   -- Fecha de nacimiento (timestamp)
        },

        progression = {
            xp      = pet.progression.xp,       -- Experiencia total
            level   = pet.progression.level,    -- Nivel calculado
            bonding = pet.progression.bonding,  -- Nivel de vínculo
        },

        veterinary = {
            breedable               = pet.veterinary.breedable,  -- Puede reproducirse. Se sustituye "No" por false,
            inbreed                 = pet.veterinary.inbreed,    -- Esta preñada. Se sustituye "No" por false
        },
    }
    return offspring
end

local function selectParent(pet)
    for id, candidate in pairs(Database.GetAllActiveCompanions()) do
        if id ~= companionid and candidate.veterinary.breedable == pet.veterinary.breedable and candidate.info.gender ~= pet.info.gender and candidate.veterinary.gestationstart == pet.veterinary.gestationstart then
            if candidate.veterinary.inbreed == false or candidate.veterinary.inbreed == nil then
                if pet.info.gender == 'female' then
                    parentA = pet
                    parentB = candidate
                else
                    parentA = candidate
                    parentB = pet
                end
                break
            end
        end
    end
    return parentA, parentB
end 
]]

local function loopGestation()
    for companionid, pet in ipairs(Database.GetAllActiveCompanions()) do
        if (pet.data and pet.data.veterinary and pet.data.veterinary.inbreed) and pet.data.veterinary.gestationstart and pet.data.veterinary.gestationperiod then
            local elapsed = os.time() - pet.data.veterinary.gestationstart
            if elapsed >= pet.data.veterinary.gestationperiod then
                -- Estructura de datos para la cría
                local offspring = snapshotOffspring(pet)
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
                        TriggerClientEvent('ox_lib:notify', -1, {
                            title = locale('cl_breed_born_title'),
                            description = locale('cl_breed_born_descripton') .. ' ' .. locale('cl_breed_no_active_slot', maxActive),
                            type = 'info',
                            duration = 8000
                        })
                    end
                    Database.InsertCompanion({
                        stable = stable,
                        citizenid = citizenid,
                        companionid = offspring.id,
                        data = json.encode(offspring),
                        active = active
                    })

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
                -- TriggerClientEvent('hdrp-pets:client:updateanimals', src, (pet.data and pet.data.id) or companionid, pet.data)

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
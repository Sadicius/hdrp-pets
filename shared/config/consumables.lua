--[[
    HDRP-PETS CONFIGURATION - CONSUMABLES & FEED ITEMS
    Sistema de items consumibles para mascotas
    Versión: 5.8.51+
    
    FIX: Este archivo faltaba en la configuración original
]]

return {
    -- Distancia máxima para alimentar (no medicina)
    DistanceFeed = 5.0,
    
    -- FIX v5.8.57: Valores por defecto para items legacy (CONFIG LEGACY - usar Config.PetFeed para nuevos items)
    DefaultValues = {
        Hunger = 15,      -- Valor por defecto de hambre
        Thirst = 15,      -- Valor por defecto de sed
        Happiness = 10,   -- Valor por defecto de felicidad
        Strength = 10,    -- Valor por defecto de fuerza
        Brushdirt = 20    -- Valor de limpieza del cepillo (dirt reduction)
    },
    
    -- Configuración de items de comida/medicina
    Items = {
        -- COMIDA BÁSICA
        ['pet_feed'] = {
            ismedicine = false,
            health = 10,
            hunger = 10,
            thirst = 0,
            happiness = 5,
            strength = 0,
            ModelHash = `s_dogbowl01x`,
            label = 'Pet Feed'
        },
        
        ['raw_meat'] = {
            ismedicine = false,
            health = 5,
            hunger = 15,
            thirst = 0,
            happiness = 10,
            strength = 0,
            ModelHash = nil,
            label = 'Raw Meat'
        },
        
        -- CARNES ESPECÍFICAS
        ['venison'] = {
            ismedicine = false,
            health = 8,
            hunger = 18,
            thirst = 5,
            happiness = 12,
            strength = 0,
            ModelHash = nil,
            label = 'Venison'
        },
        
        ['rabbit_meat'] = {
            ismedicine = false,
            health = 5,
            hunger = 12,
            thirst = 0,
            happiness = 8,
            strength = 0,
            ModelHash = nil,
            label = 'Rabbit Meat'
        },
        
        ['poultry'] = {
            ismedicine = false,
            health = 6,
            hunger = 14,
            thirst = 0,
            happiness = 10,
            strength = 0,
            ModelHash = nil,
            label = 'Poultry'
        },
        
        ['mutton'] = {
            ismedicine = false,
            health = 7,
            hunger = 16,
            thirst = 5,
            happiness = 11,
            strength = 0,
            ModelHash = nil,
            label = 'Mutton'
        },
        
        ['rat_meat'] = {
            ismedicine = false,
            health = 3,
            hunger = 8,
            thirst = 0,
            happiness = 3,
            strength = 0,
            ModelHash = nil,
            label = 'Rat Meat'
        },
        
        ['squirrel_meat'] = {
            ismedicine = false,
            health = 4,
            hunger = 10,
            thirst = 0,
            happiness = 6,
            strength = 0,
            ModelHash = nil,
            label = 'Squirrel Meat'
        },
        
        ['boar_meat'] = {
            ismedicine = false,
            health = 8,
            hunger = 18,
            thirst = 5,
            happiness = 12,
            strength = 0,
            ModelHash = nil,
            label = 'Boar Meat'
        },
        
        ['predator_meat'] = {
            ismedicine = false,
            health = 10,
            hunger = 20,
            thirst = 10,
            happiness = 15,
            strength = 0,
            ModelHash = nil,
            label = 'Predator Meat'
        },
        
        ['duck_meat'] = {
            ismedicine = false,
            health = 6,
            hunger = 13,
            thirst = 0,
            happiness = 9,
            strength = 0,
            ModelHash = nil,
            label = 'Duck Meat'
        },
        
        ['small_bird_meat'] = {
            ismedicine = false,
            health = 4,
            hunger = 9,
            thirst = 0,
            happiness = 7,
            strength = 0,
            ModelHash = nil,
            label = 'Small Bird Meat'
        },
        
        -- AGUA
        ['pet_water'] = {
            ismedicine = false,
            health = 0,
            hunger = 0,
            thirst = 15,
            happiness = 5,
            strength = 0,
            ModelHash = nil,
            label = 'Pet Water'
        },
        
        ['water'] = {
            ismedicine = false,
            health = 0,
            hunger = 0,
            thirst = 10,
            happiness = 5,
            strength = 0,
            ModelHash = nil,
            label = 'Water'
        },
        
        -- FELICIDAD
        ['sugarcube'] = {
            ismedicine = false,
            health = 0,
            hunger = 5,
            thirst = 5,
            happiness = 15,
            strength = 0,
            ModelHash = `p_sugarcube01x`,
            label = 'Sugar Cube'
        },
        
        -- MEDICINAS / ESTIMULANTES
        ['pet_stimulant'] = {
            ismedicine = true,
            health = 20,
            hunger = 0,
            thirst = 0,
            happiness = 5,
            strength = 50,
            medicineModelHash = `p_cs_syringe01x`,
            label = 'Pet Stimulant'
        },
        
        ['pet_reviver'] = {
            ismedicine = true,
            health = 100,
            hunger = 50,
            thirst = 50,
            happiness = 50,
            strength = 50,
            medicineModelHash = `p_cs_syringe01x`,
            revive = true,
            label = 'Pet Reviver'
        },
        
        -- LIMPIEZA
        ['pet_brush'] = {
            ismedicine = false,
            health = 0,
            hunger = 0,
            thirst = 0,
            happiness = 10,
            strength = 0,
            dirt = 100,  -- Limpia +100 dirt
            ModelHash = `p_brushhorse02x`,
            label = 'Pet Brush'
        }
    }
}

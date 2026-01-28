--[[
    HDRP-PETS CONFIGURATION - BLIPS
    Configuración centralizada de todos los marcadores en el mapa
    Versión: 5.8.2+
    
    Includes:
    - Pet shop/stable blips
    - Dead pet blips
    - Tracking blips
    - Color modifiers
]]

lib.locale()

return {
    Pet = {    -- PLAYER'S PET BLIP
        blipSprite = `blip_ambient_companion`,       -- Hash: 1621137324
        blipScale  = 0.2,
    },
    Shop = {    -- PET SHOP / STABLE BLIPS
        ShowBlip   = true,
        blipName   = locale('ui_blip_shop'),
        blipSprite = `blip_shop_store`,     -- Hash: 1475879922
        blipScale  = 0.2,
    },
    Dead = {    -- DEAD PET BLIP
        blipName   = 'Dead',
        blipSprite = `blip_ambient_death`,  -- Hash: 350569997
        blipScale  = 0.2,
        blipTime   = 5 * 60 * 1000,         -- 5 minutes until blip auto-deletes
    },
    Track = {    -- TRACKING / TARGET BLIP
        blipName   = 'Target',
        blipSprite = `blip_code_waypoint`,  -- Hash: 960467426
        blipScale  = 0.2,
        blipTime   = 1 * 60 * 1000,         -- 1 minute until blip auto-deletes
        Distance   = 2,                      -- Distance to target
    },
    Clue = {
        ClueBlip = false, -- if in treasure need ClueBlip = true
        blipName = locale('cl_blip_treasure_hunt'),
        blipSprite = `blip_ambient_eyewitness`,
        blipScale = 0.2,
        blipTime = 1 * 60 * 1000, -- 1 min delete blip
    },
    -- BLIP COLOR MODIFIER
    ColorModifier = `BLIP_MODIFIER_MP_COLOR_1`,  -- Applied to all pet blips and GPS
}

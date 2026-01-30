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
        blipName   = locale('ui_blip_dead'),
        blipSprite = `blip_ambient_death`,  -- Hash: 350569997
        blipScale  = 0.2,
        blipTime   = 5 * 60 * 1000,         -- 5 minutes until blip auto-deletes
    },
    Track = {    -- TRACKING / TARGET BLIP
        blipName   = locale('ui_blip_target'),
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
    Race = { 
        ShowBlip = true,
        blipSprite = `blip_mp_playlist_races`,
        blipScale = 0.2,
        blipName = locale('cl_race_blip') or 'Pet Racing'
    },
    RaceCheckPoints = {
        blipSprite = `blip_mp_race_checkpoint`,
        blipScale = 0.5,
        blipName = locale('cl_race_checkpoint_blip') or 'Race Checkpoint'
    },
    Fight = {
        ShowBlip = true,
        blipSprite = -1646261997,
        blipScale = 0.2,
        blipName = locale('cl_fight_blip')
    },
            
    -- BLIP COLOR MODIFIER
    ColorModifier = `BLIP_MODIFIER_MP_COLOR_1`,  -- Applied to all pet blips and GPS
}

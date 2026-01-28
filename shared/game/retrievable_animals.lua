--[[
    HDRP-PETS RETRIEVABLE ANIMALS CONFIGURATION
    Separated from: shared/config/games.lua (v5.8.1+)
    
    Contains:
    - Animals that can be retrieved by pets (hunt mode)
]]

lib.locale()

-- Hash ID must be the ID of the table
return { 
    -- birds
    [-1003616053]   = {['name'] = locale('animal_duck'), },
    [1459778951]    = {['name'] = locale('animal_eagle'), },
    [-164963696]    = {['name'] = locale('animal_herring_seagull'),},
    [-1104697660]   = {['name'] = locale('animal_vulture'),},
    [-466054788]    = {['name'] = locale('animal_wild_turkey'),},
    [-2011226991]   = {['name'] = locale('animal_wild_turkey'),},
    [-166054593]    = {['name'] = locale('animal_wild_turkey'),},
    [-1076508705]   = {['name'] = locale('animal_roseate_spoonbill'),},
    [-466687768]    = {['name'] = locale('animal_red_footed_booby'),},
    [-575340245]    = {['name'] = locale('animal_wester_raven'),},
    [1416324601]    = {['name'] = locale('animal_ring_necked_pheasant'),},
    [1265966684]    = {['name'] = locale('animal_american_white_pelican'),},
    [-1797450568]   = {['name'] = locale('animal_blue_and_yellow_macaw'),},
    [-2073130256]   = {['name'] = locale('animal_double_crested_cormorant'),},
    [-564099192]    = {['name'] = locale('animal_whooping_crane'),},
    [723190474]     = {['name'] = locale('animal_canada_goose'),},
    [-2145890973]   = {['name'] = locale('animal_ferruinous_hawk'),},
    [1095117488]    = {['name'] = locale('animal_great_blue_heron'),},
    [386506078]     = {['name'] = locale('animal_common_loon'),},
    [-861544272]    = {['name'] = locale('animal_great_horned_owl'),},
    [831859211]     = {['name'] = locale('animal_egret'),},
    [2079703102]    = {['name'] = locale('animal_greater_prairie_chicken'),},
    
    -- small mammals
    [-541762431]    = {['name'] = locale('animal_black_tailed_jackrabbit'),},
    [1458540991]    = {['name'] = locale('animal_north_american_raccoon'),},
    [-1414989025]   = {['name'] = locale('animal_virginia_possum'),},
    [-1134449699]   = {['name'] = locale('animal_american_muskrat'),},
    [-1211566332]   = {['name'] = locale('animal_striped_skunk'),},
    [1007418994]    = {['name'] = locale('animal_berkshire_pig'),},
    [1751700893]    = {['name'] = locale('animal_peccary_pig'),},
    [-753902995]    = {['name'] = locale('animal_alpine_goat'),},
    
    -- medium mammals
    [252669332]     = {['name'] = locale('animal_american_red_fox'),},
    [759906147]     = {['name'] = locale('animal_north_american_beaver'),},
    [-1963605336]   = {['name'] = locale('animal_buck'),},
    [2028722809]    = {['name'] = locale('animal_boar'),},
    [480688259]     = {['name'] = locale('animal_coyote'),},
    [-1143398950]   = {['name'] = locale('animal_big_grey_wolf'),},
    [-885451903]    = {['name'] = locale('animal_medium_grey_wolf'),},
    [-829273561]    = {['name'] = locale('animal_small_grey_wolf'),},
    
    -- reptiles
    [-407730502]    = {['name'] = locale('animal_snapping_turtle'),},
    [-1854059305]   = {['name'] = locale('animal_green_iguana'),},
    [-593056309]    = {['name'] = locale('animal_desert_iguana'),},
    [457416415]     = {['name'] = locale('animal_gila_monster'),},
    [-1892280447]   = {['name'] = locale('animal_alligator'),},
    
    -- legendary
    [-1149999295]   = {['name'] = locale('animal_legendary_beaver'),},
    [-1307757043]   = {['name'] = locale('animal_legendary_coyote'),},
    [-1392359921]   = {['name'] = locale('animal_legendary_wolf'),},
}

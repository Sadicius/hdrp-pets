--[[
    HDRP-PETS PET SHOP PRICES CONFIGURATION
    Separated from: shared/config/shops.lua (v5.8.1+)
    
    Contains:
    - Pet prices and availability by location
]]

lib.locale()

return {
    -- valentine
    -- dogs
    {
        npcpetcoords = vector4(-290.62, 657.11, 113.57, 122.57),
        npcpetmodel = 'a_c_doghusky_01',
        npcpetprice = 200,
        label = locale('dog_husky'),
        type = {'canis'},
        stableid = 'valentine',
    },
    {
        npcpetcoords = vector4(-289.32, 653.85, 113.44, 297.49),
        npcpetmodel = 'a_c_dogcatahoulacur_01',
        npcpetprice = 50,
        label = locale('dog_catahoulacur'),
        type = {'canis'},
        stableid = 'valentine'
    },
    {
        npcpetcoords = vector4(-283.77, 653.09, 113.22, 124.67),
        npcpetmodel = 'a_c_doglab_01',
        npcpetprice = 100,
        label = locale('dog_lab'),
        type = {'canis'},
        stableid = 'valentine'
    },
    {
        npcpetcoords = vector4(-286.63, 649.03, 113.24, 295.18),
        npcpetmodel = 'a_c_dogrufus_01',
        npcpetprice = 100,
        label = locale('dog_rufus'),
        type = {'canis'},
        stableid = 'valentine'
    },
    {
        npcpetcoords = vector4(-285.48, 654.38, 113.10, 120.20),
        npcpetmodel = 'a_c_dogbluetickcoonhound_01',
        npcpetprice = 150,
        label = locale('dog_bluetickcoonhound'),
        type = {'canis'},
        stableid = 'valentine'
    },
    -- blackwater
    -- dogs
    {
        npcpetcoords = vector4(-935.24, -1241.28, 51.55, 58.12),
        npcpetmodel = 'a_c_doghound_01',
        npcpetprice = 200,
        label = locale('dog_hound'),
        type = {'canis'},
        stableid = 'blackwater'
    },
    {
        npcpetcoords = vector4(-933.99, -1240.08, 51.49, 48.18),
        npcpetmodel = 'a_c_dogcollie_01',
        npcpetprice = 500,
        label = locale('dog_collie'),
        type = {'canis'},
        stableid = 'blackwater'
    },
    {
        npcpetcoords = vector4(-936.63, -1242.85, 51.62, 15.40),
        npcpetmodel = 'a_c_dogpoodle_01',
        npcpetprice = 120,
        label = locale('dog_poodle'),
        type = {'canis'},
        stableid = 'blackwater'
    },
    {
        npcpetcoords = vector4(-932.13, -1237.06, 51.33, 53.85),
        npcpetmodel = 'a_c_dogamericanfoxhound_01',
        npcpetprice = 225,
        label = locale('dog_americanfoxhound'),
        type = {'canis'},
        stableid = 'blackwater'
    },
    {
        npcpetcoords = vector4(-933.00, -1238.60, 51.41, 59.48),
        npcpetmodel = 'a_c_dogaustraliansheperd_01',
        npcpetprice = 350,
        label = locale('dog_australiansheperd'),
        type = {'canis'},
        stableid = 'blackwater'
    },
    -- tumbleweed
    -- cats
    {
        npcpetcoords = vector4(-5591.42, -3072.23, 2.45, 319.26),
        npcpetmodel = 'a_c_cat_01',
        npcpetprice = 500,
        label = locale('breed_cat'),
        type = {'felis'},
        stableid = 'tumbleweed',
    },
    -- dogs
    {
        npcpetcoords = vector4(-5583.70, -3048.80, 1.09, 325.51),
        npcpetmodel = 'a_c_doghound_01',
        npcpetprice = 200,
        label = locale('dog_hound'),
        type = {'canis'},
        stableid = 'tumbleweed',
    },
    {
        npcpetcoords = vector4(-5576.90, -3058.34, 2.10, 158.43),
        npcpetmodel = 'a_c_doghusky_01',
        npcpetprice = 200,
        label = locale('dog_husky'),
        type = {'canis'},
        stableid = 'tumbleweed',
    },
    {
        npcpetcoords = vector4(-5580.11, -3053.68, 1.36, 168.49),
        npcpetmodel = 'a_c_dogcatahoulacur_01',
        npcpetprice = 50,
        label = locale('dog_catahoulacur'),
        type = {'canis'},
        stableid = 'tumbleweed',
    },
    {
        npcpetcoords = vector4(-5574.61, -3049.03, 0.68, 326.73),
        npcpetmodel = 'a_c_dogbluetickcoonhound_01',
        npcpetprice = 150,
        label = locale('dog_bluetickcoonhound'),
        type = {'canis'},
        stableid = 'tumbleweed',
    },
    {
        npcpetcoords = vector4(-5576.43, -3046.67, 0.65, 286.39),
        npcpetmodel = 'a_c_doglab_01',
        npcpetprice = 100,
        type = {'canis'},
        label = locale('dog_lab'),
        stableid = 'tumbleweed',
    },
    {
        npcpetcoords = vector4(-2891.4070, -3972.5532, -15.1823, 109.7351),
        npcpetmodel = 'a_c_dogbluetickcoonhound_01', -- 'a_c_bear_01',
        npcpetprice = 600,
        label = locale('dog_bluetickcoonhound'),
        type = {'canis'},
        stableid = 'wapiti',
    },
    {
        npcpetcoords = vector4(-2892.9104, -3969.1328, -15.1855, 121.9486),
        npcpetmodel = 'a_c_dogstreet_01', -- 'a_c_wolf',
        npcpetprice = 400,
        label = locale('dog_street'),
        type = {'canis'},
        stableid = 'wapiti',
    },

    -- More Information for others animals companions
    --[[ 
    -- Animal no use WIP
    -- wilds
        -- {
        --     npcpetmodel = 'a_c_panther_01',
        --     npcpetprice = 500,
        --     type = {'felis'},
        --     label = locale('phanter'),
        -- },
        -- {
        --     npcpetmodel = 'a_c_lionmangy_01', -- A_C_Panther_01  A_C_Cougar_01  A_C_Cat_01
        --     npcpetprice = 500,
        --     type = {'felis'},
        --     label = locale('lion_mangy'),
        -- },
        -- {
        --     npcpetmodel = 'a_c_cougar_01',
        --     npcpetprice = 500,
        --     type = {'felis'},
        --     label = locale('cougar'),
        -- },
        -- {
        --     npcpetmodel = 'a_c_wolf',
        --     npcpetprice = 350,
        --     type = {'canis'},
        --     label = locale('wolf'),
        -- },
        -- {
        --     npcpetmodel = 'a_c_bear_01',
        --     npcpetprice = 120,
        --     type = {'wild'},
        --     label = locale('bear'),
        -- },

    -- reptile
        -- {
        --     npcpetcoords = vector4(-5572.65, -3062.22, 2.30, 118.12),
        --     npcpetmodel = 'a_c_iguana_01', -- A_C_IguanaDesert_01  A_C_Squirrel_01  A_C_Snake_01
        --     npcpetprice = 200,
        --     type = {'reptilia'},
        --     label = locale('iguana'),
        --     stableid = 'tumbleweed',
        -- },
        -- {
        --     npcpetcoords = vector4(-5574.81, -3063.08, 2.65, 260.43),
        --     npcpetmodel = 'a_c_iguanadesert_01',
        --     npcpetprice = 200,
        --     type = {'reptilia'},
        --     label = locale('iguana_desert'),
        --     stableid = 'tumbleweed',
        -- },
        -- {
        --     npcpetcoords = vector4(-5574.49, -3061.38, 3.40, 217.51),
        --     npcpetmodel = 'a_c_snake_01',
        --     npcpetprice = 200,
        --     type = {'reptilia'},
        --     label = locale('snake'),
        --     stableid = 'tumbleweed',
        -- },

    -- birds
        -- {
        --     npcpetcoords = vector4(-5588.38671875, -3071.296875, 3.48518502712249, 53.85),
        --     npcpetmodel = 'a_c_eagle_01', -- A_C_Owl_01  A_C_Hawk_01  A_C_Parrot_01  A_C_Woodpecker_01  A_C_SongBird_01  A_C_Cardinal_01  A_C_Bat_01
        --     npcpetprice = 225,
        --     type = {'bird'},
        --     label = locale('eagle'),
        --     stableid = 'tumbleweed',
        -- },
        -- {
        --     npcpetcoords = vector4(-5588.7841796875, -3071.784423828125, 3.49062204360961, 53.85),
        --     npcpetmodel = 'a_c_owl_01',
        --     npcpetprice = 225,
        --     type = {'bird'},
        --     label = locale('owl'),
        --     stableid = 'tumbleweed',
        -- },
        -- {
        --     npcpetcoords = vector4(-5589.1376953125, -3072.22119140625, 3.49324095249176, 53.85),
        --     npcpetmodel = 'a_c_hawk_01',
        --     npcpetprice = 225,
        --     type = {'bird'},
        --     label = locale('hawk'),
        --     stableid = 'tumbleweed',
        -- },
        -- {
        --     npcpetcoords = vector4(-5589.57080078125, -3072.650146484375, 3.49686598777771, 53.85),
        --     npcpetmodel = 'a_c_parrot_01',
        --     npcpetprice = 225,
        --     type = {'bird'},
        --     label = locale('parrot'),
        --     stableid = 'tumbleweed',
        -- },
    ]]
}

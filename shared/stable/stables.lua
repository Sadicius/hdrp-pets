--[[
    HDRP-PETS PET STABLES CONFIGURATION
    Separated from: shared/config/shops.lua (v5.8.1+)
    
    Contains:
    - Pet stable locations and NPC settings
]]

return {
    {   -- valentine
        stableid = 'valentine',
        coords = vector3(-283.79, 659.05, 113.38),
        npcmodel = `mbh_rhodesrancher_females_01`,
        npccoords = vector4(-283.79, 659.05, 113.38, 84.08),

        petcustom = vec4(-280.55, 648.30, 114.37, 141.69),
        showblip = true
    },
    {   -- blackwater
        stableid = 'blackwater',
        coords = vector3(-939.59, -1238.36, 52.07),
        npcmodel = `u_m_m_bwmstablehand_01`,
        npccoords = vector4(-939.59, -1238.36, 52.07, 238.11),

        petcustom = vec4(-865.1928, -1366.3270, 43.5440, 86.8795),
        showblip = true
    },
    {   -- tumbleweed
        stableid = 'tumbleweed',
        coords = vector3(-5584.34, -3065.37, 2.39),
        npcmodel = `u_m_m_bwmstablehand_01`,
        npccoords = vector4(-5584.34, -3065.37, 2.39, 2.41),

        petcustom = vec4(-5526.3452, -3030.7842, -2.0329, 105.3392),
        showblip = true
    },
    {   -- wapiti
        stableid = 'wapiti',
        coords = vector3(-5584.34, -3065.37, 2.39),
        npcmodel = `u_m_m_bwmstablehand_01`,
        npccoords = vector4(453.09, 2209.89, 246.07, 299.49),

        petcustom = vec4(485.41, 2221.24, 247.11, 57.77),
        showblip = true
    }
}

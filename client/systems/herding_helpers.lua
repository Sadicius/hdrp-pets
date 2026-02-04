
-- HERDING SYSTEM - Multi-Pet Group Following Behavior
-- Permite que múltiples mascotas sigan al jugador en formación

local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local State = exports['hdrp-pets']:GetState()

---Genera un número aleatorio en rango (incluye ambos extremos)
---@param min number
---@param max number
---@return number
local function randRange(min, max)
    return min + math.random() * (max - min)
end

---Formación en línea: mascotas alineadas detrás del jugador
local function formation_line(petCount)
    local offsets = {}
    for i = 1, petCount do
        -- Alterna delante/detrás/lados manteniendo alineación
        local posType = math.random(1,3) -- 1: detrás, 2: delante, 3: lado
        local y = (i - math.ceil(petCount/2)) * 2.5 + randRange(-0.5, 0.5)
        local x
        if posType == 1 then x = 3 + randRange(-0.5, 0.5) -- detrás
        elseif posType == 2 then x = -2 + randRange(-0.5, 0.5) -- delante
        else x = randRange(-2,2) end -- lado
        table.insert(offsets, {x = x, y = y})
    end
    return offsets
end

-- Columna: todos detrás del jugador
local function formation_column(petCount)
    local offsets = {}
    for i = 1, petCount do
        local posType = math.random(1,3)
        local x
        if posType == 1 then x = 3 + (i-1) * 1.5 + randRange(-0.5, 0.5)
        elseif posType == 2 then x = -2 - (i-1) * 1.2 + randRange(-0.5, 0.5)
        else x = randRange(-2,2) end
        local y = randRange(-2,2)
        table.insert(offsets, {x = x, y = y})
    end
    return offsets
end

-- Rombo/diamante: uno delante, dos a los lados, uno detrás
local function formation_diamond(petCount)
    local offsets = {}
    local base = 2.2
    if petCount >= 1 then table.insert(offsets, {x = 3, y = 0}) end
    if petCount >= 2 then table.insert(offsets, {x = 4.5, y = -base}) end
    if petCount >= 3 then table.insert(offsets, {x = 4.5, y = base}) end
    if petCount >= 4 then table.insert(offsets, {x = 6, y = 0}) end
    for i = 5, petCount do
        local angle = (2 * math.pi / (petCount-4)) * (i-4)
        local x = 6.5 + math.cos(angle) * base + randRange(-0.5, 0.5)
        local y = math.sin(angle) * base + randRange(-0.5, 0.5)
        table.insert(offsets, {x = x, y = y})
    end
    return offsets
end

-- Escalonada: alterna izquierda/derecha y atrás
local function formation_escalonada(petCount)
    local offsets = {}
    for i = 1, petCount do
        local posType = math.random(1,3)
        local side = (i % 2 == 0) and 1 or -1
        local y = side * 1.5 * math.floor((i-1)/2) + randRange(-0.5, 0.5)
        local x
        if posType == 1 then x = 3 + (i-1) * 1.2 + randRange(-0.5, 0.5)
        elseif posType == 2 then x = -2 - (i-1) * 1.2 + randRange(-0.5, 0.5)
        else x = randRange(-2,2) end
        table.insert(offsets, {x = x, y = y})
    end
    return offsets
end

-- Pelotón: mascotas agrupadas en bloques
local function formation_peloton(petCount)
    local offsets = {}
    local cols = math.ceil(math.sqrt(petCount))
    local spacing = 1.8
    for i = 1, petCount do
        local row = math.floor((i-1)/cols)
        local col = (i-1) % cols
        local posType = math.random(1,3)
        local x
        if posType == 1 then x = 3 + row * spacing + randRange(-0.5, 0.5)
        elseif posType == 2 then x = -2 - row * spacing + randRange(-0.5, 0.5)
        else x = randRange(-2,2) end
        local y = (col - math.floor(cols/2)) * spacing + randRange(-0.5, 0.5)
        table.insert(offsets, {x = x, y = y})
    end
    return offsets
end

-- Dispersa: mascotas separadas aleatoriamente
local function formation_dispersed(petCount)
    local offsets = {}
    for i = 1, petCount do
        local angle = randRange(0, 2 * math.pi)
        local dist = randRange(3, 6)
        local x = dist * math.cos(angle) + randRange(-0.5, 0.5)
        local y = dist * math.sin(angle) + randRange(-0.5, 0.5)
        table.insert(offsets, {x = x, y = y})
    end
    return offsets
end

-- Zigzag: alterna izquierda/derecha en diagonal
local function formation_zigzag(petCount)
    local offsets = {}
    for i = 1, petCount do
        local side = (i % 2 == 0) and 1 or -1
        local y = side * (1.5 + randRange(-0.5, 0.5)) * math.floor((i-1)/2)
        local x = 3 + (i-1) * 1.2 + randRange(-0.5, 0.5)
        table.insert(offsets, {x = x, y = y})
    end
    return offsets
end

-- Escalera: cada mascota más atrás y a un lado
local function formation_stair(petCount)
    local offsets = {}
    for i = 1, petCount do
        local x = 3 + (i-1) * 1.2 + randRange(-0.5, 0.5)
        local y = (i-1) * 1.2 + randRange(-0.5, 0.5)
        table.insert(offsets, {x = x, y = y})
    end
    return offsets
end

-- Cuadrado: mascotas en cuadrícula
local function formation_square(petCount)
    local offsets = {}
    local side = math.ceil(math.sqrt(petCount))
    local spacing = 2.2
    for i = 1, petCount do
        local row = math.floor((i-1)/side)
        local col = (i-1) % side
        local posType = math.random(1,3)
        local x
        if posType == 1 then x = 3 + row * spacing + randRange(-0.5, 0.5)
        elseif posType == 2 then x = -2 - row * spacing + randRange(-0.5, 0.5)
        else x = randRange(-2,2) end
        local y = (col - math.floor(side/2)) * spacing + randRange(-0.5, 0.5)
        table.insert(offsets, {x = x, y = y})
    end
    return offsets
end

local function formation_arc(petCount)
    local offsets = {}
    local radius = 3 + petCount * 0.5
    local angleStep = math.pi / (petCount + 1)
    for i = 1, petCount do
        local angle = -math.pi/2 + i * angleStep + randRange(-0.1, 0.1)
        local x = radius * math.cos(angle) + randRange(-0.5, 0.5)
        local y = radius * math.sin(angle) + randRange(-0.5, 0.5)
        table.insert(offsets, {x = x, y = y})
    end
    return offsets
end

local function formation_v(petCount)
    local offsets = {}
    local spread = 2.5
    for i = 1, petCount do
        local side = (i % 2 == 0) and 1 or -1
        local y = side * math.floor((i-1)/2) * spread + randRange(-0.5, 0.5)
        local x = 3 + math.floor((i-1)/2) * 1.5 + randRange(-0.5, 0.5)
        table.insert(offsets, {x = x, y = y})
    end
    return offsets
end

local function formation_circle(petCount)
    local offsets = {}
    local radius = 3 + petCount * 0.3
    for i = 1, petCount do
        local angle = (2 * math.pi / petCount) * i + randRange(-0.1, 0.1)
        local x = radius * math.cos(angle) + randRange(-0.5, 0.5)
        local y = radius * math.sin(angle) + randRange(-0.5, 0.5)
        table.insert(offsets, {x = x, y = y})
    end
    return offsets
end
-- Espiral: mascotas giran en espiral alrededor del jugador
local function formation_spiral(petCount)
    local offsets = {}
    local turns = 1.5
    for i = 1, petCount do
        local angle = (2 * math.pi * turns / petCount) * i
        local radius = 2.5 + i * 0.4
        local x = radius * math.cos(angle) + randRange(-0.5, 0.5)
        local y = radius * math.sin(angle) + randRange(-0.5, 0.5)
        table.insert(offsets, {x = x, y = y})
    end
    return offsets
end

-- Ondas: mascotas en forma de onda sinusoidal
local function formation_wave(petCount)
    local offsets = {}
    for i = 1, petCount do
        local x = 3 + i * 1.2 + randRange(-0.5, 0.5)
        local y = math.sin(i * 0.8) * 2.2 + randRange(-0.5, 0.5)
        table.insert(offsets, {x = x, y = y})
    end
    return offsets
end

-- Caracol: espiral cerrada
local function formation_snail(petCount)
    local offsets = {}
    for i = 1, petCount do
        local angle = (2 * math.pi / petCount) * i * 1.5
        local radius = 2.5 + i * 0.25
        local x = radius * math.cos(angle) + randRange(-0.5, 0.5)
        local y = radius * math.sin(angle) + randRange(-0.5, 0.5)
        table.insert(offsets, {x = x, y = y})
    end
    return offsets
end

-- Zigzag doble: dos líneas en zigzag
local function formation_doublezigzag(petCount)
    local offsets = {}
    for i = 1, petCount do
        local x = randRange(-3, 3)
        local y = randRange(-4, 4)
        table.insert(offsets, {x = x, y = y})
    end
    return offsets
end

-- Estrella: mascotas en los vértices de una estrella
local function formation_star(petCount)
    local offsets = {}
    local points = math.min(petCount, 5)
    local radius = 3.5
    for i = 1, petCount do
        local angle = (2 * math.pi / points) * ((i-1) % points)
        local r = radius * (1 + ((i-1) % 2) * 0.5)
        local x = r * math.cos(angle) + randRange(-0.5, 0.5)
        local y = r * math.sin(angle) + randRange(-0.5, 0.5)
        table.insert(offsets, {x = x, y = y})
    end
    return offsets
end

-- Corazón: mascotas forman la silueta de un corazón
local function formation_heart(petCount)
    local offsets = {}
    for i = 1, petCount do
        local t = (math.pi * 2 / petCount) * i
        local x = 3 + 16 * math.pow(math.sin(t), 3) / 8 + randRange(-0.5, 0.5)
        local y = 13 * math.cos(t) - 5 * math.cos(2*t) - 2 * math.cos(3*t) - math.cos(4*t)
        y = y / 8 + randRange(-0.5, 0.5)
        table.insert(offsets, {x = x, y = y})
    end
    return offsets
end

-- S: mascotas siguen la forma de una S
local function formation_s(petCount)
    local offsets = {}
    for i = 1, petCount do
        local t = (math.pi * 2 / petCount) * i
        local x = 3 + math.sin(t) * 2.5 + randRange(-0.5, 0.5)
        local y = math.sin(2*t) * 2.5 + randRange(-0.5, 0.5)
        table.insert(offsets, {x = x, y = y})
    end
    return offsets
end

-- H: mascotas forman la letra H
local function formation_h(petCount)
    local offsets = {}
    local rows = math.max(2, math.floor(petCount/3))
    for i = 1, petCount do
        if i <= rows then
            -- columna izquierda
            table.insert(offsets, {x = 3 + (i-1)*1.2, y = -2})
        elseif i <= 2*rows then
            -- columna derecha
            table.insert(offsets, {x = 3 + (i-rows-1)*1.2, y = 2})
        else
            -- barra central
            table.insert(offsets, {x = 3 + (i-2*rows-1)*1.2, y = 0})
        end
    end
    return offsets
end


---Genera la formación dinámica según cantidad de mascotas y experiencia mínima
---@param petCount number
---@param petsArray table
---@return table
local function GenerateDynamicFormation(petCount, petsArray)
    if petCount <= 1 then
        return {{x = 3 + randRange(-0.3, 0.3), y = randRange(-0.5, 0.5)}}
    end
    -- Tabla de patrones y nombres
    local patterns = {
        formation_line, formation_arc, formation_v, formation_circle, formation_zigzag, formation_stair, formation_square, formation_column, formation_diamond, formation_escalonada, formation_peloton, formation_dispersed, formation_spiral, formation_wave, formation_snail, formation_doublezigzag, formation_star, formation_heart, formation_s, formation_h
    }
    local patternNames = {
        formation_line = formation_line, formation_arc = formation_arc, formation_v = formation_v, formation_circle = formation_circle, formation_zigzag = formation_zigzag, formation_stair = formation_stair, formation_square = formation_square, formation_column = formation_column, formation_diamond = formation_diamond, formation_escalonada = formation_escalonada, formation_peloton = formation_peloton, formation_dispersed = formation_dispersed, formation_spiral = formation_spiral, formation_wave = formation_wave, formation_snail = formation_snail, formation_doublezigzag = formation_doublezigzag, formation_star = formation_star, formation_heart = formation_heart, formation_s = formation_s, formation_h = formation_h
    }
    -- Calcular experiencia mínima
    local minExp = math.huge
    if petsArray and #petsArray > 0 then
        for _, petData in ipairs(petsArray) do
            local xp = petData.companionxp or (petData.data and petData.data.companionxp) or 0
            if xp < minExp then minExp = xp end
        end
    else
        minExp = 0
    end
    -- Filtrar patrones válidos
    local validPatterns, validNames = {}, {}
    for _, pattern in ipairs(patterns) do
        local name = tostring(pattern):match('function ([^:]+)')
        if not name then
            for k,v in pairs(_G) do if v == pattern then name = k break end end
        end
        local minLimit = Config.Herding.formationMinLimits[name] or 1
        local minExpLimit = (Config.XP and Config.XP.Trick and Config.XP.Trick.formationExpLimits and Config.XP.Trick.formationExpLimits[name]) or 0
        if petCount >= minLimit and minExp >= minExpLimit then
            table.insert(validPatterns, pattern)
            validNames[name] = pattern
        end
    end
    -- Usar formación preferida si es válida
    if herdingStates and herdingStates.preferredFormation then
        local preferred = herdingStates.preferredFormation
        local preferredPattern = patternNames[preferred]
        if preferredPattern and validNames[preferred] then
            return preferredPattern(petCount)
        end
    end
    -- Si no hay válidas, fallback a línea
    if #validPatterns == 0 then
        return formation_line(petCount)
    end
    -- Aleatorio entre válidas
    local chosenPattern = validPatterns[math.random(1, #validPatterns)]
    return chosenPattern(petCount)
end

exports('GenerateDynamicFormation', GenerateDynamicFormation)

-- Elimina lógica antigua de hilos y movimiento global (ahora en herding_core.lua)
local M = {}

function M.CalculatePrice(comp, initial)
    local price = 0
    for category, value in pairs(comp) do
        local categoryPrice = Config.PriceComponent and Config.PriceComponent[category]
        if categoryPrice and value > 0 and (not initial or initial[category] ~= value) then
            price = price + categoryPrice
        end
    end
    return price
end

function M.CalculatePetMovePrice(fromCoords, toCoords)
    local baseFee = Config.MovePetBasePrice 
    local distanceMultiplier = Config.MoveFeePerMeter
    local distance = #(fromCoords - toCoords)
    local cost = math.floor(baseFee + (distance * distanceMultiplier))
    return cost
end

--- Limpia todos los componentes de customización de una mascota (devuelve tabla vacía)
function M.PetComponents_Clear(custom)
    return {}
end

--- Fusiona dos tablas de componentes (sobrescribe con los nuevos)
function M.PetComponents_Merge(current, new)
    local merged = {}
    for k, v in pairs(current or {}) do merged[k] = v end
    for k, v in pairs(new or {}) do merged[k] = v end
    return merged
end

--- Valida si un componente es válido para la mascota (existe en Config.PetShopComp)
function M.PetComponents_IsValid(category, value)
    if not Config or not Config.PetShopComp then return false end
    local cat = Config.PetShopComp[category]
    if not cat then return false end
    return value > 0 and value <= #cat
end

--- Limpia todos los props de una mascota (devuelve tabla vacía)
function M.PetProps_Clear(props)
    return {}
end

--- Fusiona dos tablas de props (sobrescribe con los nuevos)
function M.PetProps_Merge(current, new)
    local merged = {}
    for k, v in pairs(current or {}) do merged[k] = v end
    for k, v in pairs(new or {}) do merged[k] = v end
    return merged
end

--- Valida si un prop es válido para la mascota (existe en Config.PetShopProps)
function M.PetProps_IsValid(category, value)
    if not Config or not Config.PetShopProps then return false end
    local cat = Config.PetShopProps[category]
    if not cat then return false end
    return value > 0 and value <= #cat
end

return M

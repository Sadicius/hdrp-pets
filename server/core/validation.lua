local Validation = {}
lib.locale()

-- PET NAME VALIDATION --Validate pet name (prevent injection and exploits)
---@param name string
---@return boolean isValid
---@return string|nil sanitizedName or errorMessage
function Validation.PetName(name)
    if not name or type(name) ~= "string" then
        return false, locale('sv_validation_name_type')
    end
    
    -- Remove special characters (allow alphanumeric, spaces, hyphens, underscores)
    local sanitized = string.gsub(name, "[^%w%s%-_]", "")
    
    if #sanitized < 1 then
        return false, locale('sv_validation_name_short')
    end
    
    if #sanitized > 50 then
        return false, locale('sv_validation_name_long')
    end
    
    return true, sanitized
end

-- OWNERSHIP VALIDATION --Verify pet ownership
---@param citizenid string
---@param companionid string
---@return boolean isOwner
function Validation.PetOwnership(citizenid, companionid)
    if not citizenid or not companionid then
        return false
    end
    
    local result = MySQL.scalar.await(
        'SELECT COUNT(*) FROM pet_companion WHERE citizenid = ? AND companionid = ?',
        {citizenid, companionid}
    )
    
    return result and tonumber(result) > 0
end

-- PRICE VALIDATION --Validate price (prevent negative/exploits)
---@param price number
---@return boolean isValid
function Validation.Price(price)
    return type(price) == "number" and price >= 0 and price <= 999999
end

return Validation
--[[
    NOTIFICATION MANAGER
    ====================================
    Centralized notification system with debouncing to prevent spam
    Tracks recent notifications and prevents duplicates within a cooldown period
]]

local NotificationManager = {}

-- Track recent notifications with timestamps
local RecentNotifications = {}

-- Default cooldown in milliseconds (5 seconds)
local DEFAULT_COOLDOWN = 5000

--[[
    Generate unique key for a notification based on its content
    @param notifyData table Notification data
    @return string Unique key
]]
local function generateNotificationKey(notifyData)
    local title = notifyData.title or ''
    local description = notifyData.description or ''
    local type = notifyData.type or 'info'
    
    return string.format("%s|%s|%s", title, description, type)
end

--[[
    Check if notification is on cooldown
    @param key string Notification key
    @param cooldown number Cooldown duration in ms
    @return boolean True if on cooldown
]]
local function isOnCooldown(key, cooldown)
    if not RecentNotifications[key] then
        return false
    end
    
    local timeSinceLastNotify = GetGameTimer() - RecentNotifications[key]
    return timeSinceLastNotify < cooldown
end

--[[
    Record notification timestamp
    @param key string Notification key
]]
local function recordNotification(key)
    RecentNotifications[key] = GetGameTimer()
end

--[[
    Enhanced notify with automatic debouncing
    @param notifyData table Standard lib.notify parameters
    @param options table Optional: {cooldown = number (ms), force = boolean}
]]
function NotificationManager.Notify(notifyData, options)
    options = options or {}
    local cooldown = options.cooldown or DEFAULT_COOLDOWN
    local force = options.force or false
    
    -- Validate notify data
    if not notifyData then
        if Config.Debug then
            print('^1[NOTIFICATION MANAGER]^7 Invalid notify data provided')
        end
        return
    end
    
    -- Generate key for this notification
    local key = generateNotificationKey(notifyData)
    
    -- Check if on cooldown (unless forced)
    if not force and isOnCooldown(key, cooldown) then
        if Config.Debug then
            print('^3[NOTIFICATION MANAGER]^7 Notification blocked (cooldown): ' .. (notifyData.title or 'No title'))
        end
        return
    end
    
    -- Record and send notification
    recordNotification(key)
    lib.notify(notifyData)
    
    if Config.Debug then
        print('^2[NOTIFICATION MANAGER]^7 Notification sent: ' .. (notifyData.title or 'No title'))
    end
end

--[[
    Force a notification (bypass cooldown)
    @param notifyData table Standard lib.notify parameters
]]
function NotificationManager.ForceNotify(notifyData)
    NotificationManager.Notify(notifyData, {force = true})
end

--[[
    Clear cooldown for a specific notification
    Useful when you want to allow immediate re-notification
    @param notifyData table Notification data to clear
]]
function NotificationManager.ClearCooldown(notifyData)
    local key = generateNotificationKey(notifyData)
    RecentNotifications[key] = nil
    
    if Config.Debug then
        print('^2[NOTIFICATION MANAGER]^7 Cooldown cleared for: ' .. (notifyData.title or 'No title'))
    end
end

--[[
    Clear all notification cooldowns
    Useful for reset scenarios
]]
function NotificationManager.ClearAllCooldowns()
    RecentNotifications = {}
    
    if Config.Debug then
        print('^2[NOTIFICATION MANAGER]^7 All notification cooldowns cleared')
    end
end

--[[
    Get time until notification can be shown again
    @param notifyData table Notification data
    @return number|nil Time in ms until available, or nil if available now
]]
function NotificationManager.GetCooldownRemaining(notifyData)
    local key = generateNotificationKey(notifyData)
    
    if not RecentNotifications[key] then
        return nil -- Available immediately
    end
    
    local timeSinceLastNotify = GetGameTimer() - RecentNotifications[key]
    local remaining = DEFAULT_COOLDOWN - timeSinceLastNotify
    
    return remaining > 0 and remaining or nil
end

--[[
    Cleanup old notification records (older than 10 minutes)
    Prevents memory buildup
]]
CreateThread(function()
    while true do
        Wait(60000) -- Check every minute
        
        local currentTime = GetGameTimer()
        local cleanupThreshold = 10 * 60 * 1000 -- 10 minutes
        
        for key, timestamp in pairs(RecentNotifications) do
            if currentTime - timestamp > cleanupThreshold then
                RecentNotifications[key] = nil
            end
        end
    end
end)

-- Export functions
_G.NotificationManager = NotificationManager
return NotificationManager

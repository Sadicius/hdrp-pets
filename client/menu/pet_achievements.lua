local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()
local State = exports['hdrp-pets']:GetState()
local Achievements = {}

-- Calcula el progreso de un logro según la estructura robusta achievements
local function getAchievementProgress(requirement, achievements)
    if not requirement or not requirement.type or not requirement.value then
        return 0, 1, false
    end
    local progress, maxProgress = 0, requirement.value
    if requirement.type == 'level' then
        progress = (achievements.level or 0)
    elseif requirement.type == 'fight' then
        progress = (achievements.fight and achievements.fight.victories) or 0
    elseif requirement.type == 'fight_streak' then
        progress = (achievements.fight and achievements.fight.streak) or 0
    elseif requirement.type == 'formation' then
        progress = (achievements.formation and achievements.formation.unlocked) or 0
    elseif requirement.type == 'treasure' then
        progress = (achievements.treasure and achievements.treasure.completed) or 0
    else
        progress = 0
    end
    local completed = progress >= maxProgress
    if maxProgress == 0 then maxProgress = 1 end
    return math.min(progress, maxProgress), maxProgress, completed
end

function Achievements.ShowTab(companionid)
    if not Config.XP.Achievements.Enabled then
        lib.notify({ title = locale('cl_error_achievements_disabled'), type = 'info' })
        return
    end

    -- Callback para obtener la estructura completa de la mascota
    RSGCore.Functions.TriggerCallback('hdrp-pets:server:getcompanionbyid', function(petData)
        if not petData or not petData.data then
            lib.notify({ title = locale('cl_error_pet_not_found'), type = 'error' })
            return
        end
        local companionData = type(petData.data) == 'string' and json.decode(petData.data) or petData.data
        -- Actualiza State.Pets[companionid].data si existe
        local pet = State.GetPet(companionid)
        if pet then
            pet.data = companionData
        end

        local petName = (companionData.info and companionData.info.name) or 'Unknown'
        local xp = (companionData.progression and companionData.progression.xp) or 0
        local level = State.GetPetLevel and State.GetPetLevel(xp) or math.floor(xp / 100) + 1

        -- Usar la estructura robusta: achievements.fight, achievements.unlocked, etc.
        local achievements = petData.achievements or {}
        local unlocked = achievements.unlocked or {}

        local options = {}
        local unlockedCount = 0
        local totalCount = 0
        local totalXPEarned = 0

        for key, achievementConfig in pairs(Config.XP.Achievements.List) do
            totalCount = totalCount + 1
            if unlocked[key] then
                unlockedCount = unlockedCount + 1
                totalXPEarned = totalXPEarned + achievementConfig.xpBonus
            end
        end

        options[#options + 1] = {
            title = '📊 ' .. locale('cl_progress') .. ': ' .. unlockedCount .. '/' .. totalCount .. ' ' .. locale('cl_unlocked'),
            metadata = {
                {label = locale('cl_unlocked'), value = unlockedCount .. '/' .. totalCount .. ' (' .. math.floor((unlockedCount / totalCount) * 100) .. '%)'},
                {label = locale('cl_total_xp_earned'), value = '+' .. totalXPEarned .. ' XP'}
            }
        }

        for key, achievementConfig in pairs(Config.XP.Achievements.List) do
            local progress, maxProgress, completed = getAchievementProgress(achievementConfig.requirement, achievements)
            local isUnlocked = unlocked[key] or false
            local icon = isUnlocked and "✅" or (progress > 0 and "🔄" or "🔒")
            local status = isUnlocked and "COMPLETED ✅" or (progress > 0 and "IN PROGRESS 🔄" or "LOCKED 🔒")
            options[#options + 1] = {
                title = icon .. ' ' .. achievementConfig.name,
                description = achievementConfig.description,
                metadata = {
                    {label = locale('cl_status'), value = status},
                    {label = locale('cl_reward'), value = '+' .. achievementConfig.xpBonus .. ' XP ' .. (isUnlocked and '(Claimed)' or '(Pending)')},
                    {label = locale('cl_progress'), value = progress .. '/' .. maxProgress .. ' (' .. math.floor((progress / maxProgress) * 100) .. '%)', progress = math.floor((progress / maxProgress) * 100), colorScheme = isUnlocked and '#4CAF50' or '#FF9800'}
                }
            }
        end

        lib.registerContext({
            id = 'pet_achievements_tab',
            title = '🏆 ' .. petName,
            menu = 'pet_dashboard',
            onBack = function() end,
            options = options
        })
        lib.showContext('pet_achievements_tab')
    end, companionid)
end

-- Handler para logros/achievements
RegisterNetEvent('hdrp-pets:client:achievement')
AddEventHandler('hdrp-pets:client:achievement', function(title, description)
    lib.notify({
        title = locale('cl_achievement_unlocked'),
        description = title .. '\n' .. description,
        type = 'success',
        duration = 8000
    })
end)

return Achievements

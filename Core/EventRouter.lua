-- EventRouter.lua - Core 事件路由与钩子注册

local EventRouter = BuildEnv("CrateTrackerZKEventRouter")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local CoreShared = BuildEnv("CrateTrackerZKCoreShared")
local AddonLifecycle = BuildEnv("CrateTrackerZKAddonLifecycle")

local MONSTER_CHAT_EVENTS = {
    CHAT_MSG_MONSTER_SAY = true,
    CHAT_MSG_MONSTER_YELL = true,
    CHAT_MSG_MONSTER_EMOTE = true,
    CHAT_MSG_MONSTER_PARTY = true,
    CHAT_MSG_MONSTER_WHISPER = true,
    CHAT_MSG_RAID_BOSS_EMOTE = true,
    CHAT_MSG_RAID_BOSS_WHISPER = true,
}

local TEAM_CHAT_EVENTS = {
    CHAT_MSG_RAID = true,
    CHAT_MSG_RAID_LEADER = true,
    CHAT_MSG_RAID_WARNING = true,
    CHAT_MSG_PARTY = true,
    CHAT_MSG_PARTY_LEADER = true,
    CHAT_MSG_INSTANCE_CHAT = true,
    CHAT_MSG_INSTANCE_CHAT_LEADER = true,
}

local function HandleZoneChanged()
    C_Timer.After(0.1, function()
        local currentMapID = CoreShared:GetCurrentMapID()
        if Area then
            Area:CheckAndUpdateAreaValid(currentMapID)
        end
        if CoreShared:IsAreaActive() then
            if TimerManager then TimerManager:DetectMapIcons(currentMapID) end
            if Phase then Phase:UpdatePhaseInfo(currentMapID) end
        end
    end)
end

local function HandlePlayerTargetChanged()
    if CoreShared:IsAreaActive() and Phase then
        local currentMapID = CoreShared:GetCurrentMapID()
        Phase:UpdatePhaseInfo(currentMapID)
    end
end

local function HandlePlayerLogout()
    if Phase and Phase.Reset then
        Phase:Reset()
        Logger:Debug("Core", "状态", "退出游戏，已清除位面ID缓存")
    end
    if not CrateTrackerZK.isReloading then
        CoreShared:ClearAllPhaseCaches()
    end
    CrateTrackerZK.isReloading = nil
end

local function HandleMonsterChat(event, ...)
    if not CoreShared:IsAreaActive() then
        return
    end
    if ShoutDetector and ShoutDetector.HandleChatEvent then
        local message = select(1, ...)
        ShoutDetector:HandleChatEvent(event, message)
    end
end

local function HandleTeamChat(event, ...)
    if not CoreShared:CanProcessTeamMessages() then
        return
    end
    if TeamCommListener and TeamCommListener.HandleChatEvent then
        local message = select(1, ...)
        local sender = select(2, ...)
        TeamCommListener:HandleChatEvent(event, message, sender)
    end
end

function EventRouter:HandleEvent(event, ...)
    if event ~= "PLAYER_LOGIN" and event ~= "PLAYER_LOGOUT" then
        if not CoreShared:IsAddonEnabled() then
            return
        end
    end

    if event == "PLAYER_LOGIN" then
        AddonLifecycle:OnLogin()
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        HandleZoneChanged()
    elseif event == "PLAYER_TARGET_CHANGED" then
        HandlePlayerTargetChanged()
    elseif event == "PLAYER_LOGOUT" then
        HandlePlayerLogout()
    elseif MONSTER_CHAT_EVENTS[event] then
        HandleMonsterChat(event, ...)
    elseif TEAM_CHAT_EVENTS[event] then
        HandleTeamChat(event, ...)
    end
end

function EventRouter:RegisterEventFrame()
    if CrateTrackerZK.eventFrame then
        return CrateTrackerZK.eventFrame
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        EventRouter:HandleEvent(event, ...)
    end)

    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("ZONE_CHANGED")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("PLAYER_LOGOUT")
    eventFrame:RegisterEvent("CHAT_MSG_MONSTER_SAY")
    eventFrame:RegisterEvent("CHAT_MSG_MONSTER_YELL")
    eventFrame:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
    eventFrame:RegisterEvent("CHAT_MSG_MONSTER_PARTY")
    eventFrame:RegisterEvent("CHAT_MSG_MONSTER_WHISPER")
    eventFrame:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
    eventFrame:RegisterEvent("CHAT_MSG_RAID_BOSS_WHISPER")
    eventFrame:RegisterEvent("CHAT_MSG_RAID")
    eventFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
    eventFrame:RegisterEvent("CHAT_MSG_RAID_WARNING")
    eventFrame:RegisterEvent("CHAT_MSG_PARTY")
    eventFrame:RegisterEvent("CHAT_MSG_PARTY_LEADER")
    eventFrame:RegisterEvent("CHAT_MSG_INSTANCE_CHAT")
    eventFrame:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER")

    CrateTrackerZK.eventFrame = eventFrame
    return eventFrame
end

function EventRouter:RegisterTooltipHooks()
    if CrateTrackerZK.tooltipHookRegistered then
        return
    end

    local updatePhase = function()
        if CoreShared:IsAreaActive() and Phase then
            local currentMapID = CoreShared:GetCurrentMapID()
            Phase:UpdatePhaseInfo(currentMapID)
        end
    end

    if TooltipDataProcessor then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, updatePhase)
    else
        GameTooltip:HookScript("OnTooltipSetUnit", updatePhase)
    end

    CrateTrackerZK.tooltipHookRegistered = true
end

return EventRouter

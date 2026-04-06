-- EventRouter.lua - Core 事件路由与钩子注册

local EventRouter = BuildEnv("CrateTrackerZKEventRouter")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local CoreShared = BuildEnv("CrateTrackerZKCoreShared")
local AddonLifecycle = BuildEnv("CrateTrackerZKAddonLifecycle")
local TickerController = BuildEnv("CrateTrackerZKTickerController")

local MONSTER_CHAT_EVENTS = {
    CHAT_MSG_MONSTER_SAY = true,
    CHAT_MSG_MONSTER_YELL = true,
    CHAT_MSG_MONSTER_EMOTE = true,
    CHAT_MSG_MONSTER_PARTY = true,
    CHAT_MSG_MONSTER_WHISPER = true,
    CHAT_MSG_RAID_BOSS_EMOTE = true,
    CHAT_MSG_RAID_BOSS_WHISPER = true,
}

local TEAM_ADDON_EVENT = "CHAT_MSG_ADDON"

local function HandleZoneChanged()
    C_Timer.After(0.1, function()
        local currentMapID = CoreShared:GetCurrentMapID()
        if Area then
            Area:CheckAndUpdateAreaValid(currentMapID)
        end
        if TeamCommListener and TeamCommListener.RegisterAddonPrefix then
            TeamCommListener:RegisterAddonPrefix()
        end
        if PublicChannelSyncListener
            and PublicChannelSyncListener.EnsureBroadcastChannelAvailable
            and PublicChannelSyncListener.IsFeatureEnabled
            and PublicChannelSyncListener:IsFeatureEnabled() == true then
            PublicChannelSyncListener:EnsureBroadcastChannelAvailable()
        end
        if CoreShared:IsAreaActive() then
            if TimerManager then TimerManager:DetectMapIcons(currentMapID) end
            if Phase then
                Phase:UpdatePhaseInfo(currentMapID)
            end
        end
        if TickerController and TickerController.RefreshPhaseTicker then
            TickerController:RefreshPhaseTicker(CrateTrackerZK)
        end
    end)
end

local function HandleGroupRosterUpdate()
    if TeamCommListener and TeamCommListener.RegisterAddonPrefix then
        TeamCommListener:RegisterAddonPrefix()
    end
end

local function HandlePlayerTargetChanged()
    if CoreShared:IsAreaActive() and Phase then
        local currentMapID = CoreShared:GetCurrentMapID()
        Phase:UpdatePhaseInfo(currentMapID)
    end
    if TickerController and TickerController.RefreshPhaseTicker then
        TickerController:RefreshPhaseTicker(CrateTrackerZK)
    end
end

local function HandleMouseoverUnitChanged()
    if CoreShared:IsAreaActive() and Phase then
        local currentMapID = CoreShared:GetCurrentMapID()
        Phase:UpdatePhaseInfo(currentMapID)
    end
    if TickerController and TickerController.RefreshPhaseTicker then
        TickerController:RefreshPhaseTicker(CrateTrackerZK)
    end
end

local function HandlePlayerLogout()
    if Phase and Phase.Reset then
        Phase:Reset()
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

local function DispatchAddonListener(listener, event, prefix, payload, chatType, sender, ...)
    if listener and listener.IsFeatureEnabled and listener:IsFeatureEnabled() ~= true then
        return false
    end
    if not listener or type(listener.ADDON_PREFIX) ~= "string" or prefix ~= listener.ADDON_PREFIX then
        return false
    end
    if not listener.HandleAddonEvent then
        return false
    end
    return listener:HandleAddonEvent(event, prefix, payload, chatType, sender, ...)
end

local function HandleTeamAddon(event, ...)
    if not CoreShared:CanProcessTeamMessages() then
        return
    end
    local prefix = select(1, ...)
    if type(prefix) ~= "string" or prefix == "" then
        return
    end
    local payload = select(2, ...)
    local chatType = select(3, ...)
    local sender = select(4, ...)
    local target = select(5, ...)
    local zoneChannelID = select(6, ...)
    local localChannelID = select(7, ...)
    local channelName = select(8, ...)
    local instanceID = select(9, ...)

    DispatchAddonListener(TeamCommListener, event, prefix, payload, chatType, sender, target, zoneChannelID, localChannelID, channelName, instanceID)
    DispatchAddonListener(PublicChannelSyncListener, event, prefix, payload, chatType, sender, target, zoneChannelID, localChannelID, channelName, instanceID)
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
    elseif event == "GROUP_ROSTER_UPDATE" then
        HandleGroupRosterUpdate()
    elseif event == "PLAYER_TARGET_CHANGED" then
        HandlePlayerTargetChanged()
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        HandleMouseoverUnitChanged()
    elseif event == "PLAYER_LOGOUT" then
        HandlePlayerLogout()
    elseif MONSTER_CHAT_EVENTS[event] then
        HandleMonsterChat(event, ...)
    elseif event == TEAM_ADDON_EVENT then
        HandleTeamAddon(event, ...)
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
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    eventFrame:RegisterEvent("PLAYER_LOGOUT")
    eventFrame:RegisterEvent("CHAT_MSG_MONSTER_SAY")
    eventFrame:RegisterEvent("CHAT_MSG_MONSTER_YELL")
    eventFrame:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
    eventFrame:RegisterEvent("CHAT_MSG_MONSTER_PARTY")
    eventFrame:RegisterEvent("CHAT_MSG_MONSTER_WHISPER")
    eventFrame:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
    eventFrame:RegisterEvent("CHAT_MSG_RAID_BOSS_WHISPER")
    eventFrame:RegisterEvent("CHAT_MSG_ADDON")

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
        if TickerController and TickerController.RefreshPhaseTicker then
            TickerController:RefreshPhaseTicker(CrateTrackerZK)
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

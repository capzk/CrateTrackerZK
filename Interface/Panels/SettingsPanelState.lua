-- SettingsPanelState.lua - 设置面板状态与配置读取

local SettingsPanelState = BuildEnv("CrateTrackerZKSettingsPanelState")
local AddonControlService = BuildEnv("AddonControlService")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local Notification = BuildEnv("Notification")
local ThemeConfig = BuildEnv("ThemeConfig")
local ExpansionConfig = BuildEnv("ExpansionConfig")
local Data = BuildEnv("Data")
local Localization = BuildEnv("Localization")

function SettingsPanelState:LT(key, fallback)
    local L = CrateTrackerZK and CrateTrackerZK.L
    if L and L[key] then
        return L[key]
    end
    return fallback
end

function SettingsPanelState:IsAddonEnabled()
    if AddonControlService and AddonControlService.IsAddonEnabled then
        return AddonControlService:IsAddonEnabled()
    end
    if not CRATETRACKERZK_UI_DB or CRATETRACKERZK_UI_DB.addonEnabled == nil then
        return true
    end
    return CRATETRACKERZK_UI_DB.addonEnabled == true
end

function SettingsPanelState:IsTeamNotificationEnabled()
    if CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.teamNotificationEnabled ~= nil then
        return CRATETRACKERZK_UI_DB.teamNotificationEnabled == true
    end
    if Notification and Notification.IsTeamNotificationEnabled then
        return Notification:IsTeamNotificationEnabled()
    end
    return true
end

function SettingsPanelState:IsSoundAlertEnabled()
    if CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.soundAlertEnabled ~= nil then
        return CRATETRACKERZK_UI_DB.soundAlertEnabled == true
    end
    if Notification and Notification.IsSoundAlertEnabled then
        return Notification:IsSoundAlertEnabled()
    end
    return true
end

function SettingsPanelState:IsAutoTeamReportEnabled()
    if Notification and Notification.IsAutoTeamReportEnabled then
        return Notification:IsAutoTeamReportEnabled()
    end
    return false
end

function SettingsPanelState:GetAutoTeamReportInterval()
    if CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.autoTeamReportInterval ~= nil then
        local value = tonumber(CRATETRACKERZK_UI_DB.autoTeamReportInterval)
        if value and value > 0 then
            return math.floor(value)
        end
    end
    if Notification and Notification.GetAutoTeamReportInterval then
        return Notification:GetAutoTeamReportInterval()
    end
    return 60
end

function SettingsPanelState:IsThemeSwitchEnabled()
    return ThemeConfig and ThemeConfig.IsSwitchEnabled and ThemeConfig:IsSwitchEnabled()
end

function SettingsPanelState:GetThemeOptions()
    if ThemeConfig and ThemeConfig.GetThemeList then
        return ThemeConfig:GetThemeList() or {}
    end
    return {}
end

function SettingsPanelState:GetCurrentThemeButtonText()
    if not self:IsThemeSwitchEnabled() then
        return self:LT("SettingsToggleOff", "已关闭")
    end
    local currentID = ThemeConfig and ThemeConfig.GetCurrentThemeID and ThemeConfig.GetCurrentThemeID()
    local options = self:GetThemeOptions()
    for _, option in ipairs(options) do
        if option.id == currentID then
            return option.label or option.id
        end
    end
    return currentID or "N/A"
end

function SettingsPanelState:GetMapDisplayName(mapID)
    if Localization and Localization.GetMapName then
        return Localization:GetMapName(mapID)
    end
    return "Map " .. tostring(mapID)
end

function SettingsPanelState:GetTrackedMapGroups()
    local result = {}
    local expansions = ExpansionConfig and ExpansionConfig.GetAvailableExpansions and ExpansionConfig:GetAvailableExpansions() or {}

    for _, expansionInfo in ipairs(expansions) do
        local group = {
            id = expansionInfo.id,
            label = expansionInfo.label or expansionInfo.id,
            maps = {},
            anyTracked = false,
            allTracked = false,
        }

        local trackedCount = 0
        local mapCount = 0
        local maps = ExpansionConfig and ExpansionConfig.GetExpansionMaps and ExpansionConfig:GetExpansionMaps(expansionInfo.id) or {}
        for _, mapInfo in ipairs(maps) do
            if type(mapInfo.mapID) == "number" and not (ExpansionConfig and ExpansionConfig.IsMainCityMap and ExpansionConfig:IsMainCityMap(mapInfo.mapID)) then
                local tracked = Data and Data.IsMapTracked and Data:IsMapTracked(expansionInfo.id, mapInfo.mapID) or false
                mapCount = mapCount + 1
                if tracked then
                    trackedCount = trackedCount + 1
                end
                group.maps[#group.maps + 1] = {
                    id = mapInfo.mapID,
                    label = self:GetMapDisplayName(mapInfo.mapID),
                    tracked = tracked,
                }
            end
        end

        group.anyTracked = trackedCount > 0
        group.allTracked = mapCount > 0 and trackedCount == mapCount
        result[#result + 1] = group
    end

    return result
end

function SettingsPanelState:GetSettingsSnapshot()
    local addonEnabled = self:IsAddonEnabled()
    local teamEnabled = addonEnabled and self:IsTeamNotificationEnabled()
    local soundEnabled = addonEnabled and self:IsSoundAlertEnabled()
    local autoEnabled = addonEnabled and teamEnabled and self:IsAutoTeamReportEnabled()

    return {
        addonEnabled = addonEnabled,
        teamNotificationEnabled = teamEnabled,
        teamNotificationInteractable = addonEnabled,
        soundAlertEnabled = soundEnabled,
        soundAlertInteractable = addonEnabled,
        autoReportEnabled = autoEnabled,
        autoReportInteractable = addonEnabled and teamEnabled,
        autoReportInterval = self:GetAutoTeamReportInterval(),
        autoReportIntervalInteractable = addonEnabled and teamEnabled and autoEnabled,
        themeEnabled = self:IsThemeSwitchEnabled(),
        themeText = self:GetCurrentThemeButtonText(),
        mapGroups = self:GetTrackedMapGroups(),
    }
end

return SettingsPanelState

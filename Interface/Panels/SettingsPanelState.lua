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

function SettingsPanelState:IsExpansionSwitchEnabled()
    return ExpansionConfig and ExpansionConfig.IsSwitchEnabled and ExpansionConfig:IsSwitchEnabled()
end

function SettingsPanelState:GetCurrentExpansionID()
    if Data and Data.GetCurrentExpansionID then
        local expansionID = Data:GetCurrentExpansionID()
        if expansionID then
            return expansionID
        end
    end
    if ExpansionConfig and ExpansionConfig.GetCurrentExpansionID then
        return ExpansionConfig:GetCurrentExpansionID()
    end
    return nil
end

function SettingsPanelState:GetAvailableExpansions()
    if ExpansionConfig and ExpansionConfig.GetAvailableExpansions then
        return ExpansionConfig:GetAvailableExpansions() or {}
    end
    return {}
end

function SettingsPanelState:GetExpansionOptions()
    return self:GetAvailableExpansions()
end

function SettingsPanelState:GetCurrentExpansionButtonText()
    if not self:IsExpansionSwitchEnabled() then
        return self:LT("SettingsToggleOff", "已关闭")
    end
    local expansionID = self:GetCurrentExpansionID()
    local options = self:GetAvailableExpansions()
    for _, option in ipairs(options) do
        if option.id == expansionID then
            return option.id
        end
    end
    return expansionID or "N/A"
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

function SettingsPanelState:GetExpansionMapOptions(expansionID)
    local result = {}
    local targetExpansionID = expansionID or self:GetCurrentExpansionID()
    local expansion = ExpansionConfig and ExpansionConfig.expansions and ExpansionConfig.expansions[targetExpansionID]
    if not expansion then
        return result
    end

    local hiddenMaps = (Data and Data.GetHiddenMaps and Data:GetHiddenMaps(targetExpansionID)) or {}
    for _, mapID in ipairs(expansion.mapIDs or {}) do
        if type(mapID) == "number" and not (ExpansionConfig and ExpansionConfig.IsMainCityMap and ExpansionConfig:IsMainCityMap(mapID)) then
            result[#result + 1] = {
                id = mapID,
                label = self:GetMapDisplayName(mapID),
                visible = hiddenMaps[mapID] ~= true,
            }
        end
    end

    return result
end

function SettingsPanelState:GetSettingsSnapshot()
    local addonEnabled = self:IsAddonEnabled()
    local teamEnabled = addonEnabled and self:IsTeamNotificationEnabled()
    local soundEnabled = addonEnabled and self:IsSoundAlertEnabled()
    local autoEnabled = addonEnabled and teamEnabled and self:IsAutoTeamReportEnabled()
    local currentExpansionID = self:GetCurrentExpansionID()

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
        currentExpansionID = currentExpansionID,
        expansionOptions = self:GetAvailableExpansions(),
        mapOptions = self:GetExpansionMapOptions(currentExpansionID),
    }
end

return SettingsPanelState

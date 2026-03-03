-- SettingsPanelState.lua - 设置面板状态与配置读取

local SettingsPanelState = BuildEnv("CrateTrackerZKSettingsPanelState")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local Notification = BuildEnv("Notification")
local ThemeConfig = BuildEnv("ThemeConfig")
local ExpansionConfig = BuildEnv("ExpansionConfig")

function SettingsPanelState:LT(key, fallback)
    local L = CrateTrackerZK and CrateTrackerZK.L
    if L and L[key] then
        return L[key]
    end
    return fallback
end

function SettingsPanelState:GetTabLabel(key)
    if key == "settings" then
        return self:LT("SettingsTabSettings", "设置")
    end
    if key == "help" then
        return self:LT("MenuHelp", "帮助")
    end
    if key == "about" then
        return self:LT("MenuAbout", "关于")
    end
    return tostring(key)
end

function SettingsPanelState:ResolveTabKey(tabName)
    if tabName == "settings" or tabName == "help" or tabName == "about" then
        return tabName
    end
    if tabName == self:GetTabLabel("settings") then
        return "settings"
    end
    if tabName == self:GetTabLabel("help") then
        return "help"
    end
    if tabName == self:GetTabLabel("about") then
        return "about"
    end
    return nil
end

function SettingsPanelState:IsAddonEnabled()
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

function SettingsPanelState:GetExpansionOptions()
    if ExpansionConfig and ExpansionConfig.GetAvailableExpansions then
        return ExpansionConfig:GetAvailableExpansions() or {}
    end
    return {}
end

function SettingsPanelState:GetCurrentExpansionButtonText()
    if not self:IsExpansionSwitchEnabled() then
        return self:LT("SettingsToggleOff", "已关闭")
    end
    local expansionID = ExpansionConfig and ExpansionConfig.GetCurrentExpansionID and ExpansionConfig:GetCurrentExpansionID()
    local options = self:GetExpansionOptions()
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

return SettingsPanelState

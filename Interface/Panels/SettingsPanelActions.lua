-- SettingsPanelActions.lua - 设置面板交互动作

local SettingsPanelActions = BuildEnv("CrateTrackerZKSettingsPanelActions")
local SettingsPanelState = BuildEnv("CrateTrackerZKSettingsPanelState")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local Commands = BuildEnv("Commands")
local Notification = BuildEnv("Notification")
local MainPanel = BuildEnv("MainPanel")
local Data = BuildEnv("Data")
local ExpansionConfig = BuildEnv("ExpansionConfig")
local ThemeConfig = BuildEnv("ThemeConfig")

function SettingsPanelActions:SetAddonEnabled(enabled)
    if Commands and Commands.HandleAddonToggle then
        Commands:HandleAddonToggle(enabled == true)
    end
end

function SettingsPanelActions:SetTeamNotificationEnabled(enabled)
    if Notification and Notification.SetTeamNotificationEnabled then
        Notification:SetTeamNotificationEnabled(enabled == true)
    end
end

function SettingsPanelActions:SetSoundAlertEnabled(enabled)
    if Notification and Notification.SetSoundAlertEnabled then
        Notification:SetSoundAlertEnabled(enabled == true)
    end
end

function SettingsPanelActions:SetAutoTeamReportEnabled(enabled)
    if Notification and Notification.SetAutoTeamReportEnabled then
        Notification:SetAutoTeamReportEnabled(enabled == true)
    end
end

function SettingsPanelActions:CycleExpansionVersion()
    if not SettingsPanelState or not SettingsPanelState.IsExpansionSwitchEnabled or not SettingsPanelState:IsExpansionSwitchEnabled() then
        return
    end
    if not ExpansionConfig or not ExpansionConfig.GetCurrentExpansionID or not ExpansionConfig.GetNextExpansionID then
        return
    end

    local currentID = ExpansionConfig:GetCurrentExpansionID()
    local nextID = ExpansionConfig:GetNextExpansionID(currentID)
    if not nextID or nextID == currentID then
        return
    end

    if Data and Data.SwitchExpansion then
        Data:SwitchExpansion(nextID)
    elseif ExpansionConfig.SetCurrentExpansionID then
        ExpansionConfig:SetCurrentExpansionID(nextID)
    end

    if CrateTrackerZK and CrateTrackerZK.Reinitialize then
        CrateTrackerZK:Reinitialize()
    end
end

function SettingsPanelActions:SetExpansionVersion(expansionID)
    local currentExpansionID = SettingsPanelState and SettingsPanelState.GetCurrentExpansionID and SettingsPanelState:GetCurrentExpansionID() or nil
    if not expansionID or expansionID == currentExpansionID then
        return
    end

    if Data and Data.SwitchExpansion then
        Data:SwitchExpansion(expansionID)
    elseif ExpansionConfig and ExpansionConfig.SetCurrentExpansionID then
        ExpansionConfig:SetCurrentExpansionID(expansionID)
    end

    if CrateTrackerZK and CrateTrackerZK.Reinitialize then
        CrateTrackerZK:Reinitialize()
    end
end

function SettingsPanelActions:SetMapVisibleForExpansion(expansionID, mapID, visible)
    if not expansionID or type(mapID) ~= "number" then
        return
    end

    local currentExpansionID = SettingsPanelState and SettingsPanelState.GetCurrentExpansionID and SettingsPanelState:GetCurrentExpansionID() or nil
    if currentExpansionID == expansionID and Data and Data.GetMapByMapID then
        local mapData = Data:GetMapByMapID(mapID)
        if mapData and mapData.id then
            if visible then
                if MainPanel and MainPanel.RestoreMap then
                    MainPanel:RestoreMap(mapData.id)
                end
            else
                if MainPanel and MainPanel.HideMap then
                    MainPanel:HideMap(mapData.id)
                end
            end
            return
        end
    end

    if not Data or not Data.GetHiddenMaps or not Data.GetHiddenRemaining then
        return
    end

    local hiddenMaps = Data:GetHiddenMaps(expansionID)
    local hiddenRemaining = Data:GetHiddenRemaining(expansionID)
    if type(hiddenMaps) ~= "table" or type(hiddenRemaining) ~= "table" then
        return
    end

    if visible then
        hiddenMaps[mapID] = nil
        hiddenRemaining[mapID] = nil
    else
        hiddenMaps[mapID] = true
    end

    if currentExpansionID == expansionID and MainPanel and MainPanel.UpdateTable then
        MainPanel:UpdateTable(true)
    end
end

function SettingsPanelActions:CycleTheme()
    if not SettingsPanelState or not SettingsPanelState.IsThemeSwitchEnabled or not SettingsPanelState:IsThemeSwitchEnabled() then
        return
    end
    if not ThemeConfig or not ThemeConfig.GetCurrentThemeID or not ThemeConfig.SetCurrentThemeID then
        return
    end
    local options = SettingsPanelState and SettingsPanelState.GetThemeOptions and SettingsPanelState:GetThemeOptions() or {}
    if #options == 0 then
        return
    end

    local currentID = ThemeConfig.GetCurrentThemeID()
    local currentIndex = 1
    for i, option in ipairs(options) do
        if option.id == currentID then
            currentIndex = i
            break
        end
    end
    local nextIndex = currentIndex + 1
    if nextIndex > #options then
        nextIndex = 1
    end
    local nextID = options[nextIndex].id
    if nextID then
        ThemeConfig:SetCurrentThemeID(nextID)
    end

    if MainPanel and MainPanel.RefreshTheme then
        MainPanel:RefreshTheme()
    elseif MainPanel and MainPanel.UpdateTable then
        MainPanel:UpdateTable()
    end
end

function SettingsPanelActions:EnsureClearDialog()
    if not StaticPopupDialogs or StaticPopupDialogs["CRATETRACKERZK_CLEAR_DATA"] then
        return
    end

    local lt = SettingsPanelState and SettingsPanelState.LT
    StaticPopupDialogs["CRATETRACKERZK_CLEAR_DATA"] = {
        text = lt and SettingsPanelState:LT("SettingsClearConfirmText", "确认清除所有数据并重新初始化？该操作不可撤销。")
            or "确认清除所有数据并重新初始化？该操作不可撤销。",
        button1 = lt and SettingsPanelState:LT("SettingsClearConfirmYes", "确认") or "确认",
        button2 = lt and SettingsPanelState:LT("SettingsClearConfirmNo", "取消") or "取消",
        OnAccept = function()
            if Commands and Commands.HandleClearCommand then
                Commands:HandleClearCommand()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
end

function SettingsPanelActions:ApplyAutoTeamReportInterval(editBox)
    if not editBox then
        return
    end
    local value = editBox:GetText()
    local applied = nil
    if Notification and Notification.SetAutoTeamReportInterval then
        applied = Notification:SetAutoTeamReportInterval(value)
    end
    if applied then
        editBox:SetText(tostring(applied))
    else
        local fallback = SettingsPanelState and SettingsPanelState.GetAutoTeamReportInterval and SettingsPanelState:GetAutoTeamReportInterval() or 60
        editBox:SetText(tostring(fallback))
    end
end

return SettingsPanelActions

-- SettingsPanelActions.lua - 设置面板交互动作

local SettingsPanelActions = BuildEnv("CrateTrackerZKSettingsPanelActions")
local SettingsPanelState = BuildEnv("CrateTrackerZKSettingsPanelState")
local AddonControlService = BuildEnv("AddonControlService")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local Commands = BuildEnv("Commands")
local Notification = BuildEnv("Notification")
local MainPanel = BuildEnv("MainPanel")
local Data = BuildEnv("Data")
local ExpansionConfig = BuildEnv("ExpansionConfig")
local ThemeConfig = BuildEnv("ThemeConfig")

function SettingsPanelActions:SetAddonEnabled(enabled)
    if AddonControlService and AddonControlService.ApplyAddonEnabled then
        AddonControlService:ApplyAddonEnabled(enabled == true)
    elseif Commands and Commands.HandleAddonToggle then
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
    if AddonControlService and AddonControlService.CycleExpansionVersion then
        AddonControlService:CycleExpansionVersion()
    end
end

function SettingsPanelActions:SetExpansionVersion(expansionID)
    local currentExpansionID = SettingsPanelState and SettingsPanelState.GetCurrentExpansionID and SettingsPanelState:GetCurrentExpansionID() or nil
    if not expansionID or expansionID == currentExpansionID then
        return
    end

    if AddonControlService and AddonControlService.SwitchExpansionVersion then
        AddonControlService:SwitchExpansionVersion(expansionID)
    end
end

function SettingsPanelActions:SetMapVisibleForExpansion(expansionID, mapID, visible)
    if AddonControlService and AddonControlService.SetMapVisibleForExpansion then
        AddonControlService:SetMapVisibleForExpansion(expansionID, mapID, visible)
    end
end

function SettingsPanelActions:CycleTheme()
    if AddonControlService and AddonControlService.CycleTheme then
        AddonControlService:CycleTheme()
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
            if AddonControlService and AddonControlService.ClearDataAndReinitialize then
                AddonControlService:ClearDataAndReinitialize()
            elseif Commands and Commands.HandleClearCommand then
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

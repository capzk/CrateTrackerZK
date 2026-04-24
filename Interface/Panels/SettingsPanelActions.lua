-- SettingsPanelActions.lua - 设置面板交互动作

local SettingsPanelActions = BuildEnv("CrateTrackerZKSettingsPanelActions")
local SettingsPanelState = BuildEnv("CrateTrackerZKSettingsPanelState")
local AddonControlService = BuildEnv("AddonControlService")
local Commands = BuildEnv("Commands")
local Notification = BuildEnv("Notification")
local AirdropTrajectoryService = BuildEnv("AirdropTrajectoryService")

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

function SettingsPanelActions:SetLeaderModeEnabled(enabled)
    if Notification and Notification.SetLeaderModeEnabled then
        Notification:SetLeaderModeEnabled(enabled == true)
    end
end

function SettingsPanelActions:SetPhaseTeamAlertEnabled(enabled)
    if Notification and Notification.SetPhaseTeamAlertEnabled then
        Notification:SetPhaseTeamAlertEnabled(enabled == true)
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

function SettingsPanelActions:SetTrajectoryPredictionEnabled(enabled)
    if AirdropTrajectoryService and AirdropTrajectoryService.SetPredictionEnabled then
        AirdropTrajectoryService:SetPredictionEnabled(enabled == true)
    end
end

function SettingsPanelActions:SetTrackedMap(expansionID, mapID, tracked)
    if AddonControlService and AddonControlService.SetMapTracked then
        AddonControlService:SetMapTracked(expansionID, mapID, tracked == true)
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

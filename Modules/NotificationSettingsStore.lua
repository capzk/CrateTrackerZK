-- NotificationSettingsStore.lua - 通知配置存储

local NotificationSettingsStore = BuildEnv("NotificationSettingsStore")
local AppSettingsStore = BuildEnv("AppSettingsStore")

NotificationSettingsStore.DEFAULTS = {
    teamNotificationEnabled = true,
    leaderModeEnabled = false,
    phaseTeamAlertEnabled = false,
    soundAlertEnabled = true,
    autoTeamReportEnabled = false,
    autoTeamReportInterval = 60,
}

function NotificationSettingsStore:Load()
    return {
        teamNotificationEnabled = AppSettingsStore:GetBoolean("teamNotificationEnabled", self.DEFAULTS.teamNotificationEnabled),
        leaderModeEnabled = AppSettingsStore:GetBoolean("leaderModeEnabled", self.DEFAULTS.leaderModeEnabled),
        phaseTeamAlertEnabled = AppSettingsStore:GetBoolean("phaseTeamAlertEnabled", self.DEFAULTS.phaseTeamAlertEnabled),
        soundAlertEnabled = AppSettingsStore:GetBoolean("soundAlertEnabled", self.DEFAULTS.soundAlertEnabled),
        autoTeamReportEnabled = AppSettingsStore:GetBoolean("autoTeamReportEnabled", self.DEFAULTS.autoTeamReportEnabled),
        autoTeamReportInterval = math.floor(AppSettingsStore:GetNumber("autoTeamReportInterval", self.DEFAULTS.autoTeamReportInterval) or self.DEFAULTS.autoTeamReportInterval),
    }
end

function NotificationSettingsStore:SetTeamNotificationEnabled(enabled)
    return AppSettingsStore:SetBoolean("teamNotificationEnabled", enabled == true)
end

function NotificationSettingsStore:SetLeaderModeEnabled(enabled)
    return AppSettingsStore:SetBoolean("leaderModeEnabled", enabled == true)
end

function NotificationSettingsStore:SetPhaseTeamAlertEnabled(enabled)
    return AppSettingsStore:SetBoolean("phaseTeamAlertEnabled", enabled == true)
end

function NotificationSettingsStore:SetSoundAlertEnabled(enabled)
    return AppSettingsStore:SetBoolean("soundAlertEnabled", enabled == true)
end

function NotificationSettingsStore:SetAutoTeamReportEnabled(enabled)
    return AppSettingsStore:SetBoolean("autoTeamReportEnabled", enabled == true)
end

function NotificationSettingsStore:SetAutoTeamReportInterval(seconds)
    return AppSettingsStore:SetNumber("autoTeamReportInterval", seconds)
end

return NotificationSettingsStore

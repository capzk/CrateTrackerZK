-- CrateTrackerZK - English Localization
local LocaleManager = BuildEnv("LocaleManager");
if not LocaleManager or not LocaleManager.RegisterLocale then
    if LocaleManager then
        LocaleManager.failedLocales = LocaleManager.failedLocales or {};
        table.insert(LocaleManager.failedLocales, {
            locale = "enUS",
            reason = "RegisterLocale function not available"
        });
    end
    return;
end

local localeData = {};

-- General

-- Floating Button
localeData["FloatingButtonTooltipLine3"] = "Right-click to open settings";

localeData["MiniModeTooltipLine1"] = "Right-click to notify";

-- Notifications (Airdrop)
localeData["Enabled"] = "Team notifications enabled";
localeData["Disabled"] = "Team notifications disabled";
localeData["AirdropDetected"] = "[%s] Detected War Supplies airdrop!!!";  -- Auto detection message (with "Detected" keyword)
localeData["AirdropDetectedManual"] = "[%s] War Supplies airdrop!!!";  -- Manual notification message (without "Detected" keyword)
localeData["NoTimeRecord"] = "[%s] No time record!!!";
localeData["TimeRemaining"] = "[%s] War Supplies airdrop in: %s!!!";
localeData["AutoTeamReportMessage"] = "Current [%s] War Supplies in: %s!!";

-- Phase Detection Alerts
localeData["PhaseDetectedFirstTime"] = "[%s] Current phasing ID: |cffffff00%s|r";
localeData["InstanceChangedTo"] = "[%s] Current phasing ID changed to: |cffffff00%s|r";

-- UI
localeData["MapName"] = "Map Name";
localeData["PhaseID"] = "Current Phase";
localeData["LastRefresh"] = "Last Refresh";
localeData["NextRefresh"] = "Next Refresh";
localeData["Operation"] = "Operation";
localeData["Notify"] = "Alert";
localeData["Delete"] = "Delete";
localeData["Restore"] = "Restore";
localeData["NotAcquired"] = "---:---";
localeData["NoRecord"] = "--:--";
localeData["MinuteSecond"] = "%d min %02d sec";
-- Menu Items
localeData["MenuHelp"] = "Help";
localeData["MenuAbout"] = "About";

-- Settings Panel
localeData["SettingsPanelTitle"] = "CrateTrackerZK - Settings";
localeData["SettingsTabSettings"] = "Settings";
localeData["SettingsSectionControl"] = "Addon Control";
localeData["SettingsSectionData"] = "Data Management";
localeData["SettingsSectionUI"] = "UI Settings";
localeData["SettingsMiniModeCollapsedRows"] = "Rows kept after mini mode collapses";
localeData["SettingsAddonToggle"] = "Addon Toggle";
localeData["SettingsTeamNotify"] = "Team Notifications";
localeData["SettingsAutoReport"] = "Auto Notify";
localeData["SettingsAutoReportInterval"] = "Report Interval (sec)";
localeData["SettingsClearAllData"] = "Clear All Data";
localeData["SettingsClearButton"] = "Clear";
localeData["SettingsClearDesc"] = "• Clears all airdrop time and phase records";
localeData["SettingsUIConfigDesc"] = "• UI style can be adjusted in UiConfig.lua";
localeData["SettingsReloadDesc"] = "• Use /reload after changes";
localeData["SettingsToggleOn"] = "Enabled";
localeData["SettingsToggleOff"] = "Disabled";
localeData["SettingsClearConfirmText"] = "Clear all data and reinitialize? This action cannot be undone.";
localeData["SettingsClearConfirmYes"] = "Confirm";
localeData["SettingsClearConfirmNo"] = "Cancel";

-- Airdrop NPC shouts (optional for shout detection and efficiency; can be omitted or left as default)
localeData.AirdropShouts = {
    "Ruffious says: Opportunity's knocking! If you've got the mettle, there are valuables waiting to be won.",
    "Ruffious says: I see some valuable resources in the area! Get ready to grab them!",
    "Ruffious says: There's a cache of resources nearby. Find it before you have to fight over it!",
    "Ruffious says: Looks like there's treasure nearby. And that means treasure hunters. Watch your back.",
};

-- Register this locale
LocaleManager.RegisterLocale("enUS", localeData);

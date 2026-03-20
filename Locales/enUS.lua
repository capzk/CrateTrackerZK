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

-- Floating Button
localeData["FloatingButtonTooltipLine3"] = "Right-click to open settings";

-- Notifications (Airdrop)
localeData["Enabled"] = "Team notifications enabled";
localeData["Disabled"] = "Team notifications disabled";
localeData["AirdropDetected"] = "[%s] Detected War Supplies airdrop!!!";  -- Auto detection message (with "Detected" keyword)
localeData["AirdropDetectedManual"] = "[%s] War Supplies airdrop!!!";  -- Manual notification message (without "Detected" keyword)
localeData["NoTimeRecord"] = "[%s] No time record!!!";
localeData["TimeRemaining"] = "[%s] War Supplies airdrop in: %s!!!";
localeData["AutoTeamReportMessage"] = "Current [%s] War Supplies airdrop in: %s!!";

-- Phase Detection Alerts
localeData["PhaseDetectedFirstTime"] = "[%s] Current phase: |cffffff00%s|r";
localeData["InstanceChangedTo"] = "[%s] Current phase changed to: |cffffff00%s|r";

-- UI
localeData["MapName"] = "Map Name";
localeData["PhaseID"] = "Current Phase";
localeData["LastRefresh"] = "Last Refresh";
localeData["NextRefresh"] = "Next Refresh";
localeData["NotAcquired"] = "---:---";
localeData["NoRecord"] = "--:--";
localeData["MinuteSecond"] = "%d min %02d sec";
-- Menu Items
localeData["MenuHelp"] = "Help";
localeData["MenuAbout"] = "About";

-- Settings Panel
localeData["SettingsSectionExpansion"] = "Version Settings";
localeData["SettingsSectionControl"] = "Addon Control";
localeData["SettingsSectionData"] = "Data Management";
localeData["SettingsSectionUI"] = "UI Settings";
localeData["SettingsMainPage"] = "Main Settings";
localeData["SettingsMessages"] = "Message Settings";
localeData["SettingsMapList"] = "Map List";
localeData["SettingsExpansionVersion"] = "Map Version";
localeData["SettingsThemeSwitch"] = "Theme";
localeData["SettingsAddonToggle"] = "Addon Toggle";
localeData["SettingsTeamNotify"] = "Team Notifications";
localeData["SettingsSoundAlert"] = "Sound Alert";
localeData["SettingsAutoReport"] = "Auto Notify";
localeData["SettingsAutoReportInterval"] = "Report Interval (sec)";
localeData["SettingsClearButton"] = "Clear Local Data";
localeData["SettingsToggleOn"] = "Enabled";
localeData["SettingsToggleOff"] = "Disabled";
localeData["SettingsClearConfirmText"] = "Clear all data and reinitialize? This action cannot be undone.";
localeData["SettingsClearConfirmYes"] = "Confirm";
localeData["SettingsClearConfirmNo"] = "Cancel";

-- Airdrop NPC shouts (optional for shout detection and efficiency; can be omitted or left as default)
localeData.AirdropShouts = {
    --11.0
    "Ruffious says: Opportunity's knocking! If you've got the mettle, there are valuables waiting to be won.",
    "Ruffious says: I see some valuable resources in the area! Get ready to grab them!",
    "Ruffious says: There's a cache of resources nearby. Find it before you have to fight over it!",
    "Ruffious says: Looks like there's treasure nearby. And that means treasure hunters. Watch your back.",
    --12.0
    "Ziadan says: Take the early advantage and get your spoils.",
    "Ziadan says: That looks like a treasure out in the distance. Don't miss this opportunity!",
    "Vidious says: Keep an eye out for opportunities for loot when they arise, like now!",
    "Vidious says: You like goods don't you? Then find them.",
};

localeData["SettingsHelpText"] = [[
Usage Guide

1. The main UI countdown supports mouse click message sending:
   Left click: sends "[Map] War Supplies airdrop in: Time"
   Right click: sends "Current [Map] War Supplies airdrop in: Time"

2. Message Settings page options:
   Message Settings: controls manual and automatic message sending behavior
   Team Notifications: when enabled, messages are sent to party, raid, or instance chat
   Sound Alert: when enabled, a sound plays when an airdrop is detected
   Auto Notify: when enabled, automatically sends the nearest airdrop countdown at the configured interval
   Report Interval (sec): sets the interval for automatic countdown messages
]];

-- Register this locale
LocaleManager.RegisterLocale("enUS", localeData);

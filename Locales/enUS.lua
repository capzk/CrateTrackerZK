-- CrateTrackerZK - English Localization
-- This file contains only translation data, no logic
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
localeData["AddonLoaded"] = "Addon loaded, enjoy your game!";
localeData["HelpCommandHint"] = "Use |cffffcc00/ctk help|r to view help information";
localeData["CrateTrackerZK"] = "CrateTrackerZK";

-- Floating Button
localeData["FloatingButtonTooltipTitle"] = "CrateTrackerZK";
localeData["FloatingButtonTooltipLine1"] = "Click to open/close tracking panel";
localeData["FloatingButtonTooltipLine2"] = "Drag to move button position";

-- Phase Detection
localeData["NoInstanceAcquiredHint"] = "No phasing ID acquired. Please hover over any NPC to get current phasing ID";
localeData["CurrentInstanceID"] = "Current phasing ID: |cffffff00%s|r";
localeData["InstanceChangedTo"] = "Map [|cffffcc00%s|r] phasing ID changed to: |cffffff00%s|r";

-- Message Prefix
localeData["Prefix"] = "|cff00ff88[CrateTrackerZK]|r ";

-- Errors/Hints
localeData["CommandModuleNotLoaded"] = "Command module not loaded, please reload addon";
localeData["LocalizationWarning"] = "Warning";
localeData["LocalizationCritical"] = "Critical";
localeData["LocalizationMissingTranslation"] = "[Localization %s] Missing translation: %s.%s";
localeData["LocalizationFallbackWarning"] = "Warning: Locale file for %s not found, fallback to %s";
localeData["LocalizationNoLocaleError"] = "Error: No available locale file found";
localeData["LocalizationMissingTranslationsWarning"] = "Warning: Found %d missing critical translations (%s)";
localeData["LocalizationMissingMapNames"] = "Missing map names: %s";
localeData["LocalizationMissingCrateNames"] = "Missing airdrop crate names: %s";
localeData["LocalizationFailedLocalesWarning"] = "Warning: %d locale files failed to load";
localeData["MapNamesCount"] = "Missing map names: %d";
localeData["AirdropCratesCount"] = "Missing airdrop crate names: %d";

-- Notifications
localeData["TeamNotificationStatus"] = "Team notification %s";
localeData["AirdropDetected"] = "[%s] War Supplies airdrop detected!!!";
localeData["NoTimeRecord"] = "[%s] No time record!!!";
localeData["TimeRemaining"] = "[%s] War Supplies airdrop in: %s!!!";
localeData["Enabled"] = "Enabled";
localeData["Disabled"] = "Disabled";

-- Commands
localeData["UnknownCommand"] = "Unknown command: %s";
localeData["ClearingData"] = "Clearing all time and instance data...";
localeData["DataCleared"] = "All data cleared, addon reinitialized";
localeData["DataClearFailedModule"] = "Clear data failed: Data module not loaded";
localeData["ClearUsage"] = "Clear command: /ctk clear or /ctk reset";
localeData["NotificationModuleNotLoaded"] = "Notification module not loaded";
localeData["TeamUsage1"] = "Team notification commands:";
localeData["TeamUsage2"] = "/ctk team on - Enable team notification";
localeData["TeamUsage3"] = "/ctk team off - Disable team notification";
localeData["HelpTitle"] = "Available commands:";
localeData["HelpClear"] = "/ctk clear or /ctk reset - Clear all data and reinitialize addon";
localeData["HelpTeam"] = "/ctk team on|off - Enable/disable team notification";
localeData["HelpHelp"] = "/ctk help - Show this help information";
localeData["HelpUpdateWarning"] = "If any problem occurs after updating, please completely delete this addon folder and reinstall it from scratch!!";

localeData["ErrorTimerManagerNotInitialized"] = "Timer manager not initialized";
localeData["ErrorInvalidMapID"] = "Invalid map ID:";
localeData["ErrorTimerStartFailedMapID"] = "Timer start failed: Map ID=";
localeData["ErrorInvalidMapIDList"] = "Invalid map ID list";
localeData["ErrorMapNotFound"] = "Map not found:";
localeData["ErrorInvalidSourceParam"] = "Invalid detection source parameter";

-- UI
localeData["MainPanelTitle"] = "|cff00ff88[CrateTrackerZK]|r";
localeData["InfoButton"] = "Info";
localeData["AnnouncementButton"] = "Announcement";
localeData["IntroButton"] = "Introduction";
localeData["Map"] = "Map";
localeData["Phase"] = "Phasing";
localeData["LastRefresh"] = "Last Refresh";
localeData["NextRefresh"] = "Next Refresh";
localeData["Operation"] = "Operation";
localeData["Refresh"] = "Refresh";
localeData["Notify"] = "Notify";
localeData["NotAcquired"] = "Not Acquired";
localeData["NoRecord"] = "No Record";
localeData["MinuteSecond"] = "%dm%02ds";
localeData["InputTimeHint"] = "Please enter last refresh time (HH:MM:SS or HHMMSS):";
localeData["Confirm"] = "Confirm";
localeData["Cancel"] = "Cancel";
localeData["TimeFormatError"] = "Time format error, please enter HH:MM:SS or HHMMSS format";
localeData["TimestampError"] = "Unable to create valid timestamp";
localeData["InfoModuleNotLoaded"] = "Info module not loaded";
localeData["DataModuleNotLoaded"] = "Data module not loaded";
localeData["TimerManagerNotInitialized"] = "Timer manager not initialized";
localeData["Return"] = "Return";
localeData["UIFontSize"] = 15;

-- Menu Items
localeData["MenuHelp"] = "Help";
localeData["MenuAbout"] = "About";
localeData["MenuSettings"] = "Settings";

-- Map names (using map ID as key)
localeData.MapNames = {
    [2248] = "Isle of Dorn",      -- 多恩岛
    [2369] = "Siren Isle",        -- 海妖岛
    [2371] = "K'aresh",            -- 卡雷什
    [2346] = "Undermine",         -- 安德麦
    [2215] = "Hallowfall",        -- 陨圣峪
    [2214] = "The Ringing Deeps", -- 喧鸣深窟
    [2255] = "Azj-Kahet",         -- 艾基-卡赫特
};

-- Airdrop crate names
localeData.AirdropCrateNames = {
    ["WarSupplyCrate"] = "War Supply Crate",
};

-- Register this locale
LocaleManager.RegisterLocale("enUS", localeData);


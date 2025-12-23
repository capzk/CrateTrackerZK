-- CrateTrackerZK - English Localization
-- This file contains only translation data, no logic
local LocaleManager = BuildEnv("LocaleManager");
if not LocaleManager or not LocaleManager.RegisterLocale then
    -- 记录加载失败（如果 LocaleManager 已存在但 RegisterLocale 不存在）
    if LocaleManager then
        LocaleManager.failedLocales = LocaleManager.failedLocales or {};
        table.insert(LocaleManager.failedLocales, {
            locale = "enUS",
            reason = "RegisterLocale function not available"
        });
    end
    return; -- Locales.lua not loaded yet
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

-- Notifications
localeData["TeamNotificationStatus"] = "Team notification %s";
localeData["AirdropDetected"] = "[%s] War Supplies airdrop detected!!!";
localeData["NoTimeRecord"] = "[%s] No time record!!!";
localeData["TimeRemaining"] = "[%s] War Supplies airdrop in: %s!!!";
localeData["Enabled"] = "Enabled";
localeData["Disabled"] = "Disabled";

-- Commands
localeData["UnknownCommand"] = "Unknown command: %s";
localeData["DebugEnabled"] = "Debug information enabled";
localeData["DebugDisabled"] = "Debug information disabled";
localeData["DebugUsage"] = "Debug command: /ctk debug on|off";
localeData["ClearingData"] = "Clearing all time and instance data...";
localeData["DataCleared"] = "All time and instance data cleared, map list preserved";
localeData["DataClearFailedEmpty"] = "Clear data failed: map list is empty";
localeData["DataClearFailedModule"] = "Clear data failed: Data module not loaded";
localeData["ClearUsage"] = "Clear command: /ctk clear or /ctk reset";
localeData["NotificationModuleNotLoaded"] = "Notification module not loaded";
localeData["TeamNotificationStatusPrefix"] = "Team notification status: ";
localeData["TeamUsage1"] = "Team notification commands:";
localeData["TeamUsage2"] = "/ctk team on - Enable team notification";
localeData["TeamUsage3"] = "/ctk team off - Disable team notification";
localeData["TeamUsage4"] = "/ctk team status - View team notification status";
localeData["HelpTitle"] = "Available commands:";
localeData["HelpClear"] = "/ctk clear or /ctk reset - Clear all time and instance data (preserve map list)";
localeData["HelpTeam"] = "/ctk team on|off - Enable/disable team notification";
localeData["HelpStatus"] = "/ctk team status - View team notification status";
localeData["HelpHelp"] = "/ctk help - Show this help information";
localeData["HelpUpdateWarning"] = "If any problem occurs after updating, please completely delete this addon folder and reinstall it from scratch!!";

-- Debug Messages
localeData["DebugTimerStarted"] = "Timer started via %s, next refresh: %s";
localeData["DebugDetectionSourceManual"] = "Manual Input";
localeData["DebugDetectionSourceRefresh"] = "Refresh Button";
localeData["DebugDetectionSourceAPI"] = "API Interface";
localeData["DebugDetectionSourceMapIcon"] = "Map Icon Detection";
localeData["DebugNoRecord"] = "No Record";
localeData["DebugCannotGetMapName2"] = "Cannot get current map name";
localeData["DebugMapListEmpty"] = "Map list is empty, skipping map icon detection";
localeData["DebugMapNotInList"] = "[Airdrop Detection] Current map not in valid list, skipping detection: %s (Parent=%s Map ID=%s)";
localeData["DebugMapMatchSuccess"] = "[Airdrop Detection] Map match successful: %s";
localeData["DebugParentMapMatchSuccess"] = "[Airdrop Detection] Parent map match successful (sub-zone): %s (Parent=%s)";
localeData["DebugDetectedMapIconVignette"] = "[Airdrop Detection] Detected map icon (Vignette): %s (Airdrop Crate Name: %s)";
localeData["DebugUpdatedRefreshTime"] = "[Airdrop Detection] Updated refresh time: %s next refresh=%s";
localeData["DebugUpdateRefreshTimeFailed"] = "[Airdrop Detection] Update refresh time failed: Map ID=%s";
localeData["DebugMapIconNameNotConfigured"] = "[Map Icon Detection] Airdrop crate name not configured, skipping detection";
localeData["DebugAirdropActive"] = "[Airdrop Detection] Detected crate, airdrop event active: %s";
localeData["DebugWaitingForConfirmation"] = "[Airdrop Detection] Waiting for continuous detection confirmation: %s (interval=%s seconds)";
localeData["DebugClearedFirstDetectionTime"] = "[Airdrop Detection] Cleared first detection time record (icon not detected): %s";
localeData["DebugAirdropEnded"] = "[Airdrop Detection] Icon not detected, airdrop event ended: %s";
localeData["DebugFirstDetectionWait"] = "[Airdrop Detection] First icon detection, waiting for continuous detection confirmation: %s";
localeData["DebugContinuousDetectionConfirmed"] = "[Airdrop Detection] Continuous detection confirmed valid, updating refresh time and sending notification: %s (interval=%s seconds)";
localeData["ErrorTimerManagerNotInitialized"] = "Timer manager not initialized";
localeData["ErrorInvalidMapID"] = "Invalid map ID:";
localeData["ErrorTimerStartFailedMapID"] = "Timer start failed: Map ID=";
localeData["ErrorInvalidMapIDList"] = "Invalid map ID list";
localeData["ErrorMapNotFound"] = "Map not found:";
localeData["ErrorInvalidSourceParam"] = "Invalid detection source parameter";

-- Area Detection Debug Messages
localeData["DebugAreaInvalidInstance"] = "[Area Validity] Area invalid (instance/battleground/indoor), addon auto-paused";
localeData["DebugAreaCannotGetMapID"] = "[Area Validity] Cannot get map ID";
localeData["DebugAreaValid"] = "[Area Validity] Area valid, addon enabled: %s";
localeData["DebugAreaInvalidNotInList"] = "[Area Validity] Area invalid (not in valid map list), addon auto-paused: %s";

-- Phase Detection Debug Messages
localeData["DebugPhaseDetectionPaused"] = "[Phase Detection] Detection paused, skipping phase detection";
localeData["DebugPhaseNoMapID"] = "Cannot get current map ID, skipping phase info update";

-- Icon Detection Debug Messages
localeData["DebugIconDetectionStart"] = "[Map Icon Detection] Starting detection, map=%s, airdrop crate name=%s";


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
localeData["PluginAnnouncement"] = "|cff00ff88Plugin Announcement|r";
localeData["PluginIntro"] = "|cff00ff88Plugin Introduction|r";
-- UI Font Size Configuration (numeric type)
localeData["UIFontSize"] = 15;

-- Menu Items
localeData["MenuHelp"] = "Help";
localeData["MenuAbout"] = "About";
localeData["MenuSettings"] = "Settings";

-- ============================================================================
-- 地图名称翻译映射表（使用代号系统，完全语言无关）
-- ============================================================================
-- 格式：[地图代号] = "英文名称"
-- 注意：添加新语言只需创建新的本地化文件，添加代号到名称的映射即可
localeData.MapNames = {
    ["MAP_001"] = "Isle of Dorn",
    ["MAP_002"] = "K'aresh",
    ["MAP_003"] = "Hallowfall",
    ["MAP_004"] = "Azj-Kahet",
    ["MAP_005"] = "Undermine",
    ["MAP_006"] = "The Ringing Deeps",
    ["MAP_007"] = "Siren Isle",
};

-- ============================================================================
-- 空投箱子名称本地化
-- ============================================================================
localeData.AirdropCrateNames = {
    ["AIRDROP_CRATE_001"] = "War Supply Crate",
};

-- Help and About Content
localeData["AnnouncementText"] = [[
Author: capzk
Feedback: capzk@outlook.com


]];

localeData["IntroductionText"] = [[
• /ctk team on - Enable team notification
• /ctk team off - Disable team notification
• /ctk clear - Clear data

**Usage Notes:**

* Automatic airdrop detection requires the player to be in a valid area.

* Instances, battlegrounds, and indoor areas are considered invalid areas. When the player is in these areas, the addon will automatically pause detection.

* Only areas where the current map name matches the valid map list are considered valid areas.

* Players can cooperate in a group by camping different locations and reporting the spawn time to each other. You can then manually click the **Refresh** button to start the timer, or click the time display area and enter a time to start the timer.

* Team message notifications are enabled by default. You can disable them with the command: `/ctk team off`.

* The addon provides a floating button that can be used to reopen the main interface after it has been closed. Data will not be lost.

* Data is saved automatically and will not be lost when exiting the game.


Thank you for using!]];

-- Register this locale
LocaleManager.RegisterLocale("enUS", localeData);


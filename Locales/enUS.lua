-- CrateTrackerZK - English Localization
local ADDON_NAME = "CrateTrackerZK";
local locale = GetLocale();

-- Support all English locales (enUS, enGB, enAU, etc.)
-- If locale is not Chinese, load English as default
if locale == "zhCN" or locale == "zhTW" then return end

local Namespace = BuildEnv(ADDON_NAME);
local L = Namespace.L;

-- General
L["AddonLoaded"] = "Addon loaded, enjoy your game!";
L["HelpCommandHint"] = "Use |cffffcc00/ctk help|r to view help information";
L["CrateTrackerZK"] = "CrateTrackerZK";

-- Floating Button
L["FloatingButtonTooltipTitle"] = "CrateTrackerZK";
L["FloatingButtonTooltipLine1"] = "Click to open/close tracking panel";
L["FloatingButtonTooltipLine2"] = "Drag to move button position";

-- Phase Detection
L["NoInstanceAcquiredHint"] = "No phasing ID acquired. Please hover over any NPC to get current phasing ID";
L["CurrentInstanceID"] = "Current phasing ID: |cffffff00%s|r";
L["InstanceChangedTo"] = "Map [|cffffcc00%s|r] phasing ID changed to: |cffffff00%s|r";

-- Message Prefix
L["Prefix"] = "|cff00ff88[CrateTrackerZK]|r ";

-- Errors/Hints
L["CommandModuleNotLoaded"] = "Command module not loaded, please reload addon";

-- Notifications
L["TeamNotificationStatus"] = "Team notification %s";
L["AirdropDetected"] = "[%s] War Supplies airdrop detected!!!";
L["NoTimeRecord"] = "[%s] No time record!!!";
L["TimeRemaining"] = "[%s] War Supplies airdrop in: %s!!!";
L["Enabled"] = "Enabled";
L["Disabled"] = "Disabled";

-- Commands
L["UnknownCommand"] = "Unknown command: %s";
L["DebugEnabled"] = "Debug information enabled";
L["DebugDisabled"] = "Debug information disabled";
L["DebugUsage"] = "Debug command: /ctk debug on|off";
L["ClearingData"] = "Clearing all time and instance data...";
L["DataCleared"] = "All time and instance data cleared, map list preserved";
L["DataClearFailedEmpty"] = "Clear data failed: map list is empty";
L["DataClearFailedModule"] = "Clear data failed: Data module not loaded";
L["ClearUsage"] = "Clear command: /ctk clear or /ctk reset";
L["NotificationModuleNotLoaded"] = "Notification module not loaded";
L["TeamNotificationStatusPrefix"] = "Team notification status: ";
L["TeamUsage1"] = "Team notification commands:";
L["TeamUsage2"] = "/ctk team on - Enable team notification";
L["TeamUsage3"] = "/ctk team off - Disable team notification";
L["TeamUsage4"] = "/ctk team status - View team notification status";
L["HelpTitle"] = "Available commands:";
L["HelpClear"] = "/ctk clear or /ctk reset - Clear all time and instance data (preserve map list)";
L["HelpTeam"] = "/ctk team on|off - Enable/disable team notification";
L["HelpStatus"] = "/ctk team status - View team notification status";
L["HelpHelp"] = "/ctk help - Show this help information";
L["CollectDataEnabled"] = "Data collection mode enabled. Map icon information will be displayed in chat";
L["CollectDataDisabled"] = "Data collection mode disabled";
L["CollectDataUsage"] = "Data collection command: /ctk collect on|off - Enable/disable data collection mode (for collecting English version data)";
L["CollectDataLandmarkName"] = "Landmark Name";
L["CollectDataVignetteName"] = "Vignette Name";
L["CollectDataAreaPOIName"] = "Area POI Name";
L["CollectDataLabel"] = "[Data Collection]";

-- Debug Messages
L["DebugAPICall"] = "API Call";
L["DebugMapID"] = "Map ID";
L["DebugMapName"] = "Map Name";
L["DebugSource"] = "Source";
L["DebugTimestamp"] = "Timestamp";
L["DebugTimerStarted"] = "Timer started via %s, next refresh: %s";
L["DebugManualUpdate"] = "Manual operation: Updated refresh time";
L["DebugLastRefresh"] = "Last Refresh";
L["DebugNextRefresh"] = "Next Refresh";
L["DebugTimerStartFailed"] = "Timer start failed";
L["DebugReason"] = "Reason";
L["DebugGetMapInfoSuccess"] = "Successfully retrieved map info";
L["DebugUsingGetInstanceInfo"] = "Using GetInstanceInfo to get map name";
L["DebugCannotGetMapName"] = "Cannot get map name";
L["DebugUnknownSource"] = "Unknown Source";
L["DebugDetectionSourceManual"] = "Manual Input";
L["DebugDetectionSourceRefresh"] = "Refresh Button";
L["DebugDetectionSourceAPI"] = "API Interface";
L["DebugDetectionSourceMapIcon"] = "Map Icon Detection";
L["DebugNoRecord"] = "No Record";
L["DebugMap"] = "Map";
L["DebugTimerStartFailedMapID"] = "Timer start failed: Map ID=";
L["DebugInvalidMapID"] = "Invalid map ID:";
L["DebugInvalidMapIDList"] = "Invalid map ID list";
L["DebugInvalidSourceParam"] = "Invalid detection source parameter";
L["DebugCMapAPINotAvailable"] = "C_Map API not available";
L["DebugCannotGetMapID"] = "Cannot get current map ID";
L["DebugCMapGetMapInfoNotAvailable"] = "C_Map.GetMapInfo API not available";
L["DebugCannotGetMapName2"] = "Cannot get current map name";
L["DebugMapListEmpty"] = "Map list is empty, skipping map icon detection";
L["DebugMapNotInList"] = "[Airdrop Detection] Current map not in valid list, skipping detection: %s (Parent=%s Map ID=%s)";
L["DebugMapMatchSuccess"] = "[Airdrop Detection] Map match successful: %s";
L["DebugParentMapMatchSuccess"] = "[Airdrop Detection] Parent map match successful (sub-zone): %s (Parent=%s)";
L["DebugDetectedMapIconLandmark"] = "[Airdrop Detection] Detected map icon (Landmark): %s (Icon Name: %s)";
L["DebugDetectedMapIconVignette"] = "[Airdrop Detection] Detected map icon (Vignette): %s (Icon Name: %s)";
L["DebugDetectedMapIconPOI"] = "[Airdrop Detection] Detected map icon (Area POI): %s (Icon Name: %s)";
L["DebugUpdatedRefreshTime"] = "[Airdrop Detection] Updated refresh time: %s next refresh=%s";
L["DebugUpdateRefreshTimeFailed"] = "[Airdrop Detection] Update refresh time failed: Map ID=%s";
L["DebugMapIconNameNotConfigured"] = "[Map Icon Detection] Map icon name not configured, skipping detection";
L["DebugAirdropActive"] = "[Airdrop Detection] Detected crate, airdrop event active: %s";
L["DebugWaitingForConfirmation"] = "[Airdrop Detection] Waiting for continuous detection confirmation: %s (interval=%s seconds)";
L["DebugClearedFirstDetectionTime"] = "[Airdrop Detection] Cleared first detection time record (icon not detected): %s";
L["DebugAirdropEnded"] = "[Airdrop Detection] Icon not detected, airdrop event ended: %s";
L["DebugMapIconDetectionStarted"] = "Map icon detection started";
L["DebugDetectionInterval"] = "Detection interval";
L["DebugMapIconDetectionStopped"] = "Map icon detection stopped";
L["DebugSeconds"] = "seconds";
L["DebugFirstDetectionWait"] = "[Airdrop Detection] First icon detection, waiting for continuous detection confirmation: %s";
L["DebugContinuousDetectionConfirmed"] = "[Airdrop Detection] Continuous detection confirmed valid, updating refresh time and sending notification: %s (interval=%s seconds)";
L["ErrorTimerManagerNotInitialized"] = "Timer manager not initialized";
L["ErrorInvalidMapID"] = "Invalid map ID:";
L["ErrorTimerStartFailedMapID"] = "Timer start failed: Map ID=";
L["ErrorInvalidMapIDList"] = "Invalid map ID list";
L["ErrorMapNotFound"] = "Map not found:";
L["ErrorInvalidSourceParam"] = "Invalid detection source parameter";

-- UI
L["MainPanelTitle"] = "|cff00ff88[CrateTrackerZK]|r";
L["InfoButton"] = "Info";
L["AnnouncementButton"] = "Announcement";
L["IntroButton"] = "Introduction";
L["Map"] = "Map";
L["Phase"] = "Phasing";
L["LastRefresh"] = "Last Refresh";
L["NextRefresh"] = "Next Refresh";
L["Operation"] = "Operation";
L["Refresh"] = "Refresh";
L["Notify"] = "Notify";
L["NotAcquired"] = "Not Acquired";
L["NoRecord"] = "No Record";
L["MinuteSecond"] = "%dm%02ds";
L["InputTimeHint"] = "Please enter last refresh time (HH:MM:SS or HHMMSS):";
L["Confirm"] = "Confirm";
L["Cancel"] = "Cancel";
L["TimeFormatError"] = "Time format error, please enter HH:MM:SS or HHMMSS format";
L["TimestampError"] = "Unable to create valid timestamp";
L["InfoModuleNotLoaded"] = "Info module not loaded";
L["DataModuleNotLoaded"] = "Data module not loaded";
L["TimerManagerNotInitialized"] = "Timer manager not initialized";
L["Return"] = "Return";
L["PluginAnnouncement"] = "|cff00ff88Plugin Announcement|r";
L["PluginIntro"] = "|cff00ff88Plugin Introduction|r";

-- Menu Items
L["MenuHelp"] = "Help";
L["MenuAbout"] = "About";
L["MenuSettings"] = "Settings";

-- ============================================================================
-- Airdrop Detection Text (map icon detection)
-- ============================================================================
-- Map Icon Name (exact match required)
L["AirdropMapIconName"] = "War Supply Crate";

-- Help and About Content
L["AnnouncementText"] = [[
Author: capzk
Feedback: capzk@itcat.dev


]];

L["IntroductionText"] = [[
• /ctk team on - Enable team notification
• /ctk team off - Disable team notification
• /ctk clear - Clear data




Thank you for using!]];


-- CrateTrackerZK - 繁体中文本地化
local ADDON_NAME = "CrateTrackerZK";
local locale = GetLocale();

if locale ~= "zhTW" then return end

local Namespace = BuildEnv(ADDON_NAME);
local L = Namespace.L;

-- 通用
L["AddonLoaded"] = "插件已載入，祝您遊戲愉快！";
L["HelpCommandHint"] = "使用 |cffffcc00/ctk help|r 查看幫助資訊";
L["CrateTrackerZK"] = "CrateTrackerZK";

-- 浮動按鈕
L["FloatingButtonTooltipTitle"] = "CrateTrackerZK";
L["FloatingButtonTooltipLine1"] = "點擊開啟/關閉追蹤面板";
L["FloatingButtonTooltipLine2"] = "拖動可以移動按鈕位置";

-- 位面檢測
L["NoInstanceAcquiredHint"] = "未獲取任何位面ID，請使用滑鼠指向任何NPC以獲取當前位面ID";
L["CurrentInstanceID"] = "當前位面ID為：|cffffff00%s|r";
L["InstanceChangedTo"] = "地圖[|cffffcc00%s|r]位面已變更為：|cffffff00%s|r";

-- 訊息前綴
L["Prefix"] = "|cff00ff88[CrateTrackerZK]|r ";

-- 錯誤/提示
L["CommandModuleNotLoaded"] = "命令模組未載入，請重新載入插件";

-- 通知
L["TeamNotificationStatus"] = "團隊通知%s";
L["AirdropDetected"] = "【%s】 發現 戰爭補給 正在空投！！！";
L["NoTimeRecord"] = "【%s】 暫無時間記錄！！！";
L["TimeRemaining"] = "【%s】 距離 戰爭補給 空投還有：%s！！！";
L["Enabled"] = "已開啟";
L["Disabled"] = "已關閉";

-- 命令
L["UnknownCommand"] = "未知命令：%s";
L["DebugEnabled"] = "除錯資訊已開啟";
L["DebugDisabled"] = "除錯資訊已關閉";
L["DebugUsage"] = "除錯命令：/ctk debug on|off";
L["ClearingData"] = "正在清除所有時間和位面資料...";
L["DataCleared"] = "已清除所有時間和位面資料，地圖列表已保留";
L["DataClearFailedEmpty"] = "清除資料失敗：地圖列表為空";
L["DataClearFailedModule"] = "清除資料失敗：Data模組未載入";
L["ClearUsage"] = "清除命令：/ctk clear 或 /ctk reset";
L["NotificationModuleNotLoaded"] = "通知模組未載入";
L["TeamNotificationStatusPrefix"] = "團隊通知狀態：";
L["TeamUsage1"] = "團隊通知命令：";
L["TeamUsage2"] = "/ctk team on - 開啟團隊通知";
L["TeamUsage3"] = "/ctk team off - 關閉團隊通知";
L["TeamUsage4"] = "/ctk team status - 查看團隊通知狀態";
L["HelpTitle"] = "可用命令：";
L["HelpClear"] = "/ctk clear 或 /ctk reset - 清除所有時間和位面資料（保留地圖列表）";
L["HelpTeam"] = "/ctk team on|off - 開啟/關閉團隊通知";
L["HelpStatus"] = "/ctk team status - 查看團隊通知狀態";
L["HelpHelp"] = "/ctk help - 顯示此幫助資訊";
L["HelpUpdateWarning"] = "版本更新後出現任何問題，請徹底刪除此插件目錄後全新安裝！！";
L["CollectDataEnabled"] = "資料收集模式已開啟。地圖圖示資訊將在聊天中顯示";
L["CollectDataDisabled"] = "資料收集模式已關閉";
L["CollectDataUsage"] = "資料收集命令：/ctk collect on|off - 開啟/關閉資料收集模式（用於收集英文版本資料）";
L["CollectDataLandmarkName"] = "地標名稱";
L["CollectDataVignetteName"] = "Vignette名稱";
L["CollectDataAreaPOIName"] = "區域POI名稱";
L["CollectDataLabel"] = "[資料收集]";

-- Debug Messages
L["DebugAPICall"] = "API呼叫";
L["DebugMapID"] = "地圖ID";
L["DebugMapName"] = "地圖名稱";
L["DebugSource"] = "來源";
L["DebugTimestamp"] = "時間戳";
L["DebugTimerStarted"] = "計時器已啟動，來源：%s，下次刷新：%s";
L["DebugManualUpdate"] = "手動操作：已更新刷新時間";
L["DebugLastRefresh"] = "上次刷新";
L["DebugNextRefresh"] = "下次刷新";
L["DebugTimerStartFailed"] = "計時器啟動失敗";
L["DebugReason"] = "原因";
L["DebugGetMapInfoSuccess"] = "成功獲取地圖資訊";
L["DebugUsingGetInstanceInfo"] = "使用GetInstanceInfo獲取地圖名稱";
L["DebugCannotGetMapName"] = "無法獲取地圖名稱";
L["DebugUnknownSource"] = "未知來源";
L["DebugDetectionSourceManual"] = "手動輸入";
L["DebugDetectionSourceRefresh"] = "刷新按鈕";
L["DebugDetectionSourceAPI"] = "API介面";
L["DebugDetectionSourceMapIcon"] = "地圖圖示檢測";
L["DebugNoRecord"] = "無記錄";
L["DebugMap"] = "地圖";
L["DebugTimerStartFailedMapID"] = "計時器啟動失敗：地圖ID=";
L["DebugInvalidMapID"] = "無效的地圖ID：";
L["DebugInvalidMapIDList"] = "無效的地圖ID列表";
L["DebugInvalidSourceParam"] = "無效的檢測來源參數";
L["DebugCMapAPINotAvailable"] = "C_Map API不可用";
L["DebugCannotGetMapID"] = "無法獲取當前地圖ID";
L["DebugCMapGetMapInfoNotAvailable"] = "C_Map.GetMapInfo API不可用";
L["DebugCannotGetMapName2"] = "無法獲取當前地圖名稱";
L["DebugMapListEmpty"] = "地圖列表為空，跳過地圖圖示檢測";
L["DebugMapNotInList"] = "[空投檢測] 當前地圖不在有效列表中，跳過檢測：%s (父地圖=%s 地圖ID=%s)";
L["DebugMapMatchSuccess"] = "[空投檢測] 地圖匹配成功：%s";
L["DebugParentMapMatchSuccess"] = "[空投檢測] 父地圖匹配成功（子區域）：%s (父地圖=%s)";
L["DebugDetectedMapIconLandmark"] = "[空投檢測] 檢測到地圖圖示（地標）：%s (圖示名稱：%s)";
L["DebugDetectedMapIconVignette"] = "[空投檢測] 檢測到地圖圖示（Vignette）：%s (圖示名稱：%s)";
L["DebugDetectedMapIconPOI"] = "[空投檢測] 檢測到地圖圖示（區域POI）：%s (圖示名稱：%s)";
L["DebugUpdatedRefreshTime"] = "[空投檢測] 已更新刷新時間：%s 下次刷新=%s";
L["DebugUpdateRefreshTimeFailed"] = "[空投檢測] 更新刷新時間失敗：地圖ID=%s";
L["DebugMapIconNameNotConfigured"] = "[地圖圖示檢測] 地圖圖示名稱未配置，跳過檢測";
L["DebugAirdropActive"] = "[空投檢測] 檢測到空投箱，空投事件啟動：%s";
L["DebugWaitingForConfirmation"] = "[空投檢測] 等待連續檢測確認：%s (間隔=%s秒)";
L["DebugClearedFirstDetectionTime"] = "[空投檢測] 已清除首次檢測時間記錄（未檢測到圖示）：%s";
L["DebugAirdropEnded"] = "[空投檢測] 未檢測到圖示，空投事件已結束：%s";
L["DebugMapIconDetectionStarted"] = "地圖圖示檢測已啟動";
L["DebugDetectionInterval"] = "檢測間隔";
L["DebugMapIconDetectionStopped"] = "地圖圖示檢測已停止";
L["DebugSeconds"] = "秒";
L["DebugFirstDetectionWait"] = "[空投檢測] 首次檢測到圖示，等待連續檢測確認：%s";
L["DebugContinuousDetectionConfirmed"] = "[空投檢測] 連續檢測確認有效，正在更新刷新時間並發送通知：%s (間隔=%s秒)";
L["ErrorTimerManagerNotInitialized"] = "計時管理器尚未初始化";
L["ErrorInvalidMapID"] = "無效的地圖ID：";
L["ErrorTimerStartFailedMapID"] = "計時器啟動失敗：地圖ID=";
L["ErrorInvalidMapIDList"] = "無效的地圖ID列表";
L["ErrorMapNotFound"] = "未找到地圖：";
L["ErrorInvalidSourceParam"] = "無效的檢測來源參數";

-- UI
L["MainPanelTitle"] = "|cff00ff88[CrateTrackerZK]|r";
L["InfoButton"] = "資訊";
L["AnnouncementButton"] = "公告";
L["IntroButton"] = "插件簡介";
L["Map"] = "地圖";
L["Phase"] = "位面";
L["LastRefresh"] = "上次刷新";
L["NextRefresh"] = "下次刷新";
L["Operation"] = "操作";
L["Refresh"] = "刷新";
L["Notify"] = "通知";
L["NotAcquired"] = "未獲取";
L["NoRecord"] = "無記錄";
L["MinuteSecond"] = "%d分%02d秒";
L["InputTimeHint"] = "請輸入上次刷新時間 (HH:MM:SS 或 HHMMSS):";
L["Confirm"] = "確定";
L["Cancel"] = "取消";
L["TimeFormatError"] = "時間格式錯誤，請輸入HH:MM:SS或HHMMSS格式";
L["TimestampError"] = "無法建立有效的時間戳";
L["InfoModuleNotLoaded"] = "資訊模組未載入";
L["DataModuleNotLoaded"] = "Data模組未載入";
L["TimerManagerNotInitialized"] = "計時管理器尚未初始化";
L["Return"] = "返回";
L["PluginAnnouncement"] = "|cff00ff88插件公告|r";
L["PluginIntro"] = "|cff00ff88插件簡介|r";
-- UI 字體大小配置（數字類型）
L["UIFontSize"] = 15;

-- 選單項
L["MenuHelp"] = "幫助";
L["MenuAbout"] = "關於";
L["MenuSettings"] = "設定";

-- ============================================================================
-- 空投檢測相關文字（地圖圖示檢測）
-- ============================================================================
-- 地圖圖示名稱（完全匹配）
L["AirdropMapIconName"] = "戰爭補給箱";

-- ============================================================================
-- 幫助和關於介面內容配置
-- ============================================================================
-- 注意：以下內容可以在本檔案中直接修改，修改後需要重新載入插件才能生效

-- 關於介面（選單中的"關於"按鈕）
L["AnnouncementText"] = [[

插件作者：capzk
回饋建議：capzk@outlook.com


]];

-- 幫助介面（選單中的"幫助"按鈕）
L["IntroductionText"] = [[

• /ctk team on - 開啟團隊通知
• /ctk team off - 關閉團隊通知
• /ctk clear - 清除資料

使用須知：
- 自動檢測空投需要玩家處於有效區域。
- 主城，副本，戰場和室內屬於無效區域，玩家處於以上區域插件會自動暫停檢測。
- 可以團隊合作分別蹲守，互相報告刷新時間，然後手動點擊刷新按鈕來啟動計時，也可以點擊時間區域輸入一個時間來啟動計時。

- 預設開啟了團隊訊息提醒，可以使用命令暫停： /ctk team off。
- 插件有浮動按鈕，關閉插件介面可以重新開啟，資料不會遺失。
- 退出遊戲資料不會遺失。


感謝使用！]];


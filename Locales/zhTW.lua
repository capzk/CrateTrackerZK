-- CrateTrackerZK - 繁体中文本地化
-- This file contains only translation data, no logic
local LocaleManager = BuildEnv("LocaleManager");
if not LocaleManager or not LocaleManager.RegisterLocale then
    -- 记录加载失败（如果 LocaleManager 已存在但 RegisterLocale 不存在）
    if LocaleManager then
        LocaleManager.failedLocales = LocaleManager.failedLocales or {};
        table.insert(LocaleManager.failedLocales, {
            locale = "zhTW",
            reason = "RegisterLocale function not available"
        });
    end
    return; -- Locales.lua not loaded yet
end

local localeData = {};

-- 通用
localeData["AddonLoaded"] = "插件已載入，祝您遊戲愉快！";
localeData["HelpCommandHint"] = "使用 |cffffcc00/ctk help|r 查看幫助資訊";
localeData["CrateTrackerZK"] = "CrateTrackerZK";

-- 浮動按鈕
localeData["FloatingButtonTooltipTitle"] = "CrateTrackerZK";
localeData["FloatingButtonTooltipLine1"] = "點擊開啟/關閉追蹤面板";
localeData["FloatingButtonTooltipLine2"] = "拖動可以移動按鈕位置";

-- 位面檢測
localeData["NoInstanceAcquiredHint"] = "未獲取任何位面ID，請使用滑鼠指向任何NPC以獲取當前位面ID";
localeData["CurrentInstanceID"] = "當前位面ID為：|cffffff00%s|r";
localeData["InstanceChangedTo"] = "地圖[|cffffcc00%s|r]位面已變更為：|cffffff00%s|r";

-- 訊息前綴
localeData["Prefix"] = "|cff00ff88[CrateTrackerZK]|r ";

-- 錯誤/提示
localeData["CommandModuleNotLoaded"] = "命令模組未載入，請重新載入插件";

-- 通知
localeData["TeamNotificationStatus"] = "團隊通知%s";
localeData["AirdropDetected"] = "【%s】 發現 戰爭補給 正在空投！！！";
localeData["NoTimeRecord"] = "【%s】 暫無時間記錄！！！";
localeData["TimeRemaining"] = "【%s】 距離 戰爭補給 空投還有：%s！！！";
localeData["Enabled"] = "已開啟";
localeData["Disabled"] = "已關閉";

-- 命令
localeData["UnknownCommand"] = "未知命令：%s";
localeData["DebugEnabled"] = "除錯資訊已開啟";
localeData["DebugDisabled"] = "除錯資訊已關閉";
localeData["DebugUsage"] = "除錯命令：/ctk debug on|off";
localeData["ClearingData"] = "正在清除所有時間和位面資料...";
localeData["DataCleared"] = "已清除所有時間和位面資料，地圖列表已保留";
localeData["DataClearFailedEmpty"] = "清除資料失敗：地圖列表為空";
localeData["DataClearFailedModule"] = "清除資料失敗：Data模組未載入";
localeData["ClearUsage"] = "清除命令：/ctk clear 或 /ctk reset";
localeData["NotificationModuleNotLoaded"] = "通知模組未載入";
localeData["TeamNotificationStatusPrefix"] = "團隊通知狀態：";
localeData["TeamUsage1"] = "團隊通知命令：";
localeData["TeamUsage2"] = "/ctk team on - 開啟團隊通知";
localeData["TeamUsage3"] = "/ctk team off - 關閉團隊通知";
localeData["TeamUsage4"] = "/ctk team status - 查看團隊通知狀態";
localeData["HelpTitle"] = "可用命令：";
localeData["HelpClear"] = "/ctk clear 或 /ctk reset - 清除所有時間和位面資料（保留地圖列表）";
localeData["HelpTeam"] = "/ctk team on|off - 開啟/關閉團隊通知";
localeData["HelpStatus"] = "/ctk team status - 查看團隊通知狀態";
localeData["HelpHelp"] = "/ctk help - 顯示此幫助資訊";
localeData["HelpUpdateWarning"] = "版本更新後出現任何問題，請徹底刪除此插件目錄後全新安裝！！";

-- Debug Messages
localeData["DebugTimerStarted"] = "計時器已啟動，來源：%s，下次刷新：%s";
localeData["DebugDetectionSourceManual"] = "手動輸入";
localeData["DebugDetectionSourceRefresh"] = "刷新按鈕";
localeData["DebugDetectionSourceAPI"] = "API介面";
localeData["DebugDetectionSourceMapIcon"] = "地圖圖示檢測";
localeData["DebugNoRecord"] = "無記錄";
localeData["DebugCannotGetMapName2"] = "無法獲取當前地圖名稱";
localeData["DebugMapListEmpty"] = "地圖列表為空，跳過地圖圖示檢測";
localeData["DebugMapNotInList"] = "[空投檢測] 當前地圖不在有效列表中，跳過檢測：%s (父地圖=%s 地圖ID=%s)";
localeData["DebugMapMatchSuccess"] = "[空投檢測] 地圖匹配成功：%s";
localeData["DebugParentMapMatchSuccess"] = "[空投檢測] 父地圖匹配成功（子區域）：%s (父地圖=%s)";
localeData["DebugDetectedMapIconVignette"] = "[空投檢測] 檢測到地圖圖示（Vignette）：%s (空投箱子名稱：%s)";
localeData["DebugUpdatedRefreshTime"] = "[空投檢測] 已更新刷新時間：%s 下次刷新=%s";
localeData["DebugUpdateRefreshTimeFailed"] = "[空投檢測] 更新刷新時間失敗：地圖ID=%s";
localeData["DebugMapIconNameNotConfigured"] = "[地圖圖示檢測] 空投箱子名稱未配置，跳過檢測";
localeData["DebugAirdropActive"] = "[空投檢測] 檢測到空投箱，空投事件啟動：%s";
localeData["DebugWaitingForConfirmation"] = "[空投檢測] 等待連續檢測確認：%s (間隔=%s秒)";
localeData["DebugClearedFirstDetectionTime"] = "[空投檢測] 已清除首次檢測時間記錄（未檢測到圖示）：%s";
localeData["DebugAirdropEnded"] = "[空投檢測] 未檢測到圖示，空投事件已結束：%s";
localeData["DebugFirstDetectionWait"] = "[空投檢測] 首次檢測到圖示，等待連續檢測確認：%s";
localeData["DebugContinuousDetectionConfirmed"] = "[空投檢測] 連續檢測確認有效，正在更新刷新時間並發送通知：%s (間隔=%s秒)";
localeData["ErrorTimerManagerNotInitialized"] = "計時管理器尚未初始化";
localeData["ErrorInvalidMapID"] = "無效的地圖ID：";
localeData["ErrorTimerStartFailedMapID"] = "計時器啟動失敗：地圖ID=";
localeData["ErrorInvalidMapIDList"] = "無效的地圖ID列表";
localeData["ErrorMapNotFound"] = "未找到地圖：";
localeData["ErrorInvalidSourceParam"] = "無效的檢測來源參數";

-- 區域檢測除錯資訊
localeData["DebugAreaInvalidInstance"] = "【地圖有效性】區域無效（副本/戰場/室內），插件已自動暫停";
localeData["DebugAreaCannotGetMapID"] = "【地圖有效性】無法獲取地圖ID";
localeData["DebugAreaValid"] = "【地圖有效性】區域有效，插件已啟用: %s";
localeData["DebugAreaInvalidNotInList"] = "【地圖有效性】區域無效（不在有效地圖列表中），插件已自動暫停: %s";

-- 位面檢測除錯資訊
localeData["DebugPhaseDetectionPaused"] = "【位面檢測】檢測功能已暫停，跳過位面檢測";
localeData["DebugPhaseNoMapID"] = "無法獲取當前地圖ID，跳過位面資訊更新";

-- 空投檢測除錯資訊
localeData["DebugIconDetectionStart"] = "[地圖圖示檢測] 開始檢測，地圖=%s，空投箱子名稱=%s";


-- UI
localeData["MainPanelTitle"] = "|cff00ff88[CrateTrackerZK]|r";
localeData["InfoButton"] = "資訊";
localeData["AnnouncementButton"] = "公告";
localeData["IntroButton"] = "插件簡介";
localeData["Map"] = "地圖";
localeData["Phase"] = "位面";
localeData["LastRefresh"] = "上次刷新";
localeData["NextRefresh"] = "下次刷新";
localeData["Operation"] = "操作";
localeData["Refresh"] = "刷新";
localeData["Notify"] = "通知";
localeData["NotAcquired"] = "未獲取";
localeData["NoRecord"] = "無記錄";
localeData["MinuteSecond"] = "%d分%02d秒";
localeData["InputTimeHint"] = "請輸入上次刷新時間 (HH:MM:SS 或 HHMMSS):";
localeData["Confirm"] = "確定";
localeData["Cancel"] = "取消";
localeData["TimeFormatError"] = "時間格式錯誤，請輸入HH:MM:SS或HHMMSS格式";
localeData["TimestampError"] = "無法建立有效的時間戳";
localeData["InfoModuleNotLoaded"] = "資訊模組未載入";
localeData["DataModuleNotLoaded"] = "Data模組未載入";
localeData["TimerManagerNotInitialized"] = "計時管理器尚未初始化";
localeData["Return"] = "返回";
localeData["PluginAnnouncement"] = "|cff00ff88插件公告|r";
localeData["PluginIntro"] = "|cff00ff88插件簡介|r";
-- UI 字體大小配置（數字類型）
localeData["UIFontSize"] = 15;

-- 選單項
localeData["MenuHelp"] = "幫助";
localeData["MenuAbout"] = "關於";
localeData["MenuSettings"] = "設定";

-- ============================================================================
-- 地圖名稱翻譯映射表（使用代號系統，完全語言無關）
-- ============================================================================
-- 格式：[地圖代號] = "繁體中文名稱"
-- 注意：添加新語言只需創建新的本地化文件，添加代號到名稱的映射即可
localeData.MapNames = {
    ["MAP_001"] = "多恩島",      -- Isle of Dorn
    ["MAP_002"] = "凱瑞西",      -- K'aresh
    ["MAP_003"] = "聖落之地",    -- Hallowfall
    ["MAP_004"] = "阿茲-卡罕特",  -- Azj-Kahet
    ["MAP_005"] = "幽坑城",      -- Undermine
    ["MAP_006"] = "鳴響深淵",    -- The Ringing Deeps
    ["MAP_007"] = "海妖島",      -- Siren Isle
};

-- ============================================================================
-- 空投箱子名稱本地化
-- ============================================================================
localeData.AirdropCrateNames = {
    ["AIRDROP_CRATE_001"] = "戰爭補給箱",
};

-- ============================================================================
-- 幫助和關於介面內容配置
-- ============================================================================
-- 注意：以下內容可以在本檔案中直接修改，修改後需要重新載入插件才能生效

-- 關於介面（選單中的"關於"按鈕）
localeData["AnnouncementText"] = [[

插件作者：capzk
回饋建議：capzk@outlook.com


]];

-- 幫助介面（選單中的"幫助"按鈕）
localeData["IntroductionText"] = [[

• /ctk team on - 開啟團隊通知
• /ctk team off - 關閉團隊通知
• /ctk clear - 清除資料

使用須知：
- 自動檢測空投需要玩家處於有效區域。
- 副本，戰場和室內屬於無效區域，玩家處於以上區域插件會自動暫停檢測。
- 只有當前地圖名稱和地圖列表有匹配才視為有效區域。
- 可以團隊合作分別蹲守，互相報告刷新時間，然後手動點擊刷新按鈕來啟動計時，也可以點擊時間區域輸入一個時間來啟動計時。

- 預設開啟了團隊訊息提醒，可以使用命令暫停： /ctk team off。
- 插件有浮動按鈕，關閉插件介面可以重新開啟，資料不會遺失。
- 退出遊戲資料不會遺失。


感謝使用！]];

-- Register this locale
LocaleManager.RegisterLocale("zhTW", localeData);

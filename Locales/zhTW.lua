-- CrateTrackerZK - 繁体中文本地化
-- This file contains only translation data, no logic
local LocaleManager = BuildEnv("LocaleManager");
if not LocaleManager or not LocaleManager.RegisterLocale then
    if LocaleManager then
        LocaleManager.failedLocales = LocaleManager.failedLocales or {};
        table.insert(LocaleManager.failedLocales, {
            locale = "zhTW",
            reason = "RegisterLocale function not available"
        });
    end
    return;
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
localeData["LocalizationWarning"] = "警告";
localeData["LocalizationCritical"] = "嚴重";
localeData["LocalizationMissingTranslation"] = "[本地化%s] 缺失翻譯: %s.%s";
localeData["LocalizationFallbackWarning"] = "警告：未找到 %s 本地化文件，已回退到 %s";
localeData["LocalizationNoLocaleError"] = "錯誤：未找到任何可用的本地化文件";
localeData["LocalizationMissingTranslationsWarning"] = "警告：發現 %d 個缺失的關鍵翻譯 (%s)";
localeData["LocalizationMissingMapNames"] = "缺失的地圖名稱: %s";
localeData["LocalizationMissingCrateNames"] = "缺失的空投箱子名稱: %s";
localeData["LocalizationFailedLocalesWarning"] = "警告：%d 個語言文件載入失敗";
localeData["MapNamesCount"] = "地圖名稱: %d 個";
localeData["AirdropCratesCount"] = "空投箱子: %d 個";

-- 通知
localeData["TeamNotificationStatus"] = "團隊通知%s";
localeData["AirdropDetected"] = "【%s】 發現 戰爭補給 正在空投！！！";
localeData["NoTimeRecord"] = "【%s】 暫無時間記錄！！！";
localeData["TimeRemaining"] = "【%s】 距離 戰爭補給 空投還有：%s！！！";
localeData["Enabled"] = "已開啟";
localeData["Disabled"] = "已關閉";

-- 命令
localeData["UnknownCommand"] = "未知命令：%s";
localeData["ClearingData"] = "正在清除所有時間和位面資料...";
localeData["DataCleared"] = "已清除所有時間和位面資料，地圖列表已保留";
localeData["DataClearFailedEmpty"] = "清除資料失敗：地圖列表為空";
localeData["DataClearFailedModule"] = "清除資料失敗：Data模組未載入";
localeData["ClearUsage"] = "清除命令：/ctk clear 或 /ctk reset";
localeData["NotificationModuleNotLoaded"] = "通知模組未載入";
localeData["TeamUsage1"] = "團隊通知命令：";
localeData["TeamUsage2"] = "/ctk team on - 開啟團隊通知";
localeData["TeamUsage3"] = "/ctk team off - 關閉團隊通知";
localeData["HelpTitle"] = "可用命令：";
localeData["HelpClear"] = "/ctk clear 或 /ctk reset - 清除所有時間和位面資料（保留地圖列表）";
localeData["HelpTeam"] = "/ctk team on|off - 開啟/關閉團隊通知";
localeData["HelpHelp"] = "/ctk help - 顯示此幫助資訊";
localeData["HelpUpdateWarning"] = "版本更新後出現任何問題，請徹底刪除此插件目錄後全新安裝！！";

localeData["ErrorTimerManagerNotInitialized"] = "計時管理器尚未初始化";
localeData["ErrorInvalidMapID"] = "無效的地圖ID：";
localeData["ErrorTimerStartFailedMapID"] = "計時器啟動失敗：地圖ID=";
localeData["ErrorInvalidMapIDList"] = "無效的地圖ID列表";
localeData["ErrorMapNotFound"] = "未找到地圖：";
localeData["ErrorInvalidSourceParam"] = "無效的檢測來源參數";

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
localeData["UIFontSize"] = 15;

-- 選單項
localeData["MenuHelp"] = "幫助";
localeData["MenuAbout"] = "關於";
localeData["MenuSettings"] = "設定";

-- 地圖名稱翻譯
localeData.MapNames = {
    ["MAP_001"] = "多恩島",
    ["MAP_002"] = "凱瑞西",
    ["MAP_003"] = "聖落之地",
    ["MAP_004"] = "阿茲-卡罕特",
    ["MAP_005"] = "幽坑城",
    ["MAP_006"] = "鳴響深淵",
    ["MAP_007"] = "海妖島",
};

-- 空投箱子名稱
localeData.AirdropCrateNames = {
    ["AIRDROP_CRATE_001"] = "戰爭補給箱",
};

-- Register this locale
LocaleManager.RegisterLocale("zhTW", localeData);


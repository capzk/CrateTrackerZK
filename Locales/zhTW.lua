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
localeData["MapNamesCount"] = "缺失地圖名稱: %d";
localeData["AirdropCratesCount"] = "缺失空投箱子名稱: %d";

-- 通知
localeData["TeamNotificationStatus"] = "團隊通知%s";
localeData["AirdropDetected"] = "【%s】 檢測到戰爭補給正在空投！！！";  -- 自動檢測消息（帶"檢測到"關鍵字）
localeData["AirdropDetectedManual"] = "【%s】 戰爭補給正在空投！！！";  -- 手動通知消息（不帶"檢測到"關鍵字）
localeData["NoTimeRecord"] = "【%s】 暫無時間記錄！！！";
localeData["TimeRemaining"] = "【%s】 距離 戰爭補給 空投還有：%s！！！";
localeData["Enabled"] = "已開啟";
localeData["Disabled"] = "已關閉";

-- 位面檢測提示
localeData["PhaseDetectedFirstTime"] = "【%s】當前位面ID：|cffffff00%s|r";
localeData["InstanceChangedTo"] = "【%s】當前位面ID已變更為：|cffffff00%s|r";

-- 無效空投提示
localeData["InvalidAirdropNotification"] = "【%s】 檢測到無效空投事件，空投飛機存在時間過短，判定為無效事件。";

-- 命令
localeData["UnknownCommand"] = "未知命令：%s";
localeData["ClearingData"] = "正在清除所有時間和位面資料...";
localeData["DataCleared"] = "已清除所有資料，插件已重新初始化";
localeData["DataClearFailedModule"] = "清除資料失敗：Data模組未載入";
localeData["TeamUsage1"] = "團隊通知命令：";
localeData["TeamUsage2"] = "/ctk team on - 開啟團隊通知";
localeData["TeamUsage3"] = "/ctk team off - 關閉團隊通知";
localeData["HelpTitle"] = "可用命令：";
localeData["HelpClear"] = "/ctk clear 或 /ctk reset - 清除所有資料並重新初始化插件";
localeData["HelpTeam"] = "/ctk team on|off - 開啟/關閉團隊通知";
localeData["HelpTimeShare"] = "/ctk timeshare on|off - 開啟/關閉團隊時間共享（測試功能，預設關閉）";
localeData["HelpHelp"] = "/ctk help - 顯示此幫助資訊";
localeData["HelpUpdateWarning"] = "版本更新後出現任何問題，請徹底刪除此插件目錄後全新安裝！！";

localeData["ErrorTimerManagerNotInitialized"] = "計時管理器尚未初始化";
localeData["ErrorInvalidMapID"] = "無效的地圖ID：%s";
localeData["ErrorTimerStartFailedMapID"] = "計時器啟動失敗：地圖ID=%s";
localeData["ErrorUpdateRefreshTimeFailed"] = "刷新時間更新失敗：地圖ID=%s";
localeData["ErrorMapTrackerModuleNotLoaded"] = "MapTracker 模組未載入";
localeData["ErrorIconDetectorModuleNotLoaded"] = "IconDetector 模組未載入";
localeData["ErrorTimerManagerModuleNotLoaded"] = "TimerManager 模組未載入";
localeData["ErrorCannotGetMapData"] = "無法獲取地圖資料，地圖ID=%s";
localeData["TimeFormatError"] = "時間格式錯誤，請輸入HH:MM:SS或HHMMSS格式";
localeData["TimestampError"] = "無法建立有效的時間戳";
localeData["AddonInitializedSuccess"] = "插件已初始化成功，祝您遊戲愉快！";

-- UI
localeData["MainPanelTitle"] = "|cff00ff88[CrateTrackerZK]|r";
localeData["InfoButton"] = "資訊";
localeData["Map"] = "地圖";
localeData["Phase"] = "位面";
localeData["LastRefresh"] = "上次刷新";
localeData["NextRefresh"] = "下次刷新";
localeData["Operation"] = "操作";
localeData["Refresh"] = "刷新";
localeData["Notify"] = "通知";
localeData["NotAcquired"] = "N/A";
localeData["NoRecord"] = "--:--";
localeData["MinuteSecond"] = "%d分%02d秒";
localeData["InputTimeHint"] = "請輸入上次刷新時間 (HH:MM:SS 或 HHMMSS):";
localeData["Confirm"] = "確定";
localeData["Cancel"] = "取消";
localeData["Return"] = "返回";
localeData["UIFontSize"] = 15;
localeData["HelpText"] = [[可用命令：

/ctk help               顯示可用命令
/ctk team on/off        開啟/關閉團隊通知
/ctk clear              清除本地資料並重新初始化
/ctk timeshare on/off   開啟/關閉團隊時間共享（測試功能，預設關閉）

團隊時間共享需要團隊成員開啟團隊通知功能和團隊時間共享功能才能生效。

要獲取當前位面ID，您只需將滑鼠指向任意NPC。位面ID將自動檢測並顯示在主面板中。
如果插件升級後出現任何問題，請徹底刪除此插件目錄並重新安裝。]];

-- 選單項
localeData["MenuHelp"] = "幫助";
localeData["MenuAbout"] = "關於";

-- 地圖名稱翻譯（使用地圖ID作為鍵）
localeData.MapNames = {
    [2248] = "多恩島",      -- 多恩島
    [2369] = "海妖島",      -- 海妖島
    [2371] = "凱瑞西",      -- 卡雷什
    [2346] = "幽坑城",      -- 安德麦
    [2215] = "聖落之地",    -- 陨圣峪
    [2214] = "鳴響深淵",    -- 喧鸣深窟
    [2255] = "阿茲-卡罕特", -- 艾基-卡赫特
};

-- 空投箱子名稱
localeData.AirdropCrateNames = {
    ["WarSupplyCrate"] = "戰爭補給箱",
};

-- Register this locale
LocaleManager.RegisterLocale("zhTW", localeData);


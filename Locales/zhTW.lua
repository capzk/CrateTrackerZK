-- CrateTrackerZK - 繁体中文本地化
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

-- 浮動按鈕
localeData["FloatingButtonTooltipLine3"] = "右鍵開啟設定";

-- 通知（空投）
localeData["Enabled"] = "團隊通知已開啟";
localeData["Disabled"] = "團隊通知已關閉";
localeData["AirdropDetected"] = "【%s】 檢測到戰爭補給正在空投！！！";  -- 自動檢測消息（帶"檢測到"關鍵字）
localeData["AirdropDetectedManual"] = "【%s】 戰爭補給正在空投！！！";  -- 手動通知消息（不帶"檢測到"關鍵字）
localeData["NoTimeRecord"] = "【%s】 暫無時間記錄！！！";
localeData["TimeRemaining"] = "【%s】 距離戰爭補給空投還有：%s！！！";
localeData["AutoTeamReportMessage"] = "當前【%s】距離戰爭補給空投還有：%s！！";

-- 位面檢測提示
localeData["PhaseDetectedFirstTime"] = "【%s】當前位面：|cffffff00%s|r";
localeData["InstanceChangedTo"] = "【%s】當前位面已變更為：|cffffff00%s|r";

-- UI
localeData["MapName"] = "地圖名稱";
localeData["PhaseID"] = "當前位面";
localeData["LastRefresh"] = "上次刷新";
localeData["NextRefresh"] = "下次刷新";
localeData["NotAcquired"] = "---:---";
localeData["NoRecord"] = "--:--";
localeData["MinuteSecond"] = "%d分%02d秒";
-- 選單項
localeData["MenuHelp"] = "幫助";
localeData["MenuAbout"] = "關於";

-- 設定面板
localeData["SettingsSectionExpansion"] = "版本設定";
localeData["SettingsSectionControl"] = "插件控制";
localeData["SettingsSectionData"] = "資料管理";
localeData["SettingsSectionUI"] = "介面設定";
localeData["SettingsMainPage"] = "主要設定";
localeData["SettingsMessages"] = "訊息設定";
localeData["SettingsMapList"] = "地圖列表";
localeData["SettingsExpansionVersion"] = "地圖版本";
localeData["SettingsThemeSwitch"] = "介面主題";
localeData["SettingsAddonToggle"] = "插件開關";
localeData["SettingsTeamNotify"] = "團隊通知";
localeData["SettingsSoundAlert"] = "聲音提示";
localeData["SettingsAutoReport"] = "自動通知";
localeData["SettingsAutoReportInterval"] = "通知頻率（秒）";
localeData["SettingsClearButton"] = "清除本機資料";
localeData["SettingsToggleOn"] = "已開啟";
localeData["SettingsToggleOff"] = "已關閉";
localeData["SettingsClearConfirmText"] = "確認清除所有資料並重新初始化？此操作不可撤銷。";
localeData["SettingsClearConfirmYes"] = "確認";
localeData["SettingsClearConfirmNo"] = "取消";

-- 空投 NPC 喊話（用於喊話偵測，提升監測效率。是可選項，可以缺失，或者保持預設）
localeData.AirdropShouts = {
    "魯夫厄斯說：機不可失！要是你有氣魄的話，就去把那些寶物贏到手。",
    "魯夫厄斯說：附近有一箱資源。在競爭者到來之前找到它！",
    "魯夫厄斯說：附近似乎有寶藏。自然也會引來寶藏獵人。小心背後。",
    "魯夫厄斯說：我在這附近看到珍貴的資源！快去搶到手！",
};

localeData["SettingsHelpText"] = [[
使用說明

1. 主介面倒數計時支援滑鼠點擊發送訊息：
   左鍵點擊：發送「【地圖】 距離戰爭物資空投還有：時間」
   右鍵點擊：發送「當前【地圖】距離戰爭物資空投還有：時間」

2. 訊息設定頁各選項作用：
   訊息設定：控制手動發送和自動發送相關行為
   團隊通知：開啟後，會把訊息發送到小隊、團隊或副本頻道
   聲音提示：開啟後，檢測到空投時會播放提示音
   自動通知：開啟後，會依設定頻率自動發送最近的空投倒數計時
   通知頻率（秒）：設定自動通知發送間隔
]];

-- Register this locale
LocaleManager.RegisterLocale("zhTW", localeData);

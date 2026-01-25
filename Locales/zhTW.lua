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

-- 通用

-- 浮動按鈕
localeData["FloatingButtonTooltipLine1"] = "點擊開啟/關閉追蹤面板";
localeData["FloatingButtonTooltipLine2"] = "拖動可以移動按鈕位置";
localeData["FloatingButtonTooltipLine3"] = "右鍵開啟設定";

-- 啟動提示
localeData["AddonLoadedMessage"] = "CrateTrackerZK 已載入，歡迎使用。/ctk help 查看命令";

-- 通知（空投）
localeData["Enabled"] = "團隊通知已開啟";
localeData["Disabled"] = "團隊通知已關閉";
localeData["AirdropDetected"] = "【%s】 檢測到戰爭補給正在空投！！！";  -- 自動檢測消息（帶"檢測到"關鍵字）
localeData["AirdropDetectedManual"] = "【%s】 戰爭補給正在空投！！！";  -- 手動通知消息（不帶"檢測到"關鍵字）
localeData["NoTimeRecord"] = "【%s】 暫無時間記錄！！！";
localeData["TimeRemaining"] = "【%s】 距離 戰爭補給 空投還有：%s！！！";

-- 位面檢測提示
localeData["PhaseDetectedFirstTime"] = "【%s】當前位面ID：|cffffff00%s|r";
localeData["InstanceChangedTo"] = "【%s】當前位面ID已變更為：|cffffff00%s|r";

-- 命令
localeData["UnknownCommand"] = "未知命令：%s";
localeData["DataCleared"] = "已清除所有資料，插件已重新初始化";
localeData["TeamUsage1"] = "團隊通知命令：";
localeData["TeamUsage2"] = "/ctk team on - 開啟團隊通知";
localeData["TeamUsage3"] = "/ctk team off - 關閉團隊通知";

-- UI
localeData["MapName"] = "地圖名稱";
localeData["PhaseID"] = "位面ID";
localeData["LastRefresh"] = "上次刷新";
localeData["NextRefresh"] = "下次刷新";
localeData["Operation"] = "操作";
localeData["Refresh"] = "刷新";
localeData["Notify"] = "通知";
localeData["Delete"] = "刪除";
localeData["Restore"] = "恢復";
localeData["NotAcquired"] = "N/A";
localeData["NoRecord"] = "--:--";
localeData["MinuteSecond"] = "%d分%02d秒";
-- 選單項
localeData["MenuHelp"] = "幫助";
localeData["MenuAbout"] = "關於";

-- 設定面板
localeData["SettingsPanelTitle"] = "CrateTrackerZK - 設定";
localeData["SettingsTabSettings"] = "設定";
localeData["SettingsSectionControl"] = "插件控制";
localeData["SettingsSectionData"] = "資料管理";
localeData["SettingsSectionUI"] = "介面設定";
localeData["SettingsAddonToggle"] = "插件開關";
localeData["SettingsTeamNotify"] = "團隊通知";
localeData["SettingsClearAllData"] = "清除所有資料";
localeData["SettingsClearButton"] = "清除";
localeData["SettingsClearDesc"] = "• 會清空所有空投時間與位面記錄";
localeData["SettingsUIConfigDesc"] = "• 介面風格可在 UiConfig.lua 調整";
localeData["SettingsReloadDesc"] = "• 修改後使用 /reload 生效";
localeData["SettingsToggleOn"] = "已開啟";
localeData["SettingsToggleOff"] = "已關閉";
localeData["SettingsClearConfirmText"] = "確認清除所有資料並重新初始化？此操作不可撤銷。";
localeData["SettingsClearConfirmYes"] = "確認";
localeData["SettingsClearConfirmNo"] = "取消";

-- 空投 NPC 喊話（用於喊話偵測，提升監測效率。是可選項，可以缺失，或者保持預設）
localeData.AirdropShouts = {
    "魯夫厄斯說：機不可失！要是你有氣魄的話，就去把那些寶物贏到手。",
    "魯夫厄斯說：附近有一箱資源。在競爭者到來之前找到它！",
    "路费欧斯说： 机会送上门来了！只要你够有勇气，那些宝贝在等着你呢。",
    "路费欧斯说： 区域里出现了珍贵资源！快去抢吧！",
};

-- Register this locale
LocaleManager.RegisterLocale("zhTW", localeData);

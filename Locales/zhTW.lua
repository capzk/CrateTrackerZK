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

-- 通知（空投）
localeData["TeamNotificationStatus"] = "%s";
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

-- 空投NPC喊話（暫用簡中內容，待後續完善）
localeData.AirdropShouts = {
    "路費歐斯說： 附近好像有寶藏，自然也會有寶藏獵手了。小心背後。",
    "路費歐斯說： 附近有滿滿一箱資源，趕緊找，不然難免大打出手哦！",
    "路費歐斯說： 機會送上門來了！只要你夠有勇氣，那些寶貝在等著你呢。",
    "路費歐斯說： 區域裡出現了珍貴資源！快去搶吧！",
};

-- Register this locale
LocaleManager.RegisterLocale("zhTW", localeData);

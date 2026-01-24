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

-- 空投 NPC 喊話（用於喊話偵測，提升監測效率。是可選項，可以缺失，或者保持預設）
localeData.AirdropShouts = {
    "路费欧斯说： 附近好像有宝藏，自然也会有宝藏猎手了。小心背后。",
    "路费欧斯说： 附近有满满一箱资源，赶紧找，不然难免大打出手哦！",
    "路费欧斯说： 机会送上门来了！只要你够有勇气，那些宝贝在等着你呢。",
    "路费欧斯说： 区域里出现了珍贵资源！快去抢吧！",
};

-- Register this locale
LocaleManager.RegisterLocale("zhTW", localeData);

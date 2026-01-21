-- CrateTrackerZK - 简体中文本地化
local LocaleManager = BuildEnv("LocaleManager");
if not LocaleManager or not LocaleManager.RegisterLocale then
    if LocaleManager then
        LocaleManager.failedLocales = LocaleManager.failedLocales or {};
        table.insert(LocaleManager.failedLocales, {
            locale = "zhCN",
            reason = "RegisterLocale function not available"
        });
    end
    return;
end

local localeData = {};


-- 浮动按钮
localeData["FloatingButtonTooltipLine1"] = "点击打开/关闭追踪面板";
localeData["FloatingButtonTooltipLine2"] = "拖动可以移动按钮位置";

-- 通知（空投）
localeData["Enabled"] = "团队通知已开启";
localeData["Disabled"] = "团队通知已关闭";
localeData["AirdropDetected"] = "【%s】 检测到战争物资正在空投！！！";  -- 自动检测消息（带"检测到"关键字）
localeData["AirdropDetectedManual"] = "【%s】 战争物资正在空投！！！";  -- 手动通知消息（不带"检测到"关键字）
localeData["NoTimeRecord"] = "【%s】 暂无时间记录！！！";
localeData["TimeRemaining"] = "【%s】 距离 战争物资 空投还有：%s！！！";

-- 位面检测提示
localeData["PhaseDetectedFirstTime"] = "【%s】当前位面ID：|cffffff00%s|r";
localeData["InstanceChangedTo"] = "【%s】当前位面ID已变更为：|cffffff00%s|r";

-- 命令
localeData["UnknownCommand"] = "未知命令：%s";
localeData["DataCleared"] = "已清除所有数据，插件已重新初始化";
localeData["TeamUsage1"] = "团队通知命令：";
localeData["TeamUsage2"] = "/ctk team on - 开启团队通知";
localeData["TeamUsage3"] = "/ctk team off - 关闭团队通知";

-- UI
localeData["MapName"] = "地图名称";
localeData["PhaseID"] = "位面ID";
localeData["LastRefresh"] = "上次刷新";
localeData["NextRefresh"] = "下次刷新";
localeData["Operation"] = "操作";
localeData["Refresh"] = "刷新";
localeData["Notify"] = "通知";
localeData["Delete"] = "删除";
localeData["Restore"] = "恢复";
localeData["NotAcquired"] = "N/A";
localeData["NoRecord"] = "--:--";
localeData["MinuteSecond"] = "%d分%02d秒";
-- 菜单项
localeData["MenuHelp"] = "帮助";
localeData["MenuAbout"] = "关于";

-- 空投 NPC 喊话（用于喊话检测，提升监测效率。是可选项，可以缺失，或者保持默认）
localeData.AirdropShouts = {
    "路费欧斯说： 附近好像有宝藏，自然也会有宝藏猎手了。小心背后。",
    "路费欧斯说： 附近有满满一箱资源，赶紧找，不然难免大打出手哦！",
    "路费欧斯说： 机会送上门来了！只要你够有勇气，那些宝贝在等着你呢。",
    "路费欧斯说： 区域里出现了珍贵资源！快去抢吧！",
};

-- Register this locale
LocaleManager.RegisterLocale("zhCN", localeData);

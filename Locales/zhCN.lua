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
localeData["FloatingButtonTooltipLine3"] = "右键打开设置";

-- 通知（空投）
localeData["Enabled"] = "团队通知已开启";
localeData["Disabled"] = "团队通知已关闭";
localeData["AirdropDetected"] = "【%s】检测到战争物资正在空投！！！";  -- 自动检测消息（带"检测到"关键字）
localeData["AirdropDetectedManual"] = "【%s】战争物资正在空投！！！";  -- 手动通知消息（不带"检测到"关键字）
localeData["NoTimeRecord"] = "【%s】暂无时间记录！！！";
localeData["TimeRemaining"] = "【%s】距离战争物资空投还有：%s！！！";
localeData["AutoTeamReportMessage"] = "当前【%s】距离战争物资空投还有：%s！！";
localeData["SharedPhaseSyncApplied"] = "已获取【%s】当前位面的最新空投共享信息。";

-- 位面检测提示
localeData["PhaseDetectedFirstTime"] = "【%s】当前位面：|cffffff00%s|r";
localeData["InstanceChangedTo"] = "【%s】当前位面已变更为：|cffffff00%s|r";

-- UI
localeData["MapName"] = "地图名称";
localeData["PhaseID"] = "当前位面";
localeData["LastRefresh"] = "上次刷新";
localeData["NextRefresh"] = "下次刷新";
localeData["NotAcquired"] = "---:---";
localeData["NoRecord"] = "--:--";
localeData["MinuteSecond"] = "%d分%02d秒";
-- 菜单项
localeData["MenuHelp"] = "帮助";
localeData["MenuAbout"] = "关于";

-- 设置面板
localeData["SettingsSectionExpansion"] = "版本设置";
localeData["SettingsSectionControl"] = "插件控制";
localeData["SettingsSectionData"] = "数据管理";
localeData["SettingsSectionUI"] = "界面设置";
localeData["SettingsMainPage"] = "主要设置";
localeData["SettingsMessages"] = "消息设置";
localeData["SettingsMapSelection"] = "地图选择";
localeData["SettingsThemeSwitch"] = "界面主题";
localeData["SettingsAddonToggle"] = "插件开关";
localeData["SettingsLeaderMode"] = "团长模式";
localeData["SettingsLeaderModeTooltip"] = "开启后，手动空投通知会优先发送到团队警告频道；如果当前没有团队警告权限，则自动回落到普通团队频道。";
localeData["SettingsTeamNotify"] = "团队通知";
localeData["SettingsSoundAlert"] = "声音提醒";
localeData["SettingsAutoReport"] = "自动通知";
localeData["SettingsAutoReportInterval"] = "通知频率（秒）";
localeData["SettingsClearButton"] = "清除本地数据";
localeData["SettingsToggleOn"] = "已开启";
localeData["SettingsToggleOff"] = "已关闭";
localeData["SettingsClearConfirmText"] = "确认清除所有数据并重新初始化？该操作不可撤销。";
localeData["SettingsClearConfirmYes"] = "确认";
localeData["SettingsClearConfirmNo"] = "取消";

-- 空投 NPC 喊话（用于喊话检测，提升监测效率。是可选项，可以缺失，或者保持默认）
localeData.AirdropShouts = {
    --11.0
    "路费欧斯说： 附近好像有宝藏，自然也会有宝藏猎手了。小心背后。",
    "路费欧斯说： 附近有满满一箱资源，赶紧找，不然难免大打出手哦！",
    "路费欧斯说： 机会送上门来了！只要你够有勇气，那些宝贝在等着你呢。",
    "路费欧斯说： 区域里出现了珍贵资源！快去抢吧！",
    --12.0
    "兹尔丹说： 看来远方就有一处宝物。不要放过这个机会！",
    "维迪奥斯说： 你喜欢好东西吧？那就去找到它们。",
    "维迪奥斯说： 时刻关注战利品出现的机会，比如现在！",
    "兹尔丹说： 抢占先机，夺取你的战利品。",
};

localeData["SettingsHelpText"] = [[
使用说明

1. 主界面倒计时支持鼠标点击发送消息：
   左键点击：发送“【地图】 距离战争物资空投还有：时间”
   右键点击：发送“当前【地图】距离战争物资空投还有：时间”

2. 消息设置页各选项作用：
   消息设置：控制手动发送和自动发送相关行为
   团队通知：开启后，会把消息发送到小队或团队频道
   声音提示：开启后，检测到空投时会播放提示音
   自动通知：开启后，会按设定频率自动发送最近的空投倒计时
   通知频率（秒）：设置自动通知发送间隔
]];

-- Register this locale
LocaleManager.RegisterLocale("zhCN", localeData);

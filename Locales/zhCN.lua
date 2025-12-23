-- CrateTrackerZK - 简体中文本地化
-- This file contains only translation data, no logic
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

-- 通用
localeData["AddonLoaded"] = "插件已加载，祝您游戏愉快！";
localeData["HelpCommandHint"] = "使用 |cffffcc00/ctk help|r 查看帮助信息";
localeData["CrateTrackerZK"] = "CrateTrackerZK";

-- 浮动按钮
localeData["FloatingButtonTooltipTitle"] = "CrateTrackerZK";
localeData["FloatingButtonTooltipLine1"] = "点击打开/关闭追踪面板";
localeData["FloatingButtonTooltipLine2"] = "拖动可以移动按钮位置";

-- 位面检测
localeData["NoInstanceAcquiredHint"] = "未获取任何位面ID，请使用鼠标指向任何NPC以获取当前位面ID";
localeData["CurrentInstanceID"] = "当前位面ID为：|cffffff00%s|r";
localeData["InstanceChangedTo"] = "地图[|cffffcc00%s|r]位面已变更为：|cffffff00%s|r";

-- 消息前缀
localeData["Prefix"] = "|cff00ff88[CrateTrackerZK]|r ";

-- 错误/提示
localeData["CommandModuleNotLoaded"] = "命令模块未加载，请重新加载插件";
localeData["LocalizationWarning"] = "警告";
localeData["LocalizationCritical"] = "严重";
localeData["LocalizationMissingTranslation"] = "[本地化%s] 缺失翻译: %s.%s";
localeData["LocalizationFallbackWarning"] = "警告：未找到 %s 本地化文件，已回退到 %s";
localeData["LocalizationNoLocaleError"] = "错误：未找到任何可用的本地化文件";
localeData["LocalizationMissingTranslationsWarning"] = "警告：发现 %d 个缺失的关键翻译 (%s)";
localeData["LocalizationMissingMapNames"] = "缺失的地图名称: %s";
localeData["LocalizationMissingCrateNames"] = "缺失的空投箱子名称: %s";
localeData["LocalizationFailedLocalesWarning"] = "警告：%d 个语言文件加载失败";
localeData["MapNamesCount"] = "地图名称: %d 个";
localeData["AirdropCratesCount"] = "空投箱子: %d 个";

-- 通知
localeData["TeamNotificationStatus"] = "团队通知%s";
localeData["AirdropDetected"] = "【%s】 发现 战争物资 正在空投！！！";
localeData["NoTimeRecord"] = "【%s】 暂无时间记录！！！";
localeData["TimeRemaining"] = "【%s】 距离 战争物资 空投还有：%s！！！";
localeData["Enabled"] = "已开启";
localeData["Disabled"] = "已关闭";

-- 命令
localeData["UnknownCommand"] = "未知命令：%s";
localeData["ClearingData"] = "正在清除所有时间和位面数据...";
localeData["DataCleared"] = "已清除所有时间和位面数据，地图列表已保留";
localeData["DataClearFailedEmpty"] = "清除数据失败：地图列表为空";
localeData["DataClearFailedModule"] = "清除数据失败：Data模块未加载";
localeData["ClearUsage"] = "清除命令：/ctk clear 或 /ctk reset";
localeData["NotificationModuleNotLoaded"] = "通知模块未加载";
localeData["TeamUsage1"] = "团队通知命令：";
localeData["TeamUsage2"] = "/ctk team on - 开启团队通知";
localeData["TeamUsage3"] = "/ctk team off - 关闭团队通知";
localeData["HelpTitle"] = "可用命令：";
localeData["HelpClear"] = "/ctk clear 或 /ctk reset - 清除所有时间和位面数据（保留地图列表）";
localeData["HelpTeam"] = "/ctk team on|off - 开启/关闭团队通知";
localeData["HelpHelp"] = "/ctk help - 显示此帮助信息";
localeData["HelpUpdateWarning"] = "版本更新后出现任何问题，请彻底删除此插件目录后全新安装！！";

localeData["ErrorTimerManagerNotInitialized"] = "计时管理器尚未初始化";
localeData["ErrorInvalidMapID"] = "无效的地图ID：";
localeData["ErrorTimerStartFailedMapID"] = "计时器启动失败：地图ID=";
localeData["ErrorInvalidMapIDList"] = "无效的地图ID列表";
localeData["ErrorMapNotFound"] = "未找到地图：";
localeData["ErrorInvalidSourceParam"] = "无效的检测来源参数";

-- UI
localeData["MainPanelTitle"] = "|cff00ff88[CrateTrackerZK]|r";
localeData["InfoButton"] = "信息";
localeData["AnnouncementButton"] = "公告";
localeData["IntroButton"] = "插件简介";
localeData["Map"] = "地图";
localeData["Phase"] = "位面";
localeData["LastRefresh"] = "上次刷新";
localeData["NextRefresh"] = "下次刷新";
localeData["Operation"] = "操作";
localeData["Refresh"] = "刷新";
localeData["Notify"] = "通知";
localeData["NotAcquired"] = "未获取";
localeData["NoRecord"] = "无记录";
localeData["MinuteSecond"] = "%d分%02d秒";
localeData["InputTimeHint"] = "请输入上次刷新时间 (HH:MM:SS 或 HHMMSS):";
localeData["Confirm"] = "确定";
localeData["Cancel"] = "取消";
localeData["TimeFormatError"] = "时间格式错误，请输入HH:MM:SS或HHMMSS格式";
localeData["TimestampError"] = "无法创建有效的时间戳";
localeData["InfoModuleNotLoaded"] = "信息模块未加载";
localeData["DataModuleNotLoaded"] = "Data模块未加载";
localeData["TimerManagerNotInitialized"] = "计时管理器尚未初始化";
localeData["Return"] = "返回";
localeData["UIFontSize"] = 15;

-- 菜单项
localeData["MenuHelp"] = "帮助";
localeData["MenuAbout"] = "关于";
localeData["MenuSettings"] = "设置";

-- 地图名称翻译
localeData.MapNames = {
    ["MAP_001"] = "多恩岛",
    ["MAP_002"] = "卡雷什",
    ["MAP_003"] = "陨圣峪",
    ["MAP_004"] = "艾基-卡赫特",
    ["MAP_005"] = "安德麦",
    ["MAP_006"] = "喧鸣深窟",
    ["MAP_007"] = "海妖岛",
};

-- 空投箱子名称
localeData.AirdropCrateNames = {
    ["AIRDROP_CRATE_001"] = "战争物资箱",
};

-- Register this locale
LocaleManager.RegisterLocale("zhCN", localeData);


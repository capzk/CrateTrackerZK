-- CrateTrackerZK - 简体中文本地化
-- This file contains only translation data, no logic
local LocaleManager = BuildEnv("LocaleManager");
if not LocaleManager or not LocaleManager.RegisterLocale then
    -- 记录加载失败（如果 LocaleManager 已存在但 RegisterLocale 不存在）
    if LocaleManager then
        LocaleManager.failedLocales = LocaleManager.failedLocales or {};
        table.insert(LocaleManager.failedLocales, {
            locale = "zhCN",
            reason = "RegisterLocale function not available"
        });
    end
    return; -- Locales.lua not loaded yet
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
localeData["DebugEnabled"] = "调试信息已开启";
localeData["DebugDisabled"] = "调试信息已关闭";
localeData["DebugUsage"] = "调试命令：/ctk debug on|off";
localeData["ClearingData"] = "正在清除所有时间和位面数据...";
localeData["DataCleared"] = "已清除所有时间和位面数据，地图列表已保留";
localeData["DataClearFailedEmpty"] = "清除数据失败：地图列表为空";
localeData["DataClearFailedModule"] = "清除数据失败：Data模块未加载";
localeData["ClearUsage"] = "清除命令：/ctk clear 或 /ctk reset";
localeData["NotificationModuleNotLoaded"] = "通知模块未加载";
localeData["TeamNotificationStatusPrefix"] = "团队通知状态：";
localeData["TeamUsage1"] = "团队通知命令：";
localeData["TeamUsage2"] = "/ctk team on - 开启团队通知";
localeData["TeamUsage3"] = "/ctk team off - 关闭团队通知";
localeData["TeamUsage4"] = "/ctk team status - 查看团队通知状态";
localeData["HelpTitle"] = "可用命令：";
localeData["HelpClear"] = "/ctk clear 或 /ctk reset - 清除所有时间和位面数据（保留地图列表）";
localeData["HelpTeam"] = "/ctk team on|off - 开启/关闭团队通知";
localeData["HelpStatus"] = "/ctk team status - 查看团队通知状态";
localeData["HelpHelp"] = "/ctk help - 显示此帮助信息";
localeData["HelpUpdateWarning"] = "版本更新后出现任何问题，请彻底删除此插件目录后全新安装！！";

-- Debug Messages
localeData["DebugTimerStarted"] = "计时器已启动，来源：%s，下次刷新：%s";
localeData["DebugDetectionSourceManual"] = "手动输入";
localeData["DebugDetectionSourceRefresh"] = "刷新按钮";
localeData["DebugDetectionSourceAPI"] = "API接口";
localeData["DebugDetectionSourceMapIcon"] = "地图图标检测";
localeData["DebugNoRecord"] = "无记录";
localeData["DebugCannotGetMapName2"] = "无法获取当前地图名称";
localeData["DebugMapListEmpty"] = "地图列表为空，跳过地图图标检测";
localeData["DebugMapNotInList"] = "[空投检测] 当前地图不在有效列表中，跳过检测：%s (父地图=%s 地图ID=%s)";
localeData["DebugMapMatchSuccess"] = "[空投检测] 地图匹配成功：%s";
localeData["DebugParentMapMatchSuccess"] = "[空投检测] 父地图匹配成功（子区域）：%s (父地图=%s)";
localeData["DebugDetectedMapIconVignette"] = "[空投检测] 检测到地图图标（Vignette）：%s (空投箱子名称：%s)";
localeData["DebugUpdatedRefreshTime"] = "[空投检测] 已更新刷新时间：%s 下次刷新=%s";
localeData["DebugUpdateRefreshTimeFailed"] = "[空投检测] 更新刷新时间失败：地图ID=%s";
localeData["DebugMapIconNameNotConfigured"] = "[地图图标检测] 空投箱子名称未配置，跳过检测";
localeData["DebugAirdropActive"] = "[空投检测] 检测到空投箱，空投事件激活：%s";
localeData["DebugWaitingForConfirmation"] = "[空投检测] 等待连续检测确认：%s (间隔=%s秒)";
localeData["DebugClearedFirstDetectionTime"] = "[空投检测] 已清除首次检测时间记录（未检测到图标）：%s";
localeData["DebugAirdropEnded"] = "[空投检测] 未检测到图标，空投事件已结束：%s";
localeData["DebugFirstDetectionWait"] = "[空投检测] 首次检测到图标，等待连续检测确认：%s";
localeData["DebugContinuousDetectionConfirmed"] = "[空投检测] 连续检测确认有效，正在更新刷新时间并发送通知：%s (间隔=%s秒)";
localeData["ErrorTimerManagerNotInitialized"] = "计时管理器尚未初始化";
localeData["ErrorInvalidMapID"] = "无效的地图ID：";
localeData["ErrorTimerStartFailedMapID"] = "计时器启动失败：地图ID=";
localeData["ErrorInvalidMapIDList"] = "无效的地图ID列表";
localeData["ErrorMapNotFound"] = "未找到地图：";
localeData["ErrorInvalidSourceParam"] = "无效的检测来源参数";

-- 区域检测调试信息
localeData["DebugAreaInvalidInstance"] = "【地图有效性】区域无效（副本/战场/室内），插件已自动暂停";
localeData["DebugAreaCannotGetMapID"] = "【地图有效性】无法获取地图ID";
localeData["DebugAreaValid"] = "【地图有效性】区域有效，插件已启用: %s";
localeData["DebugAreaInvalidNotInList"] = "【地图有效性】区域无效（不在有效地图列表中），插件已自动暂停: %s";

-- 位面检测调试信息
localeData["DebugPhaseDetectionPaused"] = "【位面检测】检测功能已暂停，跳过位面检测";
localeData["DebugPhaseNoMapID"] = "无法获取当前地图ID，跳过位面信息更新";

-- 空投检测调试信息
localeData["DebugIconDetectionStart"] = "[地图图标检测] 开始检测，地图=%s，空投箱子名称=%s";
localeData["DebugCMapAPINotAvailable"] = "[Map API] C_Map API 不可用";
localeData["DebugCMapGetMapInfoNotAvailable"] = "[Map API] C_Map.GetMapInfo 不可用";


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
localeData["PluginAnnouncement"] = "|cff00ff88插件公告|r";
localeData["PluginIntro"] = "|cff00ff88插件简介|r";
-- UI 字体大小配置（数字类型）
localeData["UIFontSize"] = 15;

-- 菜单项
localeData["MenuHelp"] = "帮助";
localeData["MenuAbout"] = "关于";
localeData["MenuSettings"] = "设置";

-- ============================================================================
-- 地图名称翻译映射表（使用代号系统，完全语言无关）
-- ============================================================================
-- 格式：[地图代号] = "简体中文名称"
-- 注意：添加新语言只需创建新的本地化文件，添加代号到名称的映射即可
localeData.MapNames = {
    ["MAP_001"] = "多恩岛",      -- Isle of Dorn
    ["MAP_002"] = "卡雷什",      -- K'aresh
    ["MAP_003"] = "陨圣峪",      -- Hallowfall
    ["MAP_004"] = "艾基-卡赫特",  -- Azj-Kahet
    ["MAP_005"] = "安德麦",      -- Undermine
    ["MAP_006"] = "喧鸣深窟",    -- The Ringing Deeps
    ["MAP_007"] = "海妖岛",      -- Siren Isle
};

-- ============================================================================
-- 空投箱子名称本地化
-- ============================================================================
localeData.AirdropCrateNames = {
    ["AIRDROP_CRATE_001"] = "战争物资箱",
};

-- ============================================================================
-- 帮助和关于界面内容配置
-- ============================================================================
-- 注意：以下内容可以在本文件中直接修改，修改后需要重新加载插件才能生效

-- 关于界面（菜单中的"关于"按钮）
localeData["AnnouncementText"] = [[

插件作者：capzk
反馈建议：capzk@outlook.com


]];

-- 帮助界面（菜单中的"帮助"按钮）
localeData["IntroductionText"] = [[

• /ctk team on - 开启团队通知
• /ctk team off - 关闭团队通知
• /ctk clear - 清除数据

使用须知：
- 自动检测空投需要玩家处于有效区域。
- 副本，战场和室内属于无效区域，玩家处于以上区域插件会自动暂停检测。
- 只有当前地图名称和地图列表有匹配才视为有效区域。
- 可以团队合作分别蹲守，互相报告刷新时间，然后手动点击刷新按钮来启动计时，也可以点击时间区域输入一个时间来启动计时。

- 默认开启了团队消息提醒，可以使用命令暂停： /ctk team off。
- 插件有悬浮按钮，关闭插件界面可以重新打开，数据不会丢失。
- 退出游戏数据不会丢失。


感谢使用！]];

-- Register this locale
LocaleManager.RegisterLocale("zhCN", localeData);

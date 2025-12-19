-- CrateTrackerZK - 简体中文本地化
local ADDON_NAME = "CrateTrackerZK";
local locale = GetLocale();

if locale ~= "zhCN" and locale ~= "zhTW" then return end

local Namespace = BuildEnv(ADDON_NAME);
local L = Namespace.L;

-- 通用
L["AddonLoaded"] = "插件已加载，祝您游戏愉快！";
L["HelpCommandHint"] = "使用 |cffffcc00/ctk help|r 查看帮助信息";
L["CrateTrackerZK"] = "CrateTrackerZK";

-- 浮动按钮
L["FloatingButtonTooltipTitle"] = "CrateTrackerZK";
L["FloatingButtonTooltipLine1"] = "点击打开/关闭追踪面板";
L["FloatingButtonTooltipLine2"] = "拖动可以移动按钮位置";

-- 位面检测
L["NoInstanceAcquiredHint"] = "未获取任何位面ID，请使用鼠标指向任何NPC以获取当前位面ID";
L["CurrentInstanceID"] = "当前位面ID为：|cffffff00%s|r";
L["InstanceChangedTo"] = "地图[|cffffcc00%s|r]位面已变更为：|cffffff00%s|r";

-- 消息前缀
L["Prefix"] = "|cff00ff88[CrateTrackerZK]|r ";

-- 错误/提示
L["CommandModuleNotLoaded"] = "命令模块未加载，请重新加载插件";

-- 通知
L["TeamNotificationStatus"] = "团队通知%s";
L["AirdropDetected"] = "【%s】 发现 战争物资 正在空投！！！";
L["NoTimeRecord"] = "【%s】 暂无时间记录！！！";
L["TimeRemaining"] = "【%s】 距离 战争物资 空投还有：%s！！！";
L["Enabled"] = "已开启";
L["Disabled"] = "已关闭";

-- 命令
L["UnknownCommand"] = "未知命令：%s";
L["DebugEnabled"] = "调试信息已开启";
L["DebugDisabled"] = "调试信息已关闭";
L["DebugUsage"] = "调试命令：/ctk debug on|off";
L["ClearingData"] = "正在清除所有时间和位面数据...";
L["DataCleared"] = "已清除所有时间和位面数据，地图列表已保留";
L["DataClearFailedEmpty"] = "清除数据失败：地图列表为空";
L["DataClearFailedModule"] = "清除数据失败：Data模块未加载";
L["ClearUsage"] = "清除命令：/ctk clear 或 /ctk reset";
L["NotificationModuleNotLoaded"] = "通知模块未加载";
L["TeamNotificationStatusPrefix"] = "团队通知状态：";
L["TeamUsage1"] = "团队通知命令：";
L["TeamUsage2"] = "/ctk team on - 开启团队通知";
L["TeamUsage3"] = "/ctk team off - 关闭团队通知";
L["TeamUsage4"] = "/ctk team status - 查看团队通知状态";
L["HelpTitle"] = "可用命令：";
L["HelpClear"] = "/ctk clear 或 /ctk reset - 清除所有时间和位面数据（保留地图列表）";
L["HelpTeam"] = "/ctk team on|off - 开启/关闭团队通知";
L["HelpStatus"] = "/ctk team status - 查看团队通知状态";
L["HelpHelp"] = "/ctk help - 显示此帮助信息";
L["CollectDataLandmarkName"] = "地标名称";
L["CollectDataVignetteName"] = "Vignette名称";
L["CollectDataAreaPOIName"] = "区域POI名称";
L["CollectDataLabel"] = "[数据收集]";

-- UI
L["MainPanelTitle"] = "|cff00ff88[CrateTrackerZK]|r";
L["InfoButton"] = "信息";
L["AnnouncementButton"] = "公告";
L["IntroButton"] = "插件简介";
L["Map"] = "地图";
L["Phase"] = "位面";
L["LastRefresh"] = "上次刷新";
L["NextRefresh"] = "下次刷新";
L["Operation"] = "操作";
L["Refresh"] = "刷新";
L["Notify"] = "通知";
L["NotAcquired"] = "未获取";
L["NoRecord"] = "无记录";
L["MinuteSecond"] = "%d分%02d秒";
L["InputTimeHint"] = "请输入上次刷新时间 (HH:MM:SS 或 HHMMSS):";
L["Confirm"] = "确定";
L["Cancel"] = "取消";
L["TimeFormatError"] = "时间格式错误，请输入HH:MM:SS或HHMMSS格式";
L["TimestampError"] = "无法创建有效的时间戳";
L["InfoModuleNotLoaded"] = "信息模块未加载";
L["DataModuleNotLoaded"] = "Data模块未加载";
L["TimerManagerNotInitialized"] = "计时管理器尚未初始化";
L["Return"] = "返回";
L["PluginAnnouncement"] = "|cff00ff88插件公告|r";
L["PluginIntro"] = "|cff00ff88插件简介|r";

-- 菜单项
L["MenuHelp"] = "帮助";
L["MenuAbout"] = "关于";
L["MenuSettings"] = "设置";

-- ============================================================================
-- 空投检测相关文本（地图图标检测）
-- ============================================================================
-- 地图图标名称（完全匹配）
L["AirdropMapIconName"] = "战争物资箱";

-- ============================================================================
-- 帮助和关于界面内容配置
-- ============================================================================
-- 注意：以下内容可以在本文件中直接修改，修改后需要重新加载插件才能生效

-- 关于界面（菜单中的"关于"按钮）
L["AnnouncementText"] = [[

插件作者：capzk
反馈建议：capzk@itcat.dev


]];

-- 帮助界面（菜单中的"帮助"按钮）
L["IntroductionText"] = [[

• /ctk team on - 开启团队通知
• /ctk team off - 关闭团队通知
• /ctk clear - 清除数据

插件更新方式：
1. 黑盒工坊 新手盒子
2. https://app.itcat.dev/


感谢使用！]];


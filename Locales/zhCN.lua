-- CrateTrackerZK - 简体中文本地化
local ADDON_NAME = "CrateTrackerZK";
local locale = GetLocale();

if locale ~= "zhCN" then return end

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
L["HelpUpdateWarning"] = "版本更新后出现任何问题，请彻底删除此插件目录后全新安装！！";
L["CollectDataEnabled"] = "数据收集模式已开启。地图图标信息将在聊天中显示";
L["CollectDataDisabled"] = "数据收集模式已关闭";
L["CollectDataUsage"] = "数据收集命令：/ctk collect on|off - 开启/关闭数据收集模式（用于收集英文版本数据）";
L["CollectDataLandmarkName"] = "地标名称";
L["CollectDataVignetteName"] = "Vignette名称";
L["CollectDataAreaPOIName"] = "区域POI名称";
L["CollectDataLabel"] = "[数据收集]";

-- Debug Messages
L["DebugAPICall"] = "API调用";
L["DebugMapID"] = "地图ID";
L["DebugMapName"] = "地图名称";
L["DebugSource"] = "来源";
L["DebugTimestamp"] = "时间戳";
L["DebugTimerStarted"] = "计时器已启动，来源：%s，下次刷新：%s";
L["DebugManualUpdate"] = "手动操作：已更新刷新时间";
L["DebugLastRefresh"] = "上次刷新";
L["DebugNextRefresh"] = "下次刷新";
L["DebugTimerStartFailed"] = "计时器启动失败";
L["DebugReason"] = "原因";
L["DebugGetMapInfoSuccess"] = "成功获取地图信息";
L["DebugUsingGetInstanceInfo"] = "使用GetInstanceInfo获取地图名称";
L["DebugCannotGetMapName"] = "无法获取地图名称";
L["DebugUnknownSource"] = "未知来源";
L["DebugDetectionSourceManual"] = "手动输入";
L["DebugDetectionSourceRefresh"] = "刷新按钮";
L["DebugDetectionSourceAPI"] = "API接口";
L["DebugDetectionSourceMapIcon"] = "地图图标检测";
L["DebugNoRecord"] = "无记录";
L["DebugMap"] = "地图";
L["DebugTimerStartFailedMapID"] = "计时器启动失败：地图ID=";
L["DebugInvalidMapID"] = "无效的地图ID：";
L["DebugInvalidMapIDList"] = "无效的地图ID列表";
L["DebugInvalidSourceParam"] = "无效的检测来源参数";
L["DebugCMapAPINotAvailable"] = "C_Map API不可用";
L["DebugCannotGetMapID"] = "无法获取当前地图ID";
L["DebugCMapGetMapInfoNotAvailable"] = "C_Map.GetMapInfo API不可用";
L["DebugCannotGetMapName2"] = "无法获取当前地图名称";
L["DebugMapListEmpty"] = "地图列表为空，跳过地图图标检测";
L["DebugMapNotInList"] = "[空投检测] 当前地图不在有效列表中，跳过检测：%s (父地图=%s 地图ID=%s)";
L["DebugMapMatchSuccess"] = "[空投检测] 地图匹配成功：%s";
L["DebugParentMapMatchSuccess"] = "[空投检测] 父地图匹配成功（子区域）：%s (父地图=%s)";
L["DebugDetectedMapIconLandmark"] = "[空投检测] 检测到地图图标（地标）：%s (图标名称：%s)";
L["DebugDetectedMapIconVignette"] = "[空投检测] 检测到地图图标（Vignette）：%s (图标名称：%s)";
L["DebugDetectedMapIconPOI"] = "[空投检测] 检测到地图图标（区域POI）：%s (图标名称：%s)";
L["DebugUpdatedRefreshTime"] = "[空投检测] 已更新刷新时间：%s 下次刷新=%s";
L["DebugUpdateRefreshTimeFailed"] = "[空投检测] 更新刷新时间失败：地图ID=%s";
L["DebugMapIconNameNotConfigured"] = "[地图图标检测] 地图图标名称未配置，跳过检测";
L["DebugAirdropActive"] = "[空投检测] 检测到空投箱，空投事件激活：%s";
L["DebugWaitingForConfirmation"] = "[空投检测] 等待连续检测确认：%s (间隔=%s秒)";
L["DebugClearedFirstDetectionTime"] = "[空投检测] 已清除首次检测时间记录（未检测到图标）：%s";
L["DebugAirdropEnded"] = "[空投检测] 未检测到图标，空投事件已结束：%s";
L["DebugMapIconDetectionStarted"] = "地图图标检测已启动";
L["DebugDetectionInterval"] = "检测间隔";
L["DebugMapIconDetectionStopped"] = "地图图标检测已停止";
L["DebugSeconds"] = "秒";
L["DebugFirstDetectionWait"] = "[空投检测] 首次检测到图标，等待连续检测确认：%s";
L["DebugContinuousDetectionConfirmed"] = "[空投检测] 连续检测确认有效，正在更新刷新时间并发送通知：%s (间隔=%s秒)";
L["ErrorTimerManagerNotInitialized"] = "计时管理器尚未初始化";
L["ErrorInvalidMapID"] = "无效的地图ID：";
L["ErrorTimerStartFailedMapID"] = "计时器启动失败：地图ID=";
L["ErrorInvalidMapIDList"] = "无效的地图ID列表";
L["ErrorMapNotFound"] = "未找到地图：";
L["ErrorInvalidSourceParam"] = "无效的检测来源参数";

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
-- UI 字体大小配置（数字类型）
L["UIFontSize"] = 15;

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

使用须知：
- 自动检测空投需要玩家处于有效区域。
- 主城，副本，战场和室内属于无效区域，玩家处于以上区域插件会自动暂停检测。
- 可以团队合作分别蹲守，互相报告刷新时间，然后手动点击刷新按钮来启动计时，也可以点击时间区域输入一个时间来启动计时。

- 默认开启了团队消息提醒，可以使用命令暂停： /ctk team off。
- 插件有悬浮按钮，关闭插件界面可以重新打开，数据不会丢失。
- 退出游戏数据不会丢失。


感谢使用！]];


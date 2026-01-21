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

-- 通用
localeData["AddonLoaded"] = "插件已加载，祝您游戏愉快！";
localeData["HelpCommandHint"] = "使用 |cffffcc00/ctk help|r 查看帮助信息";
localeData["CrateTrackerZK"] = "CrateTrackerZK";

-- 浮动按钮
localeData["FloatingButtonTooltipTitle"] = "CrateTrackerZK";
localeData["FloatingButtonTooltipLine1"] = "点击打开/关闭追踪面板";
localeData["FloatingButtonTooltipLine2"] = "拖动可以移动按钮位置";

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
localeData["MapNamesCount"] = "缺失地图名称: %d";
localeData["AirdropCratesCount"] = "缺失空投箱子名称: %d";

-- 通知
localeData["TeamNotificationStatus"] = "团队通知%s";
localeData["AirdropDetected"] = "【%s】 检测到战争物资正在空投！！！";  -- 自动检测消息（带"检测到"关键字）
localeData["AirdropDetectedManual"] = "【%s】 战争物资正在空投！！！";  -- 手动通知消息（不带"检测到"关键字）
localeData["NoTimeRecord"] = "【%s】 暂无时间记录！！！";
localeData["TimeRemaining"] = "【%s】 距离 战争物资 空投还有：%s！！！";
localeData["Enabled"] = "已开启";
localeData["Disabled"] = "已关闭";

-- 位面检测提示
localeData["PhaseDetectedFirstTime"] = "【%s】当前位面ID：|cffffff00%s|r";
localeData["InstanceChangedTo"] = "【%s】当前位面ID已变更为：|cffffff00%s|r";

-- 无效空投提示
localeData["InvalidAirdropNotification"] = "【%s】 检测到无效空投事件，空投飞机存在时间过短，判定为无效事件。";

-- 命令
localeData["UnknownCommand"] = "未知命令：%s";
localeData["ClearingData"] = "正在清除所有时间和位面数据...";
localeData["DataCleared"] = "已清除所有数据，插件已重新初始化";
localeData["DataClearFailedModule"] = "清除数据失败：Data模块未加载";
localeData["TeamUsage1"] = "团队通知命令：";
localeData["TeamUsage2"] = "/ctk team on - 开启团队通知";
localeData["TeamUsage3"] = "/ctk team off - 关闭团队通知";
localeData["HelpTitle"] = "可用命令：";
localeData["HelpClear"] = "/ctk clear 或 /ctk reset - 清除所有数据并重新初始化插件";
localeData["HelpTeam"] = "/ctk team on|off - 开启/关闭团队通知";
localeData["HelpHelp"] = "/ctk help - 显示此帮助信息";
localeData["HelpUpdateWarning"] = "版本更新后出现任何问题，请彻底删除此插件目录后全新安装！！";

localeData["ErrorTimerManagerNotInitialized"] = "计时管理器尚未初始化";
localeData["ErrorInvalidMapID"] = "无效的地图ID：%s";
localeData["ErrorTimerStartFailedMapID"] = "计时器启动失败：地图ID=%s";
localeData["ErrorUpdateRefreshTimeFailed"] = "刷新时间更新失败：地图ID=%s";
localeData["ErrorMapTrackerModuleNotLoaded"] = "MapTracker 模块未加载";
localeData["ErrorIconDetectorModuleNotLoaded"] = "IconDetector 模块未加载";
localeData["ErrorTimerManagerModuleNotLoaded"] = "TimerManager 模块未加载";
localeData["ErrorCannotGetMapData"] = "无法获取地图数据，地图ID=%s";
localeData["TimeFormatError"] = "时间格式错误，请输入HH:MM:SS或HHMMSS格式";
localeData["TimestampError"] = "无法创建有效的时间戳";
localeData["AddonInitializedSuccess"] = "插件初始化成功，祝您游戏愉快！";

-- UI
localeData["MainPanelTitle"] = "|cff00ff88[CrateTrackerZK]|r";
localeData["InfoButton"] = "信息";
localeData["Map"] = "地图";
localeData["Phase"] = "位面";
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
localeData["InputTimeHint"] = "请输入上次刷新时间 (HH:MM:SS 或 HHMMSS):";
localeData["Confirm"] = "确定";
localeData["Cancel"] = "取消";
localeData["Return"] = "返回";
localeData["UIFontSize"] = 15;
localeData["HelpText"] = [[可用命令：

/ctk on                 启动插件
/ctk off                彻底关闭插件（暂停检测并隐藏界面）
/ctk clear              清除本地数据并重新初始化
/ctk team on/off        开启/关闭团队通知

团队时间共享已默认开启，并会通过团队通知同步时间。请确保团队成员开启团队通知功能，以便共享生效。

 要获取当前位面ID，您只需将鼠标指向任意NPC。位面ID将自动检测并显示在主面板中。
 如果插件升级后出现任何问题，请彻底删除此插件目录并重新安装。]];

-- 菜单项
localeData["MenuHelp"] = "帮助";
localeData["MenuAbout"] = "关于";

-- 地图名称翻译（使用地图ID作为键）
localeData.MapNames = {
    [2248] = "多恩岛",      -- 多恩岛
    [2369] = "海妖岛",      -- 海妖岛
    [2371] = "卡雷什",      -- 卡雷什
    [2346] = "安德麦",      -- 安德麦
    [2215] = "陨圣峪",      -- 陨圣峪
    [2214] = "喧鸣深窟",    -- 喧鸣深窟
    [2255] = "艾基-卡赫特", -- 艾基-卡赫特
};

-- 空投箱子名称
localeData.AirdropCrateNames = {
    ["WarSupplyCrate"] = "战争物资箱",
};

-- 空投 NPC 喊话（用于喊话检测，缺失将自动跳过该语言的喊话检测）
localeData.AirdropShouts = {
    "路费欧斯说： 附近好像有宝藏，自然也会有宝藏猎手了。小心背后。",
    "路费欧斯说： 附近有满满一箱资源，赶紧找，不然难免大打出手哦！",
    "路费欧斯说： 机会送上门来了！只要你够有勇气，那些宝贝在等着你呢。",
    "路费欧斯说： 区域里出现了珍贵资源！快去抢吧！",
};

-- Register this locale
LocaleManager.RegisterLocale("zhCN", localeData);

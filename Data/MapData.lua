-- CrateTrackerZK - 静态地图配置
local ADDON_NAME = "CrateTrackerZK";
local Data = BuildEnv("Data");

-- 默认刷新间隔设置为18分20秒（1100秒）
Data.DEFAULT_REFRESH_INTERVAL = 1100;

-- 内置地图列表
Data.DEFAULT_MAPS = {
    {name = "多恩岛", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {name = "卡雷什", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {name = "陨圣峪", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {name = "艾基-卡赫特", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {name = "安德麦", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {name = "喧鸣深窟", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {name = "海妖岛", interval = Data.DEFAULT_REFRESH_INTERVAL},
};


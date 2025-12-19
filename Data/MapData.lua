-- CrateTrackerZK - 静态地图配置
local ADDON_NAME = "CrateTrackerZK";
local Data = BuildEnv("Data");

Data.DEFAULT_REFRESH_INTERVAL = 1100;

-- 内置地图列表（支持中英文）
Data.DEFAULT_MAPS = {
    {name = "多恩岛", nameEn = "Isle of Dorn", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {name = "卡雷什", nameEn = "K'aresh", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {name = "陨圣峪", nameEn = "Hallowfall", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {name = "艾基-卡赫特", nameEn = "Azj-Kahet", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {name = "安德麦", nameEn = "Undermine", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {name = "喧鸣深窟", nameEn = "The Ringing Deeps", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {name = "海妖岛", nameEn = "Siren Isle", interval = Data.DEFAULT_REFRESH_INTERVAL},
};

-- 主城名称（支持中英文）
Data.CAPITAL_CITY_NAMES = {
    zhCN = "多恩诺嘉尔",
    enUS = "Dornogal",
};


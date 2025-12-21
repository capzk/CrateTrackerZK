-- CrateTrackerZK - 静态地图配置
local ADDON_NAME = "CrateTrackerZK";
local Data = BuildEnv("Data");

Data.DEFAULT_REFRESH_INTERVAL = 1100;

-- 内置地图列表（支持中英文和繁体中文）
Data.DEFAULT_MAPS = {
    {name = "多恩岛", nameEn = "Isle of Dorn", nameZhTW = "多恩島", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {name = "卡雷什", nameEn = "K'aresh", nameZhTW = "凱瑞西", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {name = "陨圣峪", nameEn = "Hallowfall", nameZhTW = "聖落之地", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {name = "艾基-卡赫特", nameEn = "Azj-Kahet", nameZhTW = "阿茲-卡罕特", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {name = "安德麦", nameEn = "Undermine", nameZhTW = "幽坑城", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {name = "喧鸣深窟", nameEn = "The Ringing Deeps", nameZhTW = "鳴響深淵", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {name = "海妖岛", nameEn = "Siren Isle", nameZhTW = "海妖島", interval = Data.DEFAULT_REFRESH_INTERVAL},
};

-- 主城名称（支持中英文和繁体中文）
Data.CAPITAL_CITY_NAMES = {
    zhCN = "多恩诺嘉尔",
    enUS = "Dornogal",
    zhTW = "多恩諾加",
};


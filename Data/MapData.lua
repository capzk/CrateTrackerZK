-- CrateTrackerZK - 静态地图
local ADDON_NAME = "CrateTrackerZK";
local Data = BuildEnv("Data");

Data.DEFAULT_REFRESH_INTERVAL = 1100;

Data.DEFAULT_MAPS = {
    {code = "MAP_001", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {code = "MAP_002", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {code = "MAP_003", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {code = "MAP_004", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {code = "MAP_005", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {code = "MAP_006", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {code = "MAP_007", interval = Data.DEFAULT_REFRESH_INTERVAL},
};

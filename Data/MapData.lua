-- CrateTrackerZK - 静态地图配置
local ADDON_NAME = "CrateTrackerZK";
local Data = BuildEnv("Data");

Data.DEFAULT_REFRESH_INTERVAL = 1100;

-- 内置地图列表（使用代号系统，完全语言无关）
-- 注意：使用代号（MAP_001, MAP_002等）作为键，所有地图名称完全依靠本地化文件
-- 
-- 关于地图编号（ID）和代号（Code）：
-- - 地图的 id 是数组索引（1, 2, 3...），自动生成
-- - 地图的 code 是唯一标识符（MAP_001, MAP_002等），用于数据存储和本地化
-- - 可以任意调整数组顺序来改变 id，但 code 保持不变
-- - 数据存储使用 code 作为键，不依赖 id，所以调整顺序不会影响已保存的数据
-- - 添加新语言只需在本地化文件中添加代号到名称的映射，无需修改代码
Data.DEFAULT_MAPS = {
    {code = "MAP_001", interval = Data.DEFAULT_REFRESH_INTERVAL},  -- id = 1, 多恩岛/Isle of Dorn
    {code = "MAP_002", interval = Data.DEFAULT_REFRESH_INTERVAL},  -- id = 2, 卡雷什/K'aresh
    {code = "MAP_003", interval = Data.DEFAULT_REFRESH_INTERVAL},  -- id = 3, 陨圣峪/Hallowfall
    {code = "MAP_004", interval = Data.DEFAULT_REFRESH_INTERVAL},  -- id = 4, 艾基-卡赫特/Azj-Kahet
    {code = "MAP_005", interval = Data.DEFAULT_REFRESH_INTERVAL},  -- id = 5, 安德麦/Undermine
    {code = "MAP_006", interval = Data.DEFAULT_REFRESH_INTERVAL},  -- id = 6, 喧鸣深窟/The Ringing Deeps
    {code = "MAP_007", interval = Data.DEFAULT_REFRESH_INTERVAL},  -- id = 7, 海妖岛/Siren Isle
};

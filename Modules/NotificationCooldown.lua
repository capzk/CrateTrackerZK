-- NotificationCooldown.lua
-- 职责：记录通知时间（已简化，仅用于记录，不再用于限制）
-- 注意：在新简化方案中，5分钟暂停期已足够防止重复通知

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local NotificationCooldown = BuildEnv('NotificationCooldown');

if not Utils then
    Utils = BuildEnv('Utils')
end

-- 使用 Logger 模块统一输出
local function SafeDebug(...)
    Logger:Debug("NotificationCooldown", "调试", ...);
end

-- 初始化
function NotificationCooldown:Initialize()
    self.lastNotificationTime = self.lastNotificationTime or {}; -- 仅用于记录
end

-- 记录通知时间
-- 输入：mapId - 地图ID
--      timestamp - 通知时间戳
function NotificationCooldown:RecordNotification(mapId, timestamp)
    if not mapId or not timestamp then
        return;
    end
    
    self:Initialize(); -- 确保初始化
    
    self.lastNotificationTime[mapId] = timestamp;
    local mapData = Data and Data:GetMap(mapId);
    local mapName = mapData and Data:GetMapDisplayName(mapData) or tostring(mapId);
    Logger:Debug("NotificationCooldown", "记录", string.format("已记录通知时间：地图=%s，时间=%s", 
        mapName, Data:FormatDateTime(timestamp)));
end


-- 初始化
NotificationCooldown:Initialize();

return NotificationCooldown;

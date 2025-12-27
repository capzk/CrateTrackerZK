-- NotificationCooldown.lua
-- 职责：独立管理通知冷却期
-- 关键：通知冷却期独立管理，不随检测状态清除

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
    self.lastNotificationTime = self.lastNotificationTime or {}; -- 独立管理，不随状态清除
    self.cooldown = 120; -- 冷却时间（秒，2分钟）
end

-- 检查是否可以发送通知
-- 输入：mapId - 地图ID
--      timestamp - 当前时间戳
-- 输出：boolean - 是否可以发送通知
function NotificationCooldown:CanNotify(mapId, timestamp)
    if not mapId or not timestamp then
        return true; -- 参数无效，允许通知（保守策略）
    end
    
    self:Initialize(); -- 确保初始化
    
    local lastNotifyTime = self.lastNotificationTime[mapId];
    
    if not lastNotifyTime or type(lastNotifyTime) ~= "number" then
        -- 无上次通知记录，允许通知
        SafeDebug(string.format("[通知冷却] 无上次通知记录（mapId=%d），允许发送通知", mapId));
        return true;
    end
    
    local timeSinceLastNotify = timestamp - lastNotifyTime;
    
    if timeSinceLastNotify >= self.cooldown then
        -- 超过冷却期，允许通知
        SafeDebug(string.format("[通知冷却] 距离上次通知 %d 秒（>= %d 秒），允许发送通知", timeSinceLastNotify, self.cooldown));
        return true;
    else
        -- 在冷却期内，不允许通知
        SafeDebug(string.format("[通知冷却] 距离上次通知 %d 秒（< %d 秒），跳过通知", timeSinceLastNotify, self.cooldown));
        return false;
    end
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
    SafeDebug(string.format("[通知冷却] 已记录通知时间：地图ID=%d，时间=%d", mapId, timestamp));
end

-- 清除通知冷却期（仅在需要时调用，如离开地图300秒后）
-- 输入：mapId - 地图ID
function NotificationCooldown:ClearCooldown(mapId)
    if not mapId then
        return;
    end
    
    self:Initialize(); -- 确保初始化
    
    if self.lastNotificationTime[mapId] then
        self.lastNotificationTime[mapId] = nil;
        SafeDebug(string.format("[通知冷却] 已清除通知冷却期：地图ID=%d", mapId));
    end
end

-- 初始化
NotificationCooldown:Initialize();

return NotificationCooldown;


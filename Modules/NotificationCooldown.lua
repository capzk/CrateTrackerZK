-- NotificationCooldown.lua
-- 记录通知时间

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

function NotificationCooldown:Initialize()
    self.lastNotificationTime = self.lastNotificationTime or {};
end

function NotificationCooldown:RecordNotification(mapId, timestamp)
    if not mapId or not timestamp then
        return;
    end
    
    self:Initialize();
    
    self.lastNotificationTime[mapId] = timestamp;
    local mapData = Data and Data:GetMap(mapId);
    local mapName = mapData and Data:GetMapDisplayName(mapData) or tostring(mapId);
    Logger:Debug("NotificationCooldown", "记录", string.format("已记录通知时间：地图=%s，时间=%s", 
        mapName, Data:FormatDateTime(timestamp)));
end

NotificationCooldown:Initialize();

return NotificationCooldown;

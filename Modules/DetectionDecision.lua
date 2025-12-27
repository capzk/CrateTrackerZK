-- DetectionDecision.lua
-- 职责：根据检测结果和状态做决策（符合设计文档）
-- 纯函数，无副作用

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local DetectionDecision = BuildEnv('DetectionDecision');

if not NotificationCooldown then
    NotificationCooldown = BuildEnv('NotificationCooldown')
end

if not DetectionState then
    DetectionState = BuildEnv('DetectionState')
end

if not Utils then
    Utils = BuildEnv('Utils')
end

-- 使用 Logger 模块统一输出
local function SafeDebug(...)
    Logger:Debug("DetectionDecision", "调试", ...);
end

-- 常量
DetectionDecision.MIN_UPDATE_INTERVAL = 30; -- 最小更新时间间隔（秒）

-- 检查是否应该发送通知
-- 输入：mapId - 地图ID
--      state - 状态对象
--      timestamp - 当前时间戳
-- 输出：boolean - 是否应该发送通知
function DetectionDecision:ShouldNotify(mapId, state, timestamp)
    if not mapId or not state or not timestamp then
        return false;
    end
    
    -- 仅在 CONFIRMED 状态且持续2秒后检查（已更新设计）
    if state.status ~= DetectionState.STATES.CONFIRMED then
        return false;
    end
    
    -- 检查通知冷却期（120秒）
    if NotificationCooldown and NotificationCooldown.CanNotify then
        return NotificationCooldown:CanNotify(mapId, timestamp);
    end
    
    -- 如果 NotificationCooldown 未加载，默认允许通知（保守策略）
    return true;
end

-- 检查是否应该更新时间
-- 输入：mapId - 地图ID
--      state - 状态对象
--      timestamp - 当前时间戳
-- 输出：boolean - 是否应该更新时间
function DetectionDecision:ShouldUpdateTime(mapId, state, timestamp)
    if not mapId or not state or not timestamp then
        return false;
    end
    
    -- 仅在 CONFIRMED 状态且持续2秒后检查
    if state.status ~= DetectionState.STATES.CONFIRMED then
        return false;
    end
    
    -- 必须有首次检测时间
    if not state.firstDetectedTime then
        return false;
    end
    
    -- 检查最小更新时间间隔（30秒）
    if state.lastUpdateTime then
        local timeSinceLastUpdate = timestamp - state.lastUpdateTime;
        if timeSinceLastUpdate < self.MIN_UPDATE_INTERVAL then
            SafeDebug(string.format("跳过更新时间（距离上次更新仅 %d 秒，小于最小间隔 %d 秒）", 
                timeSinceLastUpdate, self.MIN_UPDATE_INTERVAL));
            return false;
        end
    end
    
    return true;
end

return DetectionDecision;


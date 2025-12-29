# 空投检测流程分析报告

## 一、当前检测流程

### 1.1 检测循环（每1秒）

```
TimerManager:DetectMapIcons() [Timer.lua:177]
  │
  ├─ 1. 获取当前地图ID
  │   C_Map.GetBestMapForUnit("player")
  │
  ├─ 2. 匹配目标地图数据
  │   MapTracker:GetTargetMapData(currentMapID)
  │   └─ 支持父地图匹配
  │
  ├─ 3. 处理地图变化
  │   MapTracker:OnMapChanged(currentMapID, targetMapData, currentTime)
  │   └─ 如果配置地图变化，清除旧地图的PROCESSED状态
  │
  ├─ 4. 检查PROCESSED状态（5分钟冷却期）
  │   DetectionState:IsProcessed(targetMapData.id)
  │   ├─ 如果超时（>= 300秒）：清除PROCESSED状态
  │   └─ 如果未超时：跳过检测，返回false
  │
  ├─ 5. 检测图标
  │   IconDetector:DetectIcon(currentMapID)
  │   └─ 仅依赖名称匹配（"War Supply Crate" / "战争物资箱"）
  │
  ├─ 6. 更新状态机
  │   DetectionState:UpdateState(mapId, iconDetected, currentTime)
  │   └─ 状态转换逻辑（见下文）
  │
  └─ 7. 处理CONFIRMED状态
      ├─ 发送通知（⚠️ 问题：未检查冷却期）
      ├─ 记录通知时间
      ├─ 更新刷新时间
      └─ 标记为PROCESSED
```

### 1.2 图标检测逻辑

```lua
IconDetector:DetectIcon(currentMapID)
  ├─ 获取所有Vignette图标
  │   C_VignetteInfo.GetVignettes()
  │
  ├─ 遍历所有图标
  │   for _, vignetteGUID in ipairs(vignettes)
  │
  └─ 名称匹配
      if vignetteName == crateName then
          return true
      end
```

**特点**：
- ✅ 仅依赖名称匹配，不检查位置
- ✅ 支持子地图场景
- ✅ 简单可靠

---

## 二、状态机机制

### 2.1 状态定义

```lua
DetectionState.STATES = {
    IDLE = "idle",           -- 空闲状态
    DETECTING = "detecting", -- 检测中（等待2秒确认）
    CONFIRMED = "confirmed",  -- 已确认（持续2秒后）
    PROCESSED = "processed"  -- 已处理（更新时间和通知后）
}
```

### 2.2 状态转换流程

```
初始状态：IDLE
  │
  ├─ 检测到图标
  │   └─ IDLE → DETECTING
  │       └─ 记录首次检测时间：firstDetectedTime = currentTime
  │
  ├─ 持续检测到图标 >= 2秒
  │   └─ DETECTING → CONFIRMED
  │       └─ 设置 mapIconDetected[mapId] = true
  │
  ├─ CONFIRMED状态处理（Timer.lua:244）
  │   ├─ 发送通知
  │   ├─ 记录通知时间
  │   ├─ 更新刷新时间
  │   └─ CONFIRMED → PROCESSED
  │       └─ 标记 processedTime[mapId] = currentTime
  │
  └─ PROCESSED状态
      ├─ 暂停检测5分钟（300秒）
      └─ 超时后自动清除 → IDLE
```

### 2.3 状态清除条件

**1. DETECTING状态清除**（图标消失且未满2秒）：
```lua
if state.status == DETECTING and not iconDetected then
    if timeSinceFirstDetection < 2 then
        -- 清除首次检测时间，回到IDLE
        firstDetectedTime = nil
    end
end
```

**2. CONFIRMED状态清除**（图标立即消失）：
```lua
if state.status == CONFIRMED and not iconDetected then
    -- 判定为误报，清除所有状态
    firstDetectedTime = nil
    mapIconDetected = nil
    -- 回到IDLE
end
```

**3. PROCESSED状态清除**：
- **超时清除**：距离processedTime >= 300秒
- **地图切换清除**：切换到其他配置地图时
- **离开地图清除**：离开地图5分钟后（MapTracker:CheckAndClearLeftMaps）

---

## 三、防误报机制

### 3.1 2秒确认期

**目的**：防止短暂图标闪烁导致的误判

**实现**：
```lua
-- DetectionState.lua:91-100
if state.status == DETECTING then
    local timeSinceFirstDetection = currentTime - state.firstDetectedTime;
    if timeSinceFirstDetection >= 2 then
        -- 持续检测2秒，确认空投
        newState.status = CONFIRMED;
    end
end
```

**效果**：
- ✅ 如果图标在2秒内消失，清除检测状态（判定为误报）
- ✅ 只有持续检测2秒才确认空投

### 3.2 5分钟冷却期（PROCESSED状态）

**目的**：防止短时间内重复检测和更新

**实现**：
```lua
-- DetectionState.lua:138-144
function DetectionState:IsProcessedTimeout(mapId, currentTime)
    local processedTime = self.processedTime[mapId];
    if not processedTime then return false end;
    return (currentTime - processedTime) >= 300; -- 5分钟
end
```

**效果**：
- ✅ PROCESSED状态下暂停检测5分钟
- ✅ 防止重复更新刷新时间

### 3.3 通知冷却期（⚠️ 问题：未实现）

**文档说明**：120秒内不重复通知

**当前实现**：
- ❌ **问题**：Timer.lua在CONFIRMED状态时直接发送通知，未检查冷却期
- ❌ **问题**：NotificationCooldown模块只有`RecordNotification`方法，缺少`IsInCooldown`方法

**应该的实现**：
```lua
-- 应该在发送通知前检查冷却期
if NotificationCooldown:IsInCooldown(mapId, currentTime) then
    -- 跳过通知
else
    -- 发送通知
    Notification:NotifyAirdropDetected(...)
    NotificationCooldown:RecordNotification(mapId, currentTime)
end
```

---

## 四、状态清除机制

### 4.1 角色切换/重新进入游戏/重载时清除（Core.lua:12-83）

**触发时机**：`PLAYER_LOGIN` 事件

**重要说明**：
- ✅ **重载游戏** (`/reload`) 会触发 `PLAYER_LOGIN` 事件
- ✅ **切换角色** 会触发 `PLAYER_LOGIN` 事件
- ✅ **重新登入游戏** 会触发 `PLAYER_LOGIN` 事件
- ✅ **三者都会执行相同的 `OnLogin()` 函数，清除所有内存状态**

**清除内容**：
```lua
-- 清除所有内存检测状态
DetectionState:ClearAllStates()
  ├─ mapIconFirstDetectedTime = {}
  ├─ mapIconDetected = {}
  ├─ lastUpdateTime = {}
  └─ processedTime = {}

MapTracker:Initialize()
  ├─ mapLeftTime = {}
  ├─ lastDetectedMapId = nil
  └─ lastDetectedGameMapID = nil

NotificationCooldown:ClearAll()
  └─ lastNotificationTime = {}

Phase:Reset()
  ├─ anyInstanceIDAcquired = false
  └─ lastReportedInstanceID = nil

Area状态重置
  ├─ lastAreaValidState = nil
  └─ detectionPaused = false

核心模块定时器状态重置
  ├─ phaseTimerTicker = nil
  ├─ phaseTimerPaused = false
  └─ phaseResumePending = false
```

**目的**：防止跨角色状态污染，确保每次登录都有干净的状态

### 4.2 clear命令清除（Commands.lua:46-117）

**触发时机**：用户执行 `/ctk clear` 或 `/ctk reset` 命令

**清除内容**：
```lua
-- 1. 停止所有定时器
TimerManager:StopMapIconDetection()
CrateTrackerZK.phaseTimerTicker:Cancel()
MainPanel.updateTimer:Cancel()

-- 2. 隐藏并销毁UI
CrateTrackerZKFrame:Hide()
CrateTrackerZKFloatingButton:Hide()

-- 3. 清除所有SavedVariables数据
CRATETRACKERZK_DB.mapData = {}  -- 清除所有地图数据
CRATETRACKERZK_UI_DB = {}        -- 清除UI设置（部分）

-- 4. 清除内存数据
Data.maps = {}
TimerManager.isInitialized = false

-- 5. 清除检测状态（⚠️ 问题：只清除PROCESSED状态）
for _, mapData in ipairs(maps) do
    DetectionState:ClearProcessed(mapData.id)  -- 只清除PROCESSED
end

-- 6. 清除其他模块状态
MapTracker.mapLeftTime = {}
NotificationCooldown.lastNotificationTime = {}
Notification.isInitialized = false
Logger:ClearMessageCache()

-- 7. 重新初始化
CrateTrackerZK:Reinitialize()  -- 调用OnLogin()重新初始化
```

**目的**：完全重置插件，清除所有数据和状态

**⚠️ 问题1**：clear命令只清除了PROCESSED状态，没有清除DETECTING和CONFIRMED状态。应该调用`DetectionState:ClearAllStates()`而不是只清除PROCESSED状态。

**⚠️ 问题2**：clear命令清除状态后，又调用`Reinitialize()` → `OnLogin()`，会再次清除状态，这是冗余操作。但由于clear命令还清除SavedVariables数据（这是OnLogin()不做的），所以功能上不重复。

### 4.3 地图切换时清除（MapTracker.lua:128-141）

**触发时机**：配置地图变化（切换到不同的追踪地图）

**清除逻辑**：
```lua
if configMapChanged and lastDetectedMapId then
    if DetectionState:IsProcessed(lastDetectedMapId) then
        DetectionState:ClearProcessed(lastDetectedMapId)
        -- 记录离开时间
        mapLeftTime[lastDetectedMapId] = currentTime
    end
end
```

**目的**：切换地图时清除旧地图的处理状态

### 4.4 离开地图超时清除（MapTracker.lua:156-184）

**触发时机**：每1秒检查一次（Timer.lua:207）

**清除条件**：
```lua
-- 离开地图时间 >= 300秒（5分钟）
if timeSinceLeft >= MAP_LEFT_CLEAR_TIME then
    DetectionState:ClearProcessed(mapId)
    mapLeftTime[mapId] = nil
end
```

**目的**：离开地图5分钟后自动清除状态，释放内存

### 4.5 PROCESSED状态超时清除（Timer.lua:208-220）

**触发时机**：每次检测循环时检查

**清除条件**：
```lua
if DetectionState:IsProcessedTimeout(mapId, currentTime) then
    DetectionState:ClearProcessed(mapId)
end
```

**目的**：5分钟冷却期后恢复检测

### 4.6 Data:ClearAllData()清除（Data.lua:274-314）

**触发时机**：目前未被调用（可能是预留功能）

**清除内容**：
```lua
-- 清除所有地图数据
for i, mapData in ipairs(self.maps) do
    mapData.lastRefresh = nil
    mapData.nextRefresh = nil
    mapData.instance = nil
    mapData.lastInstance = nil
    mapData.lastRefreshInstance = nil
    CRATETRACKERZK_DB.mapData[mapData.mapID] = nil
end

-- 清除检测状态
for i, mapData in ipairs(self.maps) do
    DetectionState:ClearProcessed(mapData.id)
end

-- 清除其他状态
MapTracker.mapLeftTime = {}
NotificationCooldown.lastNotificationTime = {}
```

**目的**：清除所有数据（但保留地图配置）

**注意**：此函数目前未被调用，可能是预留功能或内部使用

### 4.7 清除机制重复性分析

**重复性总结**：

| 清除机制 | 触发时机 | 清除范围 | 是否重复 | 说明 |
|---------|---------|---------|---------|------|
| OnLogin() | PLAYER_LOGIN | 所有状态 | - | 重载/切换角色/重新登录都会触发 |
| clear命令 | 用户命令 | 所有状态+数据 | ⚠️ 与OnLogin()部分重复 | 但还清除SavedVariables，功能不同 |
| 地图切换 | 配置地图变化 | 旧地图PROCESSED | ❌ 不重复 | 特定场景 |
| 离开超时 | 离开地图>=300秒 | 该地图PROCESSED | ⚠️ 与PROCESSED超时部分重复 | 但场景不同 |
| PROCESSED超时 | PROCESSED>=300秒 | 该地图PROCESSED | ⚠️ 与离开超时部分重复 | 但场景不同 |

**结论**：
- ✅ **有重复，但不影响功能**：clear命令与OnLogin()在状态清除上有重复，但clear还清除SavedVariables数据
- ✅ **部分重复是合理的**：离开地图超时和PROCESSED超时虽然都清除PROCESSED状态，但场景不同（一个是在地图外，一个是在地图内）
- 💡 **优化建议**：clear命令可以简化，只清除SavedVariables，状态清除交给OnLogin()处理

---

## 五、发现的问题

### 5.1 ⚠️ 通知冷却期未实现

**问题描述**：
- 文档说明：120秒内不重复通知
- 实际代码：Timer.lua在CONFIRMED状态时直接发送通知，未检查冷却期

**影响**：
- 如果空投图标在短时间内多次出现（如网络延迟导致图标闪烁），会重复发送通知

**修复建议**：
1. 在NotificationCooldown模块中添加`IsInCooldown`方法
2. 在Timer.lua发送通知前检查冷却期

### 5.2 ⚠️ clear命令清除不完整

**问题描述**：
- clear命令只清除了PROCESSED状态
- 没有清除DETECTING和CONFIRMED状态
- 应该调用`DetectionState:ClearAllStates()`而不是只清除PROCESSED状态

**影响**：
- 如果用户在DETECTING或CONFIRMED状态下执行clear命令，这些状态不会被清除
- 虽然会重新初始化（OnLogin()会清除所有状态），但逻辑上不完整

**修复建议**：
```lua
-- Commands.lua:86-95 应该改为：
if DetectionState and DetectionState.ClearAllStates then
    DetectionState:ClearAllStates();  -- 清除所有状态
else
    -- 回退到逐个清除PROCESSED状态（兼容性）
    for _, mapData in ipairs(maps) do
        if mapData then
            DetectionState:ClearProcessed(mapData.id);
        end
    end
end
```

**优化建议**：
- 由于clear命令最后会调用`Reinitialize()` → `OnLogin()`，而`OnLogin()`已经会清除所有状态
- 可以考虑简化clear命令，只清除SavedVariables数据，状态清除交给OnLogin()处理
- 这样可以避免重复清除，但当前实现也不影响功能

### 5.3 ⚠️ CONFIRMED状态下的图标消失处理

**当前实现**：
```lua
-- DetectionState.lua:110-117
if state.status == CONFIRMED and not iconDetected then
    -- 立即清除状态，判定为误报
    newState.status = IDLE
end
```

**问题**：
- CONFIRMED状态是已确认的状态（持续2秒检测）
- 如果图标在CONFIRMED后立即消失，可能是：
  1. 误报（应该清除）
  2. 空投已结束（应该保持状态，因为已经确认过）

**建议**：
- 可以考虑添加一个短暂的消失确认期（如1-2秒）
- 或者保持CONFIRMED状态，因为已经确认过空投

### 5.3 ✅ 状态清除机制完善

**优点**：
- ✅ 角色切换时清除所有状态
- ✅ 地图切换时清除旧地图状态
- ✅ 离开地图超时清除
- ✅ PROCESSED状态超时清除

**结论**：状态清除机制设计合理，覆盖了各种场景

---

## 六、优化建议

### 6.1 实现通知冷却期检查

```lua
-- NotificationCooldown.lua
function NotificationCooldown:IsInCooldown(mapId, currentTime)
    self:Initialize();
    local lastTime = self.lastNotificationTime[mapId];
    if not lastTime then
        return false; -- 没有记录，不在冷却期
    end
    local cooldownPeriod = 120; -- 120秒冷却期
    return (currentTime - lastTime) < cooldownPeriod;
end

-- Timer.lua:244-257
if state.status == DetectionState.STATES.CONFIRMED then
    -- 检查通知冷却期
    local shouldNotify = true;
    if NotificationCooldown and NotificationCooldown.IsInCooldown then
        shouldNotify = not NotificationCooldown:IsInCooldown(targetMapData.id, currentTime);
    end
    
    if shouldNotify then
        if Notification and Notification.NotifyAirdropDetected then
            Notification:NotifyAirdropDetected(...)
        end
        if NotificationCooldown and NotificationCooldown.RecordNotification then
            NotificationCooldown:RecordNotification(targetMapData.id, currentTime);
        end
    else
        Logger:Debug("Timer", "通知", "通知在冷却期内，跳过通知");
    end
    
    -- 无论是否发送通知，都更新时间
    local success = Data:SetLastRefresh(...)
    ...
end
```

### 6.2 优化CONFIRMED状态处理

考虑添加消失确认期，但需要权衡：
- **优点**：减少误判
- **缺点**：增加复杂度，可能延迟状态清除

**建议**：保持当前实现，因为：
1. CONFIRMED状态已经经过2秒确认
2. 如果图标立即消失，很可能是误报或空投已结束
3. 当前实现简单可靠

---

## 七、总结

### 7.1 当前流程优点

1. ✅ **检测逻辑简单可靠**：仅依赖名称匹配
2. ✅ **防误报机制完善**：2秒确认期 + 5分钟冷却期
3. ✅ **状态清除机制完善**：覆盖各种场景
4. ✅ **状态机设计合理**：IDLE → DETECTING → CONFIRMED → PROCESSED

### 7.2 需要修复的问题

1. ⚠️ **通知冷却期未实现**：需要添加`IsInCooldown`方法并在发送通知前检查
2. ⚠️ **clear命令清除不完整**：应该调用`ClearAllStates()`而不是只清除PROCESSED状态

### 7.3 清除机制说明

1. ✅ **重载、切换角色、重新登入游戏**：三者都会触发`PLAYER_LOGIN`事件，执行相同的`OnLogin()`函数
2. ⚠️ **clear命令与OnLogin()有重复**：但功能不同（clear还清除SavedVariables数据）
3. ⚠️ **离开地图超时与PROCESSED超时部分重复**：但场景不同（一个在地图外，一个在地图内）

### 7.3 流程完整性

- ✅ 检测流程：完整
- ✅ 防误报机制：完善（但通知冷却期缺失）
- ✅ 状态机制：设计合理
- ✅ 状态清除机制：完善

---

**分析日期**：2024-12-19  
**分析者**：AI Assistant (Auto)


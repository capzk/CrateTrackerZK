# Timer.lua 模块化重构方案

## 当前问题分析

### DetectMapIcons() 函数职责过多（320行代码）

当前 `DetectMapIcons()` 函数承担了以下职责：
1. **地图匹配**：匹配当前地图到配置地图
2. **地图变化检测**：检测游戏地图ID和配置ID变化
3. **状态管理**：管理6个独立状态变量
4. **图标检测**：扫描Vignette图标
5. **通知决策**：决定是否发送通知
6. **时间更新决策**：决定是否更新时间
7. **状态清除**：清除超时状态

**问题**：
- 职责不清，难以维护
- 状态管理分散，容易出错
- 决策逻辑和检测逻辑耦合
- 难以测试和调试

## 重构方案

### 模块划分

#### 1. **检测模块** (`IconDetector`)
**职责**：只负责检测图标是否存在（符合设计文档）
```lua
IconDetector:DetectIcon(currentMapID) -> boolean
  -- 获取所有Vignette图标
  -- 遍历查找空投箱子图标（名称匹配）
  -- 仅依赖名称匹配，不依赖位置信息（符合设计文档）
```
- 输入：当前地图ID
- 输出：是否检测到空投图标
- **仅依赖名称匹配**，不依赖位置信息（符合设计文档）
- 不涉及任何状态管理或决策

#### 2. **地图管理模块** (`MapTracker`)
**职责**：管理地图匹配和变化
```lua
MapTracker:GetTargetMapData(currentMapID) -> mapData or nil
  -- 匹配当前地图或父地图
  -- 支持父地图匹配（符合设计文档）

MapTracker:OnMapChanged(currentMapID, targetMapData) -> changeInfo
  -- 检测游戏地图ID和配置ID变化
  -- 返回：{gameMapChanged, configMapChanged, oldMapId, oldGameMapID}
  -- 记录离开时间（符合设计文档）
```
- 地图匹配（支持父地图，符合设计文档）
- 地图变化检测（游戏地图ID和配置ID）
- 离开时间记录（用于300秒自动清除）

#### 3. **状态管理模块** (`DetectionState`)
**职责**：管理检测状态（状态机，符合设计文档）
```lua
DetectionState:GetState(mapId) -> state
  -- 返回当前状态对象

DetectionState:UpdateState(mapId, iconDetected, timestamp) -> newState
  -- 根据图标检测结果和当前状态，更新状态
  -- 实现状态转换规则
  -- 检查手动输入锁定（Data.manualInputLock[mapId]）
  -- 如果被锁定，自动检测不会覆盖手动输入
  -- 返回新状态

DetectionState:ClearState(mapId, reason)
  -- 清除状态（但保留通知冷却期）
  -- reason: "game_map_changed" | "left_map_timeout" | "disappeared_confirmed"

DetectionState:CheckAndClearLeftMaps(currentTime)
  -- 检查并清除离开超过300秒的地图状态（符合设计文档）
  -- 清除检测状态，但保留通知冷却期（防止误报，更符合用户体验）
  -- 注意：设计文档说清除 lastNotificationTime，但建议保留
```
- 状态机：IDLE -> DETECTING -> CONFIRMED -> ACTIVE -> DISAPPEARING
- 状态转换规则（符合设计文档：2秒确认、5秒消失确认）
- 状态持久化
- 离开地图状态自动清除（300秒，符合设计文档）

#### 4. **决策模块** (`DetectionDecision`)
**职责**：根据检测结果和状态做决策（符合设计文档）
```lua
DetectionDecision:ShouldNotify(mapId, state, timestamp) -> boolean
  -- 仅在 CONFIRMED 状态且持续2秒后检查（已更新）
  -- 检查通知冷却期（120秒）
  -- 纯函数，无副作用

DetectionDecision:ShouldUpdateTime(mapId, state, timestamp) -> boolean
  -- 仅在 CONFIRMED 状态且持续2秒后检查
  -- 检查最小更新时间间隔（30秒）
  -- 使用 firstDetectedTime 作为刷新时间
  -- 纯函数，无副作用
```
- 通知决策（检查冷却期120秒，符合设计文档）
- 时间更新决策（检查间隔30秒，使用首次检测时间，符合设计文档）
- 纯函数，无副作用

#### 5. **协调模块** (`TimerManager`)
**职责**：协调各模块，执行决策
```lua
TimerManager:DetectMapIcons()
  -> MapTracker:GetTargetMapData()
  -> MapTracker:OnMapChanged()
  -> IconDetector:DetectIcon()
  -> DetectionState:UpdateState()
  -> DetectionDecision:ShouldNotify()
  -> DetectionDecision:ShouldUpdateTime()
  -> 执行通知/更新
```

## 状态机设计

### 状态定义（符合设计文档）
```lua
states = {
  IDLE = "idle",              -- 未检测到图标
  DETECTING = "detecting",    -- 首次检测到图标，等待2秒确认
  CONFIRMED = "confirmed",    -- 已确认（持续2秒），等待更新时间
  ACTIVE = "active",          -- 持续检测中（已更新时间）
  DISAPPEARING = "disappearing" -- 图标消失，等待5秒确认
}
```

### 状态转换规则（符合设计文档）

```
IDLE (未检测到)
  -> DETECTING (检测到图标)
  
DETECTING (首次检测，等待2秒确认)
  -> CONFIRMED (持续检测2秒)
  -> IDLE (2秒内图标消失，清除首次检测时间)
  
CONFIRMED (已确认，等待通知和更新时间)
  -> ACTIVE (通知和更新时间后)
  
ACTIVE (持续检测中)
  -> DISAPPEARING (图标消失)
  -> ACTIVE (图标持续存在)
  
DISAPPEARING (图标消失，等待5秒确认)
  -> ACTIVE (5秒内图标重新出现)
  -> IDLE (持续消失5秒，清除所有检测状态)
```

### 状态对象结构
```lua
state = {
  status = "idle|detecting|confirmed|active|disappearing",
  firstDetectedTime = timestamp,  -- 首次检测时间（用于2秒确认和更新时间）
  lastUpdateTime = timestamp,     -- 上次更新时间（用于30秒间隔检查）
  disappearedTime = timestamp,    -- 消失时间（仅在状态为disappearing时有效）
}
```

### 状态转换详细规则

**IDLE -> DETECTING**：
- 触发：检测到图标
- 动作：
  - 设置 `firstDetectedTime = currentTime`
  - **不立即发送通知**（等待2秒确认）

**DETECTING -> CONFIRMED**：
- 触发：持续检测2秒
- 条件：`currentTime - firstDetectedTime >= 2`
- 动作：状态变为 CONFIRMED（通知和时间更新在状态转换后执行）

**DETECTING -> IDLE**：
- 触发：2秒内图标消失
- 条件：`currentTime - firstDetectedTime < 2` 且图标消失
- 动作：清除 `firstDetectedTime`

**CONFIRMED -> ACTIVE**（状态转换时执行通知和时间更新）：
- 触发：状态变为 CONFIRMED 后立即执行
- 条件检查：
  - 通知冷却期：距离上次通知 >= 120秒？
  - 更新时间间隔：距离上次更新 >= 30秒？
- 动作：
  - **如果不在通知冷却期**：发送通知并记录时间
  - **如果满足更新时间间隔**：使用 `firstDetectedTime` 更新时间
  - 设置 `lastUpdateTime = firstDetectedTime`
  - 状态变为 ACTIVE

**ACTIVE -> DISAPPEARING**：
- 触发：图标消失
- 动作：设置 `disappearedTime = currentTime`

**DISAPPEARING -> ACTIVE**：
- 触发：5秒内图标重新出现
- 条件：`currentTime - disappearedTime < 5`
- 动作：清除 `disappearedTime`

**DISAPPEARING -> IDLE**：
- 触发：持续消失5秒
- 条件：`currentTime - disappearedTime >= 5`
- 动作：清除所有状态（但保留通知冷却期）

## 通知冷却期独立管理（已更新设计）

**设计需求**（已更新）：
- 通知冷却期：120秒（2分钟）
- **关键**：通知冷却期独立管理，不随检测状态清除
- 地图切换时不清除通知冷却期
- 离开地图300秒后清除（根据设计文档，但需要确认是否应该清除）

```lua
NotificationCooldown = {
  lastNotificationTime = {},  -- 独立管理，不随状态清除
  cooldown = 120,            -- 冷却时间（秒）
  
  CanNotify(mapId, timestamp) -> boolean
    -- 检查距离上次通知是否 >= 120秒
    -- 如果不存在或 >= 120秒，返回 true
  
  RecordNotification(mapId, timestamp)
    -- 记录通知时间
}
```

**通知时机**（已更新设计）：
- **取消首次检测立即通知**
- **2秒确认后同时发送通知和更新时间**（在 CONFIRMED -> ACTIVE 转换时）
- 检查通知冷却期：距离上次通知 >= 120秒？
- 如果不在冷却期：发送通知并记录时间
- 如果不在冷却期：跳过通知
- **通知和时间更新同时进行**（都在2秒确认后）

## 重构步骤

### 阶段1：创建新模块文件
1. `Modules/IconDetector.lua` - 检测模块
2. `Modules/MapTracker.lua` - 地图管理模块
3. `Modules/DetectionState.lua` - 状态管理模块
4. `Modules/DetectionDecision.lua` - 决策模块

### 阶段2：重构 Timer.lua
1. 保留 TimerManager 作为协调器
2. 简化 DetectMapIcons() 函数
3. 调用各模块完成功能

### 阶段3：测试验证
1. 单元测试各模块
2. 集成测试完整流程
3. 回归测试现有功能

## 优势

1. **职责清晰**：每个模块只做一件事
2. **易于测试**：可以单独测试每个模块
3. **易于维护**：修改某个功能只需修改对应模块
4. **易于扩展**：添加新功能只需添加新模块
5. **状态管理集中**：状态机统一管理，不易出错

## 代码示例

### 重构后的 DetectMapIcons()（符合设计文档）

```lua
function TimerManager:DetectMapIcons()
    -- 1. 获取当前地图ID
    local currentMapID = C_Map.GetBestMapForUnit("player")
    if not currentMapID then
        return false
    end
    
    -- 2. 获取目标地图数据（支持父地图匹配）
    local targetMapData = MapTracker:GetTargetMapData(currentMapID)
    if not targetMapData then
        MapTracker:CheckAndClearLeftMaps(getCurrentTimestamp())
        return false
    end
    
    -- 3. 处理地图变化（符合设计文档）
    local currentTime = getCurrentTimestamp()
    local changeInfo = MapTracker:OnMapChanged(currentMapID, targetMapData, currentTime)
    
    -- 4. 如果游戏地图变化但配置ID相同，清除检测状态（保留通知冷却期）
    if changeInfo.gameMapChanged and changeInfo.configIdSame then
        DetectionState:ClearState(targetMapData.id, "game_map_changed")
    end
    
    -- 5. 检查并清除超时的离开地图状态（符合设计文档：300秒）
    MapTracker:CheckAndClearLeftMaps(currentTime)
    
    -- 6. 检测图标（仅依赖名称匹配，符合设计文档）
    local iconDetected = IconDetector:DetectIcon(currentMapID)
    
    -- 7. 更新状态（状态机转换）
    local state = DetectionState:UpdateState(targetMapData.id, iconDetected, currentTime)
    
    -- 8. 通知和时间更新决策（已更新：2秒确认后同时执行）
    if state.status == "confirmed" then
        local shouldNotify = DetectionDecision:ShouldNotify(targetMapData.id, state, currentTime)
        local shouldUpdate = DetectionDecision:ShouldUpdateTime(targetMapData.id, state, currentTime)
        
        -- 通知决策（检查冷却期）
        if shouldNotify then
            Notification:NotifyAirdropDetected(
                Data:GetMapDisplayName(targetMapData), 
                self.detectionSources.MAP_ICON
            )
            NotificationCooldown:RecordNotification(targetMapData.id, currentTime)
        end
        
        -- 时间更新决策（检查间隔和手动锁定）
        if shouldUpdate then
            -- 检查手动输入锁定
            if not Data.manualInputLock or not Data.manualInputLock[targetMapData.id] then
                Data:SetLastRefresh(targetMapData.id, state.firstDetectedTime)
                DetectionState:SetLastUpdateTime(targetMapData.id, state.firstDetectedTime)
                self:UpdateUI()
            else
                SafeDebug("跳过自动更新时间（地图被手动锁定）")
            end
        end
    end
    
    return iconDetected
end
```

**关键点**（已更新设计）：
1. 支持父地图匹配
2. 仅依赖名称匹配检测图标
3. **取消首次检测立即通知**（已更新）
4. **2秒确认后同时发送通知和更新时间**（已更新）
5. 使用首次检测时间作为刷新时间
6. 检查最小更新时间间隔（30秒）
7. 检查通知冷却期（120秒）
8. 地图切换时清除检测状态但保留通知冷却期
9. 离开地图300秒后自动清除状态

## 设计文档符合性检查

### ✅ 符合的设计需求

1. **检测原理**：
   - ✅ 每1秒扫描一次
   - ✅ 仅依赖名称匹配，不依赖位置信息
   - ✅ 支持父地图匹配

2. **持续确认机制**（已更新）：
   - ✅ 2秒确认期
   - ✅ **取消首次检测立即通知**
   - ✅ **2秒确认后同时发送通知和更新时间**（检查冷却期和间隔）

3. **通知冷却期**：
   - ✅ 120秒冷却期
   - ✅ 独立管理，不随状态清除
   - ✅ 地图切换时保留

4. **消失确认期**：
   - ✅ 5秒消失确认期
   - ✅ 已确认的空投需要持续消失5秒才清除

5. **时间更新**：
   - ✅ 使用首次检测时间作为刷新时间
   - ✅ 最小更新时间间隔30秒

6. **地图切换处理**：
   - ✅ 游戏地图ID变化但配置ID相同时，清除检测状态但保留通知冷却期
   - ✅ 离开地图300秒后自动清除状态

### ⚠️ 需要确认的设计点

1. **离开地图状态清除时是否清除通知冷却期**：
   - **设计文档 DATA_FLOW.md 第106行**：说清除 `lastNotificationTime`
   - **优化文档和当前代码**：保留通知冷却期，防止误报
   - **建议**：保留通知冷却期（更符合用户体验，防止误报）
   - **实现**：在 `CheckAndClearLeftMaps()` 中不清除 `lastNotificationTime`

2. **状态清除的时机**：
   - ✅ 游戏地图变化但配置ID相同：清除检测状态，保留通知冷却期
   - ⚠️ 离开地图300秒：清除检测状态，**保留通知冷却期**（建议，防止误报）

3. **手动输入锁定机制**：
   - 设计文档提到 `Data.manualInputLock[mapId]`
   - 需要在状态管理中处理手动锁定
   - 手动输入时锁定，自动检测确认后解除锁定
   - **实现**：在 `DetectionState:UpdateState()` 中检查手动锁定
   - 如果地图被手动锁定，自动检测不会覆盖手动输入的时间

## 迁移计划

### 阶段1：创建新模块文件（保持向后兼容）
1. `Modules/IconDetector.lua` - 检测模块
2. `Modules/MapTracker.lua` - 地图管理模块
3. `Modules/DetectionState.lua` - 状态管理模块
4. `Modules/DetectionDecision.lua` - 决策模块
5. `Modules/NotificationCooldown.lua` - 通知冷却期管理

### 阶段2：重构 Timer.lua（逐步替换）
1. 保留 TimerManager 作为协调器
2. 简化 DetectMapIcons() 函数（调用新模块）
3. 保留旧函数作为备份（注释掉）
4. 逐步迁移其他函数

### 阶段3：测试验证
1. 单元测试各模块
2. 集成测试完整流程
3. 回归测试现有功能
4. 测试地图切换场景
5. 测试通知冷却期

### 阶段4：清理
1. 删除旧代码
2. 更新文档
3. 更新注释


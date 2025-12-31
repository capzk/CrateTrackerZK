---
name: 空投检测系统重构 - 基于objectGUID去重
overview: 重构空投检测系统，使用 objectGUID 的 SpawnUID 字段来识别同一空投事件，解决因传送等原因导致的重复检测问题。删除旧的状态机机制，简化检测逻辑，优化时间存储和显示。
todos:
  - id: data_structure
    content: 扩展数据结构：在 Data.lua 中添加 currentAirdropSpawnUID、currentAirdropTimestamp 字段
    status: completed
  - id: icon_detector
    content: 重构 IconDetector.lua：修改 DetectIcon() 返回 objectGUID 和 SpawnUID，添加 SpawnUID 提取函数
    status: completed
  - id: remove_detection_state
    content: 删除 DetectionState 模块：删除文件、从 Load.xml 移除加载语句、删除所有引用
    status: completed
  - id: timer_refactor
    content: 重构 Timer.lua：删除 DetectionState 引用，实现简化的2秒确认机制和 SpawnUID 比对逻辑，实现30秒通知限制
    status: completed
    dependencies:
      - remove_detection_state
      - icon_detector
  - id: team_message_refactor
    content: 重构 TeamMessageReader.lua：实现重载后比对逻辑、进入地图后的 SpawnUID 比对
    status: completed
    dependencies:
      - data_structure
  - id: time_handling
    content: 优化时间处理：修改时间存储为完整时间戳，UI显示只显示时分秒，用户输入时间作为过去时间处理
    status: completed
    dependencies:
      - data_structure
  - id: ui_updates
    content: 更新 UI：修改时间显示格式，确保清除命令清除所有数据
    status: completed
    dependencies:
      - time_handling
  - id: data_migration
    content: 数据迁移：在 Data:Initialize() 中处理旧数据兼容性
    status: completed
    dependencies:
      - data_structure
  - id: testing
    content: 测试验证：测试所有场景（首次检测、重复检测、传送中断、团队消息、30秒限制、重载、用户输入、清除命令）
    status: pending
    dependencies:
      - timer_refactor
      - team_message_refactor
      - ui_updates
---

# 空投检测系统重构计划

## 重构目标

1. **解决重复检测问题**：使用 objectGUID 的 SpawnUID 字段识别同一空投事件

2. **简化检测逻辑**：删除旧的状态机机制（DetectionState），只保留2秒确认期

3. **优化时间管理**：时间戳存储改为完整时间戳，UI显示只显示时分秒

4. **优化通知机制**：30秒内允许发送通知，超过30秒不允许

## 核心设计

### 1. 数据结构变更

#### 1.1 地图数据结构扩展

**文件**: `Data/Data.lua`在 `mapData` 结构中添加新字段：

```lua
{
  id = 1,
  mapID = 2248,
  interval = 1100,
  instance = "123-456",
  lastInstance = "123-456",
  lastRefreshInstance = "123-456",
  lastRefresh = timestamp,  -- 完整时间戳（年月日时分秒）
  nextRefresh = timestamp,
  createTime = timestamp,
  -- 新增字段
  currentAirdropSpawnUID = "0000534112",  -- 当前空投事件的 SpawnUID
  currentAirdropTimestamp = timestamp,     -- 当前空投事件的时间戳
}
```



#### 1.2 SavedVariables 结构扩展

**文件**: `Data/Data.lua`

在 `CRATETRACKERZK_DB.mapData[mapID]` 中添加：

```lua
{
  instance = ...,
  lastInstance = ...,
  lastRefreshInstance = ...,
  lastRefresh = timestamp,  -- 完整时间戳
  createTime = timestamp,
  -- 新增字段
  currentAirdropSpawnUID = "0000534112",
  currentAirdropTimestamp = timestamp,
}
```



### 2. IconDetector 模块重构

**文件**: `Modules/IconDetector.lua`

#### 2.1 修改检测函数返回 objectGUID

当前 `DetectIcon()` 只返回 `true/false`，需要改为返回检测到的 objectGUID：

```lua
function IconDetector:DetectIcon(currentMapID)
    -- 返回: { detected = true/false, objectGUID = "Creature-0-...", spawnUID = "0000534112" }
    -- 如果检测到多个，返回第一个（飞机）
end
```



#### 2.2 提取 SpawnUID 逻辑

从 objectGUID 中提取 SpawnUID（第7部分）：

```lua
local function ExtractSpawnUID(objectGUID)
    if not objectGUID then return nil end
    local parts = {strsplit("-", objectGUID)}
    if #parts >= 7 then
        return parts[7]  -- SpawnUID 是第7部分
    end
    return nil
end
```



### 3. 删除 DetectionState 模块

**文件**: `Modules/DetectionState.lua`

- 完全删除此模块

- 删除 `Load.xml` 中的加载语句

- 删除所有对 `DetectionState` 的引用

**替代方案**：使用简单的2秒确认机制，直接在 `Timer.lua` 中实现

### 4. Timer 模块重构

**文件**: `Modules/Timer.lua`

#### 4.1 简化检测逻辑

删除所有 `DetectionState` 相关代码，实现新的检测流程：

```lua
-- 新的检测状态（简化版，不持久化）
TimerManager.detectionState = {
    [mapId] = {
        firstDetectedTime = timestamp,  -- 首次检测时间
        detectedSpawnUID = "0000534112",  -- 检测到的 SpawnUID
    }
}
```



#### 4.2 新的检测流程

```javascript
1. 检测图标（IconDetector:DetectIcon）
   ├─ 返回: { detected, objectGUID, spawnUID }
   │
2. 检查是否是已知事件
   ├─ 如果 mapData.currentAirdropSpawnUID == spawnUID
   │   └─ 跳过（同一事件）
   │
3. 首次检测
   ├─ 记录 firstDetectedTime 和 spawnUID
   │
4. 2秒确认
   ├─ 如果 (currentTime - firstDetectedTime) >= 2
   │   ├─ 再次检测确认 spawnUID 相同
   │   ├─ 检查是否在30秒内（currentAirdropTimestamp）
   │   ├─ 发送通知（如果在30秒内）
   │   ├─ 更新时间
   │   ├─ 更新 currentAirdropSpawnUID 和 currentAirdropTimestamp
   │   └─ 清除检测状态
```



#### 4.3 30秒通知限制

```lua
local function ShouldSendNotification(mapData, currentTime)
    if not mapData.currentAirdropTimestamp then
        return true  -- 首次检测，允许发送
    end
    
    local timeSinceAirdrop = currentTime - mapData.currentAirdropTimestamp
    return timeSinceAirdrop <= 30  -- 30秒内允许发送
end
```



### 5. TeamMessageReader 模块重构

**文件**: `Modules/TeamMessageReader.lua`

#### 5.1 团队消息处理逻辑

```javascript
1. 收到团队消息
   ├─ 解析地图名称
   │
2. 检查是否在空投地图
   ├─ 如果不在空投地图
   │   ├─ 更新时间（以第一个消息为准）
   │   └─ 不设置 currentAirdropSpawnUID（因为不在地图上）
   │
3. 如果进入空投地图
   ├─ 检测到空投
   │   ├─ 如果检测到相同 SpawnUID
   │   │   └─ 跳过（同一事件）
   │   └─ 由检测系统处理（SpawnUID比对和30秒通知限制）
```



#### 5.2 重载后比对逻辑

```lua
function TeamMessageReader:CheckHistoricalSpawnUID(mapId, spawnUID)
    local mapData = Data:GetMap(mapId)
    if mapData and mapData.currentAirdropSpawnUID == spawnUID then
        -- 是同一个事件，忽略
        return true
    end
    return false
end
```



### 6. Data 模块重构

**文件**: `Data/Data.lua`

#### 6.1 时间戳处理

- **存储**：使用完整时间戳（`time()` 返回的 Unix 时间戳）

- **显示**：UI 显示时只显示时分秒（`HH:MM:SS`）

#### 6.2 用户输入时间处理

修改 `Utils.GetTimestampFromTime()` 或创建新函数：

```lua
function Data:ParseUserInputTime(hh, mm, ss)
    -- 用户输入的时间永远作为过去时间（前一天）处理
    local currentDate = date('*t', time())
    local inputDate = {
        year = currentDate.year,
        month = currentDate.month,
        day = currentDate.day - 1,  -- 前一天
        hour = hh,
        min = mm,
        sec = ss
    }
    return time(inputDate)
end
```



#### 6.3 时间优先级

- **手动时间**：优先级最低，可以被自动时间覆盖

- **自动时间**：优先级最高，可以覆盖手动时间

- **刷新按钮**：使用当前时间，优先级同自动时间

### 7. UI 模块调整

**文件**: `UI/MainPanel.lua`

#### 7.1 时间显示格式

修改时间格式化函数，只显示时分秒：

```lua
function Data:FormatTimeForDisplay(timestamp)
    if not timestamp then return "--:--" end
    local t = date('*t', timestamp)
    return string.format("%02d:%02d:%02d", t.hour, t.min, t.sec)
end
```



#### 7.2 清除命令

确保 `/ctk clear` 清除所有数据，包括新增字段：

```lua
function Commands:HandleClearCommand()
    -- 清除所有数据
    CRATETRACKERZK_DB.mapData = {}
    -- 清除内存状态
    TimerManager.detectionState = {}
    -- 重新初始化
end
```



### 8. 文件修改清单

#### 8.1 核心文件修改

1. **Data/Data.lua**

- 扩展数据结构，添加 `currentAirdropSpawnUID`、`currentAirdropTimestamp`
- 修改时间处理逻辑

- 修改用户输入时间处理（作为过去时间）

2. **Modules/IconDetector.lua**

- 修改 `DetectIcon()` 返回 objectGUID 和 SpawnUID

- 添加 SpawnUID 提取函数

3. **Modules/Timer.lua**

- 删除所有 `DetectionState` 相关代码
- 实现简化的2秒确认机制

- 实现 SpawnUID 比对逻辑

- 实现30秒通知限制（基于 currentAirdropTimestamp）

4. **Modules/TeamMessageReader.lua**

- 修改团队消息处理逻辑

- 实现重载后比对逻辑

5. **UI/MainPanel.lua**

- 修改时间显示格式（只显示时分秒）

- 确保清除命令清除所有数据

#### 8.2 删除文件

- **Modules/DetectionState.lua** - 完全删除

#### 8.3 配置文件修改

- **Load.xml** - 删除 `DetectionState.lua` 的加载语句

### 9. 数据迁移

#### 9.1 旧数据兼容

在 `Data:Initialize()` 中处理旧数据：

```lua
-- 如果旧数据没有 currentAirdropSpawnUID，初始化为 nil
-- 如果旧数据的时间戳格式不对，进行转换
```



### 10. 测试场景

1. **首次检测**：检测到空投，2秒确认后发送通知并更新时间

2. **重复检测**：检测到相同 SpawnUID，跳过处理

3. **传送中断**：传送后恢复检测，识别为同一事件

4. **团队消息**：不在空投地图收到消息，更新时间

5. **进入地图**：进入空投地图后检测到空投，比对 SpawnUID

6. **30秒限制**：基于 currentAirdropTimestamp，超过30秒不发送通知

7. **重载插件**：重载后比对历史 SpawnUID

8. **用户输入**：用户输入时间作为过去时间处理

9. **清除命令**：清除所有数据包括新字段

## 实施步骤

1. **阶段1：数据结构扩展**

- 修改 `Data.lua` 数据结构

- 修改 `IconDetector.lua` 返回 objectGUID

- 添加 SpawnUID 提取函数

2. **阶段2：删除旧机制**

- 删除 `DetectionState.lua`

- 从 `Load.xml` 移除加载语句

- 从 `Timer.lua` 删除所有引用

3. **阶段3：实现新检测逻辑**

- 在 `Timer.lua` 实现简化检测流程
- 实现 SpawnUID 比对逻辑

- 实现30秒通知限制

4. **阶段4：团队消息重构**

- 修改 `TeamMessageReader.lua`

- 实现重载后比对逻辑

- 移除冷却时间机制（所有限制基于空投刷新时间戳）

5. **阶段5：时间处理优化**

- 修改时间存储为完整时间戳

- 修改UI显示只显示时分秒

- 修改用户输入时间处理

6. **阶段6：测试和验证**

- 测试所有场景
- 验证数据迁移

- 验证清除命令

## 注意事项

1. **objectGUID 获取**：需要确认 `C_VignetteInfo.GetVignetteInfo()` 是否返回 `objectGUID` 字段

2. **SpawnUID 格式**：确认 SpawnUID 的格式和长度

3. **数据兼容性**：确保旧数据能正常迁移
4. **性能影响**：SpawnUID 比对逻辑的性能影响

## 实施状态

✅ **已完成**：所有主要重构任务已完成实施

- ✅ 数据结构扩展
- ✅ IconDetector 重构
- ✅ DetectionState 模块删除
- ✅ Timer 模块重构
- ✅ TeamMessageReader 重构
- ✅ 时间处理优化
- ✅ UI 更新
- ✅ 数据迁移
- ✅ 移除冷却时间机制（所有限制基于空投刷新时间戳）

⏳ **待测试**：需要在游戏环境中进行实际测试验证

## 优化说明

**移除冷却时间机制**：
- 所有限制现在都依靠空投刷新时间戳（`currentAirdropTimestamp`）
- 同一个空投事件通过 SpawnUID 比对机制确认，重复检测不再更新时间
- 空投通知已有30秒限制（基于 `currentAirdropTimestamp`），不再需要单独的冷却时间
- 空投检测不需要暂停和冷却机制


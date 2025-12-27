# 重构对数据存储的影响分析

## 结论

✅ **已保存的数据完全不受影响，可以正常读取和使用**

## 详细分析

### 1. 数据存储结构（完全不变）

#### 持久化数据（SavedVariables）

重构**不会改变**以下数据存储结构：

```lua
-- SavedVariables: CRATETRACKERZK_DB
CRATETRACKERZK_DB = {
  mapData = {
    [mapID] = {
      instance = "123-456",              -- 当前位面ID
      lastInstance = "123-456",          -- 上次位面ID
      lastRefreshInstance = "123-456",  -- 上次刷新时的位面ID
      lastRefresh = timestamp,          -- 上次刷新时间戳 ⭐ 重要数据
      createTime = timestamp            -- 创建时间
    }
  }
}

-- SavedVariables: CRATETRACKERZK_UI_DB
CRATETRACKERZK_UI_DB = {
  position = {...},                     -- UI位置
  minimapButton = {...},                -- 小地图按钮位置
  debugEnabled = false,                 -- 调试模式
  teamNotificationEnabled = true        -- 团队通知开关
}
```

**关键点**：
- ✅ 这些数据由 `Data.lua` 模块管理
- ✅ 重构**不会修改** `Data.lua` 模块
- ✅ 数据读取和保存逻辑完全不变
- ✅ 已保存的 `lastRefresh`、`instance` 等数据**完全保留**

#### 数据加载流程（完全不变）

```lua
-- Data:Initialize() 函数（不受重构影响）
1. 从 SavedVariables 读取数据
   CRATETRACKERZK_DB.mapData[mapID]
   
2. 验证时间戳
   sanitizeTimestamp(savedData.lastRefresh)
   
3. 恢复地图数据
   Data.maps[id] = {
     lastRefresh = savedData.lastRefresh,  -- ⭐ 从保存数据恢复
     instance = savedData.instance,
     ...
   }
   
4. 计算下次刷新时间
   Data:UpdateNextRefresh(mapId)
```

### 2. 运行时状态（会重新初始化，这是正常的）

以下状态是**运行时临时状态**，不保存到 SavedVariables，每次重载游戏都会重新初始化：

```lua
-- TimerManager 的运行时状态（不持久化）
TimerManager.mapIconDetected = {}              -- 检测状态
TimerManager.mapIconFirstDetectedTime = {}     -- 首次检测时间
TimerManager.lastUpdateTime = {}               -- 上次更新时间
TimerManager.mapIconDisappearedTime = {}       -- 消失时间
TimerManager.lastNotificationTime = {}        -- 通知冷却期
TimerManager.mapLeftTime = {}                  -- 离开地图时间
```

**重构后的变化**：
- 这些状态会迁移到新模块（`DetectionState.lua`, `NotificationCooldown.lua`）
- 但**仍然是运行时状态**，不持久化
- 重载游戏后会重新初始化（这是**正常行为**）

### 3. 重构的具体影响

#### ✅ 不受影响的部分

1. **Data.lua 模块**：
   - 完全不受重构影响
   - 数据读取、保存逻辑不变
   - SavedVariables 结构不变

2. **已保存的数据**：
   - `lastRefresh`（上次刷新时间）✅ 保留
   - `instance`（位面信息）✅ 保留
   - `createTime`（创建时间）✅ 保留
   - UI 设置 ✅ 保留

3. **数据兼容性**：
   - 重构后的代码可以**完全兼容**旧数据格式
   - 不需要数据迁移
   - 不需要清理旧数据

#### ⚠️ 会重新初始化的部分（正常行为）

1. **运行时检测状态**：
   - `mapIconDetected` - 重载后重新检测
   - `mapIconFirstDetectedTime` - 重载后重新记录
   - `lastNotificationTime` - 重载后重新计算冷却期

2. **这些状态本来就是临时的**：
   - 设计上就是运行时状态
   - 重载游戏后重新初始化是**预期行为**
   - 不影响已保存的刷新时间数据

### 4. 重构后的数据流（保持不变）

```
插件启动
  │
  ▼
Data:Initialize()
  │
  ├─▶ 从 SavedVariables 读取 ⭐
  │   CRATETRACKERZK_DB.mapData[mapID]
  │
  ├─▶ 恢复地图数据 ⭐
  │   Data.maps[id].lastRefresh = savedData.lastRefresh
  │
  └─▶ 计算下次刷新时间 ⭐
      Data:UpdateNextRefresh(mapId)

检测到空投（重构后）
  │
  ▼
DetectionState:UpdateState()  -- 新模块
  │
  ▼
Data:SetLastRefresh()  -- 不变 ⭐
  │
  ▼
Data:SaveMapData()  -- 不变 ⭐
  │
  ▼
保存到 SavedVariables ⭐
  CRATETRACKERZK_DB.mapData[mapID].lastRefresh = timestamp
```

**关键点**：数据保存流程完全不变，只是检测逻辑被拆分到新模块。

## 总结

### ✅ 数据安全性

1. **已保存的数据**：
   - ✅ 完全保留，不受影响
   - ✅ 可以正常读取
   - ✅ 可以正常使用

2. **数据格式**：
   - ✅ 完全兼容，不需要迁移
   - ✅ SavedVariables 结构不变

3. **数据持久化**：
   - ✅ 保存和加载逻辑不变
   - ✅ `Data.lua` 模块不受影响

### ⚠️ 正常行为

1. **运行时状态**：
   - ⚠️ 重载游戏后会重新初始化（这是**正常行为**）
   - ⚠️ 这些状态本来就是临时的，不持久化
   - ⚠️ 不影响已保存的刷新时间数据

### 建议

重构后：
1. ✅ 可以正常使用，数据完全兼容
2. ✅ 不需要任何数据迁移操作
3. ✅ 不需要清理旧数据
4. ⚠️ 重载游戏后，检测状态会重新初始化（这是正常的）

## 验证方法

重构后可以通过以下方式验证数据是否正常：

1. **检查已保存的刷新时间**：
   ```lua
   /script print(CRATETRACKERZK_DB.mapData[2248].lastRefresh)
   ```

2. **检查数据加载**：
   - 打开主面板，查看"上次刷新"列
   - 应该显示之前保存的时间

3. **检查数据保存**：
   - 手动更新刷新时间
   - 重载游戏（/reload）
   - 检查时间是否保留


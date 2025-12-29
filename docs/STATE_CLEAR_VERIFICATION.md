# 状态清除机制验证文档

## 一、重载/重新进入游戏时的状态清除

### 1.1 触发机制

**事件注册**（Core.lua:158-160）：
```lua
CrateTrackerZK.eventFrame:RegisterEvent("PLAYER_LOGIN");
```

**触发场景**：
- `/reload` 重载游戏 → 触发 `PLAYER_LOGIN`
- 切换角色 → 触发 `PLAYER_LOGIN`
- 重新登入游戏 → 触发 `PLAYER_LOGIN`

### 1.2 清除流程（Core.lua:12-81）

```lua
local function OnLogin()
    -- 1. 初始化SavedVariables（UI设置）
    if not CRATETRACKERZK_UI_DB then
        CRATETRACKERZK_UI_DB = {};
    end
    
    -- 2. 初始化数据模块（从SavedVariables加载数据）
    if Data then Data:Initialize() end  -- ✅ 先加载数据
    
    -- 3. 清除所有内存检测状态（防止跨角色污染）
    if DetectionState and DetectionState.ClearAllStates then
        DetectionState:ClearAllStates();  -- ✅ 清除所有状态
    end
    
    -- 4. 重置其他模块状态
    MapTracker:Initialize();      -- ✅ 重置地图追踪状态
    Phase:Reset();                 -- ✅ 重置位面状态
    Area状态重置                   -- ✅ 重置区域状态
    
    -- 5. 重新初始化所有模块
    TimerManager:Initialize();
    TimerManager:StartMapIconDetection(1);
    ...
end
```

### 1.3 DetectionState:ClearAllStates() 实现

**代码位置**（DetectionState.lua:178-188）：
```lua
function DetectionState:ClearAllStates()
    self:Initialize();
    
    -- 清除所有地图的检测状态
    self.mapIconFirstDetectedTime = {};  -- ✅ 清除DETECTING状态
    self.mapIconDetected = {};           -- ✅ 清除CONFIRMED状态
    self.lastUpdateTime = {};            -- ✅ 清除更新时间
    self.processedTime = {};            -- ✅ 清除PROCESSED状态（包括3分钟冷却）
    
    Logger:Debug("DetectionState", "重置", "已清除所有地图的检测状态");
end
```

**验证结果**：
- ✅ **所有状态都会被清除**：包括IDLE、DETECTING、CONFIRMED、PROCESSED
- ✅ **PROCESSED状态会被清除**：即使3分钟冷却未结束，重载后也会清除
- ✅ **执行顺序正确**：先加载数据（Data:Initialize），再清除状态

---

## 二、3分钟冷却未结束时退出重新进入

### 2.1 场景分析

**场景**：
1. 角色A检测到空投，进入PROCESSED状态（3分钟冷却期）
2. 冷却期进行到1分钟时，玩家退出游戏
3. 玩家重新进入游戏（或切换角色）

**预期行为**：
- ✅ PROCESSED状态应该被清除（因为存储在内存中）
- ✅ 可以立即重新检测空投
- ✅ SavedVariables数据（刷新时间）应该保留

### 2.2 实际执行流程

```
玩家重新进入游戏
  ↓
触发 PLAYER_LOGIN 事件
  ↓
OnLogin() 执行
  ↓
Data:Initialize()
  ├─ 从 CRATETRACKERZK_DB.mapData 加载刷新时间 ✅ 保留
  └─ 从 CRATETRACKERZK_DB.mapData 加载位面信息 ✅ 保留
  ↓
DetectionState:ClearAllStates()
  ├─ processedTime = {} ✅ 清除PROCESSED状态
  ├─ mapIconFirstDetectedTime = {} ✅ 清除DETECTING状态
  ├─ mapIconDetected = {} ✅ 清除CONFIRMED状态
  └─ lastUpdateTime = {} ✅ 清除更新时间
  ↓
TimerManager:StartMapIconDetection(1)
  └─ 立即开始检测 ✅ 可以重新检测
```

**验证结果**：
- ✅ **PROCESSED状态会被清除**：即使3分钟冷却未结束
- ✅ **可以立即重新检测**：状态清除后立即启动检测循环
- ✅ **刷新时间数据保留**：SavedVariables数据不受影响

---

## 三、其他清除机制验证

### 3.1 PROCESSED状态超时清除（Timer.lua:208-220）

**触发时机**：每次检测循环时检查

**清除条件**：
```lua
if DetectionState:IsProcessed(targetMapData.id) then
    if DetectionState:IsProcessedTimeout(targetMapData.id, currentTime) then
        DetectionState:ClearProcessed(targetMapData.id);  -- ✅ 清除PROCESSED状态
    else
        return false;  -- 跳过检测
    end
end
```

**验证结果**：
- ✅ **超时后自动清除**：PROCESSED状态 >= 180秒后自动清除
- ✅ **清除后恢复检测**：清除后立即可以重新检测

### 3.2 clear命令清除（Commands.lua:46-117）

**触发时机**：用户执行 `/ctk clear` 或 `/ctk reset`

**清除内容**：
```lua
-- 1. 停止所有定时器
TimerManager:StopMapIconDetection()
CrateTrackerZK.phaseTimerTicker:Cancel()

-- 2. 清除SavedVariables数据
CRATETRACKERZK_DB.mapData = {}  -- ✅ 清除所有地图数据
CRATETRACKERZK_UI_DB = {}        -- ✅ 清除UI设置

-- 3. 清除内存数据
Data.maps = {}
TimerManager.isInitialized = false

-- 4. 清除所有检测状态
DetectionState:ClearAllStates()  -- ✅ 清除所有状态

-- 5. 清除其他模块状态
MapTracker.lastDetectedMapId = nil
Phase.Reset()
Area状态重置

-- 6. 重新初始化
CrateTrackerZK:Reinitialize()  -- 调用OnLogin()
```

**验证结果**：
- ✅ **清除所有SavedVariables数据**：包括刷新时间和位面信息
- ✅ **清除所有内存状态**：包括所有检测状态
- ✅ **完全重置插件**：重新初始化所有模块

---

## 四、数据共享机制验证

### 4.1 SavedVariables定义（CrateTrackerZK.toc:13）

```toc
## SavedVariables: CRATETRACKERZK_UI_DB, CRATETRACKERZK_DB
```

**关键点**：
- ✅ **没有指定 "PerCharacter"**：所以是全局共享的
- ✅ **所有角色共享数据**：刷新时间、位面信息在所有角色间共享

### 4.2 数据加载流程（Data.lua:28-93）

```lua
function Data:Initialize()
    ensureDB();  -- 确保 CRATETRACKERZK_DB 存在
    
    for _, cfg in ipairs(mapConfig) do
        local mapID = cfg.mapID;
        local savedData = CRATETRACKERZK_DB.mapData[mapID];  -- ✅ 从SavedVariables加载
        
        local mapData = {
            id = nextId,
            mapID = mapID,
            interval = interval,
            instance = savedData.instance,                    -- ✅ 共享位面信息
            lastInstance = savedData.lastInstance,           -- ✅ 共享上次位面
            lastRefreshInstance = savedData.lastRefreshInstance, -- ✅ 共享刷新时位面
            lastRefresh = sanitizeTimestamp(savedData.lastRefresh), -- ✅ 共享刷新时间
            ...
        };
        
        if mapData.lastRefresh then
            self:UpdateNextRefresh(nextId, mapData);  -- ✅ 计算下次刷新时间
        end
    end
end
```

**验证结果**：
- ✅ **数据从SavedVariables加载**：所有角色共享相同的数据
- ✅ **刷新时间共享**：角色A检测到的刷新时间，角色B可以看到
- ✅ **位面信息共享**：位面信息在所有角色间共享

### 4.3 数据保存流程（Data.lua:95-120）

```lua
function Data:SaveMapData(mapId)
    local mapData = self.maps[mapId];
    
    CRATETRACKERZK_DB.mapData[mapData.mapID] = {
        instance = mapData.instance,                    -- ✅ 保存位面信息
        lastInstance = mapData.lastInstance,            -- ✅ 保存上次位面
        lastRefreshInstance = mapData.lastRefreshInstance, -- ✅ 保存刷新时位面
        lastRefresh = mapData.lastRefresh,              -- ✅ 保存刷新时间
        createTime = mapData.createTime                 -- ✅ 保存创建时间
    };
end
```

**验证结果**：
- ✅ **数据保存到SavedVariables**：所有角色共享
- ✅ **保存时机正确**：检测到空投后立即保存

### 4.4 多角色数据共享测试场景

**场景1：角色A检测到空投**
```
角色A登录
  ↓
检测到空投 → 更新刷新时间
  ↓
Data:SaveMapData() → 保存到 CRATETRACKERZK_DB.mapData
  ↓
角色A退出
```

**场景2：角色B查看数据**
```
角色B登录
  ↓
Data:Initialize() → 从 CRATETRACKERZK_DB.mapData 加载数据
  ↓
角色B可以看到角色A检测到的刷新时间 ✅
```

**验证结果**：
- ✅ **数据共享正常**：所有角色可以共享刷新时间和位面信息
- ✅ **状态隔离正常**：每个角色的检测状态独立（内存状态）

---

## 五、完整验证总结

### 5.1 状态清除机制

| 清除场景 | 触发时机 | 清除内容 | 验证结果 |
|---------|---------|---------|---------|
| 重载/重新进入 | PLAYER_LOGIN | 所有内存状态 | ✅ 有效 |
| 3分钟冷却未结束 | PLAYER_LOGIN | PROCESSED状态 | ✅ 有效 |
| PROCESSED超时 | 检测循环 | PROCESSED状态 | ✅ 有效 |
| clear命令 | 用户命令 | 所有数据+状态 | ✅ 有效 |

### 5.2 数据共享机制

| 数据类型 | 存储位置 | 共享方式 | 验证结果 |
|---------|---------|---------|---------|
| 刷新时间 | SavedVariables | 全局共享 | ✅ 正常 |
| 位面信息 | SavedVariables | 全局共享 | ✅ 正常 |
| UI设置 | SavedVariables | 全局共享 | ✅ 正常 |
| 检测状态 | 内存 | 角色独立 | ✅ 正常 |

### 5.3 关键验证点

1. ✅ **重载时状态清除有效**：OnLogin()会清除所有内存状态
2. ✅ **3分钟冷却未结束时重载**：PROCESSED状态会被清除，可以立即重新检测
3. ✅ **数据共享正常**：所有角色可以共享刷新时间和位面信息
4. ✅ **状态隔离正常**：每个角色的检测状态独立，不会互相影响

---

## 六、潜在问题和建议

### 6.1 已验证无问题

- ✅ 重载时状态清除机制完整
- ✅ 3分钟冷却未结束时重载也能正常清除
- ✅ 数据共享机制正常
- ✅ 状态隔离机制正常

### 6.2 建议

1. **保持当前设计**：状态清除机制设计合理，覆盖了所有场景
2. **数据共享设计合理**：刷新时间应该共享，检测状态应该独立
3. **无需修改**：当前实现已经满足所有需求

---

**验证日期**：2024-12-19  
**验证者**：AI Assistant (Auto)


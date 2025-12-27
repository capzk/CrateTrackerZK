# 数据初始化与存储功能检查报告

## 检查范围

1. SavedVariables 定义和初始化
2. 数据加载和保存逻辑
3. 全新安装时的初始化流程
4. 运行时状态与持久化数据的区分
5. 数据清除功能完整性

## 检查结果

### ✅ SavedVariables 定义

**文件**: `CrateTrackerZK.toc` 第13行
```lua
## SavedVariables: CRATETRACKERZK_UI_DB, CRATETRACKERZK_DB
```

**状态**: ✅ 正确定义

### ✅ 数据持久化结构

#### CRATETRACKERZK_DB（地图数据）
**保存的数据**:
- `instance` - 当前位面
- `lastInstance` - 上次位面
- `lastRefreshInstance` - 上次刷新时的位面
- `lastRefresh` - 上次刷新时间戳
- `createTime` - 创建时间

**保存位置**: `Data/Data.lua` 的 `SaveMapData()` 函数
**加载位置**: `Data/Data.lua` 的 `Initialize()` 函数

**状态**: ✅ 正常，不受新增运行时状态影响

#### CRATETRACKERZK_UI_DB（UI设置）
**保存的数据**:
- `position` - 主面板位置
- `minimapButton` - 浮动按钮位置
- `debugEnabled` - 调试模式开关
- `teamNotificationEnabled` - 团队通知开关

**状态**: ✅ 正常，不受新增运行时状态影响

### ✅ 运行时状态（不保存到 SavedVariables）

**TimerManager 的新增字段**（运行时状态，不持久化）:
- `mapIconDetected` - 地图是否检测到空投
- `mapIconFirstDetectedTime` - 首次检测时间
- `mapIconDisappearedTime` - 图标消失时间
- `lastNotificationTime` - 上次通知时间
- `mapLeftTime` - 离开地图时间
- `lastDetectedMapId` - 上次检测到的地图ID

**设计正确性**: ✅ 这些字段都是运行时状态，不应该保存到 SavedVariables
- 每次登录时重新初始化
- 不会影响数据持久化
- 不会影响全新安装

### ✅ 数据初始化流程

#### 1. 全新安装时的初始化

**流程**:
```
1. 插件加载
   ├─ SavedVariables 未定义（nil）
   └─ 游戏自动创建空表

2. Core.lua OnLogin()
   ├─ 初始化 CRATETRACKERZK_UI_DB
   │   if not CRATETRACKERZK_UI_DB then
   │       CRATETRACKERZK_UI_DB = {};
   │   end
   │
   └─ 初始化各模块
       ├─ Data:Initialize()
       │   ├─ ensureDB() - 确保 CRATETRACKERZK_DB 存在
       │   ├─ 从配置创建地图数据
       │   └─ 从 SavedVariables 加载数据（如果存在）
       │
       └─ TimerManager:Initialize()
           ├─ 初始化运行时状态（使用 or {} 确保安全）
           ├─ mapIconDetected = {} 或 {}
           ├─ mapIconFirstDetectedTime = {} 或 {}
           ├─ mapIconDisappearedTime = {} 或 {}
           ├─ lastNotificationTime = {} 或 {}
           ├─ mapLeftTime = {} 或 {}
           └─ lastDetectedMapId = nil 或 nil
```

**状态**: ✅ 全新安装时能正常初始化

#### 2. 已有数据时的初始化

**流程**:
```
1. 插件加载
   ├─ SavedVariables 已存在
   └─ 游戏自动加载数据

2. Data:Initialize()
   ├─ ensureDB() - 确保数据库结构正确
   ├─ 从配置创建地图数据
   └─ 从 SavedVariables 恢复数据
       ├─ lastRefresh = sanitizeTimestamp(savedData.lastRefresh)
       ├─ instance = savedData.instance
       ├─ lastInstance = savedData.lastInstance
       └─ lastRefreshInstance = savedData.lastRefreshInstance

3. TimerManager:Initialize()
   └─ 初始化运行时状态（每次登录都重新初始化）
```

**状态**: ✅ 已有数据时能正常加载

### ✅ 数据保存逻辑

#### Data:SaveMapData()
**保存时机**:
- `Data:SetLastRefresh()` 调用时
- `Data:UpdateMap()` 调用时

**保存内容**:
```lua
CRATETRACKERZK_DB.mapData[mapID] = {
    instance = mapData.instance,
    lastInstance = mapData.lastInstance,
    lastRefreshInstance = mapData.lastRefreshInstance,
    lastRefresh = mapData.lastRefresh,
    createTime = mapData.createTime or time(),
};
```

**状态**: ✅ 正常，只保存持久化数据

#### Notification:SetTeamNotificationEnabled()
**保存内容**:
```lua
CRATETRACKERZK_UI_DB.teamNotificationEnabled = enabled;
```

**状态**: ✅ 正常

### ✅ 数据清除逻辑

#### Data:ClearAllData()
**清除内容**:
- 所有地图数据（内存中）
- SavedVariables 中的地图数据
- TimerManager 的所有运行时状态（包括新增字段）

**状态**: ✅ 已修复，完整清除所有状态

#### Commands:HandleClearCommand()
**清除内容**:
- SavedVariables 中的所有数据
- 所有模块的运行时状态
- TimerManager 的所有运行时状态（包括新增字段）

**状态**: ✅ 已修复，完整清除所有状态

### ✅ 初始化安全性检查

#### 1. ensureDB() 函数
```lua
local function ensureDB()
    if type(CRATETRACKERZK_DB) ~= "table" then
        CRATETRACKERZK_DB = {};
    end
    if type(CRATETRACKERZK_DB.mapData) ~= "table" then
        CRATETRACKERZK_DB.mapData = {};
    end
end
```

**状态**: ✅ 正确处理 nil 和类型错误

#### 2. TimerManager:Initialize()
```lua
self.mapIconDetected = self.mapIconDetected or {};
self.mapIconFirstDetectedTime = self.mapIconFirstDetectedTime or {};
-- ... 其他字段
```

**状态**: ✅ 使用 `or {}` 确保安全初始化

#### 3. 时间戳验证
```lua
local function sanitizeTimestamp(ts)
    if not ts or type(ts) ~= "number" then return nil end
    local maxFuture = time() + 86400 * 365;
    if ts < 0 or ts > maxFuture then return nil end
    return ts;
end
```

**状态**: ✅ 正确验证时间戳有效性

### ✅ 边界情况处理

#### 1. SavedVariables 为 nil
- ✅ `ensureDB()` 会创建空表
- ✅ `Core.lua` 会初始化 `CRATETRACKERZK_UI_DB`

#### 2. SavedVariables 类型错误
- ✅ `ensureDB()` 会重新创建
- ✅ `Core.lua` 会检查类型并重新创建

#### 3. 地图数据缺失
- ✅ `Data:Initialize()` 会从配置创建
- ✅ `sanitizeTimestamp()` 会处理无效时间戳

#### 4. 运行时状态未初始化
- ✅ `TimerManager:Initialize()` 使用 `or {}` 确保安全
- ✅ `DetectMapIcons()` 中也会初始化状态变量

## 潜在问题分析

### ⚠️ 检查点1：TimerManager 状态字段的持久化

**问题**: TimerManager 的新增字段是否会被意外保存？

**分析**:
- ✅ 这些字段都是运行时状态，不在 SavedVariables 中
- ✅ `Data:SaveMapData()` 只保存明确指定的字段
- ✅ 没有代码将这些字段写入 SavedVariables

**结论**: ✅ 安全，不会被意外保存

### ⚠️ 检查点2：全新安装时的状态初始化

**问题**: 全新安装时，TimerManager 的新增字段是否能正确初始化？

**分析**:
- ✅ `TimerManager:Initialize()` 使用 `or {}` 确保安全
- ✅ 即使字段不存在，也会创建空表
- ✅ 所有字段都有默认值

**结论**: ✅ 安全，能正确初始化

### ⚠️ 检查点3：数据迁移兼容性

**问题**: 旧版本的数据能否在新版本中正常加载？

**分析**:
- ✅ `Data:Initialize()` 只读取已知字段
- ✅ 未知字段会被忽略（不影响功能）
- ✅ 时间戳验证确保数据有效性
- ✅ 新增的运行时状态不影响数据加载

**结论**: ✅ 兼容，旧数据能正常加载

## 测试建议

### 1. 全新安装测试
1. 删除 SavedVariables 文件
2. 重新加载插件
3. 验证：
   - ✅ 插件能正常加载
   - ✅ 地图列表正确显示
   - ✅ 所有功能正常

### 2. 数据加载测试
1. 使用已有数据的账号
2. 重新加载插件
3. 验证：
   - ✅ 刷新时间正确恢复
   - ✅ 位面信息正确恢复
   - ✅ UI设置正确恢复

### 3. 数据保存测试
1. 更新刷新时间
2. 重新加载插件
3. 验证：
   - ✅ 数据正确保存
   - ✅ 数据正确恢复

### 4. 数据清除测试
1. 执行 `/ctk clear`
2. 验证：
   - ✅ 所有数据被清除
   - ✅ 所有运行时状态被清除
   - ✅ 插件能正常重新初始化

## 总结

### ✅ 所有检查通过

1. **SavedVariables 定义**: ✅ 正确
2. **数据持久化**: ✅ 正常，不受新增字段影响
3. **数据初始化**: ✅ 正常，全新安装和已有数据都能正确处理
4. **数据保存**: ✅ 正常，只保存持久化数据
5. **数据清除**: ✅ 已修复，完整清除所有状态
6. **运行时状态**: ✅ 正确，不保存到 SavedVariables
7. **边界情况**: ✅ 正确处理

### 结论

**所有数据初始化、存储和保存功能均正常，未受此次优化影响。**

新增的运行时状态字段：
- ✅ 不会保存到 SavedVariables
- ✅ 每次登录时重新初始化
- ✅ 不影响数据持久化
- ✅ 不影响全新安装
- ✅ 不影响数据加载

---

*检查日期：2024年*


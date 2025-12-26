# CrateTrackerZK 运行逻辑详解

## 一、插件初始化流程

### 1.1 文件加载顺序

根据 `Load.xml`，插件按以下顺序加载：

```
1. 基础工具模块
   - Utils/Utils.lua (工具函数)
   - Utils/Debug.lua (调试模块)

2. 本地化系统
   - Utils/Localization.lua (本地化管理)
   - Locales/Locales.lua (本地化框架)
   - Locales/zhCN.lua, zhTW.lua, ruRU.lua, enUS.lua (语言文件)

3. 数据管理
   - Data/MapConfig.lua (地图配置)
   - Data/Data.lua (数据管理)

4. 功能模块
   - Modules/Notification.lua (通知系统)
   - Modules/Commands.lua (命令处理)
   - Modules/Timer.lua (定时器和检测)
   - Modules/Area.lua (区域检测)
   - Modules/Phase.lua (位面检测)

5. UI 模块
   - UI/Info.lua (信息界面)
   - Core/Core.lua (核心逻辑)
   - UI/FloatingButton.lua (浮动按钮)
   - UI/MainPanel.lua (主面板)
```

### 1.2 初始化流程

当玩家登录时，触发 `PLAYER_LOGIN` 事件，执行 `OnLogin()` 函数：

```lua
OnLogin() {
  1. 初始化 SavedVariables (CRATETRACKERZK_UI_DB)
  2. 显示加载消息
  3. 初始化各模块：
     - Localization:Initialize()
     - Data:Initialize()
     - Debug:Initialize()
     - Notification:Initialize()
     - Commands:Initialize()
  4. 启动地图图标检测
     - TimerManager:Initialize()
     - TimerManager:StartMapIconDetection(1) // 每1秒检测一次
  5. 创建UI界面
     - MainPanel:CreateMainFrame()
     - CrateTrackerZK:CreateFloatingButton()
  6. 检查区域有效性
     - Area:CheckAndUpdateAreaValid()
}
```

## 二、核心运行机制

### 2.1 地图图标检测流程

**检测频率**: 每1秒执行一次

**检测流程**:

```
1. 获取当前地图ID
   currentMapID = C_Map.GetBestMapForUnit("player")

2. 匹配目标地图数据
   - 首先匹配当前地图ID
   - 如果未匹配，尝试匹配父地图ID

3. 获取地图上的所有Vignette图标
   vignettes = C_VignetteInfo.GetVignettes()

4. 遍历所有图标，查找空投箱子
   for each vignette in vignettes:
     - 获取图标信息（GetVignetteInfo）
     - 提取图标名称
     - 与配置的空投名称比较（"战争物资箱" / "War Supply Crate"）
     - 如果匹配，标记为找到
   
   **注意**：检测仅依赖名称匹配，不检查位置信息。原因：
   - GetVignettes() 已返回当前地图上的所有Vignette
   - 区域有效性检测已确保在正确的追踪区域
   - 支持子地图场景（子地图上的Vignette可能无法用子地图ID获取位置）

5. 持续检测确认机制
   - 首次检测到图标：记录首次检测时间
   - 持续检测2秒后：确认空投出现
   - 更新刷新时间：使用首次检测时间作为刷新时间
   - 发送通知：通知玩家和团队

6. 图标消失处理
   - 如果之前检测到图标，现在检测不到
   - 清除检测状态
```

**关键代码位置**: `Modules/Timer.lua` 的 `DetectMapIcons()` 函数

### 2.2 刷新时间计算逻辑

**计算公式**:

```
nextRefresh = lastRefresh + n * interval

其中：
- lastRefresh: 上次刷新时间戳
- interval: 刷新间隔（默认1100秒）
- n: 计算出的刷新次数

n 的计算逻辑：
1. 如果 lastRefresh < currentTime:
   n = ceil((currentTime - lastRefresh) / interval)
2. 如果 lastRefresh >= currentTime:
   向前计算，找到最接近当前时间的未来刷新点
```

**关键代码位置**: `Data/Data.lua` 的 `CalculateNextRefreshTime()` 函数

### 2.3 位面检测流程

**触发时机**:
- 区域变化时（`ZONE_CHANGED`, `ZONE_CHANGED_NEW_AREA`）
- 目标改变时（`PLAYER_TARGET_CHANGED`）
- 鼠标悬停在NPC上时（工具提示显示时）

**检测方法**:

```
1. 获取鼠标悬停或目标的单位GUID
   guid = UnitGUID("mouseover") 或 UnitGUID("target")

2. 解析GUID获取位面信息
   GUID格式: "Creature-服务器ID-实例ID-..."
   位面ID = 服务器ID + "-" + 实例ID

3. 更新地图数据
   - 如果位面ID变化，更新并提示
   - 保存到 mapData.instance
   - 保存上次位面到 mapData.lastInstance
```

**关键代码位置**: `Modules/Phase.lua` 的 `GetLayerFromNPC()` 和 `UpdatePhaseInfo()` 函数

### 2.4 区域有效性检测

**检测条件**:

```
无效区域（自动暂停检测）:
- IsIndoors() == true (室内)
- GetInstanceInfo() 返回副本类型:
  - "party" (5人副本)
  - "raid" (团队副本)
  - "pvp" (PVP战场)
  - "arena" (竞技场)
  - "scenario" (场景战役)

有效区域:
- 不在室内
- 不是副本/战场
- 当前地图在追踪列表中
```

**状态管理**:

```
Area.lastAreaValidState:
- true: 区域有效，检测运行中
- false: 区域无效，检测已暂停
- nil: 初始状态

当状态变化时：
- 从无效变为有效：恢复所有检测
- 从有效变为无效：暂停所有检测
```

**关键代码位置**: `Modules/Area.lua` 的 `CheckAndUpdateAreaValid()` 函数

## 三、事件处理机制

### 3.1 注册的事件

```lua
- PLAYER_LOGIN: 玩家登录时初始化
- ZONE_CHANGED: 区域变化
- ZONE_CHANGED_NEW_AREA: 区域变化（新区域）
- PLAYER_TARGET_CHANGED: 目标改变
```

### 3.2 事件处理流程

```
ZONE_CHANGED / ZONE_CHANGED_NEW_AREA:
  1. 延迟0.1秒后执行（等待地图信息更新）
  2. 检查区域有效性
  3. 如果区域有效：
     - 执行地图图标检测
     - 更新位面信息（延迟6秒，等待位面稳定）
  4. 如果区域从无效变为有效：
     - 延迟6秒后更新位面信息

PLAYER_TARGET_CHANGED:
  1. 如果区域有效且检测未暂停
  2. 更新位面信息

工具提示显示（Tooltip）:
  1. 钩子 TooltipDataProcessor 或 GameTooltip
  2. 当显示单位工具提示时
  3. 如果区域有效且检测未暂停
  4. 更新位面信息
```

## 四、数据流

### 4.1 数据存储结构

**CRATETRACKERZK_DB**:
```lua
{
  mapData = {
    [mapID] = {
      instance = "服务器ID-实例ID",  -- 当前位面
      lastInstance = "服务器ID-实例ID",  -- 上次位面
      lastRefreshInstance = "服务器ID-实例ID",  -- 上次刷新时的位面
      lastRefresh = timestamp,  -- 上次刷新时间戳
      createTime = timestamp  -- 创建时间
    }
  }
}
```

**CRATETRACKERZK_UI_DB**:
```lua
{
  position = {
    point = "CENTER",  -- 锚点
    x = 0,  -- X坐标
    y = 0   -- Y坐标
  },
  minimapButton = {
    position = {
      point = "TOPLEFT",
      x = 50,
      y = -50
    }
  },
  debugEnabled = false,  -- 调试模式
  teamNotificationEnabled = true  -- 团队通知
}
```

### 4.2 数据更新流程

```
地图图标检测 → 发现空投 → 更新刷新时间:
  1. TimerManager:DetectMapIcons()
  2. 确认空投出现（持续2秒）
  3. Data:SetLastRefresh(mapId, timestamp)
  4. Data:UpdateNextRefresh(mapId)
  5. Data:SaveMapData(mapId)
  6. MainPanel:UpdateTable()  // 更新UI

位面检测 → 位面变化:
  1. Phase:UpdatePhaseInfo()
  2. Phase:GetLayerFromNPC()
  3. Data:UpdateMap(mapId, {instance = newInstance})
  4. Data:SaveMapData(mapId)
  5. MainPanel:UpdateTable()  // 更新UI

手动输入时间:
  1. MainPanel:EditLastRefresh(mapId)
  2. 弹出输入框
  3. Utils.ParseTimeInput(input)
  4. Utils.GetTimestampFromTime(hh, mm, ss)
  5. TimerManager:StartTimer(mapId, MANUAL_INPUT, timestamp)
  6. Data:SetLastRefresh(mapId, timestamp)
  7. MainPanel:UpdateTable()
```

## 五、UI更新机制

### 5.1 主面板更新

**更新频率**: 每1秒更新一次

**更新内容**:
```
1. 重新计算所有地图的刷新时间
   Data:CheckAndUpdateRefreshTimes()

2. 准备表格数据
   - 获取所有地图数据
   - 计算剩余时间
   - 应用排序（如果启用）

3. 更新每一行显示
   - 地图名称
   - 位面ID（带颜色标识）
   - 上次刷新时间
   - 下次刷新倒计时（带颜色：红色<5分钟，橙色<15分钟，绿色>=15分钟）
   - 操作按钮（刷新、通知）
```

**颜色标识规则**:
- 位面ID:
  - 绿色: 当前检测到空投或位面匹配
  - 红色: 位面不匹配（与上次刷新时的位面不同）
  - 白色: 无位面信息或已过期
- 倒计时:
  - 红色: < 5分钟
  - 橙色: < 15分钟
  - 绿色: >= 15分钟

### 5.2 实时倒计时

主面板每秒自动更新，显示格式：
- 剩余时间 >= 1小时: `HH:MM:SS`
- 剩余时间 < 1小时: `MM:SS`（仅显示分钟和秒）

## 六、通知系统

### 6.1 通知触发条件

1. **自动检测到空投**:
   - 地图图标检测确认空投出现
   - 调用 `Notification:NotifyAirdropDetected()`

2. **手动通知**:
   - 用户点击"通知"按钮
   - 调用 `Notification:NotifyMapRefresh()`

### 6.2 通知内容

**自动检测通知**:
```
"[地图名称] 检测到空投！"
```

**手动通知**:
```
如果空投活跃: "[地图名称] 检测到空投！"
否则: "[地图名称] 剩余时间: MM:SS"
```

### 6.3 通知渠道

**自动检测通知**（受 `/ctk team on/off` 控制）：
1. **聊天框**: 始终显示
2. **团队消息**（仅在团队中，且 `teamNotificationEnabled = true`）:
   - RAID: 普通团队消息
   - RAID_WARNING: 团队通知
3. **小队中**: 不发送自动消息

**手动通知**（不受 `/ctk team on/off` 控制）：
1. **在队伍中**: 发送到队伍
   - 副本队伍: INSTANCE_CHAT
   - 团队: RAID
   - 队伍: PARTY
2. **不在队伍中**: 发送到聊天框

## 七、错误处理和边界情况

### 7.1 地图匹配失败

- 如果当前地图不在追踪列表中，跳过检测
- 尝试匹配父地图
- 如果都不匹配，记录调试信息（限流：30秒一次）

### 7.2 时间戳验证

- 所有时间戳都经过 `sanitizeTimestamp()` 验证
- 时间戳必须在合理范围内（0 到 当前时间+1年）
- 无效时间戳会被忽略

### 7.3 检测暂停机制

- 在副本/战场/室内时自动暂停
- 暂停时停止所有检测定时器
- 恢复时重新启动检测

### 7.4 防误触机制

- 地图图标检测需要持续2秒才确认
- 如果检测到图标但未持续2秒，清除首次检测时间
- 手动输入有锁定机制，防止与自动检测冲突


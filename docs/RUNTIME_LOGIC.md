# CrateTrackerZK 运行逻辑详解

## 一、插件初始化流程

### 1.1 文件加载顺序

根据 `Load.xml`，插件按以下顺序加载：

```
1. 基础工具模块
   - Utils/Utils.lua (工具函数)
   - Utils/Logger.lua (统一日志系统)

2. 本地化系统
   - Utils/Localization.lua (本地化管理)
   - Locales/Locales.lua (本地化框架)
   - Locales/zhCN.lua, zhTW.lua, ruRU.lua, enUS.lua (语言文件)

3. 数据管理
   - Data/MapConfig.lua (地图配置)
   - Data/Data.lua (数据管理)

4. 功能模块（按依赖顺序）
   - Modules/Notification.lua (通知系统)
   - Modules/Commands.lua (命令处理)
   - Modules/IconDetector.lua (图标检测)
   - Modules/MapTracker.lua (地图匹配和变化)
   - Modules/NotificationCooldown.lua (通知冷却期)
   - Modules/DetectionState.lua (状态机)
   - Modules/DetectionDecision.lua (决策逻辑)
   - Modules/Timer.lua (定时器和检测协调)
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
  2. 显示加载消息（通过Logger）
  3. 初始化各模块：
     - Localization:Initialize()
     - Data:Initialize()
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

**检测流程**（重构后）:

```
1. 获取当前地图ID
   currentMapID = C_Map.GetBestMapForUnit("player")
   (TimerManager:DetectMapIcons())

2. 匹配目标地图数据（MapTracker模块）
   - MapTracker:GetTargetMapData(currentMapID)
   - 首先匹配当前地图ID
   - 如果未匹配，尝试匹配父地图ID

3. 处理地图变化（MapTracker模块）
   - MapTracker:OnMapChanged(currentMapID, targetMapData, currentTime)
   - 检测游戏地图变化和配置地图变化
   - 记录离开地图时间
   - 清除回到地图的离开时间

4. 检测图标（IconDetector模块）
   - IconDetector:DetectIcon(currentMapID)
   - 获取所有Vignette图标：C_VignetteInfo.GetVignettes()
   - 遍历查找空投箱子（仅依赖名称匹配）
   
   **注意**：检测仅依赖名称匹配，不检查位置信息。原因：
   - GetVignettes() 已返回当前地图上的所有Vignette
   - 区域有效性检测已确保在正确的追踪区域
   - 支持子地图场景（子地图上的Vignette可能无法用子地图ID获取位置）

5. 更新状态（DetectionState模块 - 状态机）
   - DetectionState:UpdateState(mapId, iconDetected, currentTime)
   - 状态转换：
     * IDLE -> DETECTING: 首次检测到图标
     * DETECTING -> CONFIRMED: 持续检测2秒
     * CONFIRMED -> ACTIVE: 已更新时间
     * ACTIVE -> DISAPPEARING: 图标消失
     * DISAPPEARING -> IDLE: 持续消失5秒

6. 决策通知和更新（DetectionDecision模块）
   - DetectionDecision:ShouldNotify(): 检查通知冷却期（120秒）
   - DetectionDecision:ShouldUpdateTime(): 检查间隔和手动锁定
   - 如果应该通知：Notification:NotifyAirdropDetected()
   - 如果应该更新：Data:SetLastRefresh()

7. 定期状态汇总（每5秒）
   - TimerManager:ReportCurrentStatus()
   - 输出当前地图、区域、位面、检测状态等信息
```

**关键代码位置**: 
- `Modules/Timer.lua` 的 `DetectMapIcons()` 函数（协调）
- `Modules/IconDetector.lua` 的 `DetectIcon()` 函数（图标检测）
- `Modules/MapTracker.lua` 的 `GetTargetMapData()` 和 `OnMapChanged()` 函数（地图匹配）
- `Modules/DetectionState.lua` 的 `UpdateState()` 函数（状态机）
- `Modules/DetectionDecision.lua` 的 `ShouldNotify()` 和 `ShouldUpdateTime()` 函数（决策）

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
- GetInstanceInfo() 返回副本类型:
  - "party" (5人副本)
  - "raid" (团队副本)
  - "pvp" (PVP战场)
  - "arena" (竞技场)
  - "scenario" (场景战役)
- 无法获取地图ID
- 当前地图不在追踪列表中（且父地图也不在列表中）

有效区域:
- 不是副本/战场
- 当前地图在追踪列表中（或父地图在列表中）
- 注意: 室内区域不再被视为无效区域
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

刷新按钮:
  1. MainPanel:RefreshMap(mapId)
  2. 立即更新内存数据（同步）
     - mapData.lastRefresh = currentTimestamp
     - mapData.lastRefreshInstance = mapData.instance
     - Data:UpdateNextRefresh(mapId, mapData)
  3. 立即更新UI显示（同步）
     - MainPanel:UpdateTable()  // UI立即显示新时间
  4. 异步保存数据（异步）
     - C_Timer.After(0, function()
         TimerManager:StartTimer(mapId, REFRESH_BUTTON, currentTimestamp)
         - Data:SetLastRefresh(mapId, timestamp)
         - Data:SaveMapData(mapId)
       end)

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

1. **自动检测到空投**（优化后）:
   - **首次检测到图标时立即发送通知**（检查通知冷却期）
   - 如果不在冷却期内（距离上次通知 >= 120秒），立即发送通知
   - 2秒确认后更新时间，不再次发送通知
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
   - RAID_WARNING: 团队通知（需要权限）
3. **小队中**: 不发送自动消息
4. **通知冷却期**: 同一地图在120秒内不重复发送通知

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

- 在副本/战场时自动暂停
- 暂停时停止所有检测定时器
- 恢复时重新启动检测
- 注意: 室内区域不再被视为无效区域

### 7.4 防误触机制

- **2秒持续检测确认**：防止短暂图标闪烁导致的误判
- **消失确认期**：
  - CONFIRMED状态: 5秒确认期
  - ACTIVE状态: 5分钟确认期（因为空投是持续事件，可能因地图传送中断）
- **通知冷却期（120秒）**：防止短时间内重复通知
- **空投事件识别机制**：根据空投开始时间判断是否在持续时间内，区分检测中断和空投结束

### 7.5 状态管理优化

- **离开地图状态自动清除**：
  - 当玩家离开某个地图后，如果5分钟内没有回到该地图，自动清除该地图的检测状态
  - 避免长期占用内存，保持状态准确性
  - 清除的状态包括：检测状态、首次检测时间、消失时间、通知冷却期

- **地图切换状态管理**：
  - 自动记录离开地图的时间
  - 自动清除回到地图的离开时间
  - 定期检查并清除超时的地图状态

- 地图图标检测需要持续2秒才确认
- 如果检测到图标但未持续2秒，清除首次检测时间
- 手动输入有锁定机制，防止与自动检测冲突


# CrateTrackerZK 功能与运行逻辑完整文档

## 目录

1. [插件概述](#插件概述)
2. [核心功能详解](#核心功能详解)
3. [运行逻辑流程](#运行逻辑流程)
4. [关键机制说明](#关键机制说明)
5. [数据管理](#数据管理)
6. [用户交互](#用户交互)

---

## 插件概述

### 插件定位

CrateTrackerZK 是一个专为魔兽世界设计的空投物资追踪插件，主要用于：

- **自动检测**：通过游戏地图图标系统自动检测空投箱子出现
- **时间追踪**：精确记录和计算空投刷新时间
- **位面管理**：追踪和管理不同位面的空投状态
- **团队协作**：支持团队通知功能，方便团队协调

### 技术架构

插件采用模块化设计，主要分为：
- **核心层**：事件处理和初始化协调
- **数据层**：数据管理和持久化
- **功能层**：检测、通知、命令处理等模块
- **UI层**：用户界面和交互
- **工具层**：通用工具和本地化

---

## 核心功能详解

### 1. 自动空投检测系统

#### 检测原理

插件使用魔兽世界的 **Vignette（小地图图标）系统** 来检测空投箱子：

1. **定时扫描**：每1秒扫描一次当前地图上的所有Vignette图标
2. **名称匹配**：通过图标名称匹配空投箱子（"战争物资箱" / "War Supply Crate"）
3. **持续确认**：检测到图标后需要持续2秒才确认，防止误判
4. **自动记录**：确认后自动记录刷新时间并计算下次刷新时间

**设计说明**：
- 检测**仅依赖名称匹配**，不依赖位置信息
- 这样设计的原因：
  - `GetVignettes()` 已返回当前地图上的所有Vignette，无需位置验证
  - 区域有效性检测已确保在正确的追踪区域
  - 支持子地图检测（如塔扎维什作为卡雷什的子地图）
  - 简化逻辑，提高可靠性

#### 检测流程

```
每1秒执行一次：
├─ 获取当前地图ID
├─ 匹配目标地图（支持父地图匹配）
├─ 获取所有Vignette图标
├─ 遍历查找空投箱子图标
├─ 首次检测：记录首次检测时间
├─ 持续2秒：确认空投出现
└─ 更新刷新时间并通知
```

#### 防误触机制

- **2秒确认期**：首次检测到图标后，需要持续检测2秒才确认
- **状态清除**：如果检测中断，清除首次检测时间，重新开始
- **手动锁定**：手动输入时间时，会锁定该地图，避免自动检测覆盖

### 2. 刷新时间追踪系统

#### 时间计算逻辑

刷新时间基于以下公式计算：

```
nextRefresh = lastRefresh + n * interval

其中：
- lastRefresh: 上次刷新时间戳
- interval: 刷新间隔（默认1100秒，约18.3分钟）
- n: 计算出的刷新次数
```

#### 计算规则

1. **过去时间处理**：
   - 如果 `lastRefresh < currentTime`：计算需要多少次刷新才能到达未来
   - `n = ceil((currentTime - lastRefresh) / interval)`

2. **未来时间处理**：
   - 如果 `lastRefresh >= currentTime`：向前计算，找到最接近当前时间的未来刷新点

#### 时间更新触发

刷新时间可以通过以下方式更新：

- **自动检测**：地图图标检测确认空投出现
- **手动输入**：用户点击"上次刷新"列输入时间
- **刷新按钮**：用户点击"刷新"按钮使用当前时间

### 3. 位面（Phase）追踪系统

#### 位面检测原理

位面信息通过解析NPC的GUID获取：

```
GUID格式: "Creature-0-[分片ID]-[实例ID]-[zoneUID]-[NPC ID]-[spawnUID]"
位面ID = 分片ID + "-" + 实例ID (第3部分-第4部分)
```

#### 检测触发时机

- **区域变化**：进入新区域时
- **目标改变**：选择新目标时
- **鼠标悬停**：鼠标指向NPC时（工具提示显示时）

#### 位面状态管理

- **当前位面**：`mapData.instance` - 当前检测到的位面ID
- **上次位面**：`mapData.lastInstance` - 上次记录的位面ID
- **刷新位面**：`mapData.lastRefreshInstance` - 上次刷新时的位面ID

#### 颜色标识规则

- **绿色**：当前检测到空投，或位面匹配
- **红色**：位面不匹配（与上次刷新时的位面不同）
- **白色**：无位面信息或已过期

---

## 运行逻辑流程

### 插件初始化流程

#### 文件加载顺序

根据 `Load.xml`，插件按以下顺序加载：

```
1. 基础工具
   ├─ Utils/Utils.lua
   └─ Utils/Logger.lua

2. 本地化系统
   ├─ Utils/Localization.lua
   ├─ Locales/Locales.lua
   └─ Locales/*.lua (zhCN, zhTW, ruRU, enUS)

3. 数据管理
   ├─ Data/MapConfig.lua
   └─ Data/Data.lua

4. 功能模块（按依赖顺序）
   ├─ Modules/Notification.lua
   ├─ Modules/Commands.lua
   ├─ Modules/IconDetector.lua
   ├─ Modules/MapTracker.lua
   ├─ Modules/NotificationCooldown.lua
   ├─ Modules/DetectionState.lua
   ├─ Modules/DetectionDecision.lua
   ├─ Modules/Timer.lua
   ├─ Modules/Area.lua
   └─ Modules/Phase.lua

5. UI模块
   ├─ UI/Info.lua
   ├─ Core/Core.lua
   ├─ UI/FloatingButton.lua
   └─ UI/MainPanel.lua
```

#### 初始化步骤

当玩家登录时，触发 `PLAYER_LOGIN` 事件：

```
1. 初始化 SavedVariables
   ├─ CRATETRACKERZK_UI_DB (UI设置)
   └─ CRATETRACKERZK_DB (地图数据)

2. 初始化各模块
   ├─ Localization:Initialize()
   ├─ Data:Initialize()
   ├─ Notification:Initialize()
   └─ Commands:Initialize()
   (注意：Logger 已在 Load.xml 中自动初始化)

3. 启动检测系统
   ├─ TimerManager:Initialize()
   └─ TimerManager:StartMapIconDetection(1) // 每1秒检测

4. 创建UI界面
   ├─ MainPanel:CreateMainFrame()
   └─ CrateTrackerZK:CreateFloatingButton()

5. 检查区域有效性
   └─ Area:CheckAndUpdateAreaValid()
```

### 核心运行循环

#### 地图图标检测循环

```
每1秒执行：
├─ TimerManager:DetectMapIcons()
│  ├─ 获取当前地图ID
│  ├─ MapTracker:GetTargetMapData() - 匹配目标地图数据
│  ├─ MapTracker:OnMapChanged() - 处理地图变化
│  ├─ IconDetector:DetectIcon() - 检测图标
│  ├─ DetectionState:UpdateState() - 更新状态（状态机）
│  ├─ DetectionDecision:ShouldNotify() - 决策通知
│  ├─ DetectionDecision:ShouldUpdateTime() - 决策更新
│  └─ 定期状态汇总（每5秒）
│
└─ 条件检查：
   ├─ 区域必须有效
   ├─ 检测未暂停
   └─ 地图在追踪列表中
```

#### UI更新循环

```
每1秒执行：
├─ MainPanel:UpdateTable()
│  ├─ 更新所有地图的刷新时间
│  ├─ 计算剩余时间
│  ├─ 应用排序（如果启用）
│  └─ 更新表格显示
│
└─ 颜色更新：
   ├─ 位面ID颜色
   └─ 倒计时颜色
```

#### 位面检测触发

```
事件触发：
├─ ZONE_CHANGED / ZONE_CHANGED_NEW_AREA
│  └─ 延迟0.1秒后执行
│     ├─ 检查区域有效性
│     └─ 更新位面信息（延迟6秒）
│
├─ PLAYER_TARGET_CHANGED
│  └─ 立即更新位面信息
│
└─ Tooltip显示（鼠标悬停NPC）
   └─ 立即更新位面信息
```

---

## 关键机制说明

### 区域有效性检测

#### 检测条件

**无效区域**（自动暂停检测）：
- 副本类型为：party, raid, pvp, arena, scenario
- 无法获取地图ID
- 当前地图不在追踪列表中（且父地图也不在列表中）

**有效区域**（恢复检测）：
- 不是副本/战场
- 当前地图在追踪列表中（或父地图在列表中）
- 注意: 室内区域不再被视为无效区域

#### 状态管理

```
Area.lastAreaValidState:
├─ true: 区域有效，检测运行中
├─ false: 区域无效，检测已暂停
└─ nil: 初始状态

状态变化时：
├─ 无效 → 有效：恢复所有检测
│  ├─ TimerManager:StartMapIconDetection(1)
│  └─ 启动位面检测定时器（延迟6秒）
│
└─ 有效 → 无效：暂停所有检测
   ├─ TimerManager:StopMapIconDetection()
   └─ 停止位面检测定时器
```

### 持续检测确认机制（优化后）

#### 工作原理

```
首次检测到图标：
├─ 记录首次检测时间
│  └─ mapIconFirstDetectedTime[mapId] = currentTime
│
├─ 立即发送通知（检查冷却期）
│  ├─ 检查通知冷却期：距离上次通知 >= 120秒？
│  ├─ 如果不在冷却期：
│  │  ├─ 发送通知到聊天框和团队
│  │  └─ 记录通知时间：lastNotificationTime[mapId] = currentTime
│  └─ 如果不在冷却期：跳过通知
│
├─ 等待持续检测（不立即更新时间）
│  └─ 每1秒检查一次
│
└─ 持续2秒后：
   ├─ 确认空投出现
   ├─ 使用首次检测时间作为刷新时间
   ├─ 更新 mapIconDetected[mapId] = true
   └─ 不再次发送通知（首次检测时已发送）
```

#### 中断处理（优化后）

```
如果检测中断（图标消失）：

情况1：还在2秒确认期内
├─ 清除首次检测时间
│  └─ mapIconFirstDetectedTime[mapId] = nil
│
└─ 不发送通知（未确认）

情况2：已确认检测到
├─ 记录消失时间
│  └─ mapIconDisappearedTime[mapId] = currentTime
│
├─ 消失确认期（5秒）
│  ├─ 如果图标在5秒内重新出现：保持状态
│  └─ 如果持续消失超过5秒：
│     └─ 清除所有检测状态
│        ├─ mapIconDetected[mapId] = nil
│        ├─ mapIconFirstDetectedTime[mapId] = nil
│        └─ mapIconDisappearedTime[mapId] = nil
```

#### 通知冷却期机制

```
通知冷却期：120秒（2分钟）

首次检测时：
├─ 检查 lastNotificationTime[mapId]
├─ 如果存在且距离当前时间 < 120秒：
│  └─ 跳过通知（在冷却期内）
└─ 如果不存在或距离当前时间 >= 120秒：
   └─ 发送通知并记录时间
```

#### 离开地图状态管理（新增）

```
地图切换时：
├─ 记录离开旧地图的时间
│  └─ mapLeftTime[oldMapId] = currentTime
│
├─ 清除当前地图的离开时间（玩家已回到该地图）
│  └─ mapLeftTime[currentMapId] = nil
│
└─ 检查并清除超时的地图状态
   ├─ 遍历所有已离开的地图
   ├─ 如果离开时间 >= 300秒（5分钟）：
   │  └─ 清除该地图的所有状态
   │     ├─ mapIconDetected[mapId] = nil
   │     ├─ mapIconFirstDetectedTime[mapId] = nil
   │     ├─ mapIconDisappearedTime[mapId] = nil
   │     ├─ lastNotificationTime[mapId] = nil
   │     └─ mapLeftTime[mapId] = nil
   └─ 如果离开时间 < 300秒：保持状态
```

### 时间输入处理

#### 输入格式

支持两种格式：
- `HH:MM:SS` - 标准格式（如：14:30:00）
- `HHMMSS` - 紧凑格式（如：143000）

#### 处理流程

```
用户输入时间：
├─ 解析输入
│  ├─ Utils.ParseTimeInput(input)
│  └─ 验证格式和范围
│
├─ 转换为时间戳
│  ├─ Utils.GetTimestampFromTime(hh, mm, ss)
│  └─ 使用当前日期 + 输入时间
│
├─ 设置手动锁定
│  └─ Data.manualInputLock[mapId] = timestamp
│
└─ 更新刷新时间
   └─ TimerManager:StartTimer(mapId, MANUAL_INPUT, timestamp)
```

---

## 数据管理

### 数据结构

#### 地图数据 (Data.maps)

```lua
{
  [id] = {
    id = 1,                    -- 内部ID（从1开始）
    mapID = 2248,             -- 游戏地图ID
    interval = 1100,          -- 刷新间隔（秒）
    instance = "123-456",     -- 当前位面ID (格式: 分片ID-实例ID, 第3部分-第4部分)
    lastInstance = "123-456", -- 上次位面ID
    lastRefreshInstance = "123-456", -- 上次刷新时的位面ID
    lastRefresh = timestamp,  -- 上次刷新时间戳
    nextRefresh = timestamp,  -- 下次刷新时间戳（计算得出）
    createTime = timestamp    -- 创建时间
  }
}
```

#### 保存数据 (CRATETRACKERZK_DB)

```lua
{
  mapData = {
    [mapID] = {
      instance = "123-456",
      lastInstance = "123-456",
      lastRefreshInstance = "123-456",
      lastRefresh = timestamp,
      createTime = timestamp
    }
  }
}
```

#### UI设置 (CRATETRACKERZK_UI_DB)

```lua
{
  position = {
    point = "CENTER",
    x = 0,
    y = 0
  },
  minimapButton = {
    position = {
      point = "TOPLEFT",
      x = 50,
      y = -50
    }
  },
  debugEnabled = false,
  teamNotificationEnabled = true
}
```

### 数据持久化

#### 保存时机

- **刷新时间更新**：检测到空投或手动更新时
- **位面信息更新**：检测到位面变化时
- **UI位置变化**：拖拽窗口或按钮时
- **设置变更**：修改通知或调试设置时

#### 加载流程

```
插件初始化：
├─ Data:Initialize()
│  ├─ 从配置加载地图列表
│  │  └─ MAP_CONFIG.current_maps
│  │
  ├─ 从保存数据恢复
│  │  └─ CRATETRACKERZK_DB.mapData[mapID]
│  │
│  ├─ 验证时间戳
│  │  └─ sanitizeTimestamp() - 检查范围
│  │
│  └─ 计算下次刷新时间
│     └─ Data:UpdateNextRefresh(mapId)
```

---

## 用户交互

### 主面板功能

#### 表格显示

主面板显示5列信息：

1. **地图名称** - 本地化的地图名称
2. **位面ID** - 当前位面（后5位），带颜色标识
3. **上次刷新** - 可点击编辑，格式：HH:MM:SS
4. **下次刷新** - 倒计时显示，可排序，带颜色标识
5. **操作** - 刷新按钮、通知按钮

#### 交互功能

- **点击"上次刷新"列**：弹出输入框，可手动输入时间
- **点击"刷新"按钮**：使用当前时间更新刷新时间
- **点击"通知"按钮**：发送当前地图的刷新信息到团队
- **点击表头排序**：按"上次刷新"或"下次刷新"排序
- **拖拽窗口**：移动主面板位置，自动保存

### 命令系统

#### 可用命令

- `/ctk` 或 `/ct` - 打开/关闭主面板
- `/ctk help` - 显示帮助信息
- `/ctk clear` - 清除所有数据并重新初始化
- `/ctk team on/off` - 开启/关闭团队通知
- `/ctk debug on/off` - 开启/关闭调试模式

#### 命令处理流程

```
用户输入命令：
├─ Commands:HandleCommand(msg)
│  ├─ 解析命令和参数
│  │  └─ strsplit(" ", msg, 2)
│  │
│  └─ 执行对应处理函数
│     ├─ HandleClearCommand() - 清除数据
│     ├─ HandleTeamNotificationCommand() - 团队通知
│     ├─ HandleDebugCommand() - 调试模式
│     └─ ShowHelp() - 显示帮助
```

### 通知系统

#### 通知类型

1. **自动检测通知**：
   - 触发：检测到空投时
   - 内容：`"[地图名称] 检测到空投！"`
   - 控制：受 `/ctk team on/off` 命令控制
   - 渠道：
     - 聊天框：始终发送
     - 团队消息：仅在团队中发送（如果 `teamNotificationEnabled = true`）
       - RAID（普通团队消息）
       - RAID_WARNING（团队通知）
     - 小队中：不发送自动消息

2. **手动通知**：
   - 触发：点击"通知"按钮
   - 内容：
     - 如果空投活跃：`"[地图名称] 检测到空投！"`
     - 否则：`"[地图名称] 剩余时间: MM:SS"`
   - 控制：不受 `/ctk team on/off` 命令控制
   - 渠道：
     - 在队伍中：发送到队伍（PARTY/RAID/INSTANCE_CHAT）
     - 不在队伍中：发送到聊天框

#### 通知渠道选择

**自动检测通知**（受命令控制）：
```
如果 teamNotificationEnabled = true 且在团队中：
├─ 聊天框：始终发送
├─ RAID：普通团队消息
└─ RAID_WARNING：团队通知

如果 teamNotificationEnabled = true 但不在团队中（包括小队）：
└─ 聊天框：只发送到聊天框

如果 teamNotificationEnabled = false：
└─ 聊天框：只发送到聊天框
```

**手动通知**（不受命令控制）：
```
GetTeamChatType():
├─ 副本队伍 → INSTANCE_CHAT
├─ 团队 → RAID
├─ 队伍 → PARTY
└─ 无队伍 → 聊天框
```

---

## 总结

CrateTrackerZK 插件通过模块化设计实现了完整的空投追踪功能：

1. **自动化检测**：通过地图图标系统自动检测空投
2. **精确计时**：准确计算和显示刷新时间
3. **位面管理**：追踪不同位面的空投状态
4. **用户友好**：直观的UI和便捷的操作
5. **团队协作**：支持团队通知功能

插件采用事件驱动架构，通过定时器和游戏事件触发各种功能，确保实时性和准确性。所有数据都持久化保存，重载游戏后不会丢失。

---

*本文档版本：1.1.3-beta*  
*最后更新：2024年*


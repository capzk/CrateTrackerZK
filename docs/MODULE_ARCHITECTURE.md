# CrateTrackerZK 模块架构文档

## 一、整体架构

CrateTrackerZK 采用模块化设计，各模块职责清晰，通过 `BuildEnv` 系统进行模块间通信。

```
┌─────────────────────────────────────────────────────────┐
│                    核心层 (Core)                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Core.lua - 事件处理、初始化协调                      │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
┌───────▼──────┐  ┌───────▼──────┐  ┌───────▼──────┐
│   数据层     │  │   功能层     │  │    UI层      │
│  (Data)      │  │  (Modules)   │  │   (UI)       │
└──────────────┘  └──────────────┘  └──────────────┘
        │                 │                 │
        └─────────────────┼─────────────────┘
                          │
                ┌─────────▼─────────┐
                │   工具层 (Utils)   │
                └────────────────────┘
```

## 二、模块详细说明

### 2.1 核心层 (Core)

#### Core.lua
**职责**: 
- 插件生命周期管理
- 事件注册和处理
- 模块初始化协调
- 全局功能控制（暂停/恢复检测）

**主要函数**:
- `OnLogin()`: 玩家登录时的初始化流程
- `OnEvent()`: 游戏事件处理
- `PauseAllDetections()`: 暂停所有检测
- `ResumeAllDetections()`: 恢复所有检测
- `Reinitialize()`: 重新初始化插件

**依赖**: 所有其他模块

### 2.2 数据层 (Data)

#### Data/Data.lua
**职责**:
- 地图数据管理
- 刷新时间计算
- 数据持久化（SavedVariables）
- 时间格式化

**核心数据结构**:
```lua
Data.maps = {
  [id] = {
    id = 1,                    -- 内部ID
    mapID = 2248,             -- 游戏地图ID
    interval = 1100,          -- 刷新间隔（秒）
    instance = "123-456",     -- 当前位面
    lastInstance = "123-456", -- 上次位面
    lastRefreshInstance = "123-456", -- 上次刷新时的位面
    lastRefresh = timestamp,  -- 上次刷新时间戳
    nextRefresh = timestamp,  -- 下次刷新时间戳
    createTime = timestamp    -- 创建时间
  }
}
```

**主要函数**:
- `Initialize()`: 从配置和保存数据初始化地图列表
- `SetLastRefresh(mapId, timestamp)`: 设置刷新时间
- `UpdateNextRefresh(mapId)`: 计算下次刷新时间
- `GetMap(mapId)`: 获取地图数据
- `SaveMapData(mapId)`: 保存到 SavedVariables
- `FormatTime(seconds)`: 格式化时间显示

#### Data/MapConfig.lua
**职责**:
- 地图配置管理
- 空投箱子配置
- 配置验证

**配置结构**:
```lua
MAP_CONFIG = {
  current_maps = {
    {mapID = 2248, interval = 1100, enabled = true, priority = 1},
    ...
  },
  airdrop_crates = {
    {code = "WarSupplyCrate", enabled = true}
  },
  defaults = {
    interval = 1100,
    enabled = true
  }
}
```

### 2.3 功能模块层 (Modules)

#### Modules/Timer.lua (TimerManager)
**职责**:
- 地图图标检测
- 定时器管理
- 刷新时间更新触发

**检测流程**:
1. 每1秒执行一次检测
2. 获取当前地图ID
3. 匹配目标地图数据
4. 获取所有Vignette图标
5. 查找空投箱子图标
6. 持续检测确认（2秒）
7. 更新刷新时间

**主要函数**:
- `Initialize()`: 初始化定时器管理器
- `StartMapIconDetection(interval)`: 启动地图图标检测
- `DetectMapIcons()`: 执行地图图标检测
- `StartTimer(mapId, source, timestamp)`: 启动/更新计时器
- `StartCurrentMapTimer(source)`: 启动当前地图计时器

**检测来源类型**:
- `MANUAL_INPUT`: 手动输入
- `REFRESH_BUTTON`: 刷新按钮
- `API_INTERFACE`: API接口
- `MAP_ICON`: 地图图标检测

#### Modules/Phase.lua
**职责**:
- 位面（Phase）检测
- 位面信息更新
- 位面变化通知

**检测方法**:
- 从NPC的GUID中提取位面信息
- GUID格式: `Creature-服务器ID-实例ID-...`
- 位面ID = `服务器ID-实例ID`

**主要函数**:
- `GetLayerFromNPC()`: 从NPC获取位面ID
- `UpdatePhaseInfo()`: 更新位面信息

**触发时机**:
- 区域变化时
- 目标改变时
- 鼠标悬停在NPC上时

#### Modules/Area.lua
**职责**:
- 区域有效性检测
- 检测暂停/恢复控制

**有效性判断**:
- 无效: 室内、副本、战场、竞技场、场景战役
- 有效: 不在上述区域且地图在追踪列表中

**主要函数**:
- `GetCurrentMapId()`: 获取当前地图ID
- `CheckAndUpdateAreaValid()`: 检查并更新区域有效性
- `PauseAllDetections()`: 暂停所有检测
- `ResumeAllDetections()`: 恢复所有检测

**状态管理**:
- `lastAreaValidState`: 上次区域有效性状态
- `detectionPaused`: 检测是否暂停

#### Modules/Notification.lua
**职责**:
- 通知消息发送
- 团队通知管理

**通知类型**:
- 自动检测通知: 检测到空投时（受 `/ctk team on/off` 控制）
- 手动通知: 用户点击通知按钮（不受 `/ctk team on/off` 控制）

**主要函数**:
- `Initialize()`: 初始化通知模块
- `NotifyAirdropDetected(mapName, source)`: 通知空投检测
- `NotifyMapRefresh(mapData)`: 通知地图刷新信息
- `SetTeamNotificationEnabled(enabled)`: 设置团队通知开关
- `GetTeamChatType()`: 获取队伍聊天类型

**通知渠道**:
- **自动检测通知**（受命令控制）:
  - 聊天框（始终）
  - 团队消息（仅在团队中，且 `teamNotificationEnabled = true`）
    - RAID（普通团队消息）
    - RAID_WARNING（团队通知）
  - 小队中：不发送自动消息
- **手动通知**（不受命令控制）:
  - 在队伍中：PARTY/RAID/INSTANCE_CHAT
  - 不在队伍中：聊天框

#### Modules/Commands.lua
**职责**:
- 斜杠命令处理
- 命令解析和执行

**支持的命令**:
- `/ctk` 或 `/ct`: 打开/关闭主面板
- `/ctk help`: 显示帮助
- `/ctk clear`: 清除数据
- `/ctk team on/off`: 团队通知开关
- `/ctk debug on/off`: 调试模式开关

**主要函数**:
- `Initialize()`: 初始化命令模块
- `HandleCommand(msg)`: 处理命令
- `HandleClearCommand()`: 处理清除命令
- `HandleTeamNotificationCommand()`: 处理团队通知命令

### 2.4 UI层 (UI)

#### UI/MainPanel.lua
**职责**:
- 主面板创建和管理
- 表格显示和更新
- 用户交互处理

**主要组件**:
- 主框架: 可拖拽窗口
- 表格: 显示地图数据
- 操作按钮: 刷新、通知
- 信息按钮: 帮助、关于

**表格列**:
1. 地图名称
2. 位面ID（带颜色标识）
3. 上次刷新时间（可点击编辑）
4. 下次刷新倒计时（可排序）
5. 操作按钮（刷新、通知）

**主要函数**:
- `CreateMainFrame()`: 创建主面板
- `UpdateTable()`: 更新表格显示
- `RefreshMap(mapId)`: 刷新地图计时
- `EditLastRefresh(mapId)`: 编辑刷新时间
- `NotifyMapRefresh(mapData)`: 发送通知
- `SortTable(field)`: 排序表格

**更新频率**: 每1秒自动更新

#### UI/FloatingButton.lua
**职责**:
- 浮动按钮创建和管理
- 快速打开/关闭主面板

**特性**:
- 可拖拽
- 智能锚点选择
- 位置持久化

**主要函数**:
- `CreateFloatingButton()`: 创建浮动按钮

#### UI/Info.lua
**职责**:
- 帮助信息显示
- 关于信息显示

**主要函数**:
- `ShowIntroduction()`: 显示帮助
- `ShowAnnouncement()`: 显示关于

### 2.5 工具层 (Utils)

#### Utils/Utils.lua
**职责**:
- 通用工具函数
- 时间解析和格式化
- 错误输出

**主要函数**:
- `ParseTimeInput(input)`: 解析时间输入（HH:MM:SS 或 HHMMSS）
- `GetTimestampFromTime(hh, mm, ss)`: 将时间转换为时间戳
- `PrintError(message)`: 输出错误消息
- `Print(message)`: 输出普通消息
- `Debug(...)`: 调试输出

#### Utils/Debug.lua
**职责**:
- 调试模式管理
- 调试消息输出
- 消息限流

**特性**:
- 调试开关持久化
- 消息限流（30秒间隔）
- 本地化调试文本

**主要函数**:
- `Initialize()`: 初始化调试模块
- `IsEnabled()`: 检查是否启用
- `SetEnabled(enabled)`: 设置启用状态
- `Print(msg, ...)`: 输出调试消息
- `PrintLimited(key, msg, ...)`: 限流输出

#### Utils/Localization.lua
**职责**:
- 本地化管理
- 翻译完整性验证
- 回退机制

**支持语言**:
- zhCN（简体中文）
- zhTW（繁体中文）
- enUS（英文，回退语言）
- ruRU（俄文）

**主要函数**:
- `Initialize()`: 初始化本地化
- `GetMapName(mapID)`: 获取地图名称
- `GetAirdropCrateName()`: 获取空投箱子名称
- `ValidateCompleteness()`: 验证翻译完整性
- `GetEnglishLocale()`: 获取英文回退

## 三、模块间通信

### 3.1 BuildEnv 系统

所有模块通过 `BuildEnv(name)` 函数创建和访问：

```lua
local ModuleName = BuildEnv("ModuleName")
```

**特点**:
- 延迟加载：模块在首次访问时创建
- 全局访问：所有模块都可以访问其他模块
- 命名空间隔离：避免全局变量污染

### 3.2 数据流向

```
用户操作 / 游戏事件
    ↓
Core.lua (事件处理)
    ↓
功能模块 (Timer/Phase/Area)
    ↓
Data.lua (数据更新)
    ↓
UI (MainPanel) (界面更新)
```

### 3.3 模块依赖关系

```
Core
 ├─ Data
 │   └─ MapConfig
 ├─ TimerManager
 │   └─ Data
 ├─ Phase
 │   └─ Data
 ├─ Area
 │   └─ Data
 ├─ Notification
 │   └─ Data
 ├─ Commands
 │   ├─ Debug
 │   └─ Notification
 ├─ MainPanel
 │   ├─ Data
 │   ├─ TimerManager
 │   └─ Notification
 ├─ FloatingButton
 │   └─ MainPanel
 └─ Utils
     ├─ Debug
     └─ Localization
```

## 四、扩展性设计

### 4.1 添加新地图

1. 在 `Data/MapConfig.lua` 中添加地图配置
2. 在 `Locales/*.lua` 中添加地图名称翻译
3. 无需修改其他代码

### 4.2 添加新检测源

1. 在 `TimerManager.detectionSources` 中添加新来源
2. 在 `TimerManager:GetSourceDisplayName()` 中添加显示名称
3. 在检测逻辑中调用 `TimerManager:StartTimer()`

### 4.3 添加新语言

1. 创建 `Locales/xxXX.lua` 文件
2. 在 `Load.xml` 中添加加载语句
3. 实现完整的翻译表

## 五、性能优化

### 5.1 检测限流

- 地图图标检测: 每1秒一次
- 位面检测: 事件触发 + 10秒定时器
- UI更新: 每1秒一次
- 调试消息: 30秒限流

### 5.2 区域检测优化

- 只在区域变化时检查有效性
- 无效区域自动暂停所有检测
- 减少不必要的API调用

### 5.3 数据持久化

- 只在数据变化时保存
- 使用 SavedVariables 自动持久化
- 时间戳验证防止无效数据


# 空投物资追踪器 - 开发设计文档

## 目录

1. [项目概述](#1-项目概述)
2. [开发设计要求](#2-开发设计要求)
3. [运行逻辑要求](#3-运行逻辑要求)
4. [核心架构设计](#4-核心架构设计)
5. [UI设计文档](#5-ui设计文档)
6. [模块接口文档](#6-模块接口文档)
7. [数据存储设计](#7-数据存储设计)
8. [关键实现细节](#8-关键实现细节)
9. [版本历史](#9-版本历史)
10. [开发注意事项](#10-开发注意事项)
11. [测试要求](#11-测试要求)
12. [扩展建议](#12-扩展建议)

---

## 1. 项目概述

### 1.1 项目简介

空投物资追踪器是一个用于魔兽世界的空投箱子刷新追踪插件，帮助玩家记录和追踪游戏中各种空投箱子的刷新时间和位面信息。

### 1.2 技术栈

- **语言**：Lua 5.1
- **平台**：World of Warcraft AddOn API
- **接口版本**：110200, 110205, 110207
- **当前版本**：v1.1.2-beta
- **重构路线图**：参见 [REFACTOR_PLAN.md](REFACTOR_PLAN.md)

### 1.3 项目结构 (当前)

```
CrateTrackerZK/
├── CrateTrackerZK.toc   # 插件清单文件
├── Load.xml             # 加载顺序配置文件
├── Core/                # 核心初始化与事件分发
│   └── Core.lua
├── Data/                # 数据管理与静态数据
│   ├── MapConfig.lua    # 地图/空投配置（代号系统）
│   └── Data.lua         # 数据管理核心（使用 MapConfig 作为唯一数据源）
├── UI/                  # 界面实现
│   ├── MainPanel.lua
│   ├── FloatingButton.lua
│   ├── Info.lua
│   └── Frame.xml
├── Modules/             # 功能模块
│   ├── Timer.lua        # 空投检测（地图图标检测）
│   ├── Notification.lua # 通知系统
│   ├── Commands.lua     # 命令处理
│   ├── Area.lua         # 区域有效性检测
│   └── Phase.lua        # 位面检测
├── Locales/             # 多语言支持
│   ├── Locales.lua      # 本地化管理核心
│   ├── zhCN.lua         # 简体中文
│   ├── zhTW.lua         # 繁体中文
│   ├── enUS.lua         # 英文
│   ├── ruRU.lua         # 俄语
│   └── TRANSLATION_GUIDE.md      # 翻译指南（单文件，包含中英说明）
├── Utils/               # 工具类
│   ├── Utils.lua
│   ├── Debug.lua
│   └── Localization.lua # 本地化工具
└── docs/                # 开发文档
    ├── DEVELOPMENT.md
    ├── REFACTOR_PLAN.md
    └── BRANCH_GUIDE.md
```

---

## 2. 开发设计要求

### 2.1 模块化设计

- **要求**：所有功能必须模块化，每个模块职责单一、边界清晰
- **实现**：
  - 使用命名空间隔离（`BuildEnv`函数）
  - 模块间通过明确的接口通信
  - 避免循环依赖

### 2.2 数据存储设计（代号系统）

- **要求**：单一数据源 + 代号系统，分离内置配置与可变数据
- **实现**：
  - 内置地图/空投配置唯一来源：`Data.MAP_CONFIG.current_maps`（在 `Data/MapConfig.lua`）
  - 刷新间隔默认 1100 秒（`Data.DEFAULT_REFRESH_INTERVAL`）可被配置覆盖
  - 可变数据存储在 SavedVariables（`CRATETRACKERZK_DB.mapData`），键为代号
  - 所有角色共享数据（通用存储），无旧版本兼容逻辑（全新版本优先）
  - **代号系统优势**：
    - 完全语言无关，添加新语言无需改代码
    - 存储键使用代号，跨语言数据共享
    - 可任意调整地图顺序，不影响已保存的数据
    - 名称完全由本地化文件管理

### 2.3 错误处理

- **要求**：所有API调用必须进行空值检查
- **实现**：
  - 使用 `if Module then ... end` 模式
  - 提供降级方案
  - 错误信息通过 `Utils.PrintError` 输出

### 2.4 性能优化

- **要求**：避免不必要的计算和API调用
- **实现**：
  - 无效区域时跳过检测
  - 调试信息频率限制（30秒一次）
  - 定时器在无效区域时不调用检测函数

### 2.5 兼容性

- **要求**：支持多个WoW版本
- **实现**：
  - API调用使用安全降级（优先新API，失败时使用旧API）
  - 检查API是否存在再调用

---

## 3. 运行逻辑要求

### 3.1 三个独立检测模块

#### 3.1.1 地图有效性检测（总开关）

**设计要求**：
- 作为所有检测模块的总开关
- 事件驱动，区域变化时检测
- 检查副本/战场/室内、主城、有效地图列表

**实现要求**：
- 函数：`CheckAndUpdateAreaValid()`
- 触发事件：`ZONE_CHANGED`、`ZONE_CHANGED_NEW_AREA`
- 返回值：`true`（有效）/ `false`（无效）
- 状态提示：仅在调试模式下输出

**检查逻辑**：
1. 检查是否在副本/战场/室内 → 无效
2. 检查是否在主城（多恩诺嘉尔） → 无效
3. 检查是否在有效地图列表中（支持父地图匹配） → 有效/无效

#### 3.1.2 位面检测

**设计要求**：
- 独立运行，持续监听
- 每10秒检测一次
- 使用总开关检查有效区域

**实现要求**：
- 函数：`UpdatePhaseInfo()`
- 定时检测：每10秒（`OnUpdate`）
- 总开关：`CheckAndUpdateAreaValid()`
- 功能：获取当前地图位面ID（通过NPC）
- 特性：子区域跳过位面检测

#### 3.1.3 空投检测

**设计要求**：
- 独立运行，持续监听
  - 检测方式：地图图标（Vignette检测，定时检测）
- 使用总开关检查有效区域

**实现要求**：
- 地图图标检测（Vignette）：
  - 定时检测：每2秒一次
  - 总开关：定时器层面检查（`Area.detectionPaused`）
  - 连续检测确认（至少2秒）
  - 使用 `C_VignetteInfo` API 检测地图上的 Vignette
- 通过空投箱子名称匹配（本地化配置）来识别空投事件（仅地图图标检测，已移除 NPC 语音检测）
- 代码位置：`Modules/Timer.lua`

### 3.2 时间更新机制

#### 3.2.1 地图图标触发（Vignette检测）

**流程**：
1. 定时检测（每2秒一次）
2. 检查地图有效性（总开关）
3. 检查地图匹配（当前地图或父地图）
4. 检测Vignette图标名称（通过本地化配置匹配）
5. 连续检测确认（至少2秒）
6. 首次确认有效时，更新刷新时间

**要求**：
- 防止误报（连续检测确认，至少2秒）
- 使用首次检测到的时间作为刷新时间（更准确）
- 设置空投进行中标记
- 发送自动通知

**检测方式**：
- 使用 `C_VignetteInfo.GetVignettes()` 获取所有Vignette
- 遍历每个Vignette，检查名称是否匹配配置的空投箱子名称
- 空投箱子名称通过本地化配置（`L.AirdropCrateNames["AIRDROP_CRATE_001"]`）：
  - 中文：`"战争物资箱"`
  - 英文：`"War Supply Crate"`
  - 使用代号系统（`AIRDROP_CRATE_001`），完全语言无关

#### 3.2.2 手动更新

**方式**：
- 刷新按钮：`TimerManager:StartTimer(mapId, REFRESH_BUTTON)`
- 手动输入：`TimerManager:StartTimer(mapId, MANUAL_INPUT, timestamp)`

### 3.3 数据持久化

**要求**：
- 所有数据自动保存到SavedVariables
- 数据更新时立即保存
- 支持数据迁移（旧版本兼容）

**实现**：
- UI数据：`CRATETRACKERZK_UI_DB`
- 通用数据：`CRATETRACKERZK_DB`

### 3.4 位面检测机制

**设计要求**：
- 只有在有效区域（非主城、非副本、在地图列表中）才进行位面检测
- 只有当当前地图名称与地图列表完全匹配时才更新位面ID，确保数据有效性
- 如果只匹配父地图（当前地图不在列表中），则不更新位面ID（因为数据无效）

**实现要求**：
- 函数：`Phase:UpdatePhaseInfo()`
- 总开关：`Area.detectionPaused`（区域有效性检测）
- 主城检查：在主城时直接返回，不检测位面
- 地图匹配：优先检查当前地图名称是否直接匹配列表中的地图
- 代码位置：`Modules/Phase.lua:45-132`

### 3.5 位面ID颜色显示逻辑

**要求**：
1. **白色**：未获取位面ID 或 已过刷新时间（`time() >= mapData.nextRefresh`）
2. **绿色**：
   - 检测到空投进行中（无论位面是否变化）
   - 首次获取位面ID（还没有刷新记录，`lastRefreshInstance` 为 `nil`）
   - 位面无变化（当前位面ID与上次刷新时相同）
3. **红色**：空投刷新前（`time() < mapData.nextRefresh`），且上次刷新时有位面ID记录（`lastRefreshInstance` 存在），且当前位面ID与上次空投刷新时的位面ID不同

**实现**：
- 位置：`UI/MainPanel.lua:403-428`
- 使用 `lastRefreshInstance` 字段（在 `Data:SetLastRefresh()` 中设置）进行比较
- **重要**：首次获取位面ID时，`lastRefreshInstance` 为 `nil`，应显示绿色而不是红色
- 重新加载插件时自动初始化`lastInstance`，避免误显示红色

---

## 4. 核心架构设计

### 4.1 模块依赖关系

```
Main.lua
├── Utils.lua
├── Data.lua
├── Debug.lua
├── Notification.lua (依赖 Data)
├── Commands.lua (依赖 Debug, Notification, Data)
├── TimerManager.lua (依赖 Data, Notification)
└── MainPanel.lua (依赖 Data, Notification, Debug)
```

### 4.2 事件驱动架构

**主要事件**：
- `PLAYER_LOGIN`：插件初始化
- `ZONE_CHANGED` / `ZONE_CHANGED_NEW_AREA`：区域变化（触发地图有效性检测）
- `PLAYER_TARGET_CHANGED`：目标变化（触发位面检测）

### 4.3 定时检测架构

**定时器**：
1. **位面检测定时器**：每10秒检测一次
2. **地图图标检测定时器**：每2秒检测一次（仅在有效区域调用）

**优化**：
- 无效区域时，定时器不调用检测函数
- 避免不必要的执行和调试信息输出

---

## 5. UI设计文档

### 5.1 主面板布局设计

#### 5.1.1 框架尺寸
- **主框架宽度**：根据语言动态设置
  - 中文：550 像素
  - 英文：590 像素（地图名称较长，需要更多空间）
- **主框架高度**：320 像素
- **框架模板**：`BasicFrameTemplateWithInset`

#### 5.1.2 表格布局系统

**设计原则**：
- 表格在主框架中居中显示
- 上下左右边距均匀对称
- 列宽统一（操作列除外）
- 列间距统一

**表格尺寸计算**：
```lua
-- 列配置（根据语言动态设置）
COL_WIDTH = 90              -- 第2-4列统一宽度
MAP_COL_WIDTH = 中文80px / 英文105px  -- 地图列（第1列）动态宽度
OPERATION_COL_WIDTH = 150  -- 操作列（第5列）特殊宽度
COL_SPACING = 5            -- 列间距
COL_COUNT = 5              -- 列数

-- 表格总宽度计算（中文）
表格宽度 = 80 + 3 × 90 + 150 + 4 × 5 = 500 像素
左右边距 = (550 - 500) / 2 = 25 像素（对称）

-- 表格总宽度计算（英文）
表格宽度 = 105 + 3 × 90 + 150 + 4 × 5 = 525 像素
左右边距 = (590 - 525) / 2 = 32.5 像素（对称）

-- 其他尺寸
顶部边距 = 40 像素（标题栏高度）
底部边距 = 40 像素（对称）
表格高度 = 320 - 40 - 40 = 240 像素
```

**列定义**：
1. **地图列**：
   - 宽度：中文 80px，英文 105px（动态设置）
   - 显示：地图名称（左对齐，超出部分隐藏）
   - 文本处理：`SetNonSpaceWrap(false)`, `SetWidth()`, `SetMaxLines(1)`
2. **位面列**：
   - 宽度：90px
   - 显示：位面ID（颜色编码：绿色=正常，红色=变化，白色=未获取）
   - 无数据时显示："N/A"
3. **上次刷新列**：
   - 宽度：90px
   - 显示：上次刷新时间（可点击编辑，蓝色文字）
   - 无数据时显示："--:--"
4. **下次刷新列**：
   - 宽度：90px
   - 显示：倒计时（颜色编码：绿色>15分钟，橙色5-15分钟，红色<5分钟）
   - 无数据时显示："--:--"
5. **操作列**：
   - 宽度：150px
   - 包含："刷新"和"通知"两个按钮
   - 按钮宽度：中文 65px，英文 75px（动态设置）

#### 5.1.3 表格结构

**层级结构**：
```
tableContainer (表格容器)
├── tableHeader (表头容器)
│   └── headerCells[] (表头单元格数组)
└── tableContent (内容区域容器)
    └── tableRows[] (数据行数组)
        └── columns[] (行单元格数组)
            └── refreshBtn, notifyBtn (操作按钮)
```

**单元格创建规则**：
- 所有单元格使用统一的 `CreateTableCell` 函数创建
- 表头和内容行使用相同的列偏移量计算
- 确保列完全对齐

**列偏移量计算**：
```lua
-- 第1列：0
-- 第2列：90 + 5 = 95
-- 第3列：180 + 10 = 190
-- 第4列：270 + 15 = 285
-- 第5列：360 + 20 = 380
```

#### 5.1.4 按钮布局

**操作列按钮**：
- 按钮宽度：根据语言动态设置
  - 中文：65px
  - 英文：75px（文字较长）
- 按钮高度：26px
- 按钮间距：70px
- 定位方式：相对于操作列单元格中心点，左右对称分布
- 字体大小：15px（从本地化配置读取 `L["UIFontSize"]`）

#### 5.1.5 表格功能

**排序功能**：
- 前4列支持排序（地图、位面、上次刷新、下次刷新）
- 点击表头切换升序/降序
- 排序箭头显示当前排序状态

**交互功能**：
- 第3列（上次刷新）可点击编辑时间
- 操作列包含"刷新"和"通知"按钮
- 表格行背景交替显示（奇偶行不同透明度）

#### 5.1.6 布局配置位置

所有布局配置集中在 `UI/MainPanel.lua` 的 `Layout` 表中：
- 框架尺寸
- 列宽和列间距
- 按钮尺寸
- 边距计算

**调整布局**：
只需修改 `Layout` 表中的配置值，系统会自动计算：
- 表格总宽度
- 列偏移量
- 居中边距

### 5.2 浮动按钮设计

**位置**：
- 可拖动，位置自动保存
- 默认位置：屏幕左上角偏移 (50, -50)
- 使用智能锚点系统，自动选择最合适的锚点

**显示逻辑**：
- 主窗口显示时，浮动按钮隐藏
- 主窗口隐藏时，浮动按钮显示

**样式**：
- 尺寸：140 × 32 像素
- 背景颜色：青绿色 (0, 0.5, 0.5)
- 高亮颜色：浅青色 (0.2, 0.7, 0.7)

### 5.3 标题栏设计

**设计原则**：
- 使用原生 `BasicFrameTemplateWithInset` 模板，保持代码简洁
- 原生关闭按钮保留，确保窗口可正常关闭
- 自定义三个点菜单按钮，提供帮助、关于、设置功能

**三个点菜单按钮**：
- **位置**：位于原生关闭按钮左侧，与关闭按钮并列
- **样式**：三个横向排列的点，无边框，与关闭按钮大小一致
- **交互**：
  - 悬停时点变亮（白色）
  - 按下时点变暗（深灰色）
  - 点击显示下拉菜单
- **下拉菜单**：
  - 包含"帮助"、"关于"、"设置"三个选项
  - 点击外部区域自动关闭
  - 菜单项使用本地化配置

**窗口拖动**：
- 使用原生 `TitleRegion` 实现拖动
- 拖动结束后自动保存位置到 `CRATETRACKERZK_UI_DB.position`

### 5.4 信息界面设计

**设计原则**：
- 帮助和关于内容使用代码内硬编码英文文案（`UI/Info.lua`），不再依赖本地化键
- 界面简洁，无标题显示，滚动框展示文本

**界面结构**：
- **容器框架**：覆盖主框架内容区域
- **滚动框架**：使用 `UIPanelScrollFrameTemplate`
- **内容文本**：直接设置硬编码文本
- **返回按钮**：底部居中，点击返回主表格

### 5.5 UI模块文件

- `UI/MainPanel.lua`：主面板实现
  - 主框架创建（使用 `BasicFrameTemplateWithInset`）
  - 表格创建和更新
  - 标题栏三个点菜单按钮
  - 排序功能
- `UI/FloatingButton.lua`：浮动按钮实现
  - 可拖动浮动按钮
  - 智能锚点系统
  - 位置自动保存
- `UI/Info.lua`：信息界面（简介、公告）
  - 帮助界面显示
  - 关于界面显示
  - 颜色代码移除辅助函数
- `UI/Frame.xml`：UI框架定义（当前为空，保留用于扩展）

---

## 6. 模块接口文档

### 5.1 Debug 模块

#### Initialize()
初始化调试模块

#### SetEnabled(enabled)
设置调试状态

#### IsEnabled()
获取调试状态

#### Print(msg, ...)
输出调试信息（立即输出，文案硬编码中文，不走本地化）

#### PrintLimited(messageKey, msg, ...)
输出调试信息（限制频率，30秒一次）

### 5.2 Notification 模块

#### Initialize()
初始化通知模块

#### NotifyAirdropDetected(mapName, detectionSource)
发送空投事件通知

#### NotifyMapRefresh(mapData)
发送地图刷新时间通知

#### SetTeamNotificationEnabled(enabled)
设置团队通知状态

#### IsTeamNotificationEnabled()
获取团队通知状态

### 5.3 Commands 模块

#### Initialize()
初始化命令模块

#### HandleCommand(msg)
处理命令消息

**支持的命令（面向开发/用户）**：
- `debug on/off` - 调试模式开关（提示为硬编码中文，面向开发者）
- `clear/reset` - 清除数据并全量重置
- `team on/off` - 团队通知开关（无状态查询命令）
- `help` - 显示帮助信息（内容为硬编码英文 Help 文本）

### 5.4 Area 模块

#### CheckAndUpdateAreaValid()
检查并更新区域有效性（总开关）
- 检查是否在副本/战场/室内
- 检查是否在主城（多恩诺嘉尔）
- 检查是否在有效地图列表中
- 更新 `detectionPaused` 状态
- 触发检测功能的暂停/恢复

#### GetCurrentMapId()
获取当前地图ID
- 返回：当前地图ID，如果无法获取则返回 `nil`

#### IsValidArea()
检查当前区域是否有效
- 返回：`true` 如果区域有效，否则 `false`

**状态变量**：
- `Area.detectionPaused`：检测暂停状态标志（`true` 表示暂停）

### 5.5 Phase 模块

#### UpdatePhaseInfo()
更新位面信息
- 检查区域是否有效（`Area.detectionPaused`）
- 获取当前地图ID和名称
- 匹配地图列表（只匹配当前地图名称，不匹配父地图）
- 从NPC获取位面ID（通过 `GetLayerFromNPC()`）
- 更新地图数据中的位面ID

#### GetLayerFromNPC()
从NPC获取位面ID
- 尝试从 `mouseover` 或 `target` 获取NPC的GUID
- 从GUID中提取位面ID（格式：serverID-layerUID）
- 返回：位面ID字符串，如果无法获取则返回 `nil`

**状态变量**：
- `Phase.anyInstanceIDAcquired`：是否已获取任何位面ID
- `Phase.lastReportedInstanceID`：最后报告的位面ID（用于减少重复输出）

### 5.6 TimerManager 模块

#### Initialize()
初始化计时管理器

#### StartTimer(mapId, source, timestamp)
启动指定地图的计时
- 参数：
  - `mapId` - 地图ID（数组索引）
  - `source` - 检测来源（`MANUAL_INPUT`、`REFRESH_BUTTON`、`MAP_ICON`）
  - `timestamp` - 时间戳（可选，用于手动输入）

#### StartCurrentMapTimer(source)
启动当前地图计时
- 参数：`source` - 检测来源

#### DetectMapIcons()
检测地图图标（Vignette检测）
- 每2秒调用一次
- 检查区域有效性（`Area.detectionPaused`）
- 使用 `C_VignetteInfo.GetVignettes()` 获取所有Vignette
- 通过空投箱子名称匹配识别空投事件
- 连续检测确认（至少2秒）后更新刷新时间

#### StartMapIconDetection(interval)
开始地图图标检测
- 参数：`interval` - 检测间隔（秒，默认2秒）

#### StopMapIconDetection()
停止地图图标检测

**检测源类型**：
```lua
TimerManager.detectionSources = {
    MANUAL_INPUT = "manual_input",
    REFRESH_BUTTON = "refresh_button",
    MAP_ICON = "map_icon"
}
```

**注意**：已移除 `NPC_SPEECH` 检测源，现在只使用地图图标（Vignette）检测。

### 5.7 Data 模块

#### Initialize()
初始化数据模块

#### GetMap(mapId)
获取地图数据

#### GetAllMaps()
获取所有地图数据

#### SetLastRefresh(mapId, timestamp)
设置最后刷新时间

#### UpdateNextRefresh(mapId, mapData)
更新下次刷新时间
- 使用独立的 `CalculateNextRefreshTime` 函数计算
- 支持过去时间和未来时间的智能处理

#### CalculateRemainingTime(nextRefresh)
计算剩余时间

#### FormatTime(seconds, showOnlyMinutes)
格式化时间

#### FormatDateTime(timestamp)
格式化日期时间

#### ClearAllData()
清除所有时间和位面数据

### 5.8 Utils 模块

#### Print(msg)
打印消息

#### PrintError(msg)
打印错误消息

#### Debug(msg, ...)
调试输出

#### SetDebugEnabled(enabled)
设置调试状态

#### ParseTimeInput(input)
解析时间输入字符串，支持 HH:MM:SS 和 HHMMSS 格式
- 使用辅助函数：`ParseTimeFormatColon`、`ParseTimeFormatCompact`、`ValidateTimeRange`

#### GetTimestampFromTime(hh, mm, ss)
将时间组件转换为时间戳
- 使用当前日期创建时间戳
- 直接返回，不做任何调整（无论是未来时间还是过去时间）

### 5.9 Localization 模块

#### Initialize()
初始化本地化模块
- 设置当前语言环境
- 如果调试模式开启，自动启用缺失翻译日志
- 延迟验证翻译完整性并报告初始化状态

#### GetMapName(mapCode)
获取地图名称（支持三层回退）
- 参数：`mapCode` - 地图代号（如 `"MAP_001"`）
- 返回：本地化的地图名称
- 回退机制：当前语言 → 英文 → 格式化代号（如 `"MAP_001"`）
- 如果翻译缺失，会记录到缺失翻译日志

#### GetAirdropCrateName()
获取空投箱子名称（支持三层回退）
- 返回：本地化的空投箱子名称
- 回退机制：当前语言 → 英文 → 格式化代号（如 `"AIRDROP_CRATE_001"`）
- 如果翻译缺失，会记录到缺失翻译日志

#### IsMapNameMatch(mapData, mapName)
检查地图名称是否匹配（支持多语言）
- 参数：
  - `mapData` - 地图数据对象
  - `mapName` - 要匹配的地图名称
- 返回：`true` 如果匹配，否则 `false`
- 支持当前语言和英文的匹配

#### ValidateCompleteness()
验证翻译完整性
- 检查所有地图名称和空投箱子名称的翻译是否完整
- 返回缺失翻译列表
- 缺失的翻译会记录到缺失翻译日志

#### LogMissingTranslation(key, category, critical)
记录缺失的翻译
- 参数：
  - `key` - 翻译键（如 `"MAP_001"`）
  - `category` - 分类（如 `"MapNames"`、`"AirdropCrateNames"`）
  - `critical` - 是否为关键翻译（布尔值）
- 仅在 `missingLogEnabled` 为 `true` 时记录

#### ReportInitializationStatus()
报告初始化状态
- 显示当前使用的语言
- 显示是否使用了回退语言
- 显示缺失的关键翻译数量

#### EnableMissingLog(enabled)
启用/禁用缺失翻译日志
- 参数：`enabled` - 是否启用（布尔值）

#### GetMissingTranslations()
获取所有缺失的翻译
- 返回：缺失翻译列表

#### ClearMissingLog()
清除缺失翻译日志

### 5.10 Info 模块

#### Initialize()
初始化信息模块

#### ShowAnnouncement()
显示关于界面
- 如果当前已显示关于界面，则关闭它（切换功能）
- 隐藏主表格，显示关于内容
- 内容为硬编码英文文本（`UI/Info.lua`），不再依赖本地化

#### ShowIntroduction()
显示帮助界面
- 如果当前已显示帮助界面，则关闭它（切换功能）
- 隐藏主表格，显示帮助内容
- 内容为硬编码英文文本（`UI/Info.lua`）

#### HideAll()
隐藏所有信息界面，显示主表格

**辅助函数**：
- （已移除）原有颜色码移除函数不再需要

---

## 7. 数据存储设计

### 6.1 UI数据库 (CRATETRACKERZK_UI_DB)

```lua
CRATETRACKERZK_UI_DB = {
    version = 1,
    position = { point = "CENTER", x = 0, y = 0 },
    minimapButton = {
        hide = false,
        position = { point = "TOPLEFT", x = 50, y = -50 }
    },
    debugEnabled = false,
    teamNotificationEnabled = false
}
```

**初始化健壮性**：
- `Core/Core.lua:OnLogin()` 中确保 `CRATETRACKERZK_UI_DB` 存在
- `UI/FloatingButton.lua:CreateFloatingButton()` 中确保 `minimapButton` 和 `position` 结构存在
- 防止全新安装时访问 `nil` 值导致错误
- 代码位置：
  - `Core/Core.lua:16-18`
  - `UI/FloatingButton.lua:16-27`

### 6.2 通用数据库 (CRATETRACKERZK_DB) - 代号系统

**数据结构**：
```lua
CRATETRACKERZK_DB = {
    version = 1,
    mapData = {
        -- 使用代号（MAP_001等）作为键，完全语言无关
        -- 存储键名使用代号，确保跨语言数据共享和向后兼容
        ["MAP_001"] = {
            instance = "3043-28226",        -- 位面ID
            lastInstance = "3043-28225",     -- 上一次位面ID
            lastRefreshInstance = "3043-28226", -- 上次刷新时的位面ID
            lastRefresh = 1234567890,        -- 上次刷新时间戳
            createTime = 1234567890          -- 创建时间戳
        },
        -- ... 其他地图的可变数据
    }
}
```

**设计原则**：
- 内置地图列表存储在代码中（`Data.DEFAULT_MAPS`），使用代号系统
- 可变数据存储在SavedVariables（`mapData`），使用代号作为键
- 所有角色共享数据
- **代号系统优势**：
  - 完全语言无关，添加新语言无需修改代码
  - 数据存储使用代号（`MAP_001`等），跨语言数据共享
  - 可以任意调整地图顺序，不影响已保存的数据
  - 地图名称完全通过本地化文件管理（`L.MapNames["MAP_001"]`）

**初始化健壮性**：
- `Data:Initialize()` 中确保 `CRATETRACKERZK_DB` 和 `CRATETRACKERZK_DB.mapData` 存在
- 验证数据结构类型，处理空/损坏数据
- 验证时间戳的有效性（类型、范围）
- 访问 `CRATETRACKERZK_DB.mapData[mapCode]` 前确保表存在（防止全新安装时出错）
- 代码位置：`Data/Data.lua`
- 全新安装时，`savedData` 为空表 `{}`，字段从 `MAP_CONFIG.current_maps` 初始化

### 6.3 内置地图列表（代号系统）

- **唯一数据源**：`Data.MAP_CONFIG.current_maps`（`Data/MapConfig.lua`）
- **刷新间隔**：默认 1100 秒，可在 MapConfig 中按地图覆盖
- **代号系统说明**：
  - **地图ID（id）**：按配置顺序分配（1, 2, 3...）
  - **地图代号（code）**：唯一标识符（`MAP_001` 等），用于存储和本地化
  - **数据存储**：使用代号作为键，调整顺序不影响已保存的数据
  - **多语言支持**：名称在本地化文件中，`Localization:GetMapName()` 负责回退

---

## 8. 关键实现细节

### 7.0 时间计算逻辑优化

**核心函数**：
- `CalculateNextRefreshTime(lastRefresh, interval, currentTime)` - 独立的时间计算函数
- `Data:UpdateNextRefresh(mapId, mapData)` - 更新下次刷新时间
- `Utils.GetTimestampFromTime(hh, mm, ss)` - 时间戳转换函数

**设计原则**：
1. **用户输入时间直接使用**：无论输入过去时间还是未来时间，`lastRefresh` 都直接使用用户输入的时间戳，不做任何调整
2. **下次刷新时间智能计算**：`nextRefresh` 始终是离当前时间最近的下一次刷新时间，无论 `lastRefresh` 是过去还是未来

**核心算法**（`CalculateNextRefreshTime`）：

1. **过去时间处理**（`lastRefresh <= currentTime`）：
   - 计算需要多少个 `interval` 才能超过 `currentTime`
   - `n = ceil((currentTime - lastRefresh) / interval)`
   - `nextRefresh = lastRefresh + n * interval`

2. **未来时间处理**（`lastRefresh > currentTime`）：
   - 往前找，找到离 `currentTime` 最近且大于 `currentTime` 的刷新点
   - 计算需要往前多少个 `interval`：`forwardCount = floor((lastRefresh - currentTime) / interval)`
   - 候选刷新点：`candidateRefresh = lastRefresh - forwardCount * interval`
   - 如果 `candidateRefresh <= currentTime`，再加一个 `interval`
   - 如果 `candidateRefresh > currentTime`，继续往前找更近的点

**计算逻辑示例**：

**示例1：过去时间**
- 当前时间：`14:00:00`
- 用户输入：`12:20:20`（过去时间）
- `lastRefresh = 12:20:20`
- 计算 `nextRefresh`：
  - 12:20:20 + 1100 = 12:38:40（已过去，继续）
  - 12:38:40 + 1100 = 12:57:00（已过去，继续）
  - ... 继续加 1100 秒
  - 直到 14:10:20（未来，停止）
- 结果：`nextRefresh = 14:10:20`，倒计时 = 10分20秒

**示例2：未来时间**
- 当前时间：`08:51:00`
- 用户输入：`12:20:20`（未来时间）
- `lastRefresh = 12:20:20`（直接使用，不做调整）
- 计算 `nextRefresh`：
  - 往前找：12:20:20 - 1100 = 12:02:00（仍 > 08:51，继续）
  - 继续往前找，直到找到离 08:51 最近且 > 08:51 的刷新点
  - 假设找到：`09:05:00`
- 结果：`nextRefresh = 09:05:00`，倒计时 = 14分钟（而不是226分钟）

**代码位置**：
- `CalculateNextRefreshTime`：`Data.lua:141-186`（独立函数）
- `Data:UpdateNextRefresh`：`Data.lua:190-203`
- `Utils.GetTimestampFromTime`：`Utils.lua:115-133`
- `Data:CheckAndUpdateRefreshTimes`：`Data.lua:247-253`

### 7.1 地图有效性检测（总开关）

**函数**：`CheckAndUpdateAreaValid()`

**检查顺序**：
1. 副本/战场/室内 → 无效
2. 无法获取地图ID → 无效
3. 主城（多恩诺嘉尔） → 无效
4. 有效地图列表 → 匹配则有效，不匹配则无效

**使用位置**：
- 位面检测：`Phase:UpdatePhaseInfo()` 开头
- 地图图标检测：定时器层面检查（`Area.detectionPaused`）

### 7.2 地图图标检测（Vignette）

**函数**：`TimerManager:DetectMapIcons()`

**检测方法**：
- 使用 `C_VignetteInfo` API 检测地图上的 Vignette
- 通过图标名称匹配（本地化配置）来识别空投事件
- 代码位置：`Modules/Timer.lua:291-551`

**检测流程**：
1. 获取当前地图ID和名称
2. 匹配地图列表（支持父地图匹配）
3. 使用 `C_VignetteInfo.GetVignettes()` 获取所有Vignette
4. 遍历每个Vignette，检查名称是否匹配配置的图标名称
5. 连续检测确认（至少2秒）后更新刷新时间

**防误报机制**：
- 连续检测确认（至少2秒）
- 使用首次检测到的时间作为刷新时间（更准确）

**空投箱子名称配置**：
- 通过本地化配置（`L.AirdropCrateNames["AIRDROP_CRATE_001"]`）：
  - 中文：`"战争物资箱"`（`Locales/zhCN.lua`）
  - 英文：`"War Supply Crate"`（`Locales/enUS.lua`）
  - 使用代号系统（`AIRDROP_CRATE_001`），完全语言无关

**检测间隔**：
- 定时检测：每2秒一次（`Core/Core.lua:25`）
- 连续确认：至少2秒（`Modules/Timer.lua:514`）

### 7.4 位面ID获取

**方法**：通过NPC获取（鼠标悬停或点击NPC）

**函数**：`GetLayerFromNPC()`

**说明**：
- 无法从玩家自身获取位面信息
- 必须通过鼠标悬停或点击NPC才能获取到位面ID

### 7.5 子区域处理

**要求**：
- 支持子区域的NPC喊话和地图图标检测
- 子区域跳过位面检测

**实现**：
- 地图匹配支持父地图匹配
- 位面检测时检查是否为子区域（`isSubArea`标记）

---

## 9. 版本历史

### v1.0.8-dev（开发版本）

**发布日期**：2024年

#### 功能改进

1. **位面检测前提条件完善**
   - **问题**：位面检测缺少严格的前提条件检查，导致在无效区域或子区域也会检测位面
   - **解决方案**：
     - `UpdatePhaseInfo()` 函数开始时检查 `detectionPaused`，确保区域有效
     - 主城检查：在主城时直接返回，不检测位面
     - 子区域检查：如果当前地图匹配且有父地图在有效列表中，跳过位面检测
     - 初始化延迟：初始化时，即使区域有效，也延迟6秒后再检测位面
     - 区域变化延迟：从无效区域变为有效区域时，延迟6秒后再检测位面
   - **技术实现**：
     - `UpdatePhaseInfo()` 函数开始时检查 `detectionPaused`
     - 主城检查：检查地图名称是否为"多恩诺嘉尔"，如果是则直接返回
     - 子区域判断：检查当前地图是否有父地图，且父地图也在有效地图列表中
     - 初始化：`PLAYER_LOGIN` 事件中，不进行位面检测，只检测区域有效性
     - 区域变化延迟：`ZONE_CHANGED/ZONE_CHANGED_NEW_AREA` 事件中，检测是否从无效变为有效，如果是则延迟6秒
   - **代码位置**：
     - `UpdatePhaseInfo` 定义：Main.lua:685
     - 区域有效性检查：Main.lua:688
     - 主城检查：Main.lua:726
     - 子区域判断：Main.lua:748-771
     - 初始化逻辑：Main.lua:929-931（不进行位面检测）
     - 区域变化延迟：Main.lua:1033-1040

2. **位面检测日志和提示消息修复**
   - **问题**：位面ID更新日志显示错误的旧值，提示消息判断逻辑错误
   - **解决方案**：
     - 在调用 `Data:UpdateMap()` 之前先保存 `oldInstance`
     - 使用 `oldInstance` 显示日志和判断提示消息
   - **技术实现**：
     - 保存旧值：`local oldInstance = targetMapData.instance;`
     - 日志显示：使用 `oldInstance` 显示旧值
     - 提示消息：使用 `oldInstance` 判断是否显示"位面已变更"
   - **代码位置**：
     - 保存旧值：Main.lua:819
     - 日志显示：Main.lua:823
     - 提示消息：Main.lua:826

3. **位面检测定时器重复恢复保护**
   - **问题**：如果 `ResumeAllDetections()` 在6秒延迟期间被多次调用，会创建多个 `C_Timer.After` 定时器
   - **解决方案**：
     - 添加 `phaseTimerResumePending` 标志，防止重复创建延迟定时器
     - 在暂停时清除该标志，确保状态一致
   - **技术实现**：
     - 添加标志：`local phaseTimerResumePending = false;`
     - 恢复时检查：`if phaseTimer and phaseTimerPaused and not phaseTimerResumePending then`
     - 暂停时清除：`phaseTimerResumePending = false;`
   - **代码位置**：
     - 标志定义：Main.lua:490
     - 恢复检查：Main.lua:545
     - 暂停清除：Main.lua:506

#### 技术细节

**位面检测前提条件**：
1. 区域有效（`detectionPaused == false`）
2. 不是主城（地图名称不是"多恩诺嘉尔"）
3. 不是子区域（当前地图匹配且没有父地图在有效列表中，或父地图不在有效列表中）

**位面检测调用时机**：
- 初始化时：不调用位面检测，只检测区域有效性
- 区域变化时：从无效到有效延迟6秒，有效区域内切换立即调用
- 选择目标时：立即调用（有 `detectionPaused` 检查），用于从NPC获取位面ID
- 鼠标悬停时：立即调用（有 `detectionPaused` 检查），用于从NPC获取位面ID
- 定时器：每10秒调用一次（有 `detectionPaused` 和 `phaseTimerPaused` 检查）

**位面检测延迟机制**：
- 初始化：不进行位面检测，只检测区域有效性
- 区域变化延迟：从无效区域变为有效区域时，延迟6秒后调用 `UpdatePhaseInfo()`
- 定时器延迟：`ResumeAllDetections()` 中，延迟6秒后启动位面检测定时器

**位面ID获取机制**：
- 位面ID无法从玩家自身获取，只能从NPC的GUID中提取
- `GetLayerFromNPC()` 函数尝试从 `mouseover` 或 `target` 获取NPC的GUID
- 从GUID中提取位面ID（格式：serverID-layerUID）
- 选择目标和鼠标悬停事件用于提供获取位面ID的机会，无需等待定时器

### v1.0.7-dev（开发版本）

**发布日期**：2024年

#### 功能改进

1. **区域检测优化 - 检测功能动态暂停/恢复**
   - **问题**：在无效区域（如主城）时，位面检测和空投检测定时器仍在运行，只是跳过检测，不符合"彻底暂停"的要求
   - **解决方案**：
     - 在 `CheckAndUpdateAreaValid()` 函数中添加区域状态变化检测
     - 区域从有效变为无效：自动暂停所有检测功能（位面检测、地图图标检测、NPC喊话检测）
     - 区域从无效变为有效：自动恢复所有检测功能
   - **技术实现**：
     - 位面检测定时器：通过 `phaseTimer:SetScript("OnUpdate", nil)` 暂停，重新设置脚本恢复
     - 地图图标检测定时器：使用 `TimerManager:StopMapIconDetection()` 暂停，`TimerManager:StartMapIconDetection(3)` 恢复
     - NPC喊话检测：通过 `eventFrame:UnregisterEvent("CHAT_MSG_MONSTER_SAY")` 暂停，`eventFrame:RegisterEvent("CHAT_MSG_MONSTER_SAY")` 恢复
   - **重要说明**：
     - 时间计时功能（UI更新定时器、时间计算功能）不受影响，持续运行
     - 即使玩家在无效区域，其他有效区域的空投仍在进行，需要继续计算和显示时间

2. **区域有效性检测优化 - 仅在区域变化时检测**
   - **问题**：区域有效性检测在多个地方重复调用，造成不必要的性能开销
   - **解决方案**：
     - 区域有效性检测只在区域变化时检测一次（`ZONE_CHANGED` / `ZONE_CHANGED_NEW_AREA` 事件）
     - 初始化时检测一次（`PLAYER_LOGIN` 事件）
     - 区域无效后不再重复检测，直到区域变化事件触发
   - **技术实现**：
     - 移除 `UpdatePhaseInfo()` 中的 `CheckAndUpdateAreaValid()` 调用（因为区域无效时定时器已暂停，函数不会被调用）
     - 移除 `DetectMapIcons()` 中的 `CheckAndUpdateAreaValid()` 调用（因为区域无效时定时器已暂停，函数不会被调用）
     - 其他事件（`PLAYER_TARGET_CHANGED`、鼠标悬停、NPC喊话）中检查 `detectionPaused` 标志，无效时直接返回
   - **工作流程**：
     1. 区域变化 → 检测一次有效性
     2. 区域有效 → 恢复检测功能，执行一次检测
     3. 区域无效 → 暂停检测功能，不再检测
     4. 区域无变化 → 不检测，保持当前状态（有效则运行，无效则暂停）

#### 技术细节

**核心函数**：
- `PauseAllDetections()`：暂停所有检测功能
  - 检查 `detectionPaused` 标志，避免重复暂停
  - 暂停位面检测定时器（设置 `OnUpdate` 脚本为 `nil`）
  - 停止地图图标检测定时器（调用 `TimerManager:StopMapIconDetection()`）
  - 取消注册NPC喊话事件（调用 `eventFrame:UnregisterEvent("CHAT_MSG_MONSTER_SAY")`）

- `ResumeAllDetections()`：恢复所有检测功能
  - 检查 `detectionPaused` 标志，避免重复恢复
  - 恢复位面检测定时器（重新设置 `OnUpdate` 脚本）
  - 启动地图图标检测定时器（调用 `TimerManager:StartMapIconDetection(3)`）
  - 重新注册NPC喊话事件（调用 `eventFrame:RegisterEvent("CHAT_MSG_MONSTER_SAY")`）

**状态管理**：
- `detectionPaused`：全局检测暂停状态标志
- `phaseTimerPaused`：位面检测定时器暂停状态标志
- `npcSpeechEventRegistered`：NPC喊话事件注册状态标志
- `lastAreaValidState`：上次区域有效性状态（用于检测状态变化）

**触发机制**：
- 在 `CheckAndUpdateAreaValid()` 函数中检测区域状态变化
- 当 `lastAreaValidState` 从 `true` 变为 `false` 时，调用 `PauseAllDetections()`
- 当 `lastAreaValidState` 从 `false` 变为 `true` 时，调用 `ResumeAllDetections()`
- 确保只在状态真正变化时触发，避免重复操作

**区域有效性检测调用位置**：
- `ZONE_CHANGED` / `ZONE_CHANGED_NEW_AREA` 事件：区域变化时检测一次
- `PLAYER_LOGIN` 事件：初始化时检测一次
- 其他位置：不再调用，避免重复检测

**移除重复检测的位置**：
- `UpdatePhaseInfo()`：已移除 `CheckAndUpdateAreaValid()` 调用（区域无效时定时器已暂停，函数不会被调用）
- `DetectMapIcons()`：已移除 `CheckAndUpdateAreaValid()` 调用（区域无效时定时器已暂停，函数不会被调用）

**其他事件中的检查**：
- `PLAYER_TARGET_CHANGED`：检查 `detectionPaused`，无效时不调用 `UpdatePhaseInfo()`
- 鼠标悬停事件：检查 `detectionPaused`，无效时不调用 `UpdatePhaseInfo()`
- NPC喊话事件：检查 `detectionPaused`，无效时直接返回（事件已被取消注册，但为安全起见仍检查）

**不受影响的功能**：
- UI更新定时器（`MainPanel.updateTimer`）：持续运行，每秒更新一次表格
- 时间计算功能（`Data:CheckAndUpdateRefreshTimes()`）：持续运行，处理循环刷新
- 这些功能需要持续运行，因为即使玩家在无效区域，其他有效区域的空投仍在进行

**代码位置**：
- 函数定义：`Main.lua` 第 492-551 行
- 状态变量：`Main.lua` 第 487-489 行
- 调用位置：`Main.lua` 第 567、579、611、653、662 行（`CheckAndUpdateAreaValid()` 函数内）

### v1.0.6

**发布日期**：2024年

#### 功能改进

1. **分支管理策略**
   - 实现 `main`（正式版）和 `dev`（开发版）分支管理
   - GitHub Actions 仅从 `main` 分支构建和发布正式版
   - 版本号规范：正式版使用 `x.y.z`，开发版使用 `x.y.z-dev`

2. **文档优化**
   - 移除用户文档中的调试命令说明（调试功能仅供开发者使用）
   - 简化用户文档，仅保留使用命令和使用方法

### v1.0.5

**核心架构重构**：
- 实现三个独立的检测模块（地图有效性、位面检测、空投检测）
- 地图有效性检测作为总开关，所有检测模块统一使用
- 地图有效性检测改为事件驱动，移除定时检测

**功能优化**：
- 调整刷新间隔：从18分钟（1080秒）改为18分20秒（1100秒）
- 修复NPC喊话误报：精确匹配空投关键词
- 修复地图图标检测误报：连续检测确认机制（至少2秒）
- 修复重复时间更新：检查NPC喊话更新时间（5秒内）
- 主城检测功能：检测主城"多恩诺嘉尔"并标记为无效区域

**性能优化**：
- 定时器在无效区域时不调用检测函数
- 调试信息频率限制（30秒一次）
- 移除不必要的调试输出

**用户体验优化**：
- 提示信息优化：更温和友好的表达方式
- 位面ID颜色显示优化：空投进行中时优先显示绿色
- 重新加载插件时自动初始化`lastInstance`，避免误显示红色

### v1.0.4

- 优化数据存储：改为通用存储（SavedVariables），所有角色共享数据
- 优化团队通知：自动通知仅在团队中发送
- 优化位面ID显示：改进颜色显示逻辑
- 优化子区域检测：支持子区域的NPC喊话和地图图标检测，但跳过位面检测

### v1.0.3

- 修复API兼容性问题（GetAreaPOIInfo）
- 重构数据存储机制（分离内置地图列表和可变数据）
- 完善通知系统
- 优化检测逻辑（移除刷新周期概念）

### v1.0.2

- 优化错误处理和日志输出
- 新增地图图标检测功能

### v1.0.1

- 添加检测源管理功能

### v1.0.0

- 初始版本，实现基本功能

---

## 10. 开发注意事项

### 9.1 模块加载顺序

确保在使用模块前，模块已通过 `Initialize()` 初始化。

### 9.2 空值检查

使用模块前应检查模块是否存在：
```lua
if Module then
    Module:SomeFunction()
end
```

**数据初始化检查**：
- 访问 `CRATETRACKERZK_DB.mapData[mapName]` 前确保表存在
- 访问 `CRATETRACKERZK_UI_DB.minimapButton.position` 前确保结构存在
- 防止全新安装时访问 `nil` 值导致错误

### 9.3 数据持久化

所有设置会自动保存到数据库，无需手动保存。

### 9.4 线程安全

所有API都是线程安全的，可在任何事件中调用。

### 9.5 API兼容性

TimerManager中的Vignette检测使用了安全的API调用，兼容不同版本的魔兽世界客户端。

### 9.6 检测逻辑

地图图标检测（Vignette）持续进行，每2秒检测一次，无刷新周期概念。

### 9.7 多语言支持（代号系统）

插件支持多种语言：
- **简体中文（zhCN）**：已完整配置，可直接使用
- **繁体中文（zhTW）**：已完整配置，可直接使用
- **英文（enUS）**：已完整配置，作为默认回退语言
- **俄语（ruRU）**：已完整配置，可直接使用

**本地化系统架构**：
- `Locales/Locales.lua`：本地化管理核心，处理语言注册和选择
- `Utils/Localization.lua`：本地化工具模块，提供翻译获取和验证功能
- 各语言文件（`zhCN.lua`、`zhTW.lua`、`enUS.lua`、`ruRU.lua`）：包含翻译数据

**代号系统（Code-based System）**：
- **地图名称**：使用代号（`MAP_001`等）作为键，名称存储在 `L.MapNames["MAP_001"]`
- **空投箱子名称**：使用代号（`AIRDROP_CRATE_001`）作为键，名称存储在 `L.AirdropCrateNames["AIRDROP_CRATE_001"]`
- **优势**：
  - 完全语言无关，添加新语言无需修改代码
  - 数据存储使用代号，跨语言数据共享
  - 可以任意调整地图顺序，不影响已保存的数据

**本地化文件结构**：
```lua
-- Locales/zhCN.lua
localeData.MapNames = {
    ["MAP_001"] = "多恩岛",
    ["MAP_002"] = "卡雷什",
    -- ...
};

localeData.AirdropCrateNames = {
    ["AIRDROP_CRATE_001"] = "战争物资箱",
};
```

**翻译获取机制**：
- `Localization:GetMapName(mapCode)`：获取地图名称，支持三层回退（当前语言 → 英文 → 格式化代号）
- `Localization:GetAirdropCrateName()`：获取空投箱子名称，支持三层回退
- `Localization:IsMapNameMatch(mapData, mapName)`：支持多语言地图名称匹配

**完整性验证**：
- `Localization:ValidateCompleteness()`：验证关键翻译（地图名称、空投箱子名称）是否完整
- `Localization:LogMissingTranslation()`：记录缺失的翻译
- `Localization:ReportInitializationStatus()`：报告初始化状态和缺失翻译

**数据存储兼容性**：
- 存储键名使用代号（`MAP_001`等），完全语言无关
- 不同语言的用户数据可以共享（都使用代号作为键）
- 显示时根据用户语言自动切换
- 旧数据完全兼容，无需迁移

**翻译指南**：
- `Locales/TRANSLATION_GUIDE.md`：单文件指南（含中英说明），提供翻译步骤与注意事项

**硬编码文本说明（当前版本）**：
- 用户可见文本仍通过本地化；调试输出改为中文硬编码（开发者向）
- 帮助/关于界面文案为英文硬编码（`UI/Info.lua`），不走本地化
- 其他回退文本已移除，保持代号回退

---

## 11. 测试要求

### 10.1 功能测试

- [ ] 地图有效性检测（总开关）
- [ ] 位面检测（每10秒）
- [ ] 地图图标检测（Vignette，每2秒）
- [ ] 时间更新机制
- [ ] 数据持久化
- [ ] UI显示和交互
- [ ] 命令功能
- [ ] 多语言支持（中文/英文）

### 10.2 边界测试

- [ ] 副本/战场/室内（无效区域）
- [ ] 主城（无效区域）
- [ ] 不在有效地图列表（无效区域）
- [ ] 子区域（跳过位面检测）
- [ ] 重新加载插件（数据初始化）

### 10.3 性能测试

- [ ] 无效区域时不调用检测函数
- [ ] 调试信息频率限制
- [ ] UI更新频率（每秒一次）

---

## 12. 扩展建议

未来可以考虑添加以下功能：

1. **配置界面**：提供图形化配置选项，允许自定义刷新间隔
2. **数据导入/导出**：支持与其他玩家共享刷新数据
3. **更多语言支持**：扩展支持更多语言（当前已支持中文和英文）
4. **刷新提醒**：当箱子即将刷新时发送提醒通知
5. **地图标记**：在游戏地图上标记箱子位置
6. **统计功能**：记录刷新历史，分析刷新规律

---

**文档版本**：v1.1.2-beta  
**最后更新**：2024年

**更新记录**：
- v1.1.2-beta：代号系统完整实现、多语言支持改进、数据初始化健壮性增强
  - **代号系统（Code-based System）**：
    - 地图和空投箱子使用代号（`MAP_001`、`AIRDROP_CRATE_001`等）作为唯一标识符
    - 数据存储使用代号作为键，完全语言无关
    - 添加新语言只需在本地化文件中添加代号到名称的映射
    - 可以任意调整地图顺序，不影响已保存的数据
  - **多语言支持改进**：
    - 实现完整性验证（`Localization:ValidateCompleteness()`）
    - 实现缺失翻译日志（`Localization:LogMissingTranslation()`）
    - 实现初始化状态报告（`Localization:ReportInitializationStatus()`）
    - 三层回退机制：当前语言 → 英文 → 格式化代号
    - 添加翻译指南文档（`TRANSLATION_GUIDE.md` 和 `TRANSLATION_GUIDE_EN.md`）
  - **数据初始化健壮性**：
    - 增强数据结构验证（类型检查、时间戳验证）
    - 处理旧版本或损坏的数据
    - 确保全新安装时的正确初始化
    - 代码位置：`Data/Data.lua:11-88`、`Core/Core.lua:12-43`
  - **功能移除**：
    - 移除数据收集模式（`/ctk collect` 命令及相关代码）
  - **术语修正**：
    - 所有"空投图标"相关术语改为"空投箱子"（官方术语）
  - **位面ID染色逻辑修复**：
    - 修复首次获取位面ID时显示红色的问题
    - 首次获取位面ID时正确显示绿色
    - 代码位置：`UI/MainPanel.lua:403-428`
- v1.1.1：繁体中文支持、硬编码修复和数据初始化完善
  - **繁体中文支持**：
    - 新增 `Locales/zhTW.lua` 繁体中文本地化文件
    - 地图数据支持繁体中文名称（`nameZhTW` 字段）
    - 主城名称支持繁体中文（`CAPITAL_CITY_NAMES.zhTW`）
    - 地图图标名称支持繁体中文（`"戰爭補給箱"`）
    - `Data:GetMapDisplayName()` 根据 locale 返回对应语言的地图名称
    - `Data:IsMapNameMatch()` 支持三种语言匹配（简体、繁体、英文）
    - `Data:IsCapitalCity()` 支持三种语言主城名称匹配
    - `.toc` 文件添加繁体中文标题和说明
    - `Load.xml` 添加 `zhTW.lua` 加载
  - **硬编码文本修复**：
    - 移除所有硬编码的中文调试信息（`Core/Core.lua`、`Utils/Debug.lua`）
    - 移除所有硬编码的英文回退文本（`UI/MainPanel.lua`、`Modules/Timer.lua`、`Data/Data.lua`）
    - 所有文本完全通过本地化系统，确保多语言一致性
  - **数据初始化健壮性**：
    - `Data:Initialize()` 中确保 `CRATETRACKERZK_DB` 和 `CRATETRACKERZK_DB.mapData` 存在
    - 访问 `CRATETRACKERZK_DB.mapData[mapName]` 前确保表存在
    - `Core/Core.lua` 中确保 `CRATETRACKERZK_UI_DB` 存在
    - `UI/FloatingButton.lua` 中确保 `minimapButton` 和 `position` 结构存在
    - 防止全新安装时访问 `nil` 值导致错误
  - **数据存储兼容性**：
    - 存储键名始终使用简体中文名称（`mapName`），确保向后兼容
    - 内存中保存三种语言名称（`mapName`、`mapNameEn`、`mapNameZhTW`）
    - 旧数据完全兼容，无需迁移
    - 跨语言数据共享（不同语言用户数据可以共享）
- v1.1.1-beta：UI优化和数据初始化健壮性改进
  - **UI布局优化**：
    - 主窗口宽度动态调整：中文550px，英文590px
    - 地图列宽度动态调整：中文80px，英文105px
    - 操作按钮宽度动态调整：中文65px，英文75px
    - 地图名称文本处理：左对齐，超出部分隐藏，不换行
    - 字体大小：15px（从本地化配置读取）
  - **无数据显示优化**：
    - 位面列无数据时显示："N/A"
    - 时间列无数据时显示："--:--"（仅UI显示，调试和通知消息仍使用本地化文本）
  - **数据初始化健壮性**：
    - `Data:Initialize()` 中确保 `CRATETRACKERZK_DB.mapData[mapName]` 存在后再访问
    - `Core/Core.lua` 和 `UI/FloatingButton.lua` 中确保 `CRATETRACKERZK_UI_DB` 结构完整
    - 防止全新安装时访问 `nil` 值导致错误
  - **空投检测代码优化**：
    - `TimerManager:DetectMapIcons()` 中在更新刷新时间后重新获取地图数据，确保获取最新的 `nextRefresh` 值
    - 改进调试信息输出，避免访问可能为 `nil` 的值
  - **位面检测优化**：
    - 确保位面检测提示只在有效区域显示
    - 修复无效区域显示位面检测提示的问题

- v1.1.0-beta：正式发布版本，完整功能实现
  - **空投检测优化**：
    - 移除NPC喊话检测方式，只保留地图图标（Vignette）检测
    - 优化检测间隔：从3秒改为2秒，响应更快
    - 连续检测确认时间：2秒
    - 移除无效的检测方式（地标和区域POI API不可用）
  - **多语言支持**：
    - 完整实现中英文双语支持
    - 所有UI文本和消息完全本地化
    - 地图名称支持中英文显示
    - 图标名称本地化配置（中文："战争物资箱"，英文："War Supply Crate"）
  - **位面检测优化**：
    - 确保只有当前地图名称与地图列表完全匹配时才更新位面ID
    - 位面ID颜色显示逻辑优化（使用 `lastRefreshInstance` 进行比较）
  - **UI优化**：
    - 英文版界面按钮和字体大小优化
    - 移除设置菜单按钮
  - **文档完善**：
    - 更新开发文档，反映最新实现
    - 用户文档简化，技术细节移至开发文档

- v1.0.9-dev：重构时间计算逻辑，提取复杂逻辑为独立函数，提升代码可读性和可维护性
  - 新增 `CalculateNextRefreshTime` 独立函数，智能处理过去和未来时间
  - 优化 `Utils.ParseTimeInput`，提取时间解析辅助函数
  - 优化 `MainPanel:UpdateTable`，提取排序和数据准备辅助函数
  - 清理冗余代码（删除未使用的 `DebugPrint` 函数）
  - UI模块优化：
    - 重新设计标题栏，使用三个点菜单按钮替代多个独立按钮
    - 优化信息界面，移除标题显示，最大化内容显示区域
    - 提取 `Info.lua` 中重复的 `RemoveColorCodes` 函数为模块级函数
    - 清理 `MainPanel.lua` 中未使用的 `DebugPrint` 函数
    - 所有界面文本完全通过本地化配置，支持灵活修改


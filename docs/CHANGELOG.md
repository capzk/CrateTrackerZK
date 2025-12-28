# 变更日志

## [1.1.3] - 2024年 - UI响应优化与本地化改进

### 优化
- **刷新按钮UI响应优化**
  - 修复了刷新按钮有时需要点击两次才生效的问题
  - 实现了立即UI更新机制：点击刷新按钮后立即更新内存数据和UI显示
  - 数据保存改为异步处理，确保UI响应不受数据保存操作影响
  - 提升了用户体验，刷新操作立即生效，无需等待
  - 文件：`UI/MainPanel.lua`

- **位面信息提示优化**
  - 首次获取位面ID不再显示提示信息，仅在调试模式下显示
  - 只有位面发生变化时才显示提醒信息
  - 减少了不必要的提示信息干扰
  - 文件：`Modules/Phase.lua`

- **本地化文本优化**
  - 将 `NotAcquired` 和 `NoRecord` 统一为简洁的 "N/A" 和 "--:--"
  - 所有语言文件统一使用简洁的默认值，避免长文本显示不协调
  - 将 `HelpText` 从命令分类移动到UI分类，优化文件结构
  - 文件：`Locales/enUS.lua`, `Locales/zhCN.lua`, `Locales/zhTW.lua`, `Locales/ruRU.lua`

### 技术改进
- **UI更新机制优化**
  - 刷新按钮操作采用立即更新+异步保存的策略
  - UI更新和数据保存分离，确保UI响应速度
  - 不影响其他功能（手动输入时间等）

### 文档更新
- 更新 `CHANGELOG.md`：记录本次所有更改
- 更新 `DATA_FLOW.md`：更新刷新按钮数据流说明
- 更新 `RUNTIME_LOGIC.md`：更新刷新按钮执行流程

---

## [1.1.2-rev.2] - 2024年 - 代码优化与用户体验改进

### 修复
- **修复误判处理重复实现**
  - 移除了 Timer.lua 中重复的误报检测逻辑
  - 统一由 DetectionState:UpdateState() 处理 CONFIRMED 状态下图标消失的情况
  - 消除了冗余代码，逻辑更清晰
  - 文件：`Modules/Timer.lua`

- **修复 GetState() 无法正确返回 CONFIRMED 状态**
  - 修复了 DetectionState:GetState() 无法区分 CONFIRMED 和 ACTIVE 状态的问题
  - 现在根据 lastUpdateTime 正确区分：CONFIRMED（未更新时间）和 ACTIVE（已更新时间）
  - 解决了检测到空投后发送通知但时间不更新的问题
  - 文件：`Modules/DetectionState.lua`

### 优化
- **空投事件持续时间识别机制**
  - 实现了基于空投持续时间的识别机制，区分检测中断和空投结束
  - ACTIVE 状态使用更长的消失确认期（5分钟），因为空投是持续事件
  - 根据空投开始时间判断是否在持续时间内，如果在则使用更长的确认期
  - 避免因地图传送等原因导致的检测中断被误判为新事件
  - 解决了重复发送消息和重复更新时间的问题
  - 文件：`Modules/DetectionState.lua`

- **启动信息优化**
  - 只显示两条核心启动信息（使用绿色 SUCCESS 级别）
  - 其他初始化信息移至调试模式显示
  - 优化了用户体验，减少启动时的信息干扰
  - 文件：`Core/Core.lua`, `Data/Data.lua`, `Modules/Timer.lua`, `Utils/Logger.lua`

- **区域有效性检测优化**
  - 移除了室内区域判断，室内不再被视为无效区域
  - 现在只有副本/战场类型区域会被判定为无效
  - 文件：`Modules/Area.lua`, `Utils/Logger.lua`

- **关于菜单信息优化**
  - 简化关于菜单显示，只保留英文信息
  - 更新了信息格式和内容
  - 文件：`UI/Info.lua`

- **调试信息限流优化**
  - 为位面检测信息添加限流（10秒）
  - 为区域检查信息添加限流（30秒）
  - 状态汇总报告间隔从5秒调整为30秒
  - 减少了调试模式下的重复输出
  - 文件：`Modules/Phase.lua`, `Modules/Area.lua`, `Modules/Timer.lua`

### 技术改进
- **状态机优化**
  - 改进了 CONFIRMED 和 ACTIVE 状态的区分逻辑
  - 实现了基于空投持续时间的智能识别机制
  - 优化了消失确认期的判断逻辑

- **日志系统优化**
  - SUCCESS 级别颜色改为绿色（ff00ff00）
  - 改进了启动信息的显示方式

### 文档更新
- 更新 `CHANGELOG.md`：记录本次所有更改
- 需要更新 `MODULE_ARCHITECTURE.md`：更新 DetectionState 模块说明
- 需要更新 `RUNTIME_LOGIC.md`：更新区域有效性检测说明

---

## [1.1.2-rev.1] - 重复检测修复与状态管理优化

### 优化
- **重复检测问题修复**
  - **首次检测立即通知，2秒确认后更新时间**：
    - 首次检测到空投图标时立即发送通知（检查冷却期）
    - 不立即更新时间，等待2秒持续检测确认
    - 2秒确认后更新时间，不再次发送通知
    - 提高响应速度，避免重复通知
  - **通知冷却期机制**：
    - 同一地图在120秒（2分钟）内不重复发送通知
    - 冷却期仅在首次检测时检查
    - 时间更新不受冷却期影响
  - **消失确认期机制**：
    - 已确认的空投需要持续消失5秒才清除状态
    - 防止因地图切换或API延迟导致的误清除
    - 如果图标在确认期内重新出现，保持状态
  - **离开地图状态自动清除**：
    - 当玩家离开某个地图后，如果5分钟内没有回到该地图，自动清除该地图的检测状态
    - 避免长期占用内存，保持状态准确性
    - 文件：`Modules/Timer.lua`

### 修复
- **数据清除逻辑完善**
  - 修复 `Data:ClearAllData()` 未清除新增状态字段的问题
  - 修复 `Commands:HandleClearCommand()` 未清除新增状态字段的问题
  - 确保 `/ctk clear` 命令能完整清除所有状态
  - 文件：`Data/Data.lua`, `Modules/Commands.lua`

### 设计说明
- **检测流程优化**：
  - 首次检测立即通知，提升用户体验
  - 2秒确认机制确保检测准确性
  - 通知冷却期防止重复通知
  - 消失确认期防止误清除
  - 离开地图状态自动清除保持内存效率

### 文档更新
- 更新 `RUNTIME_LOGIC.md`：添加新的检测机制说明
- 更新 `FUNCTIONALITY_AND_LOGIC.md`：更新持续检测确认机制
- 更新 `DATA_FLOW.md`：更新数据流说明
- 更新 `MODULE_ARCHITECTURE.md`：更新Timer模块说明
- 创建 `issues/DUPLICATE_DETECTION_FIX.md`：记录重复检测问题修复
- 创建 `issues/MAP_LEFT_STATE_OPTIMIZATION.md`：记录离开地图状态优化
- 创建 `issues/COMPREHENSIVE_CHECK.md`：记录完整检查结果

---

## [未发布] - 通知功能优化与子地图检测修复

### 优化
- **通知功能优化**
  - **自动检测通知**：
    - 在团队中：发送两条消息（RAID 普通消息 + RAID_WARNING 团队通知）
    - 在小队中：不发送自动消息（只发送到聊天框）
    - 受 `/ctk team on/off` 命令控制
  - **手动通知**：
    - 不受 `/ctk team on/off` 命令控制
    - 在队伍中：发送到队伍（PARTY/RAID/INSTANCE_CHAT）
    - 不在队伍中：发送到聊天框
  - 文件：`Modules/Notification.lua`

### 修复
- **修复子地图空投检测失败问题**
  - 问题：在子地图（如塔扎维什 2472，父地图为卡雷什 2371）上无法检测到空投
  - 原因：代码使用 `GetVignettePosition` 检查位置，但子地图ID可能无法获取父地图Vignette的位置信息
  - 修复：移除位置检查的强制要求，检测逻辑仅依赖名称匹配
  - 影响：提高了检测可靠性，支持所有子地图场景
  - 文件：`Modules/Timer.lua`

### 设计说明
- **检测逻辑优化**：检测仅依赖名称匹配，不依赖位置信息
  - `GetVignettes()` 已返回当前地图上的所有Vignette，无需位置验证
  - 区域有效性检测已确保在正确的追踪区域
  - 简化了代码逻辑，提高了可靠性
  - 支持所有子地图场景（子地图上的Vignette可能无法用子地图ID获取位置）

### 文档更新
- 更新 `FUNCTIONALITY_AND_LOGIC.md`：添加检测原理的设计说明，更新通知系统说明
- 更新 `RUNTIME_LOGIC.md`：明确检测流程不依赖位置信息，更新通知渠道说明
- 更新 `DATA_FLOW.md`：更新自动和手动通知的数据流
- 更新 `MODULE_ARCHITECTURE.md`：更新通知模块说明
- 更新 `FUNCTIONALITY_OVERVIEW.md`：更新团队通知功能说明
- 更新 `issues/NOTIFICATION_OPTIMIZATION.md`：记录通知功能优化详情

---

*变更日期：2024年*

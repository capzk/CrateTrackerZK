# 变更日志

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


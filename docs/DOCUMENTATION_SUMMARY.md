# 文档整理总结

## 文档结构

### 已完成的优化

1. **修正了 API 文档中的过时路径**
   - 将所有旧的文件路径（如 `Modules/AirdropDetection.lua`）更新为实际文件名（如 `Modules/Timer.lua`）
   - 确保所有 API 使用位置信息准确

2. **明确了文档定位**
   - **FUNCTIONALITY_OVERVIEW.md** - 快速概览（简洁版）
   - **FUNCTIONALITY_AND_LOGIC.md** - 完整功能与运行逻辑（详细版）⭐
   - **RUNTIME_LOGIC.md** - 技术细节和实现逻辑
   - **DATA_FLOW.md** - 专门的数据流转文档
   - **MODULE_ARCHITECTURE.md** - 代码架构文档

3. **更新了文档索引**
   - README.md 中明确标注了文档的定位和推荐阅读顺序
   - 添加了文档间的交叉引用

## 文档关系

```
功能概述 (简洁) 
    ↓ 需要更多细节？
功能与运行逻辑 (完整) ⭐
    ↓ 需要技术细节？
运行逻辑详解 + 数据流 + 模块架构
    ↓ 需要 API 信息？
API 参考
```

## 文档覆盖情况

### ✅ 已覆盖的内容

- [x] 插件功能概述
- [x] 核心功能详解
- [x] 运行逻辑流程
- [x] 模块架构设计
- [x] 数据流转过程
- [x] API 使用参考
- [x] 用户命令说明
- [x] 错误处理机制
- [x] 扩展性设计
- [x] 重复检测修复机制
- [x] 通知冷却期机制
- [x] 消失确认期机制
- [x] 离开地图状态管理

### 📝 文档特点

- **FUNCTIONALITY_OVERVIEW.md** - 适合快速了解插件功能
- **FUNCTIONALITY_AND_LOGIC.md** - 适合全面了解功能和运行逻辑
- **RUNTIME_LOGIC.md** - 适合深入了解技术实现
- **DATA_FLOW.md** - 适合理解数据流转
- **MODULE_ARCHITECTURE.md** - 适合代码开发和维护

## 建议阅读顺序

### 新用户
1. FUNCTIONALITY_OVERVIEW.md（快速了解）
2. FUNCTIONALITY_AND_LOGIC.md（深入了解）

### 开发者
1. FUNCTIONALITY_AND_LOGIC.md（了解整体）
2. MODULE_ARCHITECTURE.md（了解架构）
3. RUNTIME_LOGIC.md（了解实现）
4. DATA_FLOW.md（了解数据流）
5. API_REFERENCE.md（查找 API）

## 文档维护

- 所有文档路径已更新为实际文件名
- 文档间已建立交叉引用
- 文档定位已明确，避免重复
- 索引文档已更新

## 最新更新（2024年）

### 模块重构与文档更新

#### 架构重构
- **模块化重构**: 将检测逻辑拆分为独立模块
  - `IconDetector.lua`: 图标检测（仅负责检测逻辑）
  - `MapTracker.lua`: 地图匹配和变化处理
  - `DetectionState.lua`: 状态机管理（IDLE -> DETECTING -> CONFIRMED -> ACTIVE -> DISAPPEARING）
  - `DetectionDecision.lua`: 通知和时间更新决策
  - `NotificationCooldown.lua`: 通知冷却期管理
- **日志系统统一**: `Debug.lua` 重构为 `Logger.lua`
  - 统一日志输出系统
  - 支持多级别日志（ERROR, WARN, INFO, DEBUG, SUCCESS）
  - 灵活的限流机制（不同类型消息不同限流间隔）
  - 限流消息统计

#### 文档更新
- **MODULE_ARCHITECTURE.md**: 
  - 添加新模块说明（IconDetector, MapTracker, DetectionState等）
  - 更新模块依赖关系
  - 删除Debug.lua引用，更新为Logger.lua
  - 更新限流策略说明
- **RUNTIME_LOGIC.md**: 
  - 更新文件加载顺序（反映新的模块结构）
  - 更新检测流程（反映新的模块架构）
  - 删除Debug模块引用
- **DATA_FLOW.md**: 
  - 更新空投检测数据流（反映新的模块架构）
  - 更新模块调用关系
- **FUNCTIONALITY_AND_LOGIC.md**: 
  - 更新文件加载顺序
  - 更新初始化步骤
  - 更新检测循环说明
- **API_REFERENCE.md**: 
  - 更新API使用位置（图标检测API现在在IconDetector模块）
  - 更新日志API使用位置（现在统一通过Logger模块）

#### 功能优化
- **状态汇总报告**: 每5秒输出一次完整状态（当前地图、区域、位面、检测状态等）
- **调试信息优化**: 
  - 高频消息（检测循环）: 5秒限流
  - 关键信息（状态变化、地图匹配）: 不限流
  - 普通信息: 20-30秒限流
  - UI更新: 300秒限流

---

*最后更新：2024年（模块重构后）*


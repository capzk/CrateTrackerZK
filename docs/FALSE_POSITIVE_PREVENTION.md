# 防止误报机制完整文档

## 概述

CrateTrackerZK 插件实现了多层防护机制，确保既不会错过真正的空投检测，也不会产生误报。这些机制对于团队协作至关重要，因为误报会影响所有团队成员的插件。

---

## 核心防护机制

### 1. 2秒确认期（CONFIRM_TIME）

**位置**：`Modules/DetectionState.lua:40`

**机制**：
- 首次检测到图标时，进入 `DETECTING` 状态
- 图标必须**持续存在至少2秒**才能进入 `CONFIRMED` 状态
- 如果图标在2秒内消失，判定为无效空投，输出警告并清除状态

**代码逻辑**：
```lua
if state.status == self.STATES.DETECTING then
    local timeSinceFirstDetection = currentTime - state.firstDetectedTime;
    if timeSinceFirstDetection >= self.CONFIRM_TIME then  -- 2秒
        newState.status = self.STATES.CONFIRMED;
    end
end
```

**防护效果**：
- ✅ 防止短暂图标闪烁导致的误报
- ✅ 确保只有持续存在的图标才会被确认

---

### 2. 重新检测验证（双重验证）

**位置**：`Modules/Timer.lua:263-274`

**机制**：
- 在进入 `CONFIRMED` 状态处理前，**重新检测图标是否仍然存在**
- 如果重新检测时图标已消失，跳过处理，不发送通知，不更新时间

**代码逻辑**：
```lua
if state.status == DetectionState.STATES.CONFIRMED then
    -- 关键验证：再次检查图标是否仍然存在
    local currentIconDetected = IconDetector:DetectIcon(currentMapID);
    if not currentIconDetected then
        -- 图标已消失，跳过处理
        return currentIconDetected;
    end
    -- 继续处理...
end
```

**防护效果**：
- ✅ 防止在状态转换过程中图标消失导致的误报
- ✅ 确保处理时图标确实存在

**为什么需要重新检测**：
- `UpdateState` 使用的是之前检测的 `iconDetected` 值
- 图标可能在检测后、处理前消失
- 重新检测确保处理时图标确实存在

---

### 3. 3分钟冷却期（PROCESSED_TIMEOUT）

**位置**：`Modules/DetectionState.lua:41`

**机制**：
- 确认空投并处理后，进入 `PROCESSED` 状态
- 在 `PROCESSED` 状态下，**暂停检测3分钟（180秒）**
- 3分钟后自动清除状态，恢复检测

**代码逻辑**：
```lua
-- 检查PROCESSED状态
if DetectionState:IsProcessed(targetMapData.id) then
    if DetectionState:IsProcessedTimeout(targetMapData.id, currentTime) then
        -- 超时，清除状态
        DetectionState:ClearProcessed(targetMapData.id);
    else
        -- 未超时，跳过检测
        return false;
    end
end
```

**防护效果**：
- ✅ 防止短时间内重复检测和通知
- ✅ 避免空投图标持续存在导致的重复处理

---

### 4. 状态机完整性检查

**位置**：`Modules/DetectionState.lua:73-152`

**状态转换规则**：

```
IDLE -> DETECTING: 首次检测到图标
DETECTING -> CONFIRMED: 持续检测2秒
CONFIRMED -> PROCESSED: 确认后处理（通知+更新时间）
PROCESSED -> IDLE: 3分钟超时后自动清除

异常情况处理：
DETECTING -> IDLE: 图标在2秒内消失（输出警告）
CONFIRMED -> IDLE: 图标消失（静默清除，已通过2秒确认）
```

**防护效果**：
- ✅ 确保状态转换的完整性和正确性
- ✅ 防止状态不一致导致的误报

---

### 5. 区域有效性检查

**位置**：`Modules/Area.lua`

**机制**：
- 检查玩家是否在副本/战场中（自动暂停检测）
- 检查当前地图是否在追踪列表中
- 支持父地图匹配

**防护效果**：
- ✅ 防止在无效区域检测导致的误报
- ✅ 确保只在正确的追踪区域进行检测

---

### 6. 团队消息冷却期

**位置**：`Modules/Timer.lua:280-299`

**机制**：
- 检查是否在30秒内收到过团队消息
- 如果收到过，不发送重复通知（但会更新刷新时间）
- 如果超过30秒，不再发送通知（因为空投已经发生30秒了，再发没意义）

**防护效果**：
- ✅ 防止团队成员重复发送通知
- ✅ 避免通知刷屏

---

## 完整检测流程

### 正常检测流程

```
1. 检测循环（每秒）
   ├─ 检查区域有效性
   ├─ 检查PROCESSED状态（3分钟冷却期）
   └─ 检测图标

2. 图标检测
   ├─ 获取所有Vignette图标
   └─ 名称匹配（"战争物资箱"）

3. 状态更新
   ├─ IDLE -> DETECTING（首次检测）
   ├─ DETECTING -> CONFIRMED（持续2秒）
   └─ CONFIRMED -> PROCESSED（确认后处理）

4. CONFIRMED处理
   ├─ 重新检测图标（双重验证）
   ├─ 检查团队消息冷却期
   ├─ 发送通知（如果应该发送）
   ├─ 更新刷新时间
   └─ 标记为PROCESSED（3分钟冷却期）
```

### 误报防护流程

```
1. 短暂图标闪烁
   ├─ 检测到图标 -> DETECTING
   ├─ 图标消失（<2秒）-> IDLE
   └─ 输出警告：无效空投

2. 图标在确认后消失
   ├─ 检测到图标 -> DETECTING
   ├─ 持续2秒 -> CONFIRMED
   ├─ 重新检测图标（已消失）-> 跳过处理
   └─ 静默清除状态

3. 重复检测防护
   ├─ 确认空投 -> PROCESSED
   ├─ 3分钟内暂停检测
   └─ 3分钟后恢复检测
```

---

## 关键代码位置

### 1. 2秒确认期
- **文件**：`Modules/DetectionState.lua`
- **函数**：`DetectionState:UpdateState()`
- **行号**：94-103

### 2. 重新检测验证
- **文件**：`Modules/Timer.lua`
- **函数**：`TimerManager:DetectMapIcons()`
- **行号**：263-274

### 3. 3分钟冷却期
- **文件**：`Modules/DetectionState.lua`
- **常量**：`PROCESSED_TIMEOUT = 180`
- **检查**：`Modules/Timer.lua:227-240`

### 4. 状态机管理
- **文件**：`Modules/DetectionState.lua`
- **函数**：`DetectionState:UpdateState()`
- **行号**：73-152

### 5. 区域有效性
- **文件**：`Modules/Area.lua`
- **函数**：`Area:CheckAndUpdateAreaValid()`

---

## 防护机制总结

| 机制 | 位置 | 防护效果 | 重要性 |
|------|------|----------|--------|
| 2秒确认期 | DetectionState.lua | 防止短暂闪烁误报 | ⭐⭐⭐⭐⭐ |
| 重新检测验证 | Timer.lua | 防止状态转换时误报 | ⭐⭐⭐⭐⭐ |
| 3分钟冷却期 | DetectionState.lua | 防止重复检测 | ⭐⭐⭐⭐ |
| 状态机完整性 | DetectionState.lua | 确保状态正确 | ⭐⭐⭐⭐ |
| 区域有效性 | Area.lua | 防止无效区域检测 | ⭐⭐⭐ |
| 团队消息冷却 | Timer.lua | 防止重复通知 | ⭐⭐⭐ |

---

## 测试场景

### 场景1：短暂图标闪烁
- **预期**：不触发通知，输出警告
- **验证**：图标在2秒内消失，状态回到IDLE

### 场景2：正常空投检测
- **预期**：2秒后确认，发送通知，更新时间
- **验证**：图标持续存在，状态正确转换

### 场景3：图标在确认后消失
- **预期**：重新检测时发现图标消失，跳过处理
- **验证**：不发送通知，不更新时间

### 场景4：重复检测
- **预期**：3分钟内不重复检测
- **验证**：PROCESSED状态下跳过检测

---

## 最新优化（2024-12-19）

### 修复的问题

1. **重新检测验证**：
   - 在 `CONFIRMED` 状态处理前，重新检测图标
   - 确保处理时图标确实存在
   - 防止使用过时的检测结果

2. **状态清除优化**：
   - 简化清除机制，只保留必要的清除场景
   - 确保状态转换的完整性

---

## 注意事项

1. **检测频率**：每秒检测一次，确保及时响应
2. **状态持久化**：检测状态不持久化，每次登录清除
3. **团队协作**：误报会影响所有团队成员，必须严格防护
4. **调试模式**：开启调试模式可以查看详细的状态转换日志

---

**最后更新**：2024-12-19  
**维护者**：capzk


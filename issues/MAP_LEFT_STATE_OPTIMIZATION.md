# 离开地图状态自动清除优化

## 优化背景

### 问题描述

当玩家抢到空投后立即离开地图，空投事件可能还没结束。此时：
- 玩家已经不在该地图
- `DetectMapIcons()` 只检测当前玩家所在的地图
- 离开的地图状态（`mapIconDetected[mapId] = true`）会一直保持
- 如果玩家不再回到该地图，状态永远不会被清除

### 影响分析

1. **内存占用**：虽然每个地图的状态只有几个变量，但长期累积可能占用内存
2. **状态不准确**：离开的地图状态可能不反映实际情况
3. **功能影响**：不影响其他地图的检测（状态是隔离的）

## 优化方案

### 核心思路

当玩家离开某个地图后，如果一段时间内（5分钟）没有回到该地图，自动清除该地图的检测状态。

### 实现机制

1. **记录离开时间**：
   - 当玩家从地图A切换到地图B时，记录地图A的离开时间
   - 使用 `mapLeftTime[mapId]` 存储离开时间戳

2. **清除离开时间**：
   - 当玩家回到某个地图时，清除该地图的离开时间
   - 表示玩家已回到该地图，不需要清除状态

3. **自动清除状态**：
   - 每次检测时，检查所有已离开的地图
   - 如果离开时间超过阈值（5分钟），自动清除该地图的所有检测状态

### 代码修改

**文件**: `Modules/Timer.lua`

**主要变更**:

1. **Initialize() 函数**：
   ```lua
   -- 新增字段
   self.mapLeftTime = self.mapLeftTime or {}; -- 记录玩家离开某个地图的时间
   self.lastDetectedMapId = self.lastDetectedMapId or nil; -- 上次检测到的地图ID（配置ID）
   self.MAP_LEFT_CLEAR_TIME = 300; -- 离开地图后清除状态的时间（秒，5分钟）
   ```

2. **新增 CheckAndClearLeftMaps() 函数**：
   - 检查所有已离开的地图
   - 如果离开时间超过阈值，清除该地图的所有检测状态
   - 包括：`mapIconDetected`、`mapIconFirstDetectedTime`、`mapIconDisappearedTime`

3. **DetectMapIcons() 函数**：
   - 在地图匹配后，检查地图是否变化
   - 如果变化，记录离开旧地图的时间
   - 清除当前地图的离开时间（玩家已回到该地图）
   - 调用 `CheckAndClearLeftMaps()` 清除超时的地图状态

### 工作流程

```
时间线：
T0: 玩家在地图A检测到空投
    ├─ mapIconDetected[mapA.id] = true
    ├─ lastDetectedMapId = mapA.id
    └─ 发送通知并更新时间 ✓

T0+30秒: 玩家拿到物资，离开地图A，前往地图B
    ├─ DetectMapIcons() 检测到地图变化
    ├─ mapLeftTime[mapA.id] = T0+30
    ├─ lastDetectedMapId = mapB.id
    └─ mapIconDetected[mapA.id] 仍然 = true（保持状态）

T0+60秒: 玩家在地图B检测空投
    ├─ DetectMapIcons() 检测地图B
    ├─ CheckAndClearLeftMaps() 检查离开的地图
    ├─ 地图A离开时间 = 30秒 < 300秒（5分钟）
    └─ 不清除地图A的状态 ✓

T0+360秒: 玩家继续在地图B
    ├─ DetectMapIcons() 检测地图B
    ├─ CheckAndClearLeftMaps() 检查离开的地图
    ├─ 地图A离开时间 = 330秒 > 300秒（5分钟）
    ├─ 自动清除地图A的所有状态 ✓
    └─ mapIconDetected[mapA.id] = nil

或者：

T0+60秒: 玩家回到地图A
    ├─ DetectMapIcons() 检测到地图变化
    ├─ mapLeftTime[mapA.id] = nil（清除离开时间）
    ├─ lastDetectedMapId = mapA.id
    └─ mapIconDetected[mapA.id] 保持 = true（状态保留）✓
```

## 优势

1. **自动清理**：
   - 离开的地图状态会在5分钟后自动清除
   - 避免长期占用内存

2. **状态准确**：
   - 离开的地图状态不会永久保持
   - 反映实际的游戏状态

3. **不影响功能**：
   - 如果玩家在5分钟内回到地图，状态会保留
   - 如果玩家不回去，状态会被清除
   - 不影响其他地图的检测

4. **性能优化**：
   - 只在检测时检查，不增加额外开销
   - 清除操作是轻量级的

## 配置参数

- **MAP_LEFT_CLEAR_TIME = 300**（5分钟）
  - 离开地图后清除状态的时间阈值
  - 可以根据需要调整

## 测试建议

1. **离开地图测试**：
   - 在地图A检测到空投
   - 立即离开地图A，前往地图B
   - 等待5分钟
   - 验证：地图A的状态被自动清除

2. **回到地图测试**：
   - 在地图A检测到空投
   - 离开地图A，前往地图B
   - 在5分钟内回到地图A
   - 验证：地图A的状态保留

3. **多地图切换测试**：
   - 在多个地图之间快速切换
   - 验证：每个地图的离开时间正确记录
   - 验证：超过5分钟的地图状态被清除

---

*优化日期：2024年*


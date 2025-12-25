# 性能分析与优化建议

## 当前性能问题

### 1. UI更新频率过高 ⚠️
**位置**: `UI/MainPanel.lua:306`
```lua
MainPanel.updateTimer = C_Timer.NewTicker(1, function() MainPanel:UpdateTable() end);
```

**问题**:
- 每秒执行一次 `UpdateTable()`，即使数据没有变化
- 每次更新都会：
  - 重新创建所有地图数据的浅拷贝（`PrepareTableData()`）
  - 重新排序数组（如果设置了排序）
  - 更新所有行的文本、颜色和位置
  - 调用 `Data:CheckAndUpdateRefreshTimes()`

**影响**: 
- CPU占用：每秒执行大量字符串操作和UI更新
- 内存占用：频繁创建临时对象

**优化建议**:
1. 降低更新频率到2-3秒
2. 添加数据变化检测，只在数据实际变化时更新
3. 只在倒计时变化时更新相关行，而不是全部行

### 2. OnUpdate脚本每帧执行 ⚠️
**位置**: `Core/Core.lua:101-107`
```lua
self.phaseTimer:SetScript("OnUpdate", function(sf, elapsed)
    phaseLastTime = phaseLastTime + elapsed;
    if phaseLastTime >= 10 then
        phaseLastTime = 0;
        if Phase then Phase:UpdatePhaseInfo() end
    end
end);
```

**问题**:
- `OnUpdate` 每帧都会执行（约60fps = 每秒60次）
- 虽然内部有10秒限制，但每帧都会检查条件

**影响**: 
- CPU占用：每帧执行函数调用和条件判断

**优化建议**:
- 使用 `C_Timer.NewTicker(10, ...)` 替代 `OnUpdate`，减少函数调用频率

### 3. 地图图标检测频率 ⚠️
**位置**: `Modules/Timer.lua:423`
```lua
self.mapIconDetectionTimer = C_Timer.NewTicker(interval, function()
```

**当前状态**: 默认2秒间隔，这是合理的

**建议**: 保持当前频率，或根据区域有效性动态调整

### 4. 字符串操作频繁 ⚠️
**位置**: `UI/MainPanel.lua:UpdateTable()`

**问题**:
- 每次更新都会调用 `Data:FormatDateTime()` 和 `Data:FormatTime()`
- 字符串拼接操作频繁

**优化建议**:
- 缓存格式化结果，只在数据变化时重新格式化
- 使用字符串池减少内存分配

### 5. 数据浅拷贝开销 ⚠️
**位置**: `UI/MainPanel.lua:PrepareTableData()`

**问题**:
- 每次更新都会为每个地图数据创建浅拷贝
- 如果有很多地图，这会创建大量临时对象

**优化建议**:
- 只在数据实际变化时重新创建
- 或者复用已有的数组，只更新变化的部分

## 已实施的优化 ✅

### 1. UI更新频率保持1秒 ✅
**实施**: `UI/MainPanel.lua:306`
- 保持1秒更新频率以确保倒计时流畅显示
- 倒计时需要每秒更新才能提供良好的用户体验

### 2. 使用C_Timer替代OnUpdate ✅
**实施**: `Core/Core.lua:ResumeAllDetections()`
- 移除 `OnUpdate` 脚本，改用 `C_Timer.NewTicker(10, ...)`
- 移除不再使用的 `phaseTimer` Frame对象
- **收益**: 函数调用频率从60次/秒降到0.1次/秒（约600倍减少）

## 优化方案（待实施）

### 方案2: 添加数据变化检测
```lua
local lastUpdateHash = nil;

function MainPanel:UpdateTable()
    local frame = self.mainFrame;
    if not frame or not frame:IsShown() then return end
    
    -- 计算数据哈希
    local currentHash = self:CalculateDataHash();
    if currentHash == lastUpdateHash then
        return; -- 数据未变化，跳过更新
    end
    lastUpdateHash = currentHash;
    
    -- ... 原有更新逻辑
end
```

**收益**: 避免不必要的UI更新

### 方案3: 使用C_Timer替代OnUpdate
```lua
-- 替换 OnUpdate 脚本
self.phaseTimer = C_Timer.NewTicker(10, function()
    if Phase then Phase:UpdatePhaseInfo() end
end);
```

**收益**: 减少函数调用频率（从60次/秒降到0.1次/秒）

### 方案4: 增量更新
只更新变化的数据行，而不是全部行。

**收益**: 减少UI操作次数

## 内存使用分析

### 当前内存占用点
1. **UI元素**: 每个表格行创建多个Frame和FontString对象
2. **数据副本**: `PrepareTableData()` 创建的数据副本
3. **事件监听器**: 多个事件注册和hook
4. **定时器对象**: 多个 `C_Timer.NewTicker` 对象

### 内存优化建议
1. **UI元素复用**: 已实现，表格行已复用
2. **减少数据副本**: 优化 `PrepareTableData()` 逻辑
3. **及时清理**: 确保定时器在不需要时正确取消

## 性能测试建议

1. 使用 `/framestack` 或性能分析工具监控
2. 测试在不同地图数量下的性能
3. 测试长时间运行的内存占用
4. 测试UI打开/关闭时的性能

## 优先级

1. **高优先级**: 降低UI更新频率（方案1）
2. **中优先级**: 使用C_Timer替代OnUpdate（方案3）
3. **低优先级**: 数据变化检测和增量更新（方案2、4）


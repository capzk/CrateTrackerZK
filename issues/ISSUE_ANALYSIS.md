# 问题分析：塔扎维什（2472）空投检测失败

## ✅ 已解决

**修复日期**: 2024年  
**修复方案**: 移除位置检查的强制要求，检测逻辑仅依赖名称匹配  
**修复文件**: `Modules/Timer.lua`  
**详细变更**: 参见 `../docs/CHANGELOG.md`

---

## 问题描述

- **当前地图ID**: 2472 (塔扎维什)
- **父地图ID**: 2371 (卡雷什)
- **父地图状态**: 卡雷什在配置中已启用（MapConfig.lua 第21行）
- **问题**: 空投发生时插件没有检测到

## 代码逻辑分析

### 1. 区域有效性检测（Area.lua）

**逻辑流程**：
```lua
1. 检查当前地图ID (2472) 是否在追踪列表中 → 否
2. 检查父地图ID (2371) 是否在追踪列表中 → 是 ✓
3. 如果匹配到父地图，设置 isValid = true
4. 恢复检测 (ResumeAllDetections)
```

**结论**: ✅ 区域有效性检测逻辑**正确**，应该能识别父地图匹配并恢复检测。

### 2. 地图匹配逻辑（Timer.lua DetectMapIcons）

**逻辑流程**：
```lua
1. 获取当前地图ID (2472)
2. 尝试匹配当前地图 → 失败
3. 获取 mapInfo.parentMapID (2371)
4. 尝试匹配父地图 → 应该成功 ✓
5. 设置 targetMapData = 卡雷什的地图数据
```

**结论**: ✅ 地图匹配逻辑**正确**，应该能找到父地图数据。

### 3. Vignette 检测逻辑（Timer.lua 第312-340行）

**潜在问题点**：

```lua
local position = C_VignetteInfo.GetVignettePosition(vignetteGUID, currentMapID)
```

**问题分析**：
- 使用的是 `currentMapID` (2472，塔扎维什)
- 但 Vignette 可能属于父地图 (2371，卡雷什)
- `GetVignettePosition` API 可能需要使用正确的 mapID 才能获取位置
- 如果位置获取失败（返回 nil），会导致检测跳过该 Vignette

**关键代码**（第318-332行）：
```lua
local position = C_VignetteInfo.GetVignettePosition(vignetteGUID, currentMapID)
if position then  -- 如果 position 为 nil，整个检测会被跳过
    local vignetteName = vignetteInfo.name or ""
    -- ... 名称匹配逻辑
end
```

## 可能的问题原因

### 原因1：Vignette 位置获取失败（最可能）

**问题**：`GetVignettePosition(vignetteGUID, currentMapID)` 使用子地图ID可能无法获取父地图Vignette的位置

**影响**：
- 即使找到了 Vignette，如果 `position` 为 nil，检测会被跳过
- 导致 `foundMapIcon` 始终为 false

**验证方法**：
- 开启调试模式：`/ctk debug on`
- 查看是否有 "Vignette list is empty" 或相关调试信息

### 原因2：区域有效性检测时机问题

**问题**：进入塔扎维什时，区域有效性检测可能：
- 在父地图匹配逻辑执行前就判断为无效
- 或者检测被暂停后没有及时恢复

**验证方法**：
- 检查调试信息中是否有 "区域无效（不在列表中）" 的消息
- 检查 `Area.lastAreaValidState` 的状态

### 原因3：Vignette 名称不匹配

**问题**：空投箱子的名称可能：
- 在塔扎维什中使用不同的名称
- 或者名称有额外的空格/字符

**验证方法**：
- 使用宏命令检测当前地图的 Vignette 名称
- 检查 Localization 中的空投箱子名称配置

## 建议的修复方案

### 方案1：修复 Vignette 位置获取逻辑（推荐）

**问题**：当使用父地图匹配时，应该尝试使用父地图ID获取位置

**修复思路**：
```lua
-- 如果匹配到的是父地图，尝试使用父地图ID获取位置
local mapIDForPosition = currentMapID;
if targetMapData and targetMapData.mapID ~= currentMapID then
    -- 匹配到的是父地图，尝试使用父地图ID
    mapIDForPosition = targetMapData.mapID;
end

-- 先尝试使用当前地图ID
local position = C_VignetteInfo.GetVignettePosition(vignetteGUID, currentMapID);
-- 如果失败且是父地图匹配，尝试父地图ID
if not position and targetMapData and targetMapData.mapID ~= currentMapID then
    position = C_VignetteInfo.GetVignettePosition(vignetteGUID, targetMapData.mapID);
end
```

### 方案2：移除位置检查的强制要求

**问题**：位置信息可能不是必需的，名称匹配就足够了

**修复思路**：
```lua
-- 移除 position 的强制检查，或者使其可选
local position = C_VignetteInfo.GetVignettePosition(vignetteGUID, currentMapID);
-- 即使 position 为 nil，也继续检测名称
if vignetteInfo then
    local vignetteName = vignetteInfo.name or "";
    -- ... 名称匹配逻辑
end
```

### 方案3：增强调试信息

**问题**：当前调试信息不足以诊断问题

**修复思路**：
- 添加更详细的调试信息，记录：
  - Vignette 检测时的地图ID
  - 位置获取是否成功
  - 名称匹配过程
  - 父地图匹配状态

## 诊断步骤

1. **开启调试模式**：
   ```
   /ctk debug on
   ```

2. **进入塔扎维什区域**，观察调试信息：
   - 是否显示 "匹配到父地图"？
   - 是否显示 "区域有效"？
   - 是否有 Vignette 相关的调试信息？

3. **空投出现时**，检查：
   - 是否有 "开始检测地图图标" 的调试信息？
   - 是否有 "检测到地图图标" 的调试信息？
   - 是否有 "Vignette list is empty" 的信息？

4. **使用宏命令验证**：
   ```lua
   /run local v=C_VignetteInfo.GetVignettes();for _,g in ipairs(v)do local n=C_VignetteInfo.GetVignetteInfo(g).name;print(n)end
   ```
   查看当前地图上所有 Vignette 的名称

## 结论

**问题确认**：`GetVignettePosition` 使用子地图ID (2472) 无法获取父地图 (2371) 上 Vignette 的位置信息，导致检测被跳过。

**最终修复**：采用方案2，移除位置检查的强制要求。原因：
- `GetVignettes()` 已返回当前地图上的所有Vignette，无需位置验证
- 区域有效性检测已确保在正确的追踪区域
- 名称匹配是检测的核心逻辑，位置信息不是必需的
- 简化了代码，提高了可靠性，支持所有子地图场景


# CrateTrackerZK 数据流文档

## 一、数据流概览

```
┌─────────────┐
│  游戏事件   │
└──────┬──────┘
       │
       ▼
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│ 地图图标检测 │ ────▶│  数据更新   │ ────▶│  UI更新     │
└─────────────┘      └─────────────┘      └─────────────┘
       │                     │                     │
       │                     ▼                     │
       │            ┌─────────────┐               │
       │            │ 持久化存储   │               │
       │            └─────────────┘               │
       │                                           │
       └───────────────────────────────────────────┘
                    (通知系统)
```

## 二、核心数据流

### 2.1 空投检测数据流（重构后）

```
1. 定时器触发 (每1秒)
   TimerManager.mapIconDetectionTimer
   │
   ▼
2. 执行检测循环
   TimerManager:DetectMapIcons()
   │
   ├─▶ 获取当前地图ID
   │   C_Map.GetBestMapForUnit("player")
   │
   ├─▶ 匹配地图数据（MapTracker模块）
   │   MapTracker:GetTargetMapData(currentMapID)
   │   │
   │   └─▶ 支持父地图匹配
   │
   ├─▶ 处理地图变化（MapTracker模块）
   │   MapTracker:OnMapChanged(currentMapID, targetMapData, currentTime)
   │   │
   │   ├─▶ 检测游戏地图变化
   │   ├─▶ 检测配置地图变化
   │   ├─▶ 记录离开地图时间
   │   └─▶ 清除回到地图的离开时间
   │
   ├─▶ 检测图标（IconDetector模块）
   │   IconDetector:DetectIcon(currentMapID)
   │   │
   │   ├─▶ 获取Vignette图标
   │   │   C_VignetteInfo.GetVignettes()
   │   │
   │   └─▶ 查找空投图标（名称匹配）
   │       C_VignetteInfo.GetVignetteInfo()
   │
   ├─▶ 更新状态（DetectionState模块 - 状态机）
   │   DetectionState:UpdateState(mapId, iconDetected, currentTime)
   │   │
   │   ├─▶ IDLE -> DETECTING: 首次检测到图标
   │   │   mapIconFirstDetectedTime[mapId] = currentTime
   │   │
   │   ├─▶ DETECTING -> CONFIRMED: 持续检测2秒
   │   │   timeSinceFirstDetection >= 2
   │   │
   │   ├─▶ CONFIRMED -> ACTIVE: 已更新时间
   │   │
   │   ├─▶ ACTIVE -> DISAPPEARING: 图标消失
   │   │   mapIconDisappearedTime[mapId] = currentTime
   │   │
   │   └─▶ DISAPPEARING -> IDLE: 持续消失5秒
   │       timeSinceDisappeared >= 5
   │
   ├─▶ 决策通知和更新（DetectionDecision模块）
   │   │
   │   ├─▶ 检查通知冷却期（NotificationCooldown模块）
   │   │   DetectionDecision:ShouldNotify()
   │   │   │
   │   │   └─▶ 如果不在冷却期（>= 120秒）：
   │   │       └─▶ Notification:NotifyAirdropDetected()
   │   │           └─▶ NotificationCooldown:RecordNotification()
   │   │
   │   └─▶ 检查时间更新条件
   │       DetectionDecision:ShouldUpdateTime()
   │       │
   │       └─▶ 如果应该更新：
   │           └─▶ Data:SetLastRefresh(mapId, firstDetectedTime)
   │               │
   │               ├─▶ 计算下次刷新时间
   │               │   Data:UpdateNextRefresh(mapId)
   │               │
   │               └─▶ 保存数据
   │                   Data:SaveMapData(mapId)
   │
   └─▶ 定期状态汇总（每5秒）
       TimerManager:ReportCurrentStatus()
       │
       └─▶ 输出当前地图、区域、位面、检测状态等信息

8. 更新UI
   MainPanel:UpdateTable()

9. 地图切换处理（MapTracker模块）
   MapTracker:CheckAndClearLeftMaps(currentTime)
   │
   └─▶ 如果离开时间 >= 300秒：
       └─▶ DetectionState:ClearState(mapId, "left_map_timeout")
           └─▶ 清除所有相关状态（但保留通知冷却期）
```

### 2.2 位面检测数据流

```
1. 触发事件
   - ZONE_CHANGED
   - ZONE_CHANGED_NEW_AREA
   - PLAYER_TARGET_CHANGED
   - Tooltip显示（鼠标悬停NPC）
   │
   ▼
2. 更新位面信息
   Phase:UpdatePhaseInfo()
   │
   ├─▶ 获取当前地图ID
   │   Area:GetCurrentMapId()
   │
   ├─▶ 匹配地图数据
   │   Data:GetAllMaps() 然后遍历匹配
   │
   └─▶ 获取位面ID
       Phase:GetLayerFromNPC()
       │
       ├─▶ UnitGUID("mouseover") 或 UnitGUID("target")
       │
       └─▶ 解析GUID提取位面信息
           strsplit("-", guid)
           │
           ▼
3. 更新地图数据
   Data:UpdateMap(mapId, {instance = newInstance})
   │
   ├─▶ 检查位面变化
   │   if instanceID ~= targetMapData.instance
   │
   ├─▶ 保存上次位面
   │   lastInstance = oldInstance
   │
   └─▶ 保存数据
       Data:SaveMapData(mapId)
       │
       ▼
4. 更新UI
   MainPanel:UpdateTable()
```

### 2.3 手动输入数据流

```
1. 用户点击"上次刷新"列
   MainPanel:EditLastRefresh(mapId)
   │
   ▼
2. 弹出输入框
   StaticPopup_Show('CRATETRACKERZK_EDIT_LASTREFRESH')
   │
   ▼
3. 用户输入时间
   格式: HH:MM:SS 或 HHMMSS
   │
   ▼
4. 解析时间输入
   Utils.ParseTimeInput(input)
   │
   ├─▶ 解析格式1: HH:MM:SS
   │   ParseTimeFormatColon(input)
   │
   └─▶ 解析格式2: HHMMSS
       ParseTimeFormatCompact(input)
       │
       ▼
5. 转换为时间戳
   Utils.GetTimestampFromTime(hh, mm, ss)
   │
   ├─▶ 获取当前日期
   │   date('*t', time())
   │
   └─▶ 构建时间表
       {year, month, day, hour, min, sec}
       │
       └─▶ time(dateTable)
           │
           ▼
6. 更新计时器
   TimerManager:StartTimer(mapId, MANUAL_INPUT, timestamp)
   │
   ├─▶ 设置手动输入锁定
   │   Data.manualInputLock[mapId] = timestamp
   │
   └─▶ 更新刷新时间
       Data:SetLastRefresh(mapId, timestamp)
       │
       ▼
7. 更新UI
   MainPanel:UpdateTable()
```

### 2.4 刷新按钮数据流

```
1. 用户点击"刷新"按钮
   MainPanel:RefreshMap(mapId)
   │
   ▼
2. 启动计时器
   TimerManager:StartTimer(mapId, REFRESH_BUTTON)
   │
   ├─▶ 使用当前时间戳
   │   timestamp = time()
   │
   └─▶ 更新刷新时间
       Data:SetLastRefresh(mapId, timestamp)
       │
       ▼
3. 更新UI
   MainPanel:UpdateTable()
```

## 三、数据持久化流程

### 3.1 保存流程

```
数据更新
   │
   ▼
Data:SaveMapData(mapId)
   │
   ├─▶ 确保数据库存在
   │   ensureDB()
   │
   └─▶ 保存到 SavedVariables
       CRATETRACKERZK_DB.mapData[mapID] = {
         instance = ...,
         lastInstance = ...,
         lastRefreshInstance = ...,
         lastRefresh = ...,
         createTime = ...
       }
```

### 3.2 加载流程

```
插件初始化
   │
   ▼
Data:Initialize()
   │
   ├─▶ 确保数据库存在
   │   ensureDB()
   │
   ├─▶ 从配置加载地图列表
   │   MAP_CONFIG.current_maps
   │
   ├─▶ 从保存数据恢复
   │   CRATETRACKERZK_DB.mapData[mapID]
   │
   ├─▶ 验证时间戳
   │   sanitizeTimestamp(savedData.lastRefresh)
   │
   └─▶ 计算下次刷新时间
       Data:UpdateNextRefresh(mapId)
```

## 四、UI更新数据流

### 4.1 主面板更新流程

```
定时器触发 (每1秒)
   MainPanel.updateTimer
   │
   ▼
MainPanel:UpdateTable()
   │
   ├─▶ 更新刷新时间
   │   Data:CheckAndUpdateRefreshTimes()
   │   │
   │   └─▶ 遍历所有地图
   │       Data:UpdateNextRefresh(mapId)
   │
   ├─▶ 准备表格数据
   │   PrepareTableData()
   │   │
   │   ├─▶ 获取所有地图
   │   │   Data:GetAllMaps()
   │   │
   │   └─▶ 计算剩余时间
   │       Data:CalculateRemainingTime(nextRefresh)
   │
   ├─▶ 应用排序（如果启用）
   │   table.sort(mapArray, comparator)
   │
   └─▶ 更新每一行
       │
       ├─▶ 地图名称
       │   Data:GetMapDisplayName(mapData)
       │
       ├─▶ 位面ID（带颜色）
       │   mapData.instance
       │   │
       │   └─▶ 颜色规则:
       │       - 绿色: 检测到空投或位面匹配
       │       - 红色: 位面不匹配
       │       - 白色: 无位面信息
       │
       ├─▶ 上次刷新时间
       │   Data:FormatDateTime(lastRefresh)
       │
       ├─▶ 下次刷新倒计时（带颜色）
       │   Data:FormatTime(remaining, true)
       │   │
       │   └─▶ 颜色规则:
       │       - 红色: < 5分钟
       │       - 橙色: < 15分钟
       │       - 绿色: >= 15分钟
       │
       └─▶ 操作按钮状态
           - 刷新按钮: 始终可用
           - 通知按钮: 始终可用
```

### 4.2 实时倒计时更新

```
每秒更新
   │
   ├─▶ 计算剩余时间
   │   remaining = nextRefresh - time()
   │
   ├─▶ 格式化显示
   │   - >= 1小时: "HH:MM:SS"
   │   - < 1小时: "MM:SS"
   │
   └─▶ 更新颜色
       根据剩余时间设置文本颜色
```

## 五、通知数据流

### 5.1 自动检测通知

```
空投检测确认
   │
   ▼
Notification:NotifyAirdropDetected(mapName, source)
   │
   ├─▶ 构建消息
   │   message = string.format(L["AirdropDetected"], mapName)
   │
   ├─▶ 发送到聊天框（始终）
   │   DEFAULT_CHAT_FRAME:AddMessage(message)
   │
   └─▶ 发送到团队（如果启用且在团队中）
       if teamNotificationEnabled and IsInRaid()
           ├─▶ SendChatMessage(message, "RAID")  // 普通团队消息
           └─▶ SendChatMessage(message, "RAID_WARNING")  // 团队通知
       
       注意：小队中不发送自动消息
```

### 5.2 手动通知

```
用户点击"通知"按钮
   │
   ▼
Notification:NotifyMapRefresh(mapData)
   │
   ├─▶ 检查空投状态
   │   TimerManager.mapIconDetected[mapData.id]
   │
   ├─▶ 构建消息
   │   if isAirdropActive:
   │       message = "检测到空投！"
   │   else:
   │       remaining = Data:CalculateRemainingTime(nextRefresh)
   │       message = "剩余时间: MM:SS"
   │
   ├─▶ 确定聊天类型（不受 teamNotificationEnabled 控制）
   │   GetTeamChatType()
   │   │
   │   ├─▶ INSTANCE_CHAT (副本队伍)
   │   ├─▶ RAID (团队)
   │   └─▶ PARTY (队伍)
   │
   ├─▶ 如果在队伍中
   │   └─▶ 发送消息到队伍
   │       SendChatMessage(message, chatType)
   │
   └─▶ 如果不在队伍中
       └─▶ 发送到聊天框
           DEFAULT_CHAT_FRAME:AddMessage(message)
```

## 六、区域检测数据流

```
区域变化事件
   ZONE_CHANGED / ZONE_CHANGED_NEW_AREA
   │
   ▼
Area:CheckAndUpdateAreaValid()
   │
   ├─▶ 检查是否在室内
   │   IsIndoors()
   │
   ├─▶ 检查是否在副本
   │   GetInstanceInfo()
   │
   ├─▶ 获取当前地图ID
   │   C_Map.GetBestMapForUnit("player")
   │
   ├─▶ 检查地图是否在列表中
   │   Data:GetAllMaps()
   │
   └─▶ 更新状态
       │
       ├─▶ 如果无效:
       │   Area:PauseAllDetections()
       │   │
       │   └─▶ 暂停所有检测
       │       - TimerManager:StopMapIconDetection()
       │       - CrateTrackerZK:PauseAllDetections()
       │
       └─▶ 如果有效:
           Area:ResumeAllDetections()
           │
           └─▶ 恢复所有检测
               - TimerManager:StartMapIconDetection(1)
               - CrateTrackerZK:ResumeAllDetections()
```

## 七、数据验证流程

### 7.1 时间戳验证

```
加载保存数据
   │
   ▼
sanitizeTimestamp(timestamp)
   │
   ├─▶ 检查类型
   │   type(timestamp) == "number"
   │
   ├─▶ 检查范围
   │   timestamp >= 0
   │   timestamp <= time() + 86400 * 365
   │
   └─▶ 返回有效时间戳或 nil
```

### 7.2 时间输入验证

```
用户输入时间
   │
   ▼
Utils.ParseTimeInput(input)
   │
   ├─▶ 格式验证
   │   - HH:MM:SS: ^%d%d:%d%d:%d%d$
   │   - HHMMSS: ^%d%d%d%d%d%d$
   │
   ├─▶ 范围验证
   │   - HH: 0-23
   │   - MM: 0-59
   │   - SS: 0-59
   │
   └─▶ 返回 (hh, mm, ss) 或 nil
```

## 八、错误处理数据流

### 8.1 地图匹配失败

```
检测地图图标
   │
   ├─▶ 当前地图不在列表中
   │   │
   │   └─▶ 记录调试信息（限流30秒）
   │       DebugPrintLimited("map_not_in_list_" .. mapID)
   │
   └─▶ 跳过检测
```

### 8.2 API不可用

```
检测地图图标
   │
   ├─▶ C_Map API 不可用
   │   │
   │   └─▶ 记录调试信息
   │       SafeDebug("C_Map API not available")
   │       return false
   │
   └─▶ 跳过检测
```

### 8.3 数据保存失败

```
保存数据
   │
   ├─▶ SavedVariables 不可用
   │   │
   │   └─▶ 数据仅在内存中
   │       重载后丢失
   │
   └─▶ 继续运行（不影响功能）
```


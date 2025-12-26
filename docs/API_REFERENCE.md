# API 参考文档

本文档列出项目中使用的所有魔兽世界 API。

## 一、地图系统 API (C_Map)

### C_Map.GetBestMapForUnit(unit)
- **用途**: 获取指定单位所在的最佳地图ID
- **使用位置**: `Modules/Timer.lua`, `Modules/Phase.lua`, `Modules/Area.lua`

### C_Map.GetMapInfo(mapID)
- **用途**: 获取指定地图的详细信息（名称、父地图ID等）
- **使用位置**: `Modules/Timer.lua`, `Modules/Area.lua`, `Modules/Phase.lua`

## 二、小地图图标系统 API (C_VignetteInfo)

### C_VignetteInfo.GetVignettes()
- **用途**: 获取当前地图上所有小地图图标的GUID列表
- **使用位置**: `Modules/Timer.lua`

### C_VignetteInfo.GetVignetteInfo(vignetteGUID)
- **用途**: 获取指定vignette的详细信息（名称等）
- **使用位置**: `Modules/Timer.lua`

## 三、定时器系统 API (C_Timer)

### C_Timer.After(delay, callback)
- **用途**: 延迟执行回调函数
- **使用位置**: `Core/Core.lua`

### C_Timer.NewTicker(interval, callback)
- **用途**: 创建周期性定时器
- **使用位置**: `Core/Core.lua`, `Modules/Timer.lua`, `UI/MainPanel.lua`

## 四、区域检测 API

### IsIndoors()
- **用途**: 判断玩家是否在室内
- **使用位置**: `Modules/Area.lua`

### GetInstanceInfo()
- **用途**: 获取当前副本信息（副本类型等）
- **使用位置**: `Modules/Area.lua`

## 五、单位系统 API

### UnitGUID(unit)
- **用途**: 获取单位的GUID（全局唯一标识符）
- **使用位置**: `Modules/Phase.lua`

## 六、聊天系统 API

### SendChatMessage(message, chatType)
- **用途**: 发送聊天消息
- **使用位置**: `Modules/Notification.lua`

### DEFAULT_CHAT_FRAME:AddMessage(message)
- **用途**: 向默认聊天框添加消息
- **使用位置**: `Core/Core.lua`, `Modules/Commands.lua`, `Modules/Notification.lua`

## 七、UI框架 API

### CreateFrame(frameType, name, parent, template)
- **用途**: 创建UI框架
- **使用位置**: `Core/Core.lua`, `UI/MainPanel.lua`, `UI/FloatingButton.lua`, `UI/Info.lua`

### frame:SetScript(scriptType, handler)
- **用途**: 设置框架脚本处理器
- **使用位置**: `Core/Core.lua`, `UI/MainPanel.lua`, `UI/FloatingButton.lua`

### frame:RegisterEvent(event)
- **用途**: 注册游戏事件
- **使用位置**: `Core/Core.lua`

### frame:RegisterForDrag(button)
- **用途**: 注册拖拽事件
- **使用位置**: `UI/MainPanel.lua`, `UI/FloatingButton.lua`

### frame:SetPoint(point, relativeTo, relativePoint, x, y)
- **用途**: 设置框架锚点位置
- **使用位置**: `UI/MainPanel.lua`, `UI/FloatingButton.lua`, `UI/Info.lua`

### frame:GetPoint()
- **用途**: 获取框架锚点信息
- **使用位置**: `UI/MainPanel.lua`, `UI/FloatingButton.lua`

### frame:StartMoving()
- **用途**: 开始移动框架
- **使用位置**: `UI/MainPanel.lua`, `UI/FloatingButton.lua`

### frame:StopMovingOrSizing()
- **用途**: 停止移动或调整大小
- **使用位置**: `UI/MainPanel.lua`, `UI/FloatingButton.lua`

### frame:Show() / frame:Hide()
- **用途**: 显示/隐藏框架
- **使用位置**: `UI/MainPanel.lua`, `UI/FloatingButton.lua`, `UI/Info.lua`

### frame:IsShown()
- **用途**: 检查框架是否显示
- **使用位置**: `UI/MainPanel.lua`, `UI/FloatingButton.lua`

### frame:CreateFontString(name, layer, fontName)
- **用途**: 创建字体字符串对象
- **使用位置**: `UI/MainPanel.lua`, `UI/Info.lua`

### frame:CreateTexture(name, layer)
- **用途**: 创建纹理对象
- **使用位置**: `UI/MainPanel.lua`, `UI/FloatingButton.lua`, `UI/Info.lua`

### frame:SetMovable(movable)
- **用途**: 设置框架是否可移动
- **使用位置**: `UI/MainPanel.lua`, `UI/FloatingButton.lua`

### frame:EnableMouse(enable)
- **用途**: 启用/禁用鼠标事件
- **使用位置**: `UI/MainPanel.lua`, `UI/FloatingButton.lua`

## 八、工具提示 API

### GameTooltip:SetOwner(owner, anchor)
- **用途**: 设置工具提示的所有者和锚点
- **使用位置**: `UI/FloatingButton.lua`

### GameTooltip:SetText(text)
- **用途**: 设置工具提示文本
- **使用位置**: `UI/FloatingButton.lua`

### GameTooltip:AddLine(text)
- **用途**: 添加工具提示行
- **使用位置**: `UI/FloatingButton.lua`

### GameTooltip:Show() / GameTooltip:Hide()
- **用途**: 显示/隐藏工具提示
- **使用位置**: `UI/FloatingButton.lua`

### GameTooltip:HookScript(scriptType, handler)
- **用途**: 钩子工具提示脚本（旧版API兼容）
- **使用位置**: `Core/Core.lua`

### TooltipDataProcessor.AddTooltipPostCall(dataType, callback)
- **用途**: 添加工具提示后处理回调（新版API）
- **使用位置**: `Core/Core.lua`

## 九、枚举 API

### Enum.TooltipDataType.Unit
- **用途**: 工具提示数据类型枚举（单位）
- **使用位置**: `Core/Core.lua`

## 十、组队系统 API

### IsInRaid()
- **用途**: 判断是否在团队中
- **使用位置**: `Modules/Notification.lua`

### IsInGroup(category)
- **用途**: 判断是否在队伍中
- **使用位置**: `Modules/Notification.lua`

### LE_PARTY_CATEGORY_INSTANCE
- **用途**: 队伍类别枚举（副本队伍）
- **使用位置**: `Modules/Notification.lua`

## 十一、弹窗对话框 API

### StaticPopup_Show(dialogName)
- **用途**: 显示静态弹窗对话框
- **使用位置**: `UI/MainPanel.lua`

### StaticPopup_Hide(dialogName)
- **用途**: 隐藏静态弹窗对话框
- **使用位置**: `UI/MainPanel.lua`

### StaticPopupDialogs
- **用途**: 静态弹窗对话框配置表
- **使用位置**: `UI/MainPanel.lua`

## 十二、屏幕信息 API

### GetScreenWidth() / GetScreenHeight()
- **用途**: 获取屏幕宽度/高度
- **使用位置**: `UI/FloatingButton.lua`

### GetCursorPosition()
- **用途**: 获取鼠标光标位置
- **使用位置**: `UI/MainPanel.lua`

### UIParent:GetEffectiveScale()
- **用途**: 获取UI父框架的有效缩放比例
- **使用位置**: `UI/MainPanel.lua`

## 十三、插件元数据 API

### GetAddOnMetadata(addonName, field)
- **用途**: 获取插件元数据
- **使用位置**: `UI/Info.lua`

### GetNumAddOns()
- **用途**: 获取已加载插件数量
- **使用位置**: `UI/Info.lua`

### GetAddOnInfo(index)
- **用途**: 获取插件信息
- **使用位置**: `UI/Info.lua`

## 十四、本地化 API

### GetLocale()
- **用途**: 获取当前游戏客户端语言代码
- **使用位置**: `UI/MainPanel.lua`

## 十五、字符串处理 API

### strsplit(delimiter, str)
- **用途**: 分割字符串
- **使用位置**: `Modules/Phase.lua`, `Modules/Commands.lua`

### select(index, ...)
- **用途**: 从可变参数中选择指定索引的值
- **使用位置**: `Modules/Area.lua`, `Utils/Utils.lua`

### string.match(str, pattern)
- **用途**: 字符串模式匹配
- **使用位置**: `Utils/Utils.lua`, `Modules/Timer.lua`

### string.sub(str, start, end)
- **用途**: 提取子字符串
- **使用位置**: `Utils/Utils.lua`, `UI/MainPanel.lua`

## 十六、时间处理 API

### time()
- **用途**: 获取当前Unix时间戳
- **使用位置**: `Modules/Timer.lua`, `Modules/Phase.lua`, `Data/Data.lua`, `Utils/Utils.lua`, `UI/MainPanel.lua`

### date(format, timestamp)
- **用途**: 格式化时间戳为日期字符串
- **使用位置**: `Utils/Utils.lua`

## 十七、类型转换 API

### tonumber(value)
- **用途**: 转换为数字
- **使用位置**: `Utils/Utils.lua`, `UI/MainPanel.lua`

### tostring(value)
- **用途**: 转换为字符串
- **使用位置**: 多处使用

### type(value)
- **用途**: 获取值类型
- **使用位置**: 多处使用

## 十八、表格操作 API

### table.insert(table, value)
- **用途**: 向表格插入值
- **使用位置**: 多处使用

### table.sort(table, comparator)
- **用途**: 排序表格
- **使用位置**: `UI/MainPanel.lua`

## 十九、错误处理 API

### pcall(func, ...)
- **用途**: 安全调用函数（捕获错误）
- **使用位置**: `Modules/Notification.lua`

## 二十、输出 API

### print(...)
- **用途**: 输出消息到聊天框
- **使用位置**: `Utils/Utils.lua`, `Modules/Timer.lua`

## 二十一、命令系统 API

### SLASH_* / SlashCmdList
- **用途**: 注册斜杠命令
- **使用位置**: `Core/Core.lua`

## 二十二、数据持久化

### SavedVariables
- **用途**: 插件数据持久化存储
- **变量名**: `CRATETRACKERZK_DB`, `CRATETRACKERZK_UI_DB`
- **使用位置**: `Data/Data.lua`, `Utils/Debug.lua`, `Modules/Notification.lua`, `UI/MainPanel.lua`, `UI/FloatingButton.lua`

## 二十三、全局对象

### UIParent
- **用途**: UI父框架
- **使用位置**: `UI/MainPanel.lua`, `UI/FloatingButton.lua`, `UI/Info.lua`

### GameTooltip
- **用途**: 游戏工具提示对象
- **使用位置**: `UI/FloatingButton.lua`, `Core/Core.lua`

### DEFAULT_CHAT_FRAME
- **用途**: 默认聊天框对象
- **使用位置**: 多处使用


# 消息格式区分功能文档

## 概述

CrateTrackerZK 插件支持两种类型的通知消息：**自动检测消息**和**手动通知消息**。为了区分这两种消息类型，插件使用不同的消息格式，确保只有自动检测的消息会被 `TeamMessageReader` 识别并用于防止重复通知。

---

## 消息格式规范

### 1. 自动检测消息格式

**格式**：`【地图名称】 发现战争物资正在空投！！！`

**特点**：
- 不带任何前缀
- 保持原始消息格式
- 会被 `TeamMessageReader` 识别并记录

**示例**：
- `【多恩岛】 发现战争物资正在空投！！！`
- `【海妖岛】 发现战争物资正在空投！！！`
- `【卡雷什】 发现战争物资正在空投！！！`

**发送时机**：
- 插件自动检测到空投图标后，经过2秒确认期，进入 `CONFIRMED` 状态时
- 仅在团队通知功能启用（`/ctk team on`）且在团队/小队中时发送到团队频道
- 始终发送到系统聊天框

---

### 2. 手动通知消息格式

**格式**：`通知：【地图名称】 发现战争物资正在空投！！！`

**特点**：
- 带有 `通知：` 前缀
- 不会被 `TeamMessageReader` 识别
- 用于用户主动发送的通知

**示例**：
- `通知：【多恩岛】 发现战争物资正在空投！！！`
- `通知：【海妖岛】 距离 战争物资 空投还有：10:30！！！`
- `通知：【卡雷什】 暂无时间记录！！！`

**发送时机**：
- 用户点击主面板中的"通知"按钮
- 不受 `/ctk team on/off` 命令控制
- 根据当前队伍状态自动选择发送渠道（团队/小队/聊天框）

---

## 技术实现

### 1. 消息发送逻辑

#### 自动检测消息（`Notification:NotifyAirdropDetected`）

```lua
-- 自动检测的消息保持原格式（不带前缀）
local message = string.format(L["AirdropDetected"], mapName);
-- 发送到团队/小队或聊天框
SendChatMessage(message, chatType);
```

**关键代码位置**：`Modules/Notification.lua:47-86`

#### 手动通知消息（`Notification:NotifyMapRefresh`）

```lua
-- 手动通知使用"通知："前缀
local message = string.format("通知：%s", string.format(L["AirdropDetected"], displayName));
-- 发送到团队/小队或聊天框
SendChatMessage(message, chatType);
```

**关键代码位置**：`Modules/Notification.lua:97-146`

---

### 2. 消息识别逻辑

#### TeamMessageReader 识别规则

`TeamMessageReader` 模块负责识别团队中的自动检测消息，并用于防止重复通知。

**识别流程**：

1. **排除手动消息**：
   ```lua
   -- 排除以"通知："开头的消息（手动消息）
   if message:match("^通知：") then
       return nil;  -- 不处理手动消息
   end
   ```

2. **匹配自动消息**：
   ```lua
   -- 尝试匹配所有已加载的消息模式（只匹配自动消息，不带"通知："前缀）
   for _, patternData in ipairs(TeamMessageReader.messagePatterns) do
       local mapName = message:match(patternData.pattern);
       if mapName then
           return mapName;  -- 识别成功
       end
   end
   ```

**关键代码位置**：`Modules/TeamMessageReader.lua:108-120`

---

### 3. 防止重复通知机制

#### 冷却期逻辑

当插件检测到空投时，会检查是否在30秒内收到过团队中的自动检测消息：

```lua
-- 检查是否在30秒内收到过团队消息
local lastTeamMessageTime = TeamMessageReader.lastTeamMessageTime[mapId];
if lastTeamMessageTime then
    local timeSinceTeamMessage = currentTime - lastTeamMessageTime;
    if timeSinceTeamMessage < TeamMessageReader.MESSAGE_COOLDOWN then
        -- 在30秒内收到过团队消息，不发送通知
        shouldSendNotification = false;
    else
        -- 超过30秒，不再发送通知（因为空投已经发生30秒了，再发没意义）
        shouldSendNotification = false;
    end
end
```

**关键参数**：
- `MESSAGE_COOLDOWN = 30` 秒
- 如果距离团队消息超过30秒，不再发送通知（因为空投已经发生30秒了，再发没意义）

**关键代码位置**：
- `Modules/TeamMessageReader.lua:26-27` - 冷却期定义
- `Modules/Timer.lua` - 冷却期检查逻辑

---

## 本地化支持

### 消息格式定义

消息格式在本地化文件中定义：

**简体中文**（`Locales/zhCN.lua`）：
```lua
localeData["AirdropDetected"] = "【%s】 发现战争物资正在空投！！！";
```

**繁体中文**（`Locales/zhTW.lua`）：
```lua
localeData["AirdropDetected"] = "【%s】 發現戰爭補給正在空投！！！";
```

**英文**（`Locales/enUS.lua`）：
```lua
localeData["AirdropDetected"] = "[%s] War Supplies airdrop detected!!!";
```

**俄文**（`Locales/ruRU.lua`）：
```lua
localeData["AirdropDetected"] = "[%s] Обнаружен воздушный десант военных припасов!!!";
```

**注意**：所有语言的消息格式都遵循相同的规则：
- 自动检测消息：直接使用本地化格式，不带前缀
- 手动通知消息：添加 `通知：` 前缀（或对应语言的"通知"翻译）

---

## 使用场景

### 场景1：自动检测并通知

1. 玩家A的插件检测到空投
2. 插件自动发送：`【多恩岛】 发现战争物资正在空投！！！`
3. 玩家B的插件识别到这条消息，记录时间
4. 如果玩家B的插件也在30秒内检测到空投，不会重复发送通知

### 场景2：手动通知

1. 玩家A点击"通知"按钮
2. 插件发送：`通知：【多恩岛】 发现战争物资正在空投！！！`
3. 玩家B的插件识别到 `通知：` 前缀，不处理这条消息
4. 玩家B的插件不会记录这条消息的时间

### 场景3：防止重复通知

1. 玩家A的插件在 09:00:00 检测到空投，发送自动消息
2. 玩家B的插件在 09:00:05 也检测到空投
3. 玩家B的插件检查：距离团队消息只有5秒（< 30秒）
4. 玩家B的插件不发送通知，但会更新刷新时间

---

## 设计原则

### 1. 消息格式区分

- **自动消息**：保持原格式，不带前缀，便于识别
- **手动消息**：添加 `通知：` 前缀，明确标识为用户操作

### 2. 识别准确性

- 只识别自动消息，避免手动消息干扰
- 使用前缀匹配快速排除手动消息

### 3. 防止重复通知

- 30秒冷却期，避免短时间内重复通知
- 超过30秒后不再发送（因为空投已经发生30秒了，再发没意义）

### 4. 多语言支持

- 所有语言遵循相同的格式规则
- 本地化消息格式统一，便于识别

---

## 相关文件

### 核心实现文件

- `Modules/Notification.lua` - 消息发送逻辑
- `Modules/TeamMessageReader.lua` - 消息识别逻辑
- `Modules/Timer.lua` - 冷却期检查逻辑

### 本地化文件

- `Locales/zhCN.lua` - 简体中文消息格式
- `Locales/zhTW.lua` - 繁体中文消息格式
- `Locales/enUS.lua` - 英文消息格式
- `Locales/ruRU.lua` - 俄文消息格式

---

## 更新历史

### 2024-12-19 - 消息格式区分功能

**新增功能**：
- 自动检测消息和手动通知消息使用不同的格式
- 自动消息保持原格式，手动消息添加 `通知：` 前缀
- `TeamMessageReader` 只识别自动消息，排除手动消息

**优化内容**：
- 冷却期从60秒调整为30秒
- 如果距离团队消息超过30秒，不再发送通知（因为空投已经发生30秒了，再发没意义）
- 变量重命名：`lastNotificationTime` → `lastTeamMessageTime`，`NOTIFICATION_COOLDOWN` → `MESSAGE_COOLDOWN`

**修改的文件**：
- `Modules/Notification.lua` - 添加消息格式区分
- `Modules/TeamMessageReader.lua` - 只识别自动消息，调整冷却期逻辑
- `Modules/Timer.lua` - 更新冷却期检查逻辑
- `Locales/zhCN.lua` - 修正消息格式空格
- `Locales/zhTW.lua` - 修正消息格式空格

---

## 常见问题

### Q1: 为什么手动消息不会被识别？

**A**: 手动消息带有 `通知：` 前缀，`TeamMessageReader` 会排除这些消息，避免手动操作干扰自动检测逻辑。

### Q2: 冷却期为什么是30秒？

**A**: 如果空投已经发生30秒了，再发送通知已经没有意义。30秒的冷却期可以防止重复通知，同时确保及时通知。

### Q3: 如果多个玩家同时检测到空投会怎样？

**A**: 第一个发送自动消息的玩家会通知团队，其他玩家的插件会识别到这条消息，在30秒内不会重复发送通知，但会更新自己的刷新时间。

### Q4: 手动消息会影响冷却期吗？

**A**: 不会。手动消息不会被 `TeamMessageReader` 识别，因此不会影响冷却期逻辑。

---

**最后更新**：2024-12-19  
**维护者**：capzk


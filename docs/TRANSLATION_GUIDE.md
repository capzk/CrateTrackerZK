# Translation Guide

**Addon Version**: 1.1.6

## Quick Start

1. Copy `Locales/enUS.lua` and rename it to your language code (e.g., `frFR.lua`, `deDE.lua`, `esES.lua`)
2. Open the file and translate the text
3. Add the file to `Load.xml` (before `enUS.lua`)
4. Test in-game with `/reload`

## What Must Be Translated

### 1. Language Code (2 places)

Find and replace `"enUS"` with your language code in two locations:

**Line 8** - Error handling:
```lua
locale = "your_language_code",  -- e.g., "frFR"
```

**Line 129** - Registration:
```lua
LocaleManager.RegisterLocale("your_language_code", localeData);
```

### 2. What Needs Translation

## What Can Be Translated (Optional)

All UI text strings can be translated:

```lua
localeData["AirdropDetected"] = "Translation here";
localeData["TimeRemaining"] = "Translation here";
// ... etc
```

- You can leave these in English if you prefer
- The system will automatically use English for missing translations
- Translating all strings provides a better user experience

## Add to Load.xml

Add your language file in `Load.xml` (before `enUS.lua`):

```xml
<Script file="Locales/Locales.lua"/>
<Script file="Locales/zhCN.lua"/>
<Script file="Locales/zhTW.lua"/>
<Script file="Locales/ruRU.lua"/>
<Script file="Locales/your_language_code.lua"/>  <!-- Add here -->
<Script file="Locales/enUS.lua"/>  <!-- Must be last -->
```

## Getting Map Information

Use these commands in-game to get map IDs for reference:

**Get current map:**
```lua
/run local m=C_Map.GetBestMapForUnit("player");if m then local i=C_Map.GetMapInfo(m);print("Current Map ID:",m,"Current Map Name:",i and i.name or "N/A")end
```

**Get parent map:**
```lua
/run local m=C_Map.GetBestMapForUnit("player");if m then local i=C_Map.GetMapInfo(m);if i and i.parentMapID then local p=C_Map.GetMapInfo(i.parentMapID);print("Parent Map ID:",i.parentMapID,"Parent Map Name:",p and p.name or "N/A")else print("No parent map")end end
```

## Important Notes

- **Color codes** (like `|cff00ff88`, `|r`) must be kept unchanged
- **Format strings** (like `%s`, `%d`) must be kept unchanged
- Language code must match WoW client language exactly (e.g., `enUS`, `zhCN`, `frFR`, `deDE`)
- Test with `/reload` after making changes

## Current Supported Languages

- `enUS` - English (default fallback)
- `zhCN` - Simplified Chinese
- `zhTW` - Traditional Chinese
- `ruRU` - Russian

---

# 翻译指南

**插件版本**: 1.1.6

## 快速开始

1. 复制 `Locales/enUS.lua` 并重命名为你的语言代码（例如：`frFR.lua`、`deDE.lua`、`esES.lua`）
2. 打开文件并翻译文本
3. 将文件添加到 `Load.xml`（在 `enUS.lua` 之前）
4. 在游戏中使用 `/reload` 测试

## 必须翻译的内容

### 1. 语言代码（2处）

找到并替换两处 `"enUS"` 为你的语言代码：

**第8行** - 错误处理：
```lua
locale = "你的语言代码",  -- 例如: "frFR"
```

**第129行** - 注册：
```lua
LocaleManager.RegisterLocale("你的语言代码", localeData);
```

### 2. 需要翻译的内容

## 可选翻译内容

所有UI文本字符串可以翻译：

```lua
localeData["AirdropDetected"] = "翻译文本";
localeData["TimeRemaining"] = "翻译文本";
// ... 等等
```

- 如果愿意，可以保持英文
- 系统会自动使用英文作为缺失翻译的回退
- 翻译所有字符串可以提供更好的用户体验

## 添加到 Load.xml

在 `Load.xml` 中添加你的语言文件（在 `enUS.lua` 之前）：

```xml
<Script file="Locales/Locales.lua"/>
<Script file="Locales/zhCN.lua"/>
<Script file="Locales/zhTW.lua"/>
<Script file="Locales/ruRU.lua"/>
<Script file="Locales/你的语言代码.lua"/>  <!-- 添加在这里 -->
<Script file="Locales/enUS.lua"/>  <!-- 必须放在最后 -->
```

## 获取地图信息

在游戏中使用以下命令获取地图ID作为参考：

**获取当前地图：**
```lua
/run local m=C_Map.GetBestMapForUnit("player");if m then local i=C_Map.GetMapInfo(m);print("当前地图ID:",m,"当前地图名称:",i and i.name or "N/A")end
```

**获取父地图：**
```lua
/run local m=C_Map.GetBestMapForUnit("player");if m then local i=C_Map.GetMapInfo(m);if i and i.parentMapID then local p=C_Map.GetMapInfo(i.parentMapID);print("父地图ID:",i.parentMapID,"父地图名称:",p and p.name or "N/A")else print("无父地图")end end
```

## 重要提示

- **颜色代码**（如 `|cff00ff88`、`|r`）必须保持不变
- **格式字符串**（如 `%s`、`%d`）必须保持不变
- 语言代码必须与 WoW 客户端语言完全匹配（例如：`enUS`、`zhCN`、`frFR`、`deDE`）
- 修改后使用 `/reload` 测试

## 当前支持的语言

- `enUS` - 英语（默认回退）
- `zhCN` - 简体中文
- `zhTW` - 繁体中文
- `ruRU` - 俄语

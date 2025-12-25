# Translation Guide

**Addon Version**: 1.1.2

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

### 2. MapNames Table (REQUIRED)

**Lines 113-121** - All 7 map entries must be translated:

```lua
localeData.MapNames = {
    [2248] = "Translation for Isle of Dorn",
    [2369] = "Translation for Siren Isle",
    [2371] = "Translation for K'aresh",
    [2346] = "Translation for Undermine",
    [2215] = "Translation for Hallowfall",
    [2214] = "Translation for The Ringing Deeps",
    [2255] = "Translation for Azj-Kahet",
};
```

**Important Notes:**
- Keep the numbers `[2248]`, `[2369]`, etc. unchanged
- Map names are only for display - you can use abbreviations or any format you prefer
- Missing entries will show as "Map [ID]"

### 3. AirdropCrateNames Table (REQUIRED)

**Lines 124-126** - Must translate:

```lua
localeData.AirdropCrateNames = {
    ["WarSupplyCrate"] = "Translation for War Supply Crate",
};
```

**Important:** Keep `"WarSupplyCrate"` unchanged, only translate the value.

## What Can Be Translated (Optional)

**Lines 17-110** - All UI text strings can be translated:

```lua
localeData["AddonLoaded"] = "Translation here";
localeData["HelpCommandHint"] = "Translation here";
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

**插件版本**: 1.1.2

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

### 2. MapNames 表（必需）

**第113-121行** - 必须翻译所有7个地图条目：

```lua
localeData.MapNames = {
    [2248] = "多恩岛的翻译",
    [2369] = "海妖岛的翻译",
    [2371] = "卡雷什的翻译",
    [2346] = "安德麦的翻译",
    [2215] = "陨圣峪的翻译",
    [2214] = "喧鸣深窟的翻译",
    [2255] = "艾基-卡赫特的翻译",
};
```

**重要提示：**
- 保持数字 `[2248]`、`[2369]` 等不变
- 地图名称仅用于显示，可以使用简写或任何你喜欢的格式
- 缺失条目会显示为 "Map [ID]"

### 3. AirdropCrateNames 表（必需）

**第124-126行** - 必须翻译：

```lua
localeData.AirdropCrateNames = {
    ["WarSupplyCrate"] = "战争物资箱的翻译",
};
```

**重要：** 保持 `"WarSupplyCrate"` 不变，只翻译值。

## 可选翻译内容

**第17-110行** - 所有UI文本字符串可以翻译：

```lua
localeData["AddonLoaded"] = "翻译文本";
localeData["HelpCommandHint"] = "翻译文本";
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

# Translation Guide

**Addon Version**: 1.2.1

## Quick Start

1. Copy `Locales/enUS.lua` and rename it to your locale code (e.g., `frFR.lua`, `deDE.lua`).
2. Replace the locale code in two places:

```lua
table.insert(LocaleManager.failedLocales, {
    locale = "xxXX",
    reason = "RegisterLocale function not available"
});

LocaleManager.RegisterLocale("xxXX", localeData);
```

3. Translate all `localeData["..."]` values.
4. (Optional) Update `localeData.AirdropShouts`. If omitted or empty, NPC shout detection will be disabled.
5. Add your file to `Load.xml` (before `enUS.lua`).
6. Test in-game with `/reload`.

## Required Changes

- Locale code in the two places shown above.
- All string values in `localeData["..."]` (UI/notifications/commands).

## Optional

- `localeData.AirdropShouts`: improves shout detection. Safe to leave empty or keep English.

## Do Not Translate / Do Not Add

- Key names, table names, or function names.
- Placeholders like `%s`, `%d`, and color codes like `|cff00ff88`, `|r`.
- Map names: map names now come from the game API. Do not add `MapNames` (deprecated).

## Add to Load.xml

```xml
<Script file="Locales/Locales.lua"/>
<Script file="Locales/zhCN.lua"/>
<Script file="Locales/zhTW.lua"/>
<Script file="Locales/ruRU.lua"/>
<Script file="Locales/your_language_code.lua"/>  <!-- Add here -->
<Script file="Locales/enUS.lua"/>  <!-- Must be last -->
```

## Current Supported Languages

- `enUS` - English (default fallback)
- `zhCN` - Simplified Chinese
- `zhTW` - Traditional Chinese
- `ruRU` - Russian

---

# 翻译指南

**插件版本**: 1.2.1

## 快速开始

1. 复制 `Locales/enUS.lua` 并重命名为你的语言代码（例如：`frFR.lua`、`deDE.lua`）。
2. 替换两处语言代码：

```lua
table.insert(LocaleManager.failedLocales, {
    locale = "xxXX",
    reason = "RegisterLocale function not available"
});

LocaleManager.RegisterLocale("xxXX", localeData);
```

3. 翻译所有 `localeData["..."]` 的字符串值。
4. （可选）补充 `localeData.AirdropShouts`。为空或不提供将禁用 NPC 喊话检测。
5. 将语言文件加入 `Load.xml`（放在 `enUS.lua` 之前）。
6. 游戏内使用 `/reload` 测试。

## 必须修改

- 上述两处语言代码。
- `localeData["..."]` 的所有字符串内容（UI/通知/命令）。

## 可选项

- `localeData.AirdropShouts`：提高喊话检测效果，可留空或保留英文。

## 不要翻译 / 不要新增

- 键名、表名、函数名。
- `%s`、`%d` 等格式占位符与 `|cff...|r` 颜色代码。
- 地图名称：地图名已由游戏 API 提供，不再使用本地化 `MapNames`（已废弃）。

## 添加到 Load.xml

```xml
<Script file="Locales/Locales.lua"/>
<Script file="Locales/zhCN.lua"/>
<Script file="Locales/zhTW.lua"/>
<Script file="Locales/ruRU.lua"/>
<Script file="Locales/你的语言代码.lua"/>  <!-- 添加在这里 -->
<Script file="Locales/enUS.lua"/>  <!-- 必须放在最后 -->
```

## 当前支持的语言

- `enUS` - 英语（默认回退）
- `zhCN` - 简体中文
- `zhTW` - 繁体中文
- `ruRU` - 俄语

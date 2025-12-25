# Translation Guide

**Addon Version**: 1.1.2-beta

## How to Add New Language Support

### Step 1: Copy Template File

Copy `Locales/enUS.lua` or `Locales/zhCN.lua` as a template, and rename it to your language code (e.g., `frFR.lua`, `deDE.lua`).

**Recommended**: Use `enUS.lua` as the template for better compatibility.

### Step 2: Modify File Content

#### 2.1 Update Language Code in Error Handling (Line 8)

Find the error handling section at the beginning of the file and update the locale code:

```lua
table.insert(LocaleManager.failedLocales, {
    locale = "your_language_code",  -- e.g., "frFR", "deDE"
    reason = "RegisterLocale function not available"
});
```

#### 2.2 Update Registration Code (Line 129)

At the end of the file, update the registration call:

```lua
LocaleManager.RegisterLocale("your_language_code", localeData);
```

#### 2.3 Translate All Text

1. **Translate all UI text** in `localeData["key"] = "translation";` format
   - Lines 17-110 contain all UI text strings
   - You can keep non-critical strings in English, the system will automatically fall back

2. **MUST translate: MapNames table** (Lines 113-121)
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
   - **Important**: Use numeric map IDs as keys (not strings)
   - Missing map names will cause functionality issues

3. **MUST translate: AirdropCrateNames table** (Lines 124-126)
   ```lua
   localeData.AirdropCrateNames = {
       ["WarSupplyCrate"] = "Translation for War Supply Crate",
   };
   ```
   - **Important**: Keep the key `"WarSupplyCrate"` unchanged
   - Missing crate names will cause functionality issues

### Step 3: Add to Load List

Add your language file in `Load.xml` between lines 11-14 (note: `enUS.lua` must be placed last):

```xml
<Script file="Locales/your_language_code.lua"/>
```

**Example** (adding French support):
```xml
<Script file="Locales/Locales.lua"/>
<Script file="Locales/zhCN.lua"/>
<Script file="Locales/zhTW.lua"/>
<Script file="Locales/ruRU.lua"/>
<Script file="Locales/frFR.lua"/>  <!-- Newly added language -->
<Script file="Locales/enUS.lua"/>  <!-- Must be placed last -->
```

### Step 4: Test

1. Reload the addon using `/reload` in-game
2. The addon will automatically detect and use your language file
3. Check the chat for any localization warnings
4. Verify that map names and crate names display correctly

## File Structure Reference

### Language File Structure

```
Locales/your_language_code.lua
├── Lines 1-2: File header comments
├── Lines 3-13: LocaleManager initialization and error handling
├── Line 15: localeData table initialization
├── Lines 17-110: UI text translations (localeData["key"] = "value")
├── Lines 113-121: MapNames table (REQUIRED)
├── Lines 124-126: AirdropCrateNames table (REQUIRED)
└── Line 129: Locale registration
```

### Current Supported Languages

- `enUS` - English (default fallback)
- `zhCN` - Simplified Chinese
- `zhTW` - Traditional Chinese
- `ruRU` - Russian

## Important Notes

### Required Translations

- **MapNames**: All 7 map entries must be translated
  - Missing entries will cause map names to display as "Map [ID]"
  - Use numeric keys matching the map IDs from `Data/MapConfig.lua`

- **AirdropCrateNames**: The `WarSupplyCrate` entry must be translated
  - Missing entry will cause crate names to display incorrectly
  - Keep the key `"WarSupplyCrate"` unchanged

### Optional Translations

- All other UI text can remain in English
- The system will automatically fall back to English for missing translations
- However, translating all strings provides a better user experience

### Language Code Requirements

- Language code must match the WoW client language code exactly
- Common codes: `enUS`, `zhCN`, `zhTW`, `ruRU`, `frFR`, `deDE`, `esES`, `ptBR`, `koKR`, `jaJP`
- Check your WoW client language in the game settings

### Color Codes

Some strings contain WoW color codes (e.g., `|cff00ff88`, `|r`). Keep these codes unchanged:

```lua
localeData["Prefix"] = "|cff00ff88[CrateTrackerZK]|r ";
localeData["CurrentInstanceID"] = "Current phasing ID: |cffffff00%s|r";
```

- `|cffRRGGBB` - Start color (RR=Red, GG=Green, BB=Blue in hexadecimal)
- `|r` - Reset color to default

### Format Strings

Some strings contain format specifiers (e.g., `%s`, `%d`). Keep these unchanged:

```lua
localeData["CurrentInstanceID"] = "Current phasing ID: |cffffff00%s|r";
localeData["MinuteSecond"] = "%dm%02ds";
```

- `%s` - String placeholder
- `%d` - Integer placeholder
- `%02d` - Integer with zero-padding (2 digits)

## Troubleshooting

### Language Not Loading

1. Check that the file is in the `Locales/` directory
2. Verify the file is added to `Load.xml` before `enUS.lua`
3. Check for syntax errors in the Lua file
4. Look for error messages in the chat after `/reload`

### Missing Translations Warning

If you see warnings about missing translations:
1. Check that all MapNames entries are present
2. Check that AirdropCrateNames entry is present
3. Verify the keys match exactly (case-sensitive)

### Map Names Not Displaying

1. Ensure MapNames table uses numeric keys (not strings)
2. Verify map IDs match those in `Data/MapConfig.lua`
3. Check that the table is properly formatted with square brackets: `[2248] = "Name"`

## Example: Adding French (frFR) Support

1. **Copy template**:
   ```bash
   cp Locales/enUS.lua Locales/frFR.lua
   ```

2. **Update error handling** (line 8):
   ```lua
   locale = "frFR",
   ```

3. **Update registration** (line 129):
   ```lua
   LocaleManager.RegisterLocale("frFR", localeData);
   ```

4. **Translate text** (example):
   ```lua
   localeData["AddonLoaded"] = "Addon chargé, profitez de votre jeu !";
   localeData["HelpCommandHint"] = "Utilisez |cffffcc00/ctk help|r pour voir les informations d'aide";
   
   localeData.MapNames = {
       [2248] = "Île de Dorn",
       [2369] = "Île des Sirènes",
       -- ... etc
   };
   
   localeData.AirdropCrateNames = {
       ["WarSupplyCrate"] = "Caisse de Fournitures de Guerre",
   };
   ```

5. **Add to Load.xml** (before enUS.lua):
   ```xml
   <Script file="Locales/frFR.lua"/>
   ```

6. **Test**: `/reload` in-game

---

# 翻译指南

**插件版本**: 1.1.2-beta

## 如何添加新语言支持

### 步骤 1：复制模板文件

复制 `Locales/enUS.lua` 或 `Locales/zhCN.lua` 作为模板，重命名为你的语言代码（例如：`frFR.lua`、`deDE.lua`）。

**推荐**：使用 `enUS.lua` 作为模板，兼容性更好。

### 步骤 2：修改文件内容

#### 2.1 更新错误处理中的语言代码（第8行）

在文件开头的错误处理部分更新语言代码：

```lua
table.insert(LocaleManager.failedLocales, {
    locale = "你的语言代码",  -- 例如: "frFR", "deDE"
    reason = "RegisterLocale function not available"
});
```

#### 2.2 更新注册代码（第129行）

在文件末尾更新注册调用：

```lua
LocaleManager.RegisterLocale("你的语言代码", localeData);
```

#### 2.3 翻译所有文本

1. **翻译所有UI文本**，格式为 `localeData["键名"] = "翻译文本";`
   - 第17-110行包含所有UI文本字符串
   - 非关键字符串可以保持英文，系统会自动回退

2. **必须翻译：MapNames 表**（第113-121行）
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
   - **重要**：使用数字地图ID作为键（不是字符串）
   - 缺失地图名称会导致功能异常

3. **必须翻译：AirdropCrateNames 表**（第124-126行）
   ```lua
   localeData.AirdropCrateNames = {
       ["WarSupplyCrate"] = "战争物资箱的翻译",
   };
   ```
   - **重要**：保持键名 `"WarSupplyCrate"` 不变
   - 缺失箱子名称会导致功能异常

### 步骤 3：添加到加载列表

在 `Load.xml` 文件的第11-14行之间添加你的语言文件（注意：`enUS.lua` 必须放在最后）：

```xml
<Script file="Locales/你的语言代码.lua"/>
```

**示例**（添加法语支持）：
```xml
<Script file="Locales/Locales.lua"/>
<Script file="Locales/zhCN.lua"/>
<Script file="Locales/zhTW.lua"/>
<Script file="Locales/ruRU.lua"/>
<Script file="Locales/frFR.lua"/>  <!-- 新添加的语言 -->
<Script file="Locales/enUS.lua"/>  <!-- 必须放在最后 -->
```

### 步骤 4：测试

1. 在游戏中使用 `/reload` 重新加载插件
2. 插件会自动检测并使用你的语言文件
3. 检查聊天窗口是否有本地化警告
4. 验证地图名称和箱子名称是否正确显示

## 文件结构参考

### 语言文件结构

```
Locales/你的语言代码.lua
├── 第1-2行: 文件头注释
├── 第3-13行: LocaleManager 初始化和错误处理
├── 第15行: localeData 表初始化
├── 第17-110行: UI文本翻译 (localeData["键名"] = "值")
├── 第113-121行: MapNames 表（必需）
├── 第124-126行: AirdropCrateNames 表（必需）
└── 第129行: 语言注册
```

### 当前支持的语言

- `enUS` - 英语（默认回退）
- `zhCN` - 简体中文
- `zhTW` - 繁体中文
- `ruRU` - 俄语

## 重要提示

### 必需翻译项

- **MapNames**：必须翻译所有7个地图条目
  - 缺失条目会导致地图名称显示为 "Map [ID]"
  - 使用数字键，匹配 `Data/MapConfig.lua` 中的地图ID

- **AirdropCrateNames**：必须翻译 `WarSupplyCrate` 条目
  - 缺失条目会导致箱子名称显示错误
  - 保持键名 `"WarSupplyCrate"` 不变

### 可选翻译项

- 所有其他UI文本可以保持英文
- 系统会自动回退到英文显示缺失的翻译
- 但翻译所有字符串可以提供更好的用户体验

### 语言代码要求

- 语言代码必须与 WoW 客户端语言代码完全匹配
- 常见代码：`enUS`、`zhCN`、`zhTW`、`ruRU`、`frFR`、`deDE`、`esES`、`ptBR`、`koKR`、`jaJP`
- 在游戏设置中查看你的 WoW 客户端语言

### 颜色代码

某些字符串包含 WoW 颜色代码（例如：`|cff00ff88`、`|r`）。保持这些代码不变：

```lua
localeData["Prefix"] = "|cff00ff88[CrateTrackerZK]|r ";
localeData["CurrentInstanceID"] = "当前位面ID为：|cffffff00%s|r";
```

- `|cffRRGGBB` - 开始颜色（RR=红色，GG=绿色，BB=蓝色，十六进制）
- `|r` - 重置为默认颜色

### 格式字符串

某些字符串包含格式说明符（例如：`%s`、`%d`）。保持这些不变：

```lua
localeData["CurrentInstanceID"] = "当前位面ID为：|cffffff00%s|r";
localeData["MinuteSecond"] = "%d分%02d秒";
```

- `%s` - 字符串占位符
- `%d` - 整数占位符
- `%02d` - 零填充整数（2位数字）

## 故障排除

### 语言未加载

1. 检查文件是否在 `Locales/` 目录中
2. 确认文件已添加到 `Load.xml` 中，且在 `enUS.lua` 之前
3. 检查 Lua 文件中是否有语法错误
4. 在 `/reload` 后查看聊天窗口中的错误消息

### 缺失翻译警告

如果看到缺失翻译的警告：
1. 检查所有 MapNames 条目是否存在
2. 检查 AirdropCrateNames 条目是否存在
3. 验证键名是否完全匹配（区分大小写）

### 地图名称未显示

1. 确保 MapNames 表使用数字键（不是字符串）
2. 验证地图ID是否与 `Data/MapConfig.lua` 中的匹配
3. 检查表格式是否正确，使用方括号：`[2248] = "名称"`

## 示例：添加法语（frFR）支持

1. **复制模板**：
   ```bash
   cp Locales/enUS.lua Locales/frFR.lua
   ```

2. **更新错误处理**（第8行）：
   ```lua
   locale = "frFR",
   ```

3. **更新注册**（第129行）：
   ```lua
   LocaleManager.RegisterLocale("frFR", localeData);
   ```

4. **翻译文本**（示例）：
   ```lua
   localeData["AddonLoaded"] = "Addon chargé, profitez de votre jeu !";
   localeData["HelpCommandHint"] = "Utilisez |cffffcc00/ctk help|r pour voir les informations d'aide";
   
   localeData.MapNames = {
       [2248] = "Île de Dorn",
       [2369] = "Île des Sirènes",
       -- ... 等等
   };
   
   localeData.AirdropCrateNames = {
       ["WarSupplyCrate"] = "Caisse de Fournitures de Guerre",
   };
   ```

5. **添加到 Load.xml**（在 enUS.lua 之前）：
   ```xml
   <Script file="Locales/frFR.lua"/>
   ```

6. **测试**：在游戏中使用 `/reload`

---

**最后更新**: 2024年  
**版本**: 1.1.2-beta

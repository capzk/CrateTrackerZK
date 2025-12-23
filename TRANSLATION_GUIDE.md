# Translation Guide

## How to Add New Language Support

### Step 1: Copy Template File

Copy `enUS.lua` or `zhCN.lua` as a template, and rename it to your language code (e.g., `frFR.lua`, `deDE.lua`).

### Step 2: Modify File Content

1. **Change the language code on line 9**:
   ```lua
   locale = "your_language_code",  -- e.g., "frFR", "deDE"
   ```

2. **Change the registration code at the end of the file** (around line 202):
   ```lua
   LocaleManager.RegisterLocale("your_language_code", localeData);
   ```

3. **Translate all text**:
   - Translate all text in `localeData["key"] = "translation";`
   - **Must translate**: All map names in the `MapNames` table (around lines 152-160)
   - **Must translate**: All airdrop crate names in the `AirdropCrateNames` table (around lines 165-167)
   - Other UI text can remain in English, the system will automatically fall back to English

### Step 3: Add to Load List

Add your language file in `Load.xml` between lines 8-14 (note: `enUS.lua` must be placed last):

```xml
<Script file="Locales/your_language_code.lua"/>
```

Example:
```xml
<Script file="Locales/Locales.lua"/>
<Script file="Locales/zhCN.lua"/>
<Script file="Locales/zhTW.lua"/>
<Script file="Locales/ruRU.lua"/>
<Script file="Locales/frFR.lua"/>  <!-- Newly added language -->
<Script file="Locales/enUS.lua"/>  <!-- Must be placed last -->
```

### Step 4: Test

Reload the addon (`/reload`), and the addon will automatically detect and use your language file.

## Important Notes

- **Map names** and **airdrop crate names** are required translations, missing them will cause functionality issues
- Other UI text can remain in English, the system will automatically fall back
- Language code must match the WoW client language code (e.g., `zhCN`, `enUS`, `frFR`, `deDE`, etc.)

---

# 翻译指南

## 如何添加新语言支持

### 步骤 1：复制模板文件

复制 `enUS.lua` 或 `zhCN.lua` 作为模板，重命名为你的语言代码（例如：`frFR.lua`、`deDE.lua`）。

### 步骤 2：修改文件内容

1. **修改第9行的语言代码**：
   ```lua
   locale = "你的语言代码",  -- 例如: "frFR", "deDE"
   ```

2. **修改文件末尾的注册代码**（最后一行，约第202行）：
   ```lua
   LocaleManager.RegisterLocale("你的语言代码", localeData);
   ```

3. **翻译所有文本**：
   - 翻译所有 `localeData["键名"] = "翻译文本";` 中的文本
   - **必须翻译**：`MapNames` 表中的所有地图名称（约第152-160行）
   - **必须翻译**：`AirdropCrateNames` 表中的空投箱子名称（约第165-167行）
   - 其他UI文本可以保持英文，系统会自动回退到英文显示

### 步骤 3：添加到加载列表

在 `Load.xml` 文件的第8-14行之间，添加你的语言文件（注意：`enUS.lua` 必须放在最后）：

```xml
<Script file="Locales/你的语言代码.lua"/>
```

例如：
```xml
<Script file="Locales/Locales.lua"/>
<Script file="Locales/zhCN.lua"/>
<Script file="Locales/zhTW.lua"/>
<Script file="Locales/ruRU.lua"/>
<Script file="Locales/frFR.lua"/>  <!-- 新添加的语言 -->
<Script file="Locales/enUS.lua"/>  <!-- 必须放在最后 -->
```

### 步骤 4：测试

重新加载插件（`/reload`），插件会自动检测并使用你的语言文件。

## 重要提示

- **地图名称**和**空投箱子名称**是必需翻译项，缺失会导致功能异常
- 其他UI文本可以保持英文，系统会自动回退
- 语言代码必须与 WoW 客户端语言代码一致（例如：`zhCN`、`enUS`、`frFR`、`deDE` 等）

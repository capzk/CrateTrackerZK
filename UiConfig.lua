-- UiConfig.lua - 界面配置（RGB + 透明度）/ UI config (RGB + alpha)

local UIConfig = BuildEnv("UIConfig")

UIConfig = UIConfig or {}

-- =====================================================
-- 使用说明 / Usage
-- - 颜色格式：{R, G, B, A}，R/G/B=0-255，A=0-1
-- - 示例：{255, 255, 255, 0.2}
-- - 所有颜色会自动转换为 WoW 0-1 颜色
-- =====================================================

-- =====================================================
-- 内部函数（勿改）/ Internal (do not edit)
-- =====================================================
local function RGBToWoW(r, g, b, a)
    return {r / 255, g / 255, b / 255, a or 1.0}
end

-- =====================================================
-- 用户可修改配置 / User editable settings
-- =====================================================

-- 主框架配置 / Main frame (MainFrame.lua)
UIConfig.mainFrame = {
    background = {0, 0, 0, 0.35},               -- 主框架背景 / Background
}

-- 标题栏配置 / Title bar (MainFrame.lua)
UIConfig.titleBar = {
    background = {0, 0, 0, 0.20},               -- 标题栏背景 / Background
    button = {255, 255, 255, 0.18},             -- 标题栏按钮 / Buttons
    buttonHover = {255, 255, 255, 0.28},        -- 标题栏悬停 / Button hover
}

-- 表格配置 / Table (TableUI.lua)
UIConfig.table = {
    header = {255, 255, 255, 0.15},             -- 表头背景 / Header background
    actionButtonNormal = {0, 0, 0, 0},          -- 操作按钮常态 / Action button normal
    actionButtonHover = {255, 255, 255, 0.25},  -- 操作按钮悬停 / Action button hover
    
    -- 数据行背景 / Data row backgrounds
    rows = {
        [1] = {255, 255, 255, 0.20},  -- 第1行 / Row 1
        [2] = {255, 255, 255, 0.15},  -- 第2行 / Row 2
        [3] = {255, 255, 255, 0.20},  -- 第3行 / Row 3
        [4] = {255, 255, 255, 0.15},  -- 第4行 / Row 4
        [5] = {255, 255, 255, 0.20},  -- 第5行 / Row 5
        [6] = {255, 255, 255, 0.15},  -- 第6行 / Row 6
        [7] = {255, 255, 255, 0.20},  -- 第7行 / Row 7
        [8] = {255, 255, 255, 0.15},  -- 第8行 / Row 8
        [9] = {255, 255, 255, 0.20},  -- 第9行 / Row 9
        [10] = {255, 255, 255, 0.15}, -- 第10行 / Row 10
    }
}

-- 文字颜色 / Text colors (TableUI.lua, SettingsPanel.lua)
UIConfig.textColors = {
    normal = {255, 255, 255, 1.0},              -- 普通文字 / Normal
    planeId = {51, 255, 51, 1.0},               -- 位面ID / Phase ID
    deleted = {128, 128, 128, 0.8},             -- 删除态 / Deleted
    
    -- 倒计时 / Countdown
    countdownNormal = {0, 255, 0, 1.0},         -- 正常 / Normal
    countdownWarning = {255, 255, 0, 1.0},      -- 警告 / Warning
    countdownCritical = {255, 51, 51, 1.0},     -- 危险 / Critical
}

-- 功能系统设置（高级）/ System timing (advanced)
UIConfig.countdownCycle = 18 * 60 + 20  -- 空投间隔 / Refresh interval (sec)
UIConfig.warningTime = 10 * 60           -- 警告阈值 / Warning threshold (sec)
UIConfig.criticalTime = 5 * 60           -- 危险阈值 / Critical threshold (sec)

-- 小地图按钮 / Minimap button (MinimapButton.lua)
UIConfig.minimapButtonPosition = 45      -- 按钮角度 / Angle (0-360)
UIConfig.minimapButtonHide = false       -- 是否隐藏 / Hide button
UIConfig.minimapButtonIcon = "Interface\\AddOns\\CrateTrackerZK\\Interface\\Assets\\icon.tga"  -- 图标路径 / Icon path

-- 设置页配色 / Settings panel (SettingsPanel.lua)
UIConfig.settingsTheme = {
    background = {0, 0, 0, 0.55},          -- 背景 / Background
    titleBar = {0, 0, 0, 0.40},            -- 顶栏 / Title bar
    panel = {235, 240, 250, 0.08},         -- 内容区 / Content
    navBg = {235, 240, 250, 0.06},         -- 导航底色 / Nav background
    navItem = {235, 240, 250, 0.12},       -- 导航按钮 / Nav item
    navItemActive = {235, 240, 250, 0.26}, -- 导航激活 / Nav active
    navIndicator = {235, 240, 250, 0.75},  -- 激活条 / Active indicator
    button = {235, 240, 250, 0.18},        -- 按钮 / Button
    buttonHover = {235, 240, 250, 0.30},   -- 悬停 / Hover
    text = {245, 248, 255, 0.95},          -- 文字 / Text
}

-- =====================================================
-- 内部函数（勿改）/ Internal functions (do not edit)
-- =====================================================
-- 获取界面颜色 / UI colors
function UIConfig.GetColor(colorType)
    local color = nil
    
    -- 主框架 / Main frame
    if colorType == "mainFrameBackground" then
        color = UIConfig.mainFrame.background
    -- 标题栏 / Title bar
    elseif colorType == "titleBarBackground" then
        color = UIConfig.titleBar.background
    elseif colorType == "titleBarButton" then
        color = UIConfig.titleBar.button
    elseif colorType == "titleBarButtonHover" then
        color = UIConfig.titleBar.buttonHover
    -- 表格 / Table
    elseif colorType == "tableHeader" then
        color = UIConfig.table.header
    elseif colorType == "actionButtonNormal" then
        color = UIConfig.table.actionButtonNormal
    elseif colorType == "actionButtonHover" then
        color = UIConfig.table.actionButtonHover
    else
        -- 默认色 / Default
        color = {255, 255, 255, 0.16}
    end
    
    if color then
        return RGBToWoW(color[1], color[2], color[3], color[4])
    else
        return RGBToWoW(255, 255, 255, 0.16)
    end
end

-- 获取文字颜色 / Text colors
function UIConfig.GetTextColor(textType)
    local color = UIConfig.textColors[textType] or UIConfig.textColors.normal
    return RGBToWoW(color[1], color[2], color[3], color[4])
end

-- 获取设置页颜色 / Settings panel colors
function UIConfig.GetSettingsColor(colorType)
    local theme = UIConfig.settingsTheme or {}
    local color = theme[colorType]
    if color then
        return RGBToWoW(color[1], color[2], color[3], color[4])
    end
    return RGBToWoW(255, 255, 255, 0.16)
end

-- 获取数据行颜色 / Data row colors
function UIConfig.GetDataRowColor(rowIndex)
    local rowColor = UIConfig.table.rows[rowIndex]
    if rowColor then
        return RGBToWoW(rowColor[1], rowColor[2], rowColor[3], rowColor[4])
    else
        return RGBToWoW(0, 0, 0, 0)
    end
end

return UIConfig

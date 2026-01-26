-- UiConfig.lua - 界面配置（模板化 RGB 配置）

local UIConfig = BuildEnv("UIConfig")

UIConfig = UIConfig or {}

-- ========================================
-- 界面颜色配置系统 (RGB + 透明度格式)
-- ========================================

-- RGB转换函数 (内部使用，用户无需关心)
local function RGBToWoW(r, g, b, a)
    return {r / 255, g / 255, b / 255, a or 1.0}
end

-- 主框架配置 (使用标准RGB值 0-255)
UIConfig.mainFrame = {
    background = {0, 0, 0, 0.15},               -- 主框架背景 RGB(0,0,0) + 75%透明度
}

-- 标题栏配置 (使用标准RGB值 0-255)
UIConfig.titleBar = {
    background = {0, 0, 0, 0.10},               -- 标题栏背景 RGB(0,0,0) + 12%透明度
    button = {255, 255, 255, 0.18},             -- 标题栏按钮 RGB(255,255,255) + 18%透明度
    buttonHover = {255, 255, 255, 0.28},        -- 标题栏按钮悬停 RGB(255,255,255) + 28%透明度
}

-- 表格配置 (使用标准RGB值 0-255)
UIConfig.table = {
    header = {255, 255, 255, 0.15},             -- 表头行背景 RGB(255,255,255) + 15%透明度
    actionButtonNormal = {0, 0, 0, 0},          -- 操作按钮正常状态 RGB(0,0,0) + 完全透明
    actionButtonHover = {255, 255, 255, 0.25},  -- 操作按钮悬停状态 RGB(255,255,255) + 25%透明度
    
    -- 数据行配置 (支持最多10行，使用标准RGB值 0-255)
    rows = {
        [1] = {255, 255, 255, 0.08},  -- 第1行背景 RGB(255,255,255) + 8%透明度
        [2] = {255, 255, 255, 0.12},  -- 第2行背景 RGB(255,255,255) + 12%透明度
        [3] = {255, 255, 255, 0.08},  -- 第3行背景 RGB(255,255,255) + 8%透明度
        [4] = {255, 255, 255, 0.12},  -- 第4行背景 RGB(255,255,255) + 12%透明度
        [5] = {255, 255, 255, 0.08},  -- 第5行背景 RGB(255,255,255) + 8%透明度
        [6] = {255, 255, 255, 0.12},  -- 第6行背景 RGB(255,255,255) + 12%透明度
        [7] = {255, 255, 255, 0.08},  -- 第7行背景 RGB(255,255,255) + 8%透明度
        [8] = {255, 255, 255, 0.12},  -- 第8行背景 RGB(255,255,255) + 12%透明度
        [9] = {255, 255, 255, 0.08},  -- 第9行背景 RGB(255,255,255) + 8%透明度
        [10] = {255, 255, 255, 0.12}, -- 第10行背景 RGB(255,255,255) + 12%透明度
    }
}

-- ========================================
-- 文字颜色设置 (RGB + 透明度格式)
-- ========================================
UIConfig.textColors = {
    normal = {255, 255, 255, 1.0},              -- 普通文字 RGB(255,255,255) 白色
    planeId = {51, 255, 51, 1.0},               -- 位面ID文字 RGB(51,255,51) 绿色
    deleted = {128, 128, 128, 0.8},             -- 删除状态文字 RGB(128,128,128) 灰色
    
    -- 倒计时颜色
    countdownNormal = {0, 255, 0, 1.0},         -- 倒计时正常状态 RGB(0,255,0) 绿色
    countdownWarning = {255, 255, 0, 1.0},      -- 倒计时警告状态 RGB(255,255,0) 黄色 (<10分钟)
    countdownCritical = {255, 51, 51, 1.0},     -- 倒计时危险状态 RGB(255,51,51) 红色 (<5分钟)
}

-- ========================================
-- 功能系统设置
-- ========================================
-- 倒计时系统
UIConfig.countdownCycle = 18 * 60 + 20  -- 18分20秒 = 1100秒
UIConfig.warningTime = 10 * 60           -- 10分钟警告
UIConfig.criticalTime = 5 * 60           -- 5分钟危险

-- 小地图按钮
UIConfig.minimapButtonPosition = 45      -- 按钮位置角度 (0-360度)
UIConfig.minimapButtonHide = false       -- 是否隐藏小地图按钮
UIConfig.minimapButtonIcon = "Interface\\AddOns\\CrateTrackerZK\\Interface\\Assets\\icon.tga"  -- 自定义图标路径

-- ========================================
-- 设置页面配色（RGB + 透明度格式）
-- ========================================
UIConfig.settingsTheme = {
    background = {0, 0, 0, 0.35},          -- 背景
    titleBar = {0, 0, 0, 0.40},            -- 顶部状态栏
    panel = {235, 240, 250, 0.08},         -- 内容区底色
    navBg = {235, 240, 250, 0.06},         -- 左侧导航底色
    navItem = {235, 240, 250, 0.12},       -- 导航按钮
    navItemActive = {235, 240, 250, 0.26}, -- 导航激活态
    navIndicator = {235, 240, 250, 0.75},  -- 激活指示条
    button = {235, 240, 250, 0.18},        -- 按钮
    buttonHover = {235, 240, 250, 0.30},   -- 按钮悬停
    text = {245, 248, 255, 0.95},          -- 文字
}

-- ========================================
-- 统一颜色获取函数 (自动RGB转换)
-- ========================================
-- 获取界面区域颜色 (自动转换RGB到WoW格式)
function UIConfig.GetColor(colorType)
    local color = nil
    
    -- 主框架相关
    if colorType == "mainFrameBackground" then
        color = UIConfig.mainFrame.background
    -- 标题栏相关
    elseif colorType == "titleBarBackground" then
        color = UIConfig.titleBar.background
    elseif colorType == "titleBarButton" then
        color = UIConfig.titleBar.button
    elseif colorType == "titleBarButtonHover" then
        color = UIConfig.titleBar.buttonHover
    -- 表格相关
    elseif colorType == "tableHeader" then
        color = UIConfig.table.header
    elseif colorType == "actionButtonNormal" then
        color = UIConfig.table.actionButtonNormal
    elseif colorType == "actionButtonHover" then
        color = UIConfig.table.actionButtonHover
    else
        -- 默认颜色 RGB(255,255,255) + 16%透明度
        color = {255, 255, 255, 0.16}
    end
    
    -- 自动转换RGB到WoW格式
    if color then
        return RGBToWoW(color[1], color[2], color[3], color[4])
    else
        return RGBToWoW(255, 255, 255, 0.16)  -- 默认白色
    end
end

-- 获取文字颜色 (自动转换RGB到WoW格式)
function UIConfig.GetTextColor(textType)
    local color = UIConfig.textColors[textType] or UIConfig.textColors.normal
    return RGBToWoW(color[1], color[2], color[3], color[4])
end

function UIConfig.GetSettingsColor(colorType)
    local theme = UIConfig.settingsTheme or {}
    local color = theme[colorType]
    if color then
        return RGBToWoW(color[1], color[2], color[3], color[4])
    end
    return RGBToWoW(255, 255, 255, 0.16)
end

-- 获取数据行颜色 (自动转换RGB到WoW格式)
function UIConfig.GetDataRowColor(rowIndex)
    -- 完全依赖配置文件，如果没有配置则返回透明
    local rowColor = UIConfig.table.rows[rowIndex]
    if rowColor then
        return RGBToWoW(rowColor[1], rowColor[2], rowColor[3], rowColor[4])
    else
        -- 如果没有配置，返回完全透明
        return RGBToWoW(0, 0, 0, 0)
    end
end

return UIConfig

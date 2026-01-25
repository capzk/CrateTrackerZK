-- UiConfig.lua - 界面配置 / UI settings

local UIConfig = BuildEnv("UIConfig")

UIConfig.values = UIConfig.values or {
    -- 透明度设置（用户可调）
    -- Opacity settings (user-facing)
    -- 0.0 = 完全透明，1.0 = 完全不透明；改完后需 /reload
    -- 0.0 = fully transparent, 1.0 = fully opaque; /reload required
    -- 推荐范围（保持当前风格）/ Suggested ranges:
    -- backgroundAlpha: 0.60 - 0.85（想更通透就调低 / lower = more transparent）
    -- borderAlpha: 0.10 - 0.25
    -- titleBarAlpha: 0.08 - 0.20
    -- buttonAlpha: 0.12 - 0.25
    -- buttonHoverAlpha: 比 buttonAlpha 高 0.08 - 0.15 / +0.08 to +0.15
    backgroundAlpha = 0.62,        -- 主背景透明度（背景色固定为黑色，只能改透明度）
    borderAlpha = 0.12,            -- 边框透明度
    titleBarAlpha = 0.10,          -- 标题栏透明度
    buttonAlpha = 0.14,            -- 按钮默认透明度
    buttonHoverAlpha = 0.22,       -- 按钮悬停透明度

    -- 文字与状态颜色（用户可调）
    -- Text & status colors (user-facing)
    -- RGBA：{R, G, B, A}，范围 0.0 - 1.0 / Range 0.0 - 1.0
    -- 颜色换算 / RGB to RGBA: RGB(255,255,255) => {1,1,1}
    -- 示例 / Examples: 白 {1,1,1,1}；黑 {0,0,0,1}；半透明白 {1,1,1,0.5}
    textColor = {1, 1, 1, 1},      -- 默认文本颜色（想柔和可用 {0.9,0.9,0.9,1}）
    titleColor = {1, 1, 1, 0.85},  -- 标题文本颜色
    phaseIdColor = {1, 1, 1, 1}, -- 位面ID颜色（无匹配信息时的默认色）
    countdownNormalColor = {0, 1, 0, 1},   -- 倒计时正常颜色（> warningTime）
    countdownWarningColor = {1, 0.5, 0, 1}, -- 倒计时警告颜色（<= warningTime）
    countdownCriticalColor = {1, 0, 0, 1}, -- 倒计时危险颜色（<= criticalTime）

    -- 主框架尺寸（用户可调）/ Main frame size (user-facing)
    frameWidth = 600,              -- 主面板宽度
    frameHeight = 335,             -- 主面板高度

    -- 表格背景色（用户可调）
    -- Table background colors (user-facing)
    -- 表头与数据行建议只改透明度，保持磨砂感
    -- Suggested alpha: header 0.12 - 0.20, rows 0.06 - 0.14
    headerRowColor = {1, 1, 1, 0.12}, -- 表头背景（白色 + 透明度）
    dataRowColors = {
        [1] = {1, 1, 1, 0.05},
        [2] = {1, 1, 1, 0.09},
        [3] = {1, 1, 1, 0.05},
        [4] = {1, 1, 1, 0.09},
        [5] = {1, 1, 1, 0.05},
        [6] = {1, 1, 1, 0.09},
        [7] = {1, 1, 1, 0.05},
        [8] = {1, 1, 1, 0.09},
        [9] = {1, 1, 1, 0.05},
        [10] = {1, 1, 1, 0.09},
    },

    -- 列调试底色（调试用，正常使用无需改）
    -- Column debug colors (debug-only, do not change for normal use)
    columnDebug = {
        enabled = false,
        colors = {
            [1] = {1, 0, 0, 0.08},
            [2] = {0, 1, 0, 0.08},
            [3] = {0, 0, 1, 0.08},
            [4] = {1, 1, 0, 0.08},
            [5] = {1, 0, 1, 0.08},
        },
        headerColors = {
            [1] = {1, 0, 0, 0.12},
            [2] = {0, 1, 0, 0.12},
            [3] = {0, 0, 1, 0.12},
            [4] = {1, 1, 0, 0.12},
            [5] = {1, 0, 1, 0.12},
        },
    },

    -- 倒计时阈值（用户可调，秒）
    -- Countdown thresholds (user-facing, seconds)
    -- <= warningTime 使用警告色，<= criticalTime 使用危险色
    warningTime = 900,
    criticalTime = 300,

    -- 操作按钮颜色（用户可调）
    -- Action button colors (user-facing)
    -- refresh/notify 为默认背景色；当前悬停仅改文字颜色
    -- Want visible button bg: set refresh/notify alpha to 0.08 - 0.15
    actionButtonColors = {
        refresh = {0, 0, 0, 0.04},
        notify = {0, 0, 0, 0.04},
        refreshHover = {1, 0.9, 0.2, 0.45},
        notifyHover = {1, 0.9, 0.2, 0.45},
    },
    -- 操作按钮文字悬停色（用户可调）/ Button text hover color (user-facing)
    actionButtonTextHoverColor = {1, 0.9, 0.2, 1},

    -- 小地图按钮（用户可调）
    -- Minimap button (user-facing)
    -- 角度示例：0=右侧，90=上方，180=左侧，270=下方
    -- Angle examples: 0=right, 90=top, 180=left, 270=bottom
    minimapButtonPosition = 45,    -- 角度（0-360），相对小地图圆周位置
    minimapButtonHide = false,     -- 是否隐藏小地图按钮
    minimapButtonIcon = "Interface\\AddOns\\CrateTrackerZK\\Assets\\icon.tga",
}

return UIConfig

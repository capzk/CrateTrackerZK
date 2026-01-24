-- UiConfig.lua - 界面配置

local UIConfig = BuildEnv("UIConfig")

UIConfig.values = UIConfig.values or {
    -- 透明度设置（0.0 = 完全透明，1.0 = 完全不透明）
    -- 透明度越大越不透明。改完后需 /reload。
    -- 推荐范围（保持当前风格）：
    -- backgroundAlpha: 0.60 - 0.85（当前 0.75，想更通透就调低）
    -- borderAlpha: 0.10 - 0.25
    -- titleBarAlpha: 0.08 - 0.20
    -- buttonAlpha: 0.12 - 0.25
    -- buttonHoverAlpha: 比 buttonAlpha 高 0.08 - 0.15
    backgroundAlpha = 0.62,        -- 主背景透明度（背景色固定为黑色，只能改透明度）
    borderAlpha = 0.12,            -- 边框透明度
    titleBarAlpha = 0.10,          -- 标题栏透明度
    buttonAlpha = 0.14,            -- 按钮默认透明度
    buttonHoverAlpha = 0.22,       -- 按钮悬停透明度

    -- 文字与状态颜色（RGBA：{R, G, B, A}，范围 0.0 - 1.0）
    -- 颜色换算：RGB(255,255,255) => {1,1,1}；RGB(128,128,128) => {0.5,0.5,0.5}
    -- 示例：纯白 {1,1,1,1}；纯黑 {0,0,0,1}；50%透明白 {1,1,1,0.5}
    textColor = {1, 1, 1, 1},      -- 默认文本颜色（想柔和可用 {0.9,0.9,0.9,1}）
    titleColor = {1, 1, 1, 0.85},  -- 标题文本颜色
    phaseIdColor = {1, 1, 1, 1}, -- 位面ID颜色（无匹配信息时的默认色）
    countdownNormalColor = {0, 1, 0, 1},   -- 倒计时正常颜色（> warningTime）
    countdownWarningColor = {1, 0.5, 0, 1}, -- 倒计时警告颜色（<= warningTime）
    countdownCriticalColor = {1, 0, 0, 1}, -- 倒计时危险颜色（<= criticalTime）

    -- 主框架尺寸（像素）
    frameWidth = 600,              -- 主面板宽度
    frameHeight = 335,             -- 主面板高度

    -- 表格背景色（RGBA）
    -- 表头与数据行建议只改透明度，保持磨砂感
    -- 推荐透明度：表头 0.12 - 0.20，数据行 0.06 - 0.14
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

    -- 倒计时阈值（秒）
    -- 小于 warningTime 使用警告色，小于 criticalTime 使用危险色
    warningTime = 900,
    criticalTime = 300,

    -- 操作按钮背景色（RGBA）
    -- refresh/notify 为默认背景色，*Hover 为悬停背景色
    -- 想让按钮常显底色：把 refresh/notify 的 A 调到 0.08 - 0.15
    actionButtonColors = {
        refresh = {0, 0, 0, 0.04},
        notify = {0, 0, 0, 0.04},
        refreshHover = {1, 1, 1, 0.18},
        notifyHover = {1, 1, 1, 0.18},
    },

    -- 小地图按钮
    -- 角度示例：0=右侧，90=上方，180=左侧，270=下方
    minimapButtonPosition = 45,    -- 角度（0-360），相对小地图圆周位置
    minimapButtonHide = false,     -- 是否隐藏小地图按钮
    minimapButtonIcon = "Interface\\AddOns\\CrateTrackerZK\\Assets\\icon.tga",
}

return UIConfig

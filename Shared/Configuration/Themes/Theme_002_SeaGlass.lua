-- Theme_002_SeaGlass.lua - 海玻璃主题

local ThemeConfig = BuildEnv("ThemeConfig")

if not ThemeConfig or not ThemeConfig.RegisterTheme then
    return
end

ThemeConfig:RegisterTheme("sea_glass", {
    label = "Sea Glass",
    mainFrame = {
        background = {27, 60, 71, 0.95},
    },
    titleBar = {
        background = {5, 18, 25, 0.35},
        button = {30, 78, 89, 0.95},
        buttonHover = {195, 238, 245, 0.35},
    },
    table = {
        header = {18, 52, 64, 0.92},
        actionButtonNormal = {0, 0, 0, 0},
        actionButtonHover = {195, 238, 245, 0.25},
        rows = {
            [1] = {20, 56, 68, 0.90},
            [2] = {20, 56, 68, 0.90},
            [3] = {20, 56, 68, 0.90},
            [4] = {20, 56, 68, 0.90},
            [5] = {20, 56, 68, 0.90},
            [6] = {20, 56, 68, 0.90},
            [7] = {20, 56, 68, 0.90},
            [8] = {20, 56, 68, 0.90},
            [9] = {20, 56, 68, 0.90},
            [10] = {20, 56, 68, 0.90},
        },
    },
    textColors = {
        normal = {238, 250, 252, 1.0},
        planeId = {90, 255, 204, 1.0},
        deleted = {128, 128, 128, 0.8},
        countdownNormal = {90, 255, 204, 1.0},
        countdownWarning = {255, 224, 102, 1.0},
        countdownCritical = {255, 102, 102, 1.0},
    },
}, 2)

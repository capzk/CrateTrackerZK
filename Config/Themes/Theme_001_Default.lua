-- Theme_001_Default.lua - 默认主题

local ThemeConfig = BuildEnv("ThemeConfig")

if not ThemeConfig or not ThemeConfig.RegisterTheme then
    return
end

ThemeConfig:RegisterTheme("default", {
    label = "Default",
    mainFrame = {
        background = {38, 51, 77, 0.95},
    },
    titleBar = {
        background = {0, 0, 0, 0.20},
        button = {38, 51, 77, 0.95},
        buttonHover = {255, 255, 255, 0.28},
    },
    table = {
        header = {26, 38, 51, 0.90},
        actionButtonNormal = {0, 0, 0, 0},
        actionButtonHover = {255, 255, 255, 0.25},
        rows = {
            [1] = {26, 38, 51, 0.90},
            [2] = {26, 38, 51, 0.90},
            [3] = {26, 38, 51, 0.90},
            [4] = {26, 38, 51, 0.90},
            [5] = {26, 38, 51, 0.90},
            [6] = {26, 38, 51, 0.90},
            [7] = {26, 38, 51, 0.90},
            [8] = {26, 38, 51, 0.90},
            [9] = {26, 38, 51, 0.90},
            [10] = {26, 38, 51, 0.90},
        },
    },
    textColors = {
        normal = {255, 255, 255, 1.0},
        planeId = {51, 255, 51, 1.0},
        deleted = {128, 128, 128, 0.8},
        countdownNormal = {0, 255, 0, 1.0},
        countdownWarning = {255, 255, 0, 1.0},
        countdownCritical = {255, 51, 51, 1.0},
    },
}, 1)

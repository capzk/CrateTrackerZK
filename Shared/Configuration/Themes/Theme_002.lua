-- Theme_002.lua - 海玻璃主题

local ThemeConfig = BuildEnv("ThemeConfig")

if not ThemeConfig or not ThemeConfig.RegisterTheme then
    return
end

ThemeConfig:RegisterTheme("sea_glass", {
    label = "002",
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
        normal = {255, 255, 255, 1.0},
        tableHeader = {238, 250, 252, 1.0},
        tableHeaderSortDesc = {255, 214, 214, 1.0},
        tableHeaderSortAsc = {180, 255, 224, 1.0},
        planeId = {51, 255, 51, 1.0},
        deleted = {128, 128, 128, 0.8},
        countdownNormal = {0, 255, 0, 1.0},
        countdownWarning = {255, 255, 0, 1.0},
        countdownCritical = {255, 51, 51, 1.0},
    },
}, 2)

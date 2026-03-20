-- Theme_005.lua - 通透玻璃主题

local ThemeConfig = BuildEnv("ThemeConfig")

if not ThemeConfig or not ThemeConfig.RegisterTheme then
    return
end

ThemeConfig:RegisterTheme("pine_signal", {
    label = "005",
    mainFrame = {
        background = {39, 46, 34, 0.96},
    },
    titleBar = {
        background = {0, 0, 0, 0.10},
        button = {255, 255, 255, 0.18},
        buttonHover = {255, 255, 255, 0.28},
    },
    table = {
        header = {55, 65, 45, 1.0},
        actionButtonNormal = {0, 0, 0, 0},
        actionButtonHover = {94, 109, 78, 0.95},
        rows = {
            [1] = {66, 77, 56, 1.0},
            [2] = {59, 69, 50, 1.0},
            [3] = {66, 77, 56, 1.0},
            [4] = {59, 69, 50, 1.0},
            [5] = {66, 77, 56, 1.0},
            [6] = {59, 69, 50, 1.0},
            [7] = {66, 77, 56, 1.0},
            [8] = {59, 69, 50, 1.0},
            [9] = {66, 77, 56, 1.0},
            [10] = {59, 69, 50, 1.0},
        },
    },
    textColors = {
        normal = {255, 255, 255, 1.0},
        tableHeader = {255, 202, 118, 1.0},
        tableHeaderSortDesc = {255, 205, 186, 1.0},
        tableHeaderSortAsc = {198, 244, 214, 1.0},
        planeId = {51, 255, 51, 1.0},
        deleted = {128, 128, 128, 0.8},
        countdownNormal = {0, 255, 0, 1.0},
        countdownWarning = {255, 255, 0, 1.0},
        countdownCritical = {255, 51, 51, 1.0},
    },
}, 5)

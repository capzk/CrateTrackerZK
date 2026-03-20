-- Theme_004.lua - 通透玻璃主题

local ThemeConfig = BuildEnv("ThemeConfig")

if not ThemeConfig or not ThemeConfig.RegisterTheme then
    return
end

ThemeConfig:RegisterTheme("sunforge", {
    label = "004",
    mainFrame = {
        background = {0, 0, 0, 0.05},
    },
    titleBar = {
        background = {0, 0, 0, 0.10},
        button = {255, 255, 255, 0.18},
        buttonHover = {255, 255, 255, 0.28},
    },
    table = {
        header = {255, 255, 255, 0.18},
        actionButtonNormal = {0, 0, 0, 0},
        actionButtonHover = {255, 255, 255, 0.25},
        rows = {
            [1] = {255, 255, 255, 0.14},
            [2] = {255, 255, 255, 0.18},
            [3] = {255, 255, 255, 0.14},
            [4] = {255, 255, 255, 0.18},
            [5] = {255, 255, 255, 0.14},
            [6] = {255, 255, 255, 0.18},
            [7] = {255, 255, 255, 0.14},
            [8] = {255, 255, 255, 0.18},
            [9] = {255, 255, 255, 0.14},
            [10] = {255, 255, 255, 0.18},
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
}, 4)

-- Theme_003.lua - 旧版玻璃感主题

local ThemeConfig = BuildEnv("ThemeConfig")

if not ThemeConfig or not ThemeConfig.RegisterTheme then
    return
end

ThemeConfig:RegisterTheme("legacy_glass", {
    label = "003",
    mainFrame = {
        background = {0, 0, 0, 0.05},
    },
    titleBar = {
        background = {0, 0, 0, 0.10},
        button = {255, 255, 255, 0.18},
        buttonHover = {255, 255, 255, 0.28},
    },
    table = {
        header = {255, 255, 255, 0.15},
        actionButtonNormal = {0, 0, 0, 0},
        actionButtonHover = {255, 255, 255, 0.25},
        rows = {
            [1] = {255, 255, 255, 0.08},
            [2] = {255, 255, 255, 0.12},
            [3] = {255, 255, 255, 0.08},
            [4] = {255, 255, 255, 0.12},
            [5] = {255, 255, 255, 0.08},
            [6] = {255, 255, 255, 0.12},
            [7] = {255, 255, 255, 0.08},
            [8] = {255, 255, 255, 0.12},
            [9] = {255, 255, 255, 0.08},
            [10] = {255, 255, 255, 0.12},
        },
    },
    textColors = {
        normal = {255, 255, 255, 1.0},
        tableHeader = {255, 255, 255, 1.0},
        tableHeaderSortDesc = {255, 204, 204, 1.0},
        tableHeaderSortAsc = {204, 255, 204, 1.0},
        planeId = {51, 255, 51, 1.0},
        deleted = {128, 128, 128, 0.8},
        countdownNormal = {0, 255, 0, 1.0},
        countdownWarning = {255, 255, 0, 1.0},
        countdownCritical = {255, 51, 51, 1.0},
    },
}, 3)

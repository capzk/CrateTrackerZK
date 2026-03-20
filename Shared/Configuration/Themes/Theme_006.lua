-- Theme_006.lua - ElvUI 风格主题

local ThemeConfig = BuildEnv("ThemeConfig")

if not ThemeConfig or not ThemeConfig.RegisterTheme then
    return
end

ThemeConfig:RegisterTheme("moonwell", {
    label = "006",
    mainFrame = {
        background = {21, 24, 29, 0.94},
    },
    titleBar = {
        background = {14, 17, 21, 0.88},
        button = {64, 97, 126, 0.64},
        buttonHover = {92, 132, 166, 0.84},
    },
    table = {
        header = {36, 41, 48, 0.94},
        actionButtonNormal = {0, 0, 0, 0},
        actionButtonHover = {120, 158, 188, 0.22},
        rows = {
            [1] = {28, 32, 38, 0.86},
            [2] = {24, 28, 34, 0.86},
            [3] = {28, 32, 38, 0.86},
            [4] = {24, 28, 34, 0.86},
            [5] = {28, 32, 38, 0.86},
            [6] = {24, 28, 34, 0.86},
            [7] = {28, 32, 38, 0.86},
            [8] = {24, 28, 34, 0.86},
            [9] = {28, 32, 38, 0.86},
            [10] = {24, 28, 34, 0.86},
        },
    },
    textColors = {
        normal = {255, 255, 255, 1.0},
        tableHeader = {236, 240, 245, 1.0},
        tableHeaderSortDesc = {255, 195, 195, 1.0},
        tableHeaderSortAsc = {196, 234, 216, 1.0},
        planeId = {51, 255, 51, 1.0},
        deleted = {114, 121, 131, 0.80},
        countdownNormal = {0, 255, 0, 1.0},
        countdownWarning = {255, 255, 0, 1.0},
        countdownCritical = {255, 51, 51, 1.0},
    },
}, 6)

-- ThemeConfig.lua - 主题注册与切换

local ThemeConfig = BuildEnv("ThemeConfig")

ThemeConfig.defaultThemeID = ThemeConfig.defaultThemeID or "default"
ThemeConfig.enableSwitch = ThemeConfig.enableSwitch ~= false
ThemeConfig.themeOrder = ThemeConfig.themeOrder or {}
ThemeConfig.themes = ThemeConfig.themes or {}

ThemeConfig.countdownCycle = 18 * 60 + 20
ThemeConfig.warningTime = 10 * 60
ThemeConfig.criticalTime = 5 * 60

ThemeConfig.minimapButtonPosition = 45
ThemeConfig.minimapButtonHide = false
ThemeConfig.minimapButtonIcon = "Interface\\AddOns\\CrateTrackerZK\\Assets\\icon.tga"
ThemeConfig.settingsTheme = ThemeConfig.settingsTheme or {
    background = {26, 38, 51, 0.90},
    titleBar = {0, 0, 0, 0.40},
    panel = {235, 240, 250, 0.08},
    navBg = {235, 240, 250, 0.06},
    navItem = {235, 240, 250, 0.12},
    navItemActive = {235, 240, 250, 0.26},
    navIndicator = {235, 240, 250, 0.75},
    button = {235, 240, 250, 0.18},
    buttonHover = {235, 240, 250, 0.30},
    text = {245, 248, 255, 0.95},
}

local FALLBACK_THEME = {
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
    settingsTheme = {
        background = {26, 38, 51, 0.90},
        titleBar = {0, 0, 0, 0.40},
        panel = {235, 240, 250, 0.08},
        navBg = {235, 240, 250, 0.06},
        navItem = {235, 240, 250, 0.12},
        navItemActive = {235, 240, 250, 0.26},
        navIndicator = {235, 240, 250, 0.75},
        button = {235, 240, 250, 0.18},
        buttonHover = {235, 240, 250, 0.30},
        text = {245, 248, 255, 0.95},
    },
}

local function EnsureThemeState()
    if type(ThemeConfig.themeOrder) ~= "table" then
        ThemeConfig.themeOrder = {}
    end
    if type(ThemeConfig.themes) ~= "table" then
        ThemeConfig.themes = {}
    end
end

local function EnsureUIState()
    if not CRATETRACKERZK_UI_DB or type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {}
    end
    return CRATETRACKERZK_UI_DB
end

local function IsValidThemeID(themeID)
    return themeID and ThemeConfig.themes and ThemeConfig.themes[themeID] ~= nil
end

local function RGBToWoW(r, g, b, a)
    return {r / 255, g / 255, b / 255, a or 1.0}
end

local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for k, v in pairs(value) do
        copy[k] = DeepCopy(v)
    end
    return copy
end

local function GetResolvedTheme()
    local active = ThemeConfig:GetActiveTheme()
    if active then
        return active
    end
    return FALLBACK_THEME
end

function ThemeConfig:RegisterTheme(themeID, themeData, orderIndex)
    if type(themeID) ~= "string" or themeID == "" or type(themeData) ~= "table" then
        return false
    end

    EnsureThemeState()
    self.themes[themeID] = DeepCopy(themeData)

    local existingIndex = nil
    for i, id in ipairs(self.themeOrder) do
        if id == themeID then
            existingIndex = i
            break
        end
    end
    if existingIndex then
        table.remove(self.themeOrder, existingIndex)
    end

    if type(orderIndex) == "number" then
        local idx = math.floor(orderIndex)
        if idx < 1 then
            idx = 1
        elseif idx > #self.themeOrder + 1 then
            idx = #self.themeOrder + 1
        end
        table.insert(self.themeOrder, idx, themeID)
    else
        table.insert(self.themeOrder, themeID)
    end

    return true
end

function ThemeConfig:IsSwitchEnabled()
    return self.enableSwitch == true
end

function ThemeConfig:GetThemeList()
    EnsureThemeState()
    local result = {}
    for _, themeID in ipairs(self.themeOrder or {}) do
        local theme = self.themes and self.themes[themeID]
        if theme then
            table.insert(result, {
                id = themeID,
                label = theme.label or themeID,
            })
        end
    end
    return result
end

function ThemeConfig.GetCurrentThemeID()
    local db = EnsureUIState()
    local selected = db.themeID
    if IsValidThemeID(selected) then
        return selected
    end
    if IsValidThemeID(ThemeConfig.defaultThemeID) then
        return ThemeConfig.defaultThemeID
    end
    local list = ThemeConfig:GetThemeList()
    return list[1] and list[1].id or nil
end

function ThemeConfig:SetCurrentThemeID(themeID)
    if not IsValidThemeID(themeID) then
        return false
    end
    local db = EnsureUIState()
    db.themeID = themeID
    return true
end

function ThemeConfig:GetTheme(themeID)
    if not themeID then
        return nil
    end
    return self.themes and self.themes[themeID] or nil
end

function ThemeConfig:GetActiveTheme()
    local themeID = ThemeConfig.GetCurrentThemeID()
    return self:GetTheme(themeID)
end

function ThemeConfig.GetColor(colorType)
    local theme = GetResolvedTheme()
    local color = nil

    if colorType == "mainFrameBackground" then
        color = theme.mainFrame and theme.mainFrame.background
    elseif colorType == "titleBarBackground" then
        color = theme.titleBar and theme.titleBar.background
    elseif colorType == "titleBarButton" then
        color = theme.titleBar and theme.titleBar.button
    elseif colorType == "titleBarButtonHover" then
        color = theme.titleBar and theme.titleBar.buttonHover
    elseif colorType == "tableHeader" then
        color = theme.table and theme.table.header
    elseif colorType == "actionButtonNormal" then
        color = theme.table and theme.table.actionButtonNormal
    elseif colorType == "actionButtonHover" then
        color = theme.table and theme.table.actionButtonHover
    else
        color = {255, 255, 255, 0.16}
    end

    if color then
        return RGBToWoW(color[1], color[2], color[3], color[4])
    end
    return RGBToWoW(255, 255, 255, 0.16)
end

function ThemeConfig.GetTextColor(textType)
    local theme = GetResolvedTheme()
    local textColors = theme.textColors or FALLBACK_THEME.textColors
    local color = textColors[textType] or textColors.normal or FALLBACK_THEME.textColors.normal
    return RGBToWoW(color[1], color[2], color[3], color[4])
end

function ThemeConfig.GetSettingsColor(colorType)
    local settingsTheme = ThemeConfig.settingsTheme or FALLBACK_THEME.settingsTheme
    local color = settingsTheme[colorType]
    if color then
        return RGBToWoW(color[1], color[2], color[3], color[4])
    end
    return RGBToWoW(255, 255, 255, 0.16)
end

function ThemeConfig.GetDataRowColor(rowIndex)
    local theme = GetResolvedTheme()
    local rows = theme.table and theme.table.rows
    local rowColor = rows and rows[rowIndex]
    if rowColor then
        return RGBToWoW(rowColor[1], rowColor[2], rowColor[3], rowColor[4])
    end
    return RGBToWoW(0, 0, 0, 0)
end

return ThemeConfig

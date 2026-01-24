-- MainFrame.lua - 主框架

local MainFrame = BuildEnv("MainFrame")
local UIConfig = BuildEnv("UIConfig")
local SettingsPanel = BuildEnv("CrateTrackerZKSettingsPanel")
local RowStateSystem = BuildEnv("RowStateSystem")

local function GetConfig()
    return UIConfig.values
end

function MainFrame:Create()
    local cfg = GetConfig()
    local frame = CreateFrame("Frame", "CrateTrackerZKFrame", UIParent)
    frame:SetSize(cfg.frameWidth, cfg.frameHeight)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)

    self:CreateBackground(frame)
    self:CreateTitleBar(frame)
    self:CreateTableContainer(frame)

    if RowStateSystem and RowStateSystem.AddClickListenerToTableArea then
        RowStateSystem:AddClickListenerToTableArea(frame)
    end

    return frame
end

local function SaveFramePosition(frame)
    if not CRATETRACKERZK_UI_DB or type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {}
    end
    local point, _, _, x, y = frame:GetPoint()
    CRATETRACKERZK_UI_DB.position = { point = point, x = x, y = y }
end

function MainFrame:CreateBackground(frame)
    local cfg = GetConfig()

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(0, 0, 0, cfg.backgroundAlpha)

    local border = frame:CreateTexture(nil, "BORDER")
    border:SetAllPoints(frame)
    border:SetColorTexture(1, 1, 1, cfg.borderAlpha)

    bg:ClearAllPoints()
    bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)

    self:CreateDragArea(frame)
end

function MainFrame:CreateDragArea(frame)
    local titleDragArea = CreateFrame("Frame", nil, frame)
    titleDragArea:SetSize(598, 22)
    titleDragArea:SetPoint("TOP", frame, "TOP", 0, -1)
    titleDragArea:SetFrameLevel(2)
    titleDragArea:EnableMouse(true)
    titleDragArea:RegisterForDrag("LeftButton")

    local bottomDragArea = CreateFrame("Frame", nil, frame)
    bottomDragArea:SetSize(598, 30)
    bottomDragArea:SetPoint("BOTTOM", frame, "BOTTOM", 0, 1)
    bottomDragArea:SetFrameLevel(2)
    bottomDragArea:EnableMouse(true)
    bottomDragArea:RegisterForDrag("LeftButton")

    local leftDragArea = CreateFrame("Frame", nil, frame)
    leftDragArea:SetSize(20, 220)
    leftDragArea:SetPoint("LEFT", frame, "LEFT", 1, -40)
    leftDragArea:SetFrameLevel(2)
    leftDragArea:EnableMouse(true)
    leftDragArea:RegisterForDrag("LeftButton")

    local rightDragArea = CreateFrame("Frame", nil, frame)
    rightDragArea:SetSize(20, 220)
    rightDragArea:SetPoint("RIGHT", frame, "RIGHT", -1, -40)
    rightDragArea:SetFrameLevel(2)
    rightDragArea:EnableMouse(true)
    rightDragArea:RegisterForDrag("LeftButton")

    for _, dragArea in ipairs({titleDragArea, bottomDragArea, leftDragArea, rightDragArea}) do
        dragArea:SetScript("OnDragStart", function() frame:StartMoving() end)
        dragArea:SetScript("OnDragStop", function()
            frame:StopMovingOrSizing()
            SaveFramePosition(frame)
        end)
    end
end

function MainFrame:CreateTitleBar(frame)
    local cfg = GetConfig()

    local titleBg = frame:CreateTexture(nil, "ARTWORK")
    titleBg:SetSize(598, 22)
    titleBg:SetPoint("TOP", frame, "TOP", 0, -1)
    titleBg:SetColorTexture(0, 0, 0, cfg.titleBarAlpha)

    local titleLine = frame:CreateTexture(nil, "ARTWORK")
    titleLine:SetSize(598, 1)
    titleLine:SetPoint("TOP", titleBg, "BOTTOM", 0, 0)
    titleLine:SetColorTexture(1, 1, 1, cfg.borderAlpha)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("CENTER", titleBg, "CENTER", 0, 0)
    title:SetText("CrateTrackerZK")
    title:SetTextColor(cfg.titleColor[1], cfg.titleColor[2], cfg.titleColor[3], cfg.titleColor[4])
    title:SetJustifyH("CENTER")
    title:SetJustifyV("MIDDLE")
    title:SetShadowOffset(0, 0)

    self:CreateSettingsButton(frame)
    self:CreateCloseButton(frame)
end

function MainFrame:CreateSettingsButton(frame)
    local cfg = GetConfig()
    local settingsButton = CreateFrame("Button", nil, frame)
    settingsButton:SetSize(16, 16)
    settingsButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -35, -3)
    settingsButton:SetFrameLevel(frame:GetFrameLevel() + 20)

    local settingsBg = settingsButton:CreateTexture(nil, "BACKGROUND")
    settingsBg:SetAllPoints(settingsButton)
    settingsBg:SetColorTexture(1, 1, 1, cfg.buttonAlpha)

    local dot1 = settingsButton:CreateTexture(nil, "OVERLAY")
    dot1:SetSize(2, 2)
    dot1:SetPoint("CENTER", settingsButton, "CENTER", -3, 0)
    dot1:SetColorTexture(cfg.textColor[1], cfg.textColor[2], cfg.textColor[3], cfg.textColor[4])

    local dot2 = settingsButton:CreateTexture(nil, "OVERLAY")
    dot2:SetSize(2, 2)
    dot2:SetPoint("CENTER", settingsButton, "CENTER", 0, 0)
    dot2:SetColorTexture(cfg.textColor[1], cfg.textColor[2], cfg.textColor[3], cfg.textColor[4])

    local dot3 = settingsButton:CreateTexture(nil, "OVERLAY")
    dot3:SetSize(2, 2)
    dot3:SetPoint("CENTER", settingsButton, "CENTER", 3, 0)
    dot3:SetColorTexture(cfg.textColor[1], cfg.textColor[2], cfg.textColor[3], cfg.textColor[4])

    settingsButton:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel.Show then
            SettingsPanel:Show()
        end
    end)

    settingsButton:SetScript("OnEnter", function()
        settingsBg:SetColorTexture(1, 1, 1, cfg.buttonHoverAlpha)
    end)
    settingsButton:SetScript("OnLeave", function()
        settingsBg:SetColorTexture(1, 1, 1, cfg.buttonAlpha)
    end)
end

function MainFrame:CreateCloseButton(frame)
    local cfg = GetConfig()
    local closeButton = CreateFrame("Button", nil, frame)
    closeButton:SetSize(16, 16)
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -3)
    closeButton:SetFrameLevel(frame:GetFrameLevel() + 20)

    local closeBg = closeButton:CreateTexture(nil, "BACKGROUND")
    closeBg:SetAllPoints(closeButton)
    closeBg:SetColorTexture(1, 1, 1, cfg.buttonAlpha)

    local line = closeButton:CreateTexture(nil, "OVERLAY")
    line:SetSize(8, 1)
    line:SetPoint("CENTER", closeButton, "CENTER", 0, 0)
    line:SetColorTexture(cfg.textColor[1], cfg.textColor[2], cfg.textColor[3], cfg.textColor[4])

    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    closeButton:SetScript("OnEnter", function()
        closeBg:SetColorTexture(1, 1, 1, cfg.buttonHoverAlpha)
    end)
    closeButton:SetScript("OnLeave", function()
        closeBg:SetColorTexture(1, 1, 1, cfg.buttonAlpha)
    end)
end

function MainFrame:CreateTableContainer(frame)
    local tableContainer = frame:CreateTexture(nil, "ARTWORK")
    tableContainer:SetSize(580, 255)
    tableContainer:SetPoint("CENTER", frame, "CENTER", 0, -10)
    tableContainer:SetColorTexture(0, 0, 0, 0)
end

return MainFrame

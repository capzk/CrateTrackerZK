-- MainFrame.lua - 主框架

local MainFrame = BuildEnv("MainFrame")
local UIConfig = BuildEnv("UIConfig")
local SettingsPanel = BuildEnv("CrateTrackerZKSettingsPanel")
local RowStateSystem = BuildEnv("RowStateSystem")

local FRAME_CFG = {
    width = 600,
    height = 335,
    minScale = 0.6,
    maxScale = 1.25,
    minWidth = 360,
    minHeight = 201,
    maxWidth = 750,
    maxHeight = 419,
}

local TABLE_PADDING_EXTRA = 4

local function EnsureUIState()
    if not CRATETRACKERZK_UI_DB or type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {}
    end
end

local function NotifyLayoutChanged(frame)
    if frame and frame.OnLayoutChanged then
        frame:OnLayoutChanged()
    end
end

local function NotifyLayoutChangedIfNeeded(frame)
    if not frame then
        return
    end
    local width = math.floor((frame:GetWidth() or 0) * 100 + 0.5)
    local height = math.floor((frame:GetHeight() or 0) * 100 + 0.5)
    if frame.lastLayoutWidth == width and frame.lastLayoutHeight == height then
        return
    end
    frame.lastLayoutWidth = width
    frame.lastLayoutHeight = height
    NotifyLayoutChanged(frame)
end

local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function ApplyFontScale(fontString, scale, minSize, maxSize)
    if not fontString or not fontString.GetFont then
        return
    end
    if not fontString.__ctkBaseFont then
        local font, size, flags = fontString:GetFont()
        if not font then
            local defaultFont, defaultSize, defaultFlags = GameFontNormal:GetFont()
            font, size, flags = defaultFont, defaultSize, defaultFlags
        end
        fontString.__ctkBaseFont = {
            font = font,
            size = size or 12,
            flags = flags,
        }
    end
    local base = fontString.__ctkBaseFont
    local scaled = math.floor(base.size * (scale or 1) + 0.5)
    scaled = Clamp(scaled, minSize or 8, maxSize or 18)
    fontString:SetFont(base.font, scaled, base.flags)
end

local function GetFrameScale(frame)
    local width = frame and frame:GetWidth() or FRAME_CFG.width
    return Clamp(width / FRAME_CFG.width, FRAME_CFG.minScale, FRAME_CFG.maxScale)
end

function MainFrame:ApplyScaledChrome(frame, scale)
    if not frame then
        return
    end
    local scaled = scale or GetFrameScale(frame)
    local handleSize = math.max(12, math.floor(16 * scaled + 0.5))
    local handleInset = math.max(1, math.floor(2 * scaled + 0.5))
    local titleHeight = math.max(14, math.floor(22 * scaled + 0.5))
    local sideWidth = math.max(14, math.floor(20 * scaled + 0.5))
    local bottomHeight = math.max(20, math.floor(30 * scaled + 0.5))
    local extraInset = math.floor(TABLE_PADDING_EXTRA * scaled + 0.5)
    local tableInset = math.max(6, math.floor(10 * scaled + 0.5) + extraInset)
    local tableTopInset = math.max(22, math.floor(30 * scaled + 0.5) + extraInset)

    if frame.titleDragArea then
        frame.titleDragArea:SetHeight(titleHeight)
    end
    if frame.bottomDragArea then
        frame.bottomDragArea:SetHeight(bottomHeight)
        frame.bottomDragArea:ClearAllPoints()
        frame.bottomDragArea:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
        frame.bottomDragArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(handleSize + handleInset + 4), 1)
    end
    if frame.leftDragArea then
        frame.leftDragArea:SetWidth(sideWidth)
        frame.leftDragArea:ClearAllPoints()
        frame.leftDragArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -(titleHeight + 1))
        frame.leftDragArea:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, bottomHeight + 1)
    end
    if frame.rightDragArea then
        frame.rightDragArea:SetWidth(sideWidth)
        frame.rightDragArea:ClearAllPoints()
        frame.rightDragArea:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -(titleHeight + 1))
        frame.rightDragArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, bottomHeight + 1)
    end

    if frame.titleBg then
        frame.titleBg:SetHeight(titleHeight)
    end
    if frame.titleText then
        ApplyFontScale(frame.titleText, scaled, 8, 16)
    end

    if frame.settingsButton then
        local btnSize = math.max(12, math.floor(16 * scaled + 0.5))
        frame.settingsButton:SetSize(btnSize, btnSize)
        frame.settingsButton:ClearAllPoints()
        frame.settingsButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -math.floor(35 * scaled + 0.5), -math.floor(3 * scaled + 0.5))
        local dotSize = math.max(1, math.floor(2 * scaled + 0.5))
        local dotOffset = math.max(1, math.floor(3 * scaled + 0.5))
        if frame.settingsDot1 then
            frame.settingsDot1:SetSize(dotSize, dotSize)
            frame.settingsDot1:ClearAllPoints()
            frame.settingsDot1:SetPoint("CENTER", frame.settingsButton, "CENTER", -dotOffset, 0)
        end
        if frame.settingsDot2 then
            frame.settingsDot2:SetSize(dotSize, dotSize)
            frame.settingsDot2:ClearAllPoints()
            frame.settingsDot2:SetPoint("CENTER", frame.settingsButton, "CENTER", 0, 0)
        end
        if frame.settingsDot3 then
            frame.settingsDot3:SetSize(dotSize, dotSize)
            frame.settingsDot3:ClearAllPoints()
            frame.settingsDot3:SetPoint("CENTER", frame.settingsButton, "CENTER", dotOffset, 0)
        end
    end

    if frame.closeButton then
        local btnSize = math.max(12, math.floor(16 * scaled + 0.5))
        frame.closeButton:SetSize(btnSize, btnSize)
        frame.closeButton:ClearAllPoints()
        frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -math.floor(12 * scaled + 0.5), -math.floor(3 * scaled + 0.5))
    end
    if frame.closeLine then
        frame.closeLine:SetSize(math.max(5, math.floor(8 * scaled + 0.5)), math.max(1, math.floor(1 * scaled + 0.5)))
    end

    if frame.tableContainer then
        frame.tableContainer:ClearAllPoints()
        frame.tableContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", tableInset, -tableTopInset)
        frame.tableContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -tableInset, tableInset)
    end

    if frame.mainFrameResizeHandle then
        frame.mainFrameResizeHandle:SetSize(handleSize, handleSize)
        frame.mainFrameResizeHandle:ClearAllPoints()
        frame.mainFrameResizeHandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -handleInset, handleInset)
    end
end

function MainFrame:NormalizeSize(frame)
    if not frame then
        return
    end
    local currentWidth = frame:GetWidth() or FRAME_CFG.width
    local scale = Clamp(currentWidth / FRAME_CFG.width, FRAME_CFG.minScale, FRAME_CFG.maxScale)
    local targetHeight = math.floor(FRAME_CFG.height * scale + 0.5)
    local currentHeight = frame:GetHeight() or targetHeight

    if math.abs(currentHeight - targetHeight) > 0.5 then
        frame.isNormalizingSize = true
        frame:SetHeight(targetHeight)
        frame.isNormalizingSize = nil
    end
    self:ApplyScaledChrome(frame, scale)
end

function MainFrame:Create()
    local frame = CreateFrame("Frame", "CrateTrackerZKFrame", UIParent)
    frame:SetSize(FRAME_CFG.width, FRAME_CFG.height)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(FRAME_CFG.minWidth, FRAME_CFG.minHeight, FRAME_CFG.maxWidth, FRAME_CFG.maxHeight)
    else
        if frame.SetMinResize then
            frame:SetMinResize(FRAME_CFG.minWidth, FRAME_CFG.minHeight)
        end
        if frame.SetMaxResize then
            frame:SetMaxResize(FRAME_CFG.maxWidth, FRAME_CFG.maxHeight)
        end
    end

    self:ApplySavedSize(frame)

    self:CreateBackground(frame)
    self:CreateTitleBar(frame)
    self:CreateTableContainer(frame)
    self:CreateResizeHandle(frame)
    self:ApplyScaledChrome(frame, GetFrameScale(frame))

    frame:SetScript("OnSizeChanged", function()
        if not frame.isNormalizingSize then
            self:NormalizeSize(frame)
        end
        if not frame.isSizing then
            NotifyLayoutChangedIfNeeded(frame)
        end
    end)

    if RowStateSystem and RowStateSystem.AddClickListenerToTableArea then
        RowStateSystem:AddClickListenerToTableArea(frame)
    end

    return frame
end

local function SaveFramePosition(frame)
    EnsureUIState()
    local point, _, _, x, y = frame:GetPoint()
    CRATETRACKERZK_UI_DB.position = { point = point, x = x, y = y }
end

local function SaveFrameSize(frame)
    EnsureUIState()
    CRATETRACKERZK_UI_DB.mainFrameSize = {
        width = frame:GetWidth(),
        height = frame:GetHeight(),
    }
end

function MainFrame:ApplySavedSize(frame)
    EnsureUIState()
    local size = CRATETRACKERZK_UI_DB.mainFrameSize
    if not size then
        self:ApplyScaledChrome(frame, 1)
        return
    end
    local width = tonumber(size.width) or FRAME_CFG.width
    local height = tonumber(size.height) or FRAME_CFG.height
    width = math.max(FRAME_CFG.minWidth, math.min(FRAME_CFG.maxWidth, width))
    height = math.max(FRAME_CFG.minHeight, math.min(FRAME_CFG.maxHeight, height))
    frame:SetSize(width, height)
    self:NormalizeSize(frame)
end

function MainFrame:CreateBackground(frame)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    local bgColor = UIConfig.GetColor("mainFrameBackground")
    bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])

    self:CreateDragArea(frame)
end

function MainFrame:CreateDragArea(frame)
    local titleDragArea = CreateFrame("Frame", nil, frame)
    titleDragArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    titleDragArea:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    titleDragArea:SetHeight(22)
    titleDragArea:SetFrameLevel(2)
    titleDragArea:EnableMouse(true)
    titleDragArea:RegisterForDrag("LeftButton")

    local bottomDragArea = CreateFrame("Frame", nil, frame)
    bottomDragArea:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    bottomDragArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 1)
    bottomDragArea:SetHeight(30)
    bottomDragArea:SetFrameLevel(2)
    bottomDragArea:EnableMouse(true)
    bottomDragArea:RegisterForDrag("LeftButton")

    local leftDragArea = CreateFrame("Frame", nil, frame)
    leftDragArea:SetWidth(20)
    leftDragArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -23)
    leftDragArea:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 31)
    leftDragArea:SetFrameLevel(2)
    leftDragArea:EnableMouse(true)
    leftDragArea:RegisterForDrag("LeftButton")

    local rightDragArea = CreateFrame("Frame", nil, frame)
    rightDragArea:SetWidth(20)
    rightDragArea:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -23)
    rightDragArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 31)
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

    frame.titleDragArea = titleDragArea
    frame.bottomDragArea = bottomDragArea
    frame.leftDragArea = leftDragArea
    frame.rightDragArea = rightDragArea
end

function MainFrame:CreateTitleBar(frame)
    local titleBg = frame:CreateTexture(nil, "ARTWORK")
    titleBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    titleBg:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    titleBg:SetHeight(22)
    local titleBarColor = UIConfig.GetColor("titleBarBackground")
    titleBg:SetColorTexture(titleBarColor[1], titleBarColor[2], titleBarColor[3], titleBarColor[4])

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("CENTER", titleBg, "CENTER", 0, 0)
    title:SetText("CrateTrackerZK")
    local titleColor = UIConfig.GetTextColor("normal")
    title:SetTextColor(titleColor[1], titleColor[2], titleColor[3], titleColor[4])
    title:SetJustifyH("CENTER")
    title:SetJustifyV("MIDDLE")
    title:SetShadowOffset(0, 0)

    frame.titleBg = titleBg
    frame.titleText = title

    self:CreateSettingsButton(frame)
    self:CreateCloseButton(frame)
end

function MainFrame:CreateSettingsButton(frame)
    local settingsButton = CreateFrame("Button", nil, frame)
    settingsButton:SetSize(16, 16)
    settingsButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -35, -3)
    settingsButton:SetFrameLevel(frame:GetFrameLevel() + 20)

    local settingsBg = settingsButton:CreateTexture(nil, "BACKGROUND")
    settingsBg:SetAllPoints(settingsButton)
    local buttonColor = UIConfig.GetColor("titleBarButton")
    settingsBg:SetColorTexture(buttonColor[1], buttonColor[2], buttonColor[3], buttonColor[4])

    local dot1 = settingsButton:CreateTexture(nil, "OVERLAY")
    dot1:SetSize(2, 2)
    dot1:SetPoint("CENTER", settingsButton, "CENTER", -3, 0)
    local textColor = UIConfig.GetTextColor("normal")
    dot1:SetColorTexture(textColor[1], textColor[2], textColor[3], textColor[4])

    local dot2 = settingsButton:CreateTexture(nil, "OVERLAY")
    dot2:SetSize(2, 2)
    dot2:SetPoint("CENTER", settingsButton, "CENTER", 0, 0)
    dot2:SetColorTexture(textColor[1], textColor[2], textColor[3], textColor[4])

    local dot3 = settingsButton:CreateTexture(nil, "OVERLAY")
    dot3:SetSize(2, 2)
    dot3:SetPoint("CENTER", settingsButton, "CENTER", 3, 0)
    dot3:SetColorTexture(textColor[1], textColor[2], textColor[3], textColor[4])

    settingsButton:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel.Show then
            SettingsPanel:Show()
        end
    end)

    settingsButton:SetScript("OnEnter", function()
        local hoverColor = UIConfig.GetColor("titleBarButtonHover")
        settingsBg:SetColorTexture(hoverColor[1], hoverColor[2], hoverColor[3], hoverColor[4])
    end)
    settingsButton:SetScript("OnLeave", function()
        local normalColor = UIConfig.GetColor("titleBarButton")
        settingsBg:SetColorTexture(normalColor[1], normalColor[2], normalColor[3], normalColor[4])
    end)

    frame.settingsButton = settingsButton
    frame.settingsDot1 = dot1
    frame.settingsDot2 = dot2
    frame.settingsDot3 = dot3
end

function MainFrame:CreateCloseButton(frame)
    local closeButton = CreateFrame("Button", nil, frame)
    closeButton:SetSize(16, 16)
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -3)
    closeButton:SetFrameLevel(frame:GetFrameLevel() + 20)

    local closeBg = closeButton:CreateTexture(nil, "BACKGROUND")
    closeBg:SetAllPoints(closeButton)
    local buttonColor = UIConfig.GetColor("titleBarButton")
    closeBg:SetColorTexture(buttonColor[1], buttonColor[2], buttonColor[3], buttonColor[4])

    local line = closeButton:CreateTexture(nil, "OVERLAY")
    line:SetSize(8, 1)
    line:SetPoint("CENTER", closeButton, "CENTER", 0, 0)
    local textColor = UIConfig.GetTextColor("normal")
    line:SetColorTexture(textColor[1], textColor[2], textColor[3], textColor[4])

    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    closeButton:SetScript("OnEnter", function()
        local hoverColor = UIConfig.GetColor("titleBarButtonHover")
        closeBg:SetColorTexture(hoverColor[1], hoverColor[2], hoverColor[3], hoverColor[4])
    end)
    closeButton:SetScript("OnLeave", function()
        local normalColor = UIConfig.GetColor("titleBarButton")
        closeBg:SetColorTexture(normalColor[1], normalColor[2], normalColor[3], normalColor[4])
    end)

    frame.closeButton = closeButton
    frame.closeLine = line
end

function MainFrame:CreateTableContainer(frame)
    local tableContainer = CreateFrame("Frame", nil, frame)
    tableContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 10 + TABLE_PADDING_EXTRA, -(30 + TABLE_PADDING_EXTRA))
    tableContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(10 + TABLE_PADDING_EXTRA), 10 + TABLE_PADDING_EXTRA)
    tableContainer:SetFrameLevel(frame:GetFrameLevel() + 5)
    frame.tableContainer = tableContainer
end

function MainFrame:CreateResizeHandle(frame)
    local resizeHandle = CreateFrame("Button", nil, frame)
    resizeHandle:SetSize(16, 16)
    resizeHandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    resizeHandle:SetFrameLevel(frame:GetFrameLevel() + 20)
    resizeHandle:EnableMouse(true)
    if resizeHandle.SetHitRectInsets then
        resizeHandle:SetHitRectInsets(-4, -4, -4, -4)
    end
    resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    local function StartLayoutRefreshTicker()
        if frame.layoutRefreshTicker then
            return
        end
        frame.layoutRefreshTicker = C_Timer.NewTicker(0.016, function()
            if not frame or not frame:IsShown() or not frame.isSizing then
                return
            end
            NotifyLayoutChangedIfNeeded(frame)
        end)
    end

    local function StopLayoutRefreshTicker()
        if frame.layoutRefreshTicker then
            frame.layoutRefreshTicker:Cancel()
            frame.layoutRefreshTicker = nil
        end
    end

    local function StopSizing()
        if not frame.isSizing then
            return
        end
        frame.isSizing = false
        frame:StopMovingOrSizing()
        StopLayoutRefreshTicker()
        self:NormalizeSize(frame)
        SaveFrameSize(frame)
        NotifyLayoutChangedIfNeeded(frame)
    end

    resizeHandle:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then
            return
        end
        frame.isSizing = true
        StartLayoutRefreshTicker()
        frame:StartSizing("BOTTOMRIGHT")
        NotifyLayoutChangedIfNeeded(frame)
    end)

    resizeHandle:SetScript("OnMouseUp", function()
        StopSizing()
    end)

    frame:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            StopSizing()
        end
    end)

    frame:SetScript("OnHide", function()
        StopLayoutRefreshTicker()
    end)

    frame.mainFrameResizeHandle = resizeHandle
end

return MainFrame

-- MainFrameChrome.lua - 主框架外观与拖拽区

local MainFrameChrome = BuildEnv("MainFrameChrome")
local MainFrameMetrics = BuildEnv("MainFrameMetrics")
local SettingsPanel = BuildEnv("CrateTrackerZKSettingsPanel")
local UIConfig = BuildEnv("ThemeConfig")

local function ApplyFontScale(fontString, scale, minSize, maxSize)
    if MainFrameMetrics and MainFrameMetrics.ApplyFontScale then
        return MainFrameMetrics:ApplyFontScale(fontString, scale, minSize, maxSize)
    end
end

local function GetFrameScale(frame)
    if MainFrameMetrics and MainFrameMetrics.GetFrameScale then
        return MainFrameMetrics:GetFrameScale(frame)
    end
    return 1
end

local function IsAtMinimumWidth(frame)
    if MainFrameMetrics and MainFrameMetrics.IsAtMinimumWidth then
        return MainFrameMetrics:IsAtMinimumWidth(frame)
    end
    return false
end

function MainFrameChrome:ApplyScaledChrome(frame, scale)
    if not frame then
        return
    end
    local scaled = scale or GetFrameScale(frame)
    local chromeMetrics = MainFrameMetrics:GetChromeMetrics(scaled)
    local titleHeight = chromeMetrics.titleHeight
    local sideWidth = chromeMetrics.sideWidth
    local bottomHeight = chromeMetrics.bottomHeight
    local tableInset = chromeMetrics.tableInset
    local tableTopInset = chromeMetrics.tableTopInset

    if frame.titleDragArea then
        frame.titleDragArea:SetHeight(titleHeight)
    end
    if frame.bottomDragArea then
        frame.bottomDragArea:SetHeight(bottomHeight)
        frame.bottomDragArea:ClearAllPoints()
        frame.bottomDragArea:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
        frame.bottomDragArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(chromeMetrics.handleSize + chromeMetrics.handleInset + 4), 1)
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
        ApplyFontScale(frame.titleText, 1, 8, 16)
        if IsAtMinimumWidth(frame) or frame.__ctkHideTitleForCompactLayout == true then
            frame.titleText:Hide()
        else
            frame.titleText:Show()
        end
    end

    if frame.settingsButton then
        frame.settingsButton:SetSize(chromeMetrics.buttonSize, chromeMetrics.buttonSize)
        frame.settingsButton:ClearAllPoints()
        if frame.closeButton then
            frame.settingsButton:SetPoint("TOPRIGHT", frame.closeButton, "TOPLEFT", -chromeMetrics.buttonGap, 0)
        else
            frame.settingsButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -chromeMetrics.buttonInsetX, -chromeMetrics.buttonInsetY)
        end
        if frame.settingsDot1 then
            frame.settingsDot1:SetSize(chromeMetrics.dotSize, chromeMetrics.dotSize)
            frame.settingsDot1:ClearAllPoints()
            frame.settingsDot1:SetPoint("CENTER", frame.settingsButton, "CENTER", -chromeMetrics.dotOffset, 0)
        end
        if frame.settingsDot2 then
            frame.settingsDot2:SetSize(chromeMetrics.dotSize, chromeMetrics.dotSize)
            frame.settingsDot2:ClearAllPoints()
            frame.settingsDot2:SetPoint("CENTER", frame.settingsButton, "CENTER", 0, 0)
        end
        if frame.settingsDot3 then
            frame.settingsDot3:SetSize(chromeMetrics.dotSize, chromeMetrics.dotSize)
            frame.settingsDot3:ClearAllPoints()
            frame.settingsDot3:SetPoint("CENTER", frame.settingsButton, "CENTER", chromeMetrics.dotOffset, 0)
        end
    end

    if frame.closeButton then
        frame.closeButton:SetSize(chromeMetrics.buttonSize, chromeMetrics.buttonSize)
        frame.closeButton:ClearAllPoints()
        frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -chromeMetrics.buttonInsetX, -chromeMetrics.buttonInsetY)
    end
    if frame.closeLine then
        frame.closeLine:SetSize(chromeMetrics.closeLineWidth, chromeMetrics.closeLineHeight)
    end

    if frame.tableContainer then
        frame.tableContainer:ClearAllPoints()
        frame.tableContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", tableInset, -tableTopInset)
        frame.tableContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -tableInset, tableInset)
    end

    if frame.mainFrameResizeHandle then
        frame.mainFrameResizeHandle:SetSize(chromeMetrics.handleSize, chromeMetrics.handleSize)
        frame.mainFrameResizeHandle:ClearAllPoints()
        frame.mainFrameResizeHandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -chromeMetrics.handleInset, chromeMetrics.handleInset)
    end
end

function MainFrameChrome:CreateBackground(frame, createDragAreaCallback)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    local bgColor = UIConfig.GetColor("mainFrameBackground")
    bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
    frame.mainBg = bg

    if createDragAreaCallback then
        createDragAreaCallback(frame)
    end
end

function MainFrameChrome:CreateDragArea(frame, savePositionCallback)
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
            if savePositionCallback then
                savePositionCallback(frame)
            end
        end)
    end

    frame.titleDragArea = titleDragArea
    frame.bottomDragArea = bottomDragArea
    frame.leftDragArea = leftDragArea
    frame.rightDragArea = rightDragArea
end

function MainFrameChrome:CreateTitleBar(frame, createSettingsButtonCallback, createCloseButtonCallback)
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

    if createSettingsButtonCallback then
        createSettingsButtonCallback(frame)
    end
    if createCloseButtonCallback then
        createCloseButtonCallback(frame)
    end
end

function MainFrameChrome:CreateSettingsButton(frame)
    local settingsButton = CreateFrame("Button", nil, frame)
    settingsButton:SetSize(16, 16)
    settingsButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -35, -3)
    settingsButton:SetFrameLevel(frame:GetFrameLevel() + 20)

    local settingsBg = settingsButton:CreateTexture(nil, "BACKGROUND")
    settingsBg:SetAllPoints(settingsButton)
    local buttonColor = UIConfig.GetColor("titleBarButton")
    settingsBg:SetColorTexture(buttonColor[1], buttonColor[2], buttonColor[3], buttonColor[4])

    local textColor = UIConfig.GetTextColor("normal")
    local dot1 = settingsButton:CreateTexture(nil, "OVERLAY")
    dot1:SetSize(2, 2)
    dot1:SetPoint("CENTER", settingsButton, "CENTER", -3, 0)
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
    frame.settingsButtonBg = settingsBg
    frame.settingsDot1 = dot1
    frame.settingsDot2 = dot2
    frame.settingsDot3 = dot3
end

function MainFrameChrome:CreateCloseButton(frame)
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
    frame.closeButtonBg = closeBg
    frame.closeLine = line
end

return MainFrameChrome

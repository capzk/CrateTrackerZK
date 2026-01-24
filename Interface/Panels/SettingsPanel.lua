-- SettingsPanel.lua - 设置面板

local SettingsPanel = BuildEnv("CrateTrackerZKSettingsPanel")
local UIConfig = BuildEnv("UIConfig")
local HelpTextProvider = BuildEnv("HelpTextProvider")
local AboutTextProvider = BuildEnv("AboutTextProvider")
local Commands = BuildEnv("Commands")
local Notification = BuildEnv("Notification")

local settingsFrame = nil
local currentTab = "设置"
local tabButtons = {}
local settingControls = {}

local function GetConfig()
    return UIConfig.values
end

local function CreateNoShadowText(parent, template, text)
    local cfg = GetConfig()
    local fontString = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    fontString:SetText(text or "")
    fontString:SetTextColor(cfg.textColor[1], cfg.textColor[2], cfg.textColor[3], cfg.textColor[4])
    fontString:SetShadowOffset(0, 0)
    return fontString
end

local function CreateScrollableText(parent, text)
    local cfg = GetConfig()
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -28, 0)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(parent:GetWidth() or 520, parent:GetHeight() or 300)
    scroll:SetScrollChild(content)

    local editBox = CreateFrame("EditBox", nil, content)
    editBox:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -4)
    editBox:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, -4)
    editBox:SetFontObject("GameFontNormal")
    editBox:SetTextColor(cfg.textColor[1], cfg.textColor[2], cfg.textColor[3], cfg.textColor[4])
    editBox:SetShadowOffset(0, 0)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:EnableMouse(true)
    editBox:SetScript("OnEscapePressed", function() editBox:ClearFocus() end)
    editBox:SetScript("OnEditFocusLost", function() editBox:HighlightText(0, 0) end)
    editBox:SetScript("OnTextChanged", function(self)
        if self.ignoreTextChanged then return end
        self.ignoreTextChanged = true
        self:SetText(self.originalText or "")
        self.ignoreTextChanged = false
    end)

    editBox.originalText = text or ""
    editBox.ignoreTextChanged = true
    editBox:SetText(text or "")
    editBox.ignoreTextChanged = false

    C_Timer.After(0.05, function()
        local h = editBox:GetHeight() + 20
        local viewH = scroll:GetHeight()
        local child = scroll:GetScrollChild()
        if child then child:SetHeight(math.max(h, viewH)) end
        local sb = scroll.ScrollBar
        if sb then
            if h > viewH + 1 then sb:Show() else sb:Hide() scroll:SetVerticalScroll(0) end
        end
    end)

    return editBox
end

local function IsAddonEnabled()
    if not CRATETRACKERZK_UI_DB or CRATETRACKERZK_UI_DB.addonEnabled == nil then
        return true
    end
    return CRATETRACKERZK_UI_DB.addonEnabled == true
end

local function IsTeamNotificationEnabled()
    if CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.teamNotificationEnabled ~= nil then
        return CRATETRACKERZK_UI_DB.teamNotificationEnabled == true
    end
    if Notification and Notification.IsTeamNotificationEnabled then
        return Notification:IsTeamNotificationEnabled()
    end
    return true
end

local function EnsureClearDialog()
    if not StaticPopupDialogs or StaticPopupDialogs["CRATETRACKERZK_CLEAR_DATA"] then
        return
    end

    StaticPopupDialogs["CRATETRACKERZK_CLEAR_DATA"] = {
        text = "确认清除所有数据并重新初始化？该操作不可撤销。",
        button1 = "确认",
        button2 = "取消",
        OnAccept = function()
            if Commands and Commands.HandleClearCommand then
                Commands:HandleClearCommand()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
end

local function UpdateToggleButtonState(control, enabled)
    if not control or not control.text then return end
    control.text:SetText(enabled and control.onText or control.offText)
end

local function UpdateSettingsState()
    UpdateToggleButtonState(settingControls.addon, IsAddonEnabled())
    UpdateToggleButtonState(settingControls.teamNotify, IsTeamNotificationEnabled())
end

local function CreateSettingButton(parent, text)
    local cfg = GetConfig()
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(90, 22)

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(button)
    bg:SetColorTexture(1, 1, 1, cfg.buttonAlpha)

    local label = CreateNoShadowText(button, "GameFontNormal", text or "")
    label:SetPoint("CENTER", button, "CENTER", 0, 0)

    button:SetScript("OnEnter", function()
        bg:SetColorTexture(1, 1, 1, cfg.buttonHoverAlpha)
    end)
    button:SetScript("OnLeave", function()
        bg:SetColorTexture(1, 1, 1, cfg.buttonAlpha)
    end)

    return button, label
end

local function UpdateTabStyles(activeName)
    for _, info in ipairs(tabButtons) do
        if info.name == activeName then
            info.bg:SetColorTexture(1, 1, 1, UIConfig.values.buttonHoverAlpha)
            if info.indicator then
                info.indicator:Show()
            end
        else
            info.bg:SetColorTexture(1, 1, 1, UIConfig.values.buttonAlpha)
            if info.indicator then
                info.indicator:Hide()
            end
        end
    end
end

function SettingsPanel:CreateFrame()
    if settingsFrame then return settingsFrame end

    local cfg = GetConfig()
    local frame = CreateFrame("Frame", "CrateTrackerZKSettingsFrame", UIParent)
    frame:SetSize(600, 500)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("HIGH")

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(0, 0, 0, cfg.backgroundAlpha)

    local border = frame:CreateTexture(nil, "BORDER")
    border:SetAllPoints(frame)
    border:SetColorTexture(1, 1, 1, cfg.borderAlpha)

    bg:ClearAllPoints()
    bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    local titleBg = frame:CreateTexture(nil, "ARTWORK")
    titleBg:SetSize(598, 22)
    titleBg:SetPoint("TOP", frame, "TOP", 0, -1)
    titleBg:SetColorTexture(0, 0, 0, cfg.titleBarAlpha)

    local titleLine = frame:CreateTexture(nil, "ARTWORK")
    titleLine:SetSize(598, 1)
    titleLine:SetPoint("TOP", titleBg, "BOTTOM", 0, 0)
    titleLine:SetColorTexture(1, 1, 1, cfg.borderAlpha)

    local title = CreateNoShadowText(frame, "GameFontNormal", "CrateTrackerZK - 设置")
    title:SetPoint("CENTER", titleBg, "CENTER", 0, 0)

    local closeButton = CreateFrame("Button", nil, frame)
    closeButton:SetSize(16, 16)
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -3)

    local closeBg = closeButton:CreateTexture(nil, "BACKGROUND")
    closeBg:SetAllPoints(closeButton)
    closeBg:SetColorTexture(1, 1, 1, cfg.buttonAlpha)

    local closeText = CreateNoShadowText(closeButton, "GameFontNormal", "X")
    closeText:SetPoint("CENTER", closeButton, "CENTER", 0, 0)

    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)
    closeButton:SetScript("OnEnter", function()
        closeBg:SetColorTexture(1, 1, 1, cfg.buttonHoverAlpha)
    end)
    closeButton:SetScript("OnLeave", function()
        closeBg:SetColorTexture(1, 1, 1, cfg.buttonAlpha)
    end)

    local contentBg = frame:CreateTexture(nil, "ARTWORK")
    contentBg:SetSize(580, 430)
    contentBg:SetPoint("CENTER", frame, "CENTER", 0, -20)
    contentBg:SetColorTexture(0, 0, 0, 0.02)

    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetSize(580, 430)
    contentFrame:SetPoint("CENTER", frame, "CENTER", 0, -20)

    local tabs = {"设置", "帮助", "关于"}
    tabButtons = {}
    local navWidth = 140
    local navPadding = 10
    local navButtonHeight = 30
    local navSpacing = 8

    local navFrame = CreateFrame("Frame", nil, contentFrame)
    navFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 8, -8)
    navFrame:SetPoint("BOTTOMLEFT", contentFrame, "BOTTOMLEFT", 8, 8)
    navFrame:SetWidth(navWidth)

    local navBg = navFrame:CreateTexture(nil, "BACKGROUND")
    navBg:SetAllPoints(navFrame)
    navBg:SetColorTexture(1, 1, 1, cfg.buttonAlpha * 0.5)

    local navLine = navFrame:CreateTexture(nil, "ARTWORK")
    navLine:SetWidth(1)
    navLine:SetPoint("TOPRIGHT", navFrame, "TOPRIGHT", 0, 0)
    navLine:SetPoint("BOTTOMRIGHT", navFrame, "BOTTOMRIGHT", 0, 0)
    navLine:SetColorTexture(1, 1, 1, cfg.borderAlpha)

    local contentPanel = CreateFrame("Frame", nil, contentFrame)
    contentPanel:SetPoint("TOPLEFT", navFrame, "TOPRIGHT", 12, 0)
    contentPanel:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", -8, 8)

    local panelBg = contentPanel:CreateTexture(nil, "BACKGROUND")
    panelBg:SetAllPoints(contentPanel)
    panelBg:SetColorTexture(1, 1, 1, cfg.buttonAlpha * 0.35)

    for i, tabName in ipairs(tabs) do
        local tabBtn = CreateFrame("Button", nil, navFrame)
        tabBtn:SetHeight(navButtonHeight)
        local yPos = -navPadding - (i - 1) * (navButtonHeight + navSpacing)
        tabBtn:SetPoint("TOPLEFT", navFrame, "TOPLEFT", navPadding, yPos)
        tabBtn:SetPoint("TOPRIGHT", navFrame, "TOPRIGHT", -navPadding, yPos)

        local tabBg = tabBtn:CreateTexture(nil, "BACKGROUND")
        tabBg:SetAllPoints(tabBtn)
        tabBg:SetColorTexture(1, 1, 1, cfg.buttonAlpha)

        local tabText = CreateNoShadowText(tabBtn, "GameFontNormal", tabName)
        tabText:SetPoint("LEFT", tabBtn, "LEFT", 12, 0)

        local tabIndicator = tabBtn:CreateTexture(nil, "ARTWORK")
        tabIndicator:SetWidth(3)
        tabIndicator:SetPoint("TOPLEFT", tabBtn, "TOPLEFT", 0, 0)
        tabIndicator:SetPoint("BOTTOMLEFT", tabBtn, "BOTTOMLEFT", 0, 0)
        tabIndicator:SetColorTexture(1, 1, 1, cfg.buttonHoverAlpha)
        tabIndicator:Hide()

        local contentArea = CreateFrame("Frame", nil, contentPanel)
        contentArea:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 12, -12)
        contentArea:SetPoint("BOTTOMRIGHT", contentPanel, "BOTTOMRIGHT", -12, 12)
        contentArea:Hide()

        if tabName == "设置" then
            local function AddToggleRow(label, controlKey, onClick, yOffset)
                local rowLabel = CreateNoShadowText(contentArea, "GameFontNormal", label)
                rowLabel:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 10, yOffset)

                local button, text = CreateSettingButton(contentArea, "")
                button:SetPoint("TOPRIGHT", contentArea, "TOPRIGHT", -10, yOffset + 2)
                button:SetScript("OnClick", function()
                    onClick()
                    UpdateSettingsState()
                end)

                settingControls[controlKey] = {
                    button = button,
                    text = text,
                    onText = "已开启",
                    offText = "已关闭",
                }
            end

            local y = -10
            local controlTitle = CreateNoShadowText(contentArea, "GameFontNormal", "插件控制")
            controlTitle:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 10, y)

            y = y - 30
            AddToggleRow("插件开关", "addon", function()
                if Commands and Commands.HandleAddonToggle then
                    Commands:HandleAddonToggle(not IsAddonEnabled())
                end
            end, y)

            y = y - 28
            AddToggleRow("团队通知", "teamNotify", function()
                if Notification and Notification.SetTeamNotificationEnabled then
                    Notification:SetTeamNotificationEnabled(not IsTeamNotificationEnabled())
                end
            end, y)

            y = y - 40
            local dataTitle = CreateNoShadowText(contentArea, "GameFontNormal", "数据管理")
            dataTitle:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 10, y)

            y = y - 30
            local clearLabel = CreateNoShadowText(contentArea, "GameFontNormal", "清除所有数据")
            clearLabel:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 10, y)

            local clearBtn, clearText = CreateSettingButton(contentArea, "清除")
            clearBtn:SetPoint("TOPRIGHT", contentArea, "TOPRIGHT", -10, y + 2)
            clearBtn:SetScript("OnClick", function()
                EnsureClearDialog()
                if StaticPopup_Show then
                    StaticPopup_Show("CRATETRACKERZK_CLEAR_DATA")
                end
            end)
            clearText:SetTextColor(1, 0.6, 0.6, 1)

            y = y - 24
            local clearDesc = CreateNoShadowText(contentArea, "GameFontNormal", "• 会清空所有空投时间与位面记录")
            clearDesc:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 10, y)

            y = y - 40
            local settingsTitle = CreateNoShadowText(contentArea, "GameFontNormal", "界面设置")
            settingsTitle:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 10, y)

            y = y - 24
            local desc1 = CreateNoShadowText(contentArea, "GameFontNormal", "• 界面风格可在 UiConfig.lua 调整")
            desc1:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 10, y)

            y = y - 20
            local desc2 = CreateNoShadowText(contentArea, "GameFontNormal", "• 修改后使用 /reload 生效")
            desc2:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 10, y)

            UpdateSettingsState()
        elseif tabName == "帮助" then
            local helpText = HelpTextProvider and HelpTextProvider.GetHelpText and HelpTextProvider:GetHelpText() or ""
            CreateScrollableText(contentArea, helpText)
        elseif tabName == "关于" then
            local aboutText = AboutTextProvider and AboutTextProvider.GetAboutText and AboutTextProvider:GetAboutText() or ""
            CreateScrollableText(contentArea, aboutText)
        end

        tabBtn:SetScript("OnClick", function()
            for _, info in ipairs(tabButtons) do
                info.contentArea:Hide()
            end
            contentArea:Show()
            currentTab = tabName
            UpdateTabStyles(tabName)
            if tabName == "设置" then
                UpdateSettingsState()
            end
        end)

        tabBtn:SetScript("OnEnter", function()
            if currentTab ~= tabName then
                tabBg:SetColorTexture(1, 1, 1, cfg.buttonHoverAlpha * 0.7)
            end
        end)
        tabBtn:SetScript("OnLeave", function()
            if currentTab ~= tabName then
                tabBg:SetColorTexture(1, 1, 1, cfg.buttonAlpha)
            end
        end)

        table.insert(tabButtons, {
            button = tabBtn,
            bg = tabBg,
            indicator = tabIndicator,
            contentArea = contentArea,
            name = tabName,
        })
    end

    if tabButtons[1] then
        tabButtons[1].contentArea:Show()
        tabButtons[1].bg:SetColorTexture(1, 1, 1, cfg.buttonHoverAlpha)
        if tabButtons[1].indicator then
            tabButtons[1].indicator:Show()
        end
    end

    settingsFrame = frame
    return frame
end

function SettingsPanel:Show()
    if not settingsFrame then
        self:CreateFrame()
    end
    settingsFrame:Show()
    if currentTab == "设置" then
        UpdateSettingsState()
    end
end

function SettingsPanel:Hide()
    if settingsFrame then
        settingsFrame:Hide()
    end
end

function SettingsPanel:IsShown()
    return settingsFrame and settingsFrame:IsShown()
end

function SettingsPanel:Toggle()
    if not settingsFrame then
        self:CreateFrame()
    end
    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        settingsFrame:Show()
        if currentTab == "设置" then
            UpdateSettingsState()
        end
    end
end

function SettingsPanel:ShowTab(tabName)
    if not settingsFrame then
        self:CreateFrame()
    end
    self:Show()

    for _, info in ipairs(tabButtons) do
        if info.name == tabName then
            info.contentArea:Show()
            currentTab = tabName
        else
            info.contentArea:Hide()
        end
    end
    UpdateTabStyles(tabName)
    if tabName == "设置" then
        UpdateSettingsState()
    end
end

return SettingsPanel

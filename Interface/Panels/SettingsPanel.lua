-- SettingsPanel.lua - 设置面板

local SettingsPanel = BuildEnv("CrateTrackerZKSettingsPanel")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local UIConfig = BuildEnv("UIConfig")
local HelpTextProvider = BuildEnv("HelpTextProvider")
local AboutTextProvider = BuildEnv("AboutTextProvider")
local Commands = BuildEnv("Commands")
local Notification = BuildEnv("Notification")
local L = CrateTrackerZK.L

local TAB_SETTINGS = "settings"
local TAB_HELP = "help"
local TAB_ABOUT = "about"
local settingsFrame = nil
local currentTab = TAB_SETTINGS
local tabButtons = {}
local settingControls = {}

local function LT(key, fallback)
    if L and L[key] then
        return L[key]
    end
    return fallback
end

local function GetTabLabel(key)
    if key == TAB_SETTINGS then
        return LT("SettingsTabSettings", "设置")
    end
    if key == TAB_HELP then
        return LT("MenuHelp", "帮助")
    end
    if key == TAB_ABOUT then
        return LT("MenuAbout", "关于")
    end
    return tostring(key)
end

local function ResolveTabKey(tabName)
    if tabName == TAB_SETTINGS or tabName == TAB_HELP or tabName == TAB_ABOUT then
        return tabName
    end
    if tabName == GetTabLabel(TAB_SETTINGS) then
        return TAB_SETTINGS
    end
    if tabName == GetTabLabel(TAB_HELP) then
        return TAB_HELP
    end
    if tabName == GetTabLabel(TAB_ABOUT) then
        return TAB_ABOUT
    end
    return nil
end

local function GetTheme()
    return {
        background = UIConfig.GetSettingsColor("background"),
        titleBar = UIConfig.GetSettingsColor("titleBar"),
        panel = UIConfig.GetSettingsColor("panel"),
        navBg = UIConfig.GetSettingsColor("navBg"),
        navItem = UIConfig.GetSettingsColor("navItem"),
        navItemActive = UIConfig.GetSettingsColor("navItemActive"),
        navIndicator = UIConfig.GetSettingsColor("navIndicator"),
        button = UIConfig.GetSettingsColor("button"),
        buttonHover = UIConfig.GetSettingsColor("buttonHover"),
        text = UIConfig.GetSettingsColor("text"),
    }
end

local function CreateNoShadowText(parent, template, text)
    local theme = GetTheme()
    local fontString = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    fontString:SetText(text or "")
    fontString:SetTextColor(theme.text[1], theme.text[2], theme.text[3], theme.text[4])
    fontString:SetShadowOffset(0, 0)
    return fontString
end

local function CreateScrollableText(parent, text, enableWrap)
    local theme = GetTheme()
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -28, 0)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(parent:GetWidth() or 520, parent:GetHeight() or 300)
    scroll:SetScrollChild(content)

    local editBox = CreateFrame("EditBox", nil, content)
    editBox:SetPoint("TOPLEFT", content, "TOPLEFT", 6, -6)
    editBox:SetPoint("TOPRIGHT", content, "TOPRIGHT", -6, -6)
    editBox:SetFontObject("GameFontNormal")
    editBox:SetTextColor(theme.text[1], theme.text[2], theme.text[3], theme.text[4])
    editBox:SetShadowOffset(0, 0)
    editBox:SetMultiLine(true)
    if enableWrap then
        if editBox.SetWordWrap then
            editBox:SetWordWrap(true)
        end
        if editBox.SetNonSpaceWrap then
            editBox:SetNonSpaceWrap(true)
        end
    else
        if editBox.SetWordWrap then
            editBox:SetWordWrap(false)
        end
        if editBox.SetNonSpaceWrap then
            editBox:SetNonSpaceWrap(false)
        end
    end
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

    local function UpdateLayout()
        local viewW = scroll:GetWidth()
        if viewW and viewW > 0 then
            content:SetWidth(viewW)
            editBox:SetWidth(viewW - 12)
        end
        local h = (editBox.GetStringHeight and editBox:GetStringHeight() or editBox:GetHeight()) + 20
        local viewH = scroll:GetHeight()
        local child = scroll:GetScrollChild()
        if child then child:SetHeight(math.max(h, viewH)) end
        local sb = scroll.ScrollBar
        if sb then
            if h > viewH + 1 then sb:Show() else sb:Hide() scroll:SetVerticalScroll(0) end
        end
    end

    scroll:SetScript("OnSizeChanged", UpdateLayout)
    C_Timer.After(0.05, UpdateLayout)

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

local function IsAutoTeamReportEnabled()
    if Notification and Notification.IsAutoTeamReportEnabled then
        return Notification:IsAutoTeamReportEnabled()
    end
    return false
end

local function GetAutoTeamReportInterval()
    if CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.autoTeamReportInterval ~= nil then
        local value = tonumber(CRATETRACKERZK_UI_DB.autoTeamReportInterval)
        if value and value > 0 then
            return math.floor(value)
        end
    end
    if Notification and Notification.GetAutoTeamReportInterval then
        return Notification:GetAutoTeamReportInterval()
    end
    return 60
end

local function EnsureClearDialog()
    if not StaticPopupDialogs or StaticPopupDialogs["CRATETRACKERZK_CLEAR_DATA"] then
        return
    end

    StaticPopupDialogs["CRATETRACKERZK_CLEAR_DATA"] = {
        text = LT("SettingsClearConfirmText", "确认清除所有数据并重新初始化？该操作不可撤销。"),
        button1 = LT("SettingsClearConfirmYes", "确认"),
        button2 = LT("SettingsClearConfirmNo", "取消"),
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
    local teamEnabled = IsTeamNotificationEnabled()
    local autoEnabled = teamEnabled and IsAutoTeamReportEnabled()
    UpdateToggleButtonState(settingControls.addon, IsAddonEnabled())
    UpdateToggleButtonState(settingControls.teamNotify, teamEnabled)
    UpdateToggleButtonState(settingControls.autoReport, autoEnabled)
    local autoControl = settingControls.autoReport
    if autoControl and autoControl.button and autoControl.text then
        local theme = GetTheme()
        if autoControl.button.SetEnabled then
            autoControl.button:SetEnabled(teamEnabled)
        end
        autoControl.button:EnableMouse(teamEnabled)
        if autoControl.button.bg then
            local bgAlpha = teamEnabled and theme.button[4] or math.min(theme.button[4], 0.2)
            autoControl.button.bg:SetColorTexture(theme.button[1], theme.button[2], theme.button[3], bgAlpha)
        end
        local textAlpha = teamEnabled and theme.text[4] or 0.5
        autoControl.text:SetTextColor(theme.text[1], theme.text[2], theme.text[3], textAlpha)
    end
    local control = settingControls.autoReportInterval
    if control and control.editBox then
        local theme = GetTheme()
        local enabled = autoEnabled
        if control.editBox.SetEnabled then
            control.editBox:SetEnabled(enabled)
        end
        control.editBox:EnableMouse(enabled)
        local textAlpha = enabled and theme.text[4] or 0.5
        control.editBox:SetTextColor(theme.text[1], theme.text[2], theme.text[3], textAlpha)
        if control.bg then
            local bgAlpha = enabled and theme.button[4] or math.min(theme.button[4], 0.3)
            control.bg:SetColorTexture(theme.button[1], theme.button[2], theme.button[3], bgAlpha)
        end
        if not control.editBox:HasFocus() then
            control.editBox:SetText(tostring(GetAutoTeamReportInterval()))
        end
    end
end

local function ApplyAutoTeamReportInterval(editBox)
    if not editBox then
        return
    end
    local value = editBox:GetText()
    local applied = nil
    if Notification and Notification.SetAutoTeamReportInterval then
        applied = Notification:SetAutoTeamReportInterval(value)
    end
    if applied then
        editBox:SetText(tostring(applied))
    else
        editBox:SetText(tostring(GetAutoTeamReportInterval()))
    end
end

local function CreateSettingButton(parent, text)
    local theme = GetTheme()
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(90, 22)

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(button)
    bg:SetColorTexture(theme.button[1], theme.button[2], theme.button[3], theme.button[4])
    button.bg = bg

    local label = CreateNoShadowText(button, "GameFontNormal", text or "")
    label:SetPoint("CENTER", button, "CENTER", 0, 0)

    button:SetScript("OnEnter", function()
        bg:SetColorTexture(theme.buttonHover[1], theme.buttonHover[2], theme.buttonHover[3], theme.buttonHover[4])
    end)
    button:SetScript("OnLeave", function()
        bg:SetColorTexture(theme.button[1], theme.button[2], theme.button[3], theme.button[4])
    end)

    return button, label
end

local function UpdateTabStyles(activeName)
    local theme = GetTheme()
    for _, info in ipairs(tabButtons) do
        if info.name == activeName then
            info.bg:SetColorTexture(theme.navItemActive[1], theme.navItemActive[2], theme.navItemActive[3], theme.navItemActive[4])
            if info.indicator then
                info.indicator:Show()
            end
        else
            info.bg:SetColorTexture(theme.navItem[1], theme.navItem[2], theme.navItem[3], theme.navItem[4])
            if info.indicator then
                info.indicator:Hide()
            end
        end
    end
end

function SettingsPanel:CreateFrame()
    if settingsFrame then return settingsFrame end

    local theme = GetTheme()
    local frame = CreateFrame("Frame", "CrateTrackerZKSettingsFrame", UIParent)
    frame:SetSize(760, 500)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("HIGH")

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(theme.background[1], theme.background[2], theme.background[3], theme.background[4])

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    local titleBg = frame:CreateTexture(nil, "ARTWORK")
    titleBg:SetSize(758, 22)
    titleBg:SetPoint("TOP", frame, "TOP", 0, -1)
    titleBg:SetColorTexture(theme.titleBar[1], theme.titleBar[2], theme.titleBar[3], theme.titleBar[4])

    local title = CreateNoShadowText(frame, "GameFontNormal", LT("SettingsPanelTitle", "CrateTrackerZK - 设置"))
    title:SetPoint("CENTER", titleBg, "CENTER", 0, 0)

    local closeButton = CreateFrame("Button", nil, frame)
    closeButton:SetSize(16, 16)
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -3)

    local closeBg = closeButton:CreateTexture(nil, "BACKGROUND")
    closeBg:SetAllPoints(closeButton)
    closeBg:SetColorTexture(theme.button[1], theme.button[2], theme.button[3], theme.button[4])

    local closeText = CreateNoShadowText(closeButton, "GameFontNormal", "X")
    closeText:SetPoint("CENTER", closeButton, "CENTER", 0, 0)

    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)
    closeButton:SetScript("OnEnter", function()
        closeBg:SetColorTexture(theme.buttonHover[1], theme.buttonHover[2], theme.buttonHover[3], theme.buttonHover[4])
    end)
    closeButton:SetScript("OnLeave", function()
        closeBg:SetColorTexture(theme.button[1], theme.button[2], theme.button[3], theme.button[4])
    end)

    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
    contentFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)

    local tabs = {TAB_SETTINGS, TAB_HELP, TAB_ABOUT}
    tabButtons = {}
    local navWidth = 110
    local navPadding = 6
    local navButtonHeight = 30
    local navSpacing = 8

    local navFrame = CreateFrame("Frame", nil, contentFrame)
    navFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 6, -6)
    navFrame:SetPoint("BOTTOMLEFT", contentFrame, "BOTTOMLEFT", 6, 6)
    navFrame:SetWidth(navWidth)

    local contentPanel = CreateFrame("Frame", nil, contentFrame)
    contentPanel:SetPoint("TOPLEFT", navFrame, "TOPRIGHT", 10, 0)
    contentPanel:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", -6, 6)

    for i, tabKey in ipairs(tabs) do
        local tabLabel = GetTabLabel(tabKey)
        local tabBtn = CreateFrame("Button", nil, navFrame)
        tabBtn:SetHeight(navButtonHeight)
        local yPos = -navPadding - (i - 1) * (navButtonHeight + navSpacing)
        tabBtn:SetPoint("TOPLEFT", navFrame, "TOPLEFT", navPadding, yPos)
        tabBtn:SetPoint("TOPRIGHT", navFrame, "TOPRIGHT", -navPadding, yPos)

        local tabBg = tabBtn:CreateTexture(nil, "BACKGROUND")
        tabBg:SetAllPoints(tabBtn)
        tabBg:SetColorTexture(theme.navItem[1], theme.navItem[2], theme.navItem[3], theme.navItem[4])

        local tabText = CreateNoShadowText(tabBtn, "GameFontNormal", tabLabel)
        tabText:SetPoint("LEFT", tabBtn, "LEFT", 12, 0)

        local tabIndicator = tabBtn:CreateTexture(nil, "ARTWORK")
        tabIndicator:SetWidth(3)
        tabIndicator:SetPoint("TOPLEFT", tabBtn, "TOPLEFT", 0, 0)
        tabIndicator:SetPoint("BOTTOMLEFT", tabBtn, "BOTTOMLEFT", 0, 0)
        tabIndicator:SetColorTexture(theme.navIndicator[1], theme.navIndicator[2], theme.navIndicator[3], theme.navIndicator[4])
        tabIndicator:Hide()

        local contentArea = CreateFrame("Frame", nil, contentPanel)
        contentArea:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 8, -8)
        contentArea:SetPoint("BOTTOMRIGHT", contentPanel, "BOTTOMRIGHT", -8, 8)
        contentArea:Hide()

        if tabKey == TAB_SETTINGS then
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
                    onText = LT("SettingsToggleOn", "已开启"),
                    offText = LT("SettingsToggleOff", "已关闭"),
                }
            end

            local y = -10
            local controlTitle = CreateNoShadowText(contentArea, "GameFontNormal", LT("SettingsSectionControl", "插件控制"))
            controlTitle:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 10, y)

            y = y - 30
            AddToggleRow(LT("SettingsAddonToggle", "插件开关"), "addon", function()
                if Commands and Commands.HandleAddonToggle then
                    Commands:HandleAddonToggle(not IsAddonEnabled())
                end
            end, y)

            y = y - 28
            AddToggleRow(LT("SettingsTeamNotify", "团队通知"), "teamNotify", function()
                if Notification and Notification.SetTeamNotificationEnabled then
                    Notification:SetTeamNotificationEnabled(not IsTeamNotificationEnabled())
                end
            end, y)

            y = y - 28
            AddToggleRow(LT("SettingsAutoReport", "自动通知"), "autoReport", function()
                if Notification and Notification.SetAutoTeamReportEnabled then
                    Notification:SetAutoTeamReportEnabled(not IsAutoTeamReportEnabled())
                end
            end, y)

            y = y - 28
            local intervalLabel = CreateNoShadowText(contentArea, "GameFontNormal", LT("SettingsAutoReportInterval", "通知频率（秒）"))
            intervalLabel:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 10, y)

            local intervalBox = CreateFrame("EditBox", nil, contentArea)
            intervalBox:SetSize(70, 22)
            intervalBox:SetPoint("TOPRIGHT", contentArea, "TOPRIGHT", -10, y + 2)
            intervalBox:SetAutoFocus(false)
            intervalBox:SetFontObject("GameFontNormal")
            intervalBox:SetJustifyH("CENTER")
            intervalBox:SetNumeric(true)
            intervalBox:SetTextColor(theme.text[1], theme.text[2], theme.text[3], theme.text[4])
            intervalBox:SetShadowOffset(0, 0)

            local intervalBg = intervalBox:CreateTexture(nil, "BACKGROUND")
            intervalBg:SetAllPoints(intervalBox)
            intervalBg:SetColorTexture(theme.button[1], theme.button[2], theme.button[3], theme.button[4])

            intervalBox:SetScript("OnEscapePressed", function(self)
                self:ClearFocus()
                self:SetText(tostring(GetAutoTeamReportInterval()))
            end)
            intervalBox:SetScript("OnEnterPressed", function(self)
                ApplyAutoTeamReportInterval(self)
                self:ClearFocus()
            end)
            intervalBox:SetScript("OnEditFocusLost", function(self)
                ApplyAutoTeamReportInterval(self)
            end)

            settingControls.autoReportInterval = {
                editBox = intervalBox,
                bg = intervalBg,
            }

            y = y - 40
            local dataTitle = CreateNoShadowText(contentArea, "GameFontNormal", LT("SettingsSectionData", "数据管理"))
            dataTitle:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 10, y)

            y = y - 30
            local clearLabel = CreateNoShadowText(contentArea, "GameFontNormal", LT("SettingsClearAllData", "清除所有数据"))
            clearLabel:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 10, y)

            local clearBtn, clearText = CreateSettingButton(contentArea, LT("SettingsClearButton", "清除"))
            clearBtn:SetPoint("TOPRIGHT", contentArea, "TOPRIGHT", -10, y + 2)
            clearBtn:SetScript("OnClick", function()
                EnsureClearDialog()
                if StaticPopup_Show then
                    StaticPopup_Show("CRATETRACKERZK_CLEAR_DATA")
                end
            end)
            clearText:SetTextColor(1, 0.6, 0.6, 1)

            y = y - 24
            local clearDesc = CreateNoShadowText(contentArea, "GameFontNormal", LT("SettingsClearDesc", "• 会清空所有空投时间与位面记录"))
            clearDesc:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 10, y)

            y = y - 40
            local settingsTitle = CreateNoShadowText(contentArea, "GameFontNormal", LT("SettingsSectionUI", "界面设置"))
            settingsTitle:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 10, y)

            y = y - 24
            local desc1 = CreateNoShadowText(contentArea, "GameFontNormal", LT("SettingsUIConfigDesc", "• 界面风格可在 UiConfig.lua 调整"))
            desc1:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 10, y)

            y = y - 20
            local desc2 = CreateNoShadowText(contentArea, "GameFontNormal", LT("SettingsReloadDesc", "• 修改后使用 /reload 生效"))
            desc2:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 10, y)

            UpdateSettingsState()
        elseif tabKey == TAB_HELP then
            local helpText = HelpTextProvider and HelpTextProvider.GetHelpText and HelpTextProvider:GetHelpText() or ""
            CreateScrollableText(contentArea, helpText, true)
        elseif tabKey == TAB_ABOUT then
            local aboutText = AboutTextProvider and AboutTextProvider.GetAboutText and AboutTextProvider:GetAboutText() or ""
            CreateScrollableText(contentArea, aboutText, false)
        end

        tabBtn:SetScript("OnClick", function()
            for _, info in ipairs(tabButtons) do
                info.contentArea:Hide()
            end
            contentArea:Show()
            currentTab = tabKey
            UpdateTabStyles(tabKey)
            if tabKey == TAB_SETTINGS then
                UpdateSettingsState()
            end
        end)

        tabBtn:SetScript("OnEnter", function()
            if currentTab ~= tabKey then
                tabBg:SetColorTexture(theme.navItemActive[1], theme.navItemActive[2], theme.navItemActive[3], theme.navItemActive[4])
            end
        end)
        tabBtn:SetScript("OnLeave", function()
            if currentTab ~= tabKey then
                tabBg:SetColorTexture(theme.navItem[1], theme.navItem[2], theme.navItem[3], theme.navItem[4])
            end
        end)

        table.insert(tabButtons, {
            button = tabBtn,
            bg = tabBg,
            indicator = tabIndicator,
            contentArea = contentArea,
            name = tabKey,
            label = tabLabel,
        })
    end

    if tabButtons[1] then
        tabButtons[1].contentArea:Show()
        tabButtons[1].bg:SetColorTexture(theme.navItemActive[1], theme.navItemActive[2], theme.navItemActive[3], theme.navItemActive[4])
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
    if currentTab == TAB_SETTINGS then
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
        if currentTab == TAB_SETTINGS then
            UpdateSettingsState()
        end
    end
end

function SettingsPanel:ShowTab(tabName)
    if not settingsFrame then
        self:CreateFrame()
    end
    self:Show()

    local targetTab = ResolveTabKey(tabName) or TAB_SETTINGS
    for _, info in ipairs(tabButtons) do
        if info.name == targetTab then
            info.contentArea:Show()
            currentTab = targetTab
        else
            info.contentArea:Hide()
        end
    end
    UpdateTabStyles(targetTab)
    if targetTab == TAB_SETTINGS then
        UpdateSettingsState()
    end
end

return SettingsPanel

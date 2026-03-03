-- SettingsPanel.lua - 设置面板

local SettingsPanel = BuildEnv("CrateTrackerZKSettingsPanel")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local ThemeConfig = BuildEnv("ThemeConfig")
local HelpTextProvider = BuildEnv("HelpTextProvider")
local AboutTextProvider = BuildEnv("AboutTextProvider")
local Commands = BuildEnv("Commands")
local Notification = BuildEnv("Notification")
local MainPanel = BuildEnv("MainPanel")
local L = CrateTrackerZK.L

local TAB_SETTINGS = "settings"
local TAB_HELP = "help"
local TAB_ABOUT = "about"
local settingsFrame = nil
local currentTab = TAB_SETTINGS
local tabButtons = {}
local settingControls = {}
local SettingsPanelState = BuildEnv("CrateTrackerZKSettingsPanelState")
local SettingsPanelLayout = BuildEnv("CrateTrackerZKSettingsPanelLayout")
local SettingsPanelActions = BuildEnv("CrateTrackerZKSettingsPanelActions")

local function LT(key, fallback)
    if SettingsPanelState and SettingsPanelState.LT then
        return SettingsPanelState:LT(key, fallback)
    end
    if L and L[key] then
        return L[key]
    end
    return fallback
end

local function GetTabLabel(key)
    if SettingsPanelState and SettingsPanelState.GetTabLabel then
        return SettingsPanelState:GetTabLabel(key)
    end
    return tostring(key)
end

local function ResolveTabKey(tabName)
    if SettingsPanelState and SettingsPanelState.ResolveTabKey then
        return SettingsPanelState:ResolveTabKey(tabName)
    end
    return nil
end

local function GetTheme()
    if SettingsPanelLayout and SettingsPanelLayout.GetTheme then
        return SettingsPanelLayout:GetTheme()
    end
    return {
        background = ThemeConfig.GetSettingsColor("background"),
        titleBar = ThemeConfig.GetSettingsColor("titleBar"),
        panel = ThemeConfig.GetSettingsColor("panel"),
        navBg = ThemeConfig.GetSettingsColor("navBg"),
        navItem = ThemeConfig.GetSettingsColor("navItem"),
        navItemActive = ThemeConfig.GetSettingsColor("navItemActive"),
        navIndicator = ThemeConfig.GetSettingsColor("navIndicator"),
        button = ThemeConfig.GetSettingsColor("button"),
        buttonHover = ThemeConfig.GetSettingsColor("buttonHover"),
        text = ThemeConfig.GetSettingsColor("text"),
    }
end

local function CreateNoShadowText(parent, template, text)
    if SettingsPanelLayout and SettingsPanelLayout.CreateNoShadowText then
        return SettingsPanelLayout:CreateNoShadowText(parent, template, text)
    end
    local fontString = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    fontString:SetText(text or "")
    return fontString
end

local function CreateScrollableText(parent, text, enableWrap)
    if SettingsPanelLayout and SettingsPanelLayout.CreateScrollableText then
        return SettingsPanelLayout:CreateScrollableText(parent, text, enableWrap)
    end
    return nil
end

local function IsAddonEnabled()
    if SettingsPanelState and SettingsPanelState.IsAddonEnabled then
        return SettingsPanelState:IsAddonEnabled()
    end
    return true
end

local function IsTeamNotificationEnabled()
    if SettingsPanelState and SettingsPanelState.IsTeamNotificationEnabled then
        return SettingsPanelState:IsTeamNotificationEnabled()
    end
    return true
end

local function IsSoundAlertEnabled()
    if SettingsPanelState and SettingsPanelState.IsSoundAlertEnabled then
        return SettingsPanelState:IsSoundAlertEnabled()
    end
    return true
end

local function IsAutoTeamReportEnabled()
    if SettingsPanelState and SettingsPanelState.IsAutoTeamReportEnabled then
        return SettingsPanelState:IsAutoTeamReportEnabled()
    end
    return false
end

local function GetAutoTeamReportInterval()
    if SettingsPanelState and SettingsPanelState.GetAutoTeamReportInterval then
        return SettingsPanelState:GetAutoTeamReportInterval()
    end
    return 60
end

local function IsExpansionSwitchEnabled()
    if SettingsPanelState and SettingsPanelState.IsExpansionSwitchEnabled then
        return SettingsPanelState:IsExpansionSwitchEnabled()
    end
    return false
end

local function GetCurrentExpansionButtonText()
    if SettingsPanelState and SettingsPanelState.GetCurrentExpansionButtonText then
        return SettingsPanelState:GetCurrentExpansionButtonText()
    end
    return "N/A"
end

local function CycleExpansionVersion()
    if SettingsPanelActions and SettingsPanelActions.CycleExpansionVersion then
        SettingsPanelActions:CycleExpansionVersion()
    end
end

local function IsThemeSwitchEnabled()
    if SettingsPanelState and SettingsPanelState.IsThemeSwitchEnabled then
        return SettingsPanelState:IsThemeSwitchEnabled()
    end
    return false
end

local function GetCurrentThemeButtonText()
    if SettingsPanelState and SettingsPanelState.GetCurrentThemeButtonText then
        return SettingsPanelState:GetCurrentThemeButtonText()
    end
    return "N/A"
end

local function CycleTheme()
    if SettingsPanelActions and SettingsPanelActions.CycleTheme then
        SettingsPanelActions:CycleTheme()
    end
end

local function EnsureClearDialog()
    if SettingsPanelActions and SettingsPanelActions.EnsureClearDialog then
        SettingsPanelActions:EnsureClearDialog()
    end
end

local function ApplyAutoTeamReportInterval(editBox)
    if SettingsPanelActions and SettingsPanelActions.ApplyAutoTeamReportInterval then
        SettingsPanelActions:ApplyAutoTeamReportInterval(editBox)
    end
end

local function UpdateToggleButtonState(control, enabled)
    if not control or not control.text then return end
    control.text:SetText(enabled and control.onText or control.offText)
end

local function SetControlEnabled(control, enabled)
    if not control then return end
    local theme = GetTheme()
    if control.button then
        if control.button.SetEnabled then
            control.button:SetEnabled(enabled)
        end
        control.button:EnableMouse(enabled)
        if control.button.bg then
            local bgAlpha = enabled and theme.button[4] or math.min(theme.button[4], 0.2)
            control.button.bg:SetColorTexture(theme.button[1], theme.button[2], theme.button[3], bgAlpha)
        end
    end
    local textAlpha = enabled and theme.text[4] or 0.5
    if control.text then
        control.text:SetTextColor(theme.text[1], theme.text[2], theme.text[3], textAlpha)
    end
    if control.label then
        control.label:SetTextColor(theme.text[1], theme.text[2], theme.text[3], textAlpha)
    end
    if control.desc then
        control.desc:SetTextColor(theme.text[1], theme.text[2], theme.text[3], textAlpha)
    end
end

local function UpdateSettingsState()
    local addonEnabled = IsAddonEnabled()
    local teamEnabled = addonEnabled and IsTeamNotificationEnabled()
    local soundEnabled = addonEnabled and IsSoundAlertEnabled()
    local autoEnabled = addonEnabled and teamEnabled and IsAutoTeamReportEnabled()
    UpdateToggleButtonState(settingControls.addon, addonEnabled)
    UpdateToggleButtonState(settingControls.teamNotify, teamEnabled)
    UpdateToggleButtonState(settingControls.soundAlert, soundEnabled)
    UpdateToggleButtonState(settingControls.autoReport, autoEnabled)
    SetControlEnabled(settingControls.teamNotify, addonEnabled)
    SetControlEnabled(settingControls.soundAlert, addonEnabled)
    SetControlEnabled(settingControls.autoReport, addonEnabled and teamEnabled)
    SetControlEnabled(settingControls.expansionSwitch, addonEnabled and IsExpansionSwitchEnabled())
    SetControlEnabled(settingControls.themeSwitch, IsThemeSwitchEnabled())
    SetControlEnabled(settingControls.clearData, addonEnabled)
    local autoControl = settingControls.autoReport
    if autoControl and autoControl.button and autoControl.text then
        local theme = GetTheme()
        if autoControl.button.SetEnabled then
            autoControl.button:SetEnabled(addonEnabled and teamEnabled)
        end
        autoControl.button:EnableMouse(addonEnabled and teamEnabled)
        if autoControl.button.bg then
            local bgAlpha = (addonEnabled and teamEnabled) and theme.button[4] or math.min(theme.button[4], 0.2)
            autoControl.button.bg:SetColorTexture(theme.button[1], theme.button[2], theme.button[3], bgAlpha)
        end
        local textAlpha = (addonEnabled and teamEnabled) and theme.text[4] or 0.5
        autoControl.text:SetTextColor(theme.text[1], theme.text[2], theme.text[3], textAlpha)
    end
    local control = settingControls.autoReportInterval
    if control and control.editBox then
        local theme = GetTheme()
        local enabled = addonEnabled and autoEnabled
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
        if control.label then
            control.label:SetTextColor(theme.text[1], theme.text[2], theme.text[3], textAlpha)
        end
        if not control.editBox:HasFocus() then
            control.editBox:SetText(tostring(GetAutoTeamReportInterval()))
        end
    end

    if settingControls.expansionSwitch and settingControls.expansionSwitch.text then
        settingControls.expansionSwitch.text:SetText(GetCurrentExpansionButtonText())
    end
    if settingControls.themeSwitch and settingControls.themeSwitch.text then
        settingControls.themeSwitch.text:SetText(GetCurrentThemeButtonText())
    end
end

local function CreateSettingButton(parent, text)
    if SettingsPanelLayout and SettingsPanelLayout.CreateSettingButton then
        return SettingsPanelLayout:CreateSettingButton(parent, text)
    end
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(90, 22)
    local label = CreateNoShadowText(button, "GameFontNormal", text or "")
    label:SetPoint("CENTER", button, "CENTER", 0, 0)
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
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)

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
            local SECTION_X = 10
            local ITEM_X = 24
            local NOTE_X = 36

            local function IndentText(level, text)
                local depth = tonumber(level) or 0
                if depth < 0 then
                    depth = 0
                end
                return string.rep("  ", depth) .. (text or "")
            end

            local function AddToggleRow(label, controlKey, onClick, yOffset)
                local rowLabel = CreateNoShadowText(contentArea, "GameFontNormal", label)
                rowLabel:SetPoint("TOPLEFT", contentArea, "TOPLEFT", ITEM_X, yOffset)

                local button, text = CreateSettingButton(contentArea, "")
                button:SetPoint("TOPRIGHT", contentArea, "TOPRIGHT", -10, yOffset + 2)
                button:SetScript("OnClick", function()
                    onClick()
                    UpdateSettingsState()
                end)

                settingControls[controlKey] = {
                    button = button,
                    text = text,
                    label = rowLabel,
                    onText = LT("SettingsToggleOn", "已开启"),
                    offText = LT("SettingsToggleOff", "已关闭"),
                }
            end

            local function AddCycleRow(label, controlKey, onClick, yOffset)
                local rowLabel = CreateNoShadowText(contentArea, "GameFontNormal", label)
                rowLabel:SetPoint("TOPLEFT", contentArea, "TOPLEFT", ITEM_X, yOffset)

                local button, text = CreateSettingButton(contentArea, "")
                button:SetPoint("TOPRIGHT", contentArea, "TOPRIGHT", -10, yOffset + 2)
                button:SetScript("OnClick", function()
                    onClick()
                    UpdateSettingsState()
                end)

                settingControls[controlKey] = {
                    button = button,
                    text = text,
                    label = rowLabel,
                }
            end

            local y = -10
            local expansionTitle = CreateNoShadowText(contentArea, "GameFontNormal", LT("SettingsSectionExpansion", "版本设置"))
            expansionTitle:SetPoint("TOPLEFT", contentArea, "TOPLEFT", SECTION_X, y)

            y = y - 30
            AddCycleRow(IndentText(1, LT("SettingsExpansionVersion", "游戏版本")), "expansionSwitch", function()
                CycleExpansionVersion()
            end, y)

            y = y - 40
            local controlTitle = CreateNoShadowText(contentArea, "GameFontNormal", LT("SettingsSectionControl", "插件控制"))
            controlTitle:SetPoint("TOPLEFT", contentArea, "TOPLEFT", SECTION_X, y)

            y = y - 30
            AddToggleRow(IndentText(1, LT("SettingsAddonToggle", "插件开关")), "addon", function()
                if Commands and Commands.HandleAddonToggle then
                    Commands:HandleAddonToggle(not IsAddonEnabled())
                end
            end, y)

            y = y - 28
            AddToggleRow(IndentText(1, LT("SettingsTeamNotify", "团队通知")), "teamNotify", function()
                if Notification and Notification.SetTeamNotificationEnabled then
                    Notification:SetTeamNotificationEnabled(not IsTeamNotificationEnabled())
                end
            end, y)

            y = y - 28
            AddToggleRow(IndentText(1, LT("SettingsSoundAlert", "声音提示")), "soundAlert", function()
                if Notification and Notification.SetSoundAlertEnabled then
                    Notification:SetSoundAlertEnabled(not IsSoundAlertEnabled())
                end
            end, y)

            y = y - 28
            AddToggleRow(IndentText(1, LT("SettingsAutoReport", "自动通知")), "autoReport", function()
                if Notification and Notification.SetAutoTeamReportEnabled then
                    Notification:SetAutoTeamReportEnabled(not IsAutoTeamReportEnabled())
                end
            end, y)

            y = y - 28
            local intervalLabel = CreateNoShadowText(contentArea, "GameFontNormal", IndentText(1, LT("SettingsAutoReportInterval", "通知频率（秒）")))
            intervalLabel:SetPoint("TOPLEFT", contentArea, "TOPLEFT", ITEM_X, y)

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
                label = intervalLabel,
            }

            y = y - 40
            local dataTitle = CreateNoShadowText(contentArea, "GameFontNormal", LT("SettingsSectionData", "数据管理"))
            dataTitle:SetPoint("TOPLEFT", contentArea, "TOPLEFT", SECTION_X, y)

            y = y - 30
            local clearLabel = CreateNoShadowText(contentArea, "GameFontNormal", IndentText(1, LT("SettingsClearAllData", "清除所有数据")))
            clearLabel:SetPoint("TOPLEFT", contentArea, "TOPLEFT", ITEM_X, y)

            local clearBtn, clearText = CreateSettingButton(contentArea, LT("SettingsClearButton", "清除"))
            clearBtn:SetPoint("TOPRIGHT", contentArea, "TOPRIGHT", -10, y + 2)
            clearBtn:SetScript("OnClick", function()
                EnsureClearDialog()
                if StaticPopup_Show then
                    StaticPopup_Show("CRATETRACKERZK_CLEAR_DATA")
                end
            end)
            clearText:SetTextColor(1, 0.6, 0.6, 1)
            settingControls.clearData = {
                button = clearBtn,
                text = clearText,
                label = clearLabel,
            }

            y = y - 24
            local clearDesc = CreateNoShadowText(contentArea, "GameFontNormal", LT("SettingsClearDesc", "• 会清空所有空投时间与位面记录"))
            clearDesc:SetPoint("TOPLEFT", contentArea, "TOPLEFT", NOTE_X, y)
            if settingControls.clearData then
                settingControls.clearData.desc = clearDesc
            end

            y = y - 40
            local settingsTitle = CreateNoShadowText(contentArea, "GameFontNormal", LT("SettingsSectionUI", "界面设置"))
            settingsTitle:SetPoint("TOPLEFT", contentArea, "TOPLEFT", SECTION_X, y)

            y = y - 30
            AddCycleRow(IndentText(1, LT("SettingsThemeSwitch", "界面主题")), "themeSwitch", function()
                CycleTheme()
            end, y)

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
    settingsFrame:Raise()
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

function SettingsPanel:RefreshState()
    if settingsFrame and settingsFrame:IsShown() and currentTab == TAB_SETTINGS then
        UpdateSettingsState()
    end
end

return SettingsPanel

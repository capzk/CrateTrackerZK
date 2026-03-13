local SettingsPanelView = BuildEnv("CrateTrackerZKSettingsPanelView")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local SettingsPanelState = BuildEnv("CrateTrackerZKSettingsPanelState")
local SettingsPanelActions = BuildEnv("CrateTrackerZKSettingsPanelActions")
local SettingsPanelLayout = BuildEnv("CrateTrackerZKSettingsPanelLayout")
local ThemeConfig = BuildEnv("ThemeConfig")

SettingsPanelView.PAGE_MAIN = "main"
SettingsPanelView.PAGE_NOTIFICATIONS = "notifications"
SettingsPanelView.PAGE_APPEARANCE = "appearance"
SettingsPanelView.PAGE_DATA = "data"
SettingsPanelView.PAGE_HELP = "help"
SettingsPanelView.PAGE_ABOUT = "about"

local TAB_SETTINGS = "settings"
local TAB_HELP = "help"
local TAB_ABOUT = "about"

local pageOrder = {
    SettingsPanelView.PAGE_MAIN,
    SettingsPanelView.PAGE_NOTIFICATIONS,
    SettingsPanelView.PAGE_APPEARANCE,
    SettingsPanelView.PAGE_DATA,
    SettingsPanelView.PAGE_HELP,
    SettingsPanelView.PAGE_ABOUT,
}

local frameRef = nil
local navButtons = {}
local pages = {}
local controls = {}
local currentPage = SettingsPanelView.PAGE_MAIN
local ABOUT_TEXT = [[

Maintainer:
capzk

Source Code:
https://github.com/capzk/CrateTrackerZK

Addon Release Page:
https://www.curseforge.com/wow/addons/cratetrackerzk
]]

local function LT(key, fallback)
    if SettingsPanelState and SettingsPanelState.LT then
        return SettingsPanelState:LT(key, fallback)
    end
    local L = CrateTrackerZK and CrateTrackerZK.L
    if L and L[key] then
        return L[key]
    end
    return fallback
end

local function GetNavColor(colorType, fallback)
    if ThemeConfig and ThemeConfig.GetSettingsColor then
        return ThemeConfig.GetSettingsColor(colorType)
    end
    return fallback
end

local function SetTextEnabled(fontString, enabled)
    if not fontString then
        return
    end
    if enabled then
        fontString:SetTextColor(1, 1, 1, 1)
    else
        fontString:SetTextColor(0.5, 0.5, 0.5, 1)
    end
end

local function SetValueEnabled(fontString, enabled)
    if not fontString then
        return
    end
    if enabled then
        fontString:SetTextColor(1, 0.82, 0, 1)
    else
        fontString:SetTextColor(0.5, 0.5, 0.5, 1)
    end
end

local function CreateDivider(parent, anchor, offsetY)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY or -8)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -24, offsetY or -8)
    divider:SetHeight(1)
    divider:SetColorTexture(1, 1, 1, 0.12)
    return divider
end

local function ApplyNavButtonVisualState(button, active, hovered)
    if not button then
        return
    end

    local indicator = GetNavColor("navIndicator", {1, 1, 1, 0.85})
    local textColor = {1, 0.82, 0, 1}
    if active then
        button.label:SetTextColor(textColor[1], textColor[2], textColor[3], 1)
        button.indicator:SetColorTexture(indicator[1], indicator[2], indicator[3], 0.9)
        button.indicator:Show()
    else
        button.label:SetTextColor(textColor[1], textColor[2], textColor[3], hovered and 0.92 or 0.72)
        button.indicator:Hide()
    end
end

local function UpdateNavButtonStates()
    for pageKey, button in pairs(navButtons) do
        local hovered = button.IsMouseOver and button:IsMouseOver() or false
        ApplyNavButtonVisualState(button, pageKey == currentPage, hovered)
    end
end

local function CreateNavButton(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:EnableMouse(true)

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", button, "CENTER", 0, 0)
    label:SetText(text or "")
    button.label = label

    local textWidth = math.ceil((label.GetStringWidth and label:GetStringWidth() or 40) + 12)
    button:SetSize(math.max(textWidth, 40), 22)

    local indicator = button:CreateTexture(nil, "OVERLAY")
    indicator:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
    indicator:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    indicator:SetHeight(1)
    button.indicator = indicator

    button:SetScript("OnEnter", function(self)
        ApplyNavButtonVisualState(self, self.pageKey == currentPage, true)
    end)
    button:SetScript("OnLeave", function(self)
        ApplyNavButtonVisualState(self, self.pageKey == currentPage, false)
    end)
    button:SetScript("OnClick", function(self)
        if self.pageKey ~= currentPage and onClick then
            onClick(self.pageKey)
        end
    end)

    ApplyNavButtonVisualState(button, false, false)
    return button
end

local function CreatePageFrame(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    page:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    page.topAnchor = CreateFrame("Frame", nil, page)
    page.topAnchor:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    page.topAnchor:SetSize(1, 1)
    page:Hide()
    return page
end

local function CreateCheckbox(parent, anchor, labelText, onClick)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)

    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", check, "RIGHT", 4, 1)
    label:SetJustifyH("LEFT")
    label:SetText(labelText or "")
    check.label = label

    check:SetScript("OnClick", function(self)
        if onClick then
            onClick(self:GetChecked() == true)
        end
    end)

    return check
end

local function CreateActionButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 120, 24)
    button:SetText(text or "")
    button:SetScript("OnClick", function()
        if onClick then
            onClick()
        end
    end)
    return button
end

local function UpdateButtonText(button, text, minWidth)
    if not button then
        return
    end
    button:SetText(text or "")
    local width = minWidth or 120
    if button.GetFontString and button:GetFontString() and button:GetFontString().GetStringWidth then
        width = math.max(width, math.ceil(button:GetFontString():GetStringWidth() + 24))
    end
    button:SetWidth(width)
end

local function CreateValueRow(parent, anchor, labelText, buttonText, buttonWidth, onClick)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)
    label:SetJustifyH("LEFT")
    label:SetText(labelText or "")

    local value = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    value:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
    value:SetJustifyH("LEFT")
    value:SetText("")

    local button = CreateActionButton(parent, buttonText, buttonWidth, onClick)
    button:SetPoint("LEFT", value, "RIGHT", 16, 0)

    return {
        label = label,
        value = value,
        button = button,
    }
end

local function CreateInlineButtonRow(parent, anchor, labelText, buttonText, buttonWidth, onClick)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)
    label:SetJustifyH("LEFT")
    label:SetText(labelText or "")

    local button = CreateActionButton(parent, buttonText, buttonWidth, onClick)
    button:SetPoint("LEFT", label, "RIGHT", 16, 0)

    return {
        label = label,
        button = button,
    }
end

local function CreateSectionLabel(parent, anchor, text)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -18)
    label:SetJustifyH("LEFT")
    label:SetText(text or "")
    return label
end

local function CreateIntervalRow(parent, anchor)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 26, -14)
    label:SetJustifyH("LEFT")
    label:SetText(LT("SettingsAutoReportInterval", "通知频率（秒）"))

    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editBox:SetSize(64, 24)
    editBox:SetPoint("LEFT", label, "RIGHT", 12, 0)
    editBox:SetAutoFocus(false)
    editBox:SetNumeric(true)
    editBox:SetMaxLetters(4)

    editBox:SetScript("OnEnterPressed", function(self)
        if SettingsPanelActions and SettingsPanelActions.ApplyAutoTeamReportInterval then
            SettingsPanelActions:ApplyAutoTeamReportInterval(self)
        end
        self:ClearFocus()
        SettingsPanelView:RefreshState()
    end)

    editBox:SetScript("OnEditFocusLost", function(self)
        if SettingsPanelActions and SettingsPanelActions.ApplyAutoTeamReportInterval then
            SettingsPanelActions:ApplyAutoTeamReportInterval(self)
        end
        SettingsPanelView:RefreshState()
    end)

    return label, editBox
end

local function CreateScrollableContent(parent, text)
    if SettingsPanelLayout and SettingsPanelLayout.CreateScrollableText then
        return SettingsPanelLayout:CreateScrollableText(parent, text or "", true)
    end

    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    label:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("TOP")
    label:SetText(text or "")
    return label
end

local function GetHelpText()
    return LT("SettingsHelpText", "")
end

local function RefreshExpansionSelectors(expansionOptions, currentExpansionID)
    local selectorGroup = controls.expansionSelectors
    if not selectorGroup then
        return
    end

    local previous = nil
    for index, option in ipairs(expansionOptions or {}) do
        local checkbox = selectorGroup.checkboxes[index]
        if not checkbox then
            checkbox = CreateFrame("CheckButton", nil, selectorGroup, "UICheckButtonTemplate")
            local label = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            label:SetPoint("LEFT", checkbox, "RIGHT", 4, 1)
            label:SetJustifyH("LEFT")
            checkbox.label = label
            checkbox:SetScript("OnClick", function(self)
                if self:GetChecked() ~= true then
                    self:SetChecked(true)
                    return
                end
                if SettingsPanelActions and SettingsPanelActions.SetExpansionVersion then
                    SettingsPanelActions:SetExpansionVersion(self.expansionID)
                end
                SettingsPanelView:RefreshState()
            end)
            selectorGroup.checkboxes[index] = checkbox
        end

        checkbox:ClearAllPoints()
        if previous then
            checkbox:SetPoint("LEFT", previous, "RIGHT", 64, 0)
        else
            checkbox:SetPoint("TOPLEFT", selectorGroup.anchor, "BOTTOMLEFT", 0, -12)
        end
        checkbox.expansionID = option.id
        checkbox.label:SetText(option.label or option.id)
        checkbox:SetChecked(option.id == currentExpansionID)
        checkbox:Show()
        previous = checkbox
    end

    for index = #(expansionOptions or {}) + 1, #selectorGroup.checkboxes do
        selectorGroup.checkboxes[index]:Hide()
    end
end

local function RefreshVersionMapList(mapOptions, currentExpansionID)
    local mapList = controls.versionMapList
    if not mapList then
        return
    end

    mapList.expansionID = currentExpansionID
    local previous = nil
    for _, checkbox in ipairs(mapList.checkboxes) do
        checkbox:Hide()
    end

    for index, option in ipairs(mapOptions or {}) do
        local checkbox = mapList.checkboxes[index]
        if not checkbox then
            checkbox = CreateFrame("CheckButton", nil, mapList, "UICheckButtonTemplate")
            local label = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            label:SetPoint("LEFT", checkbox, "RIGHT", 4, 1)
            label:SetJustifyH("LEFT")
            checkbox.label = label
            checkbox:SetScript("OnClick", function(self)
                if SettingsPanelActions and SettingsPanelActions.SetMapVisibleForExpansion then
                    SettingsPanelActions:SetMapVisibleForExpansion(mapList.expansionID, self.mapID, self:GetChecked() == true)
                end
                SettingsPanelView:RefreshState()
            end)
            mapList.checkboxes[index] = checkbox
        end

        checkbox:ClearAllPoints()
        checkbox:SetPoint("TOPLEFT", previous or mapList.anchor, previous and "BOTTOMLEFT" or "BOTTOMLEFT", 0, previous and -8 or -12)
        checkbox.mapID = option.id
        checkbox.label:SetText(option.label)
        checkbox:SetChecked(option.visible == true)
        checkbox:Show()
        previous = checkbox
    end

    if mapList.emptyText then
        if #(mapOptions or {}) == 0 then
            mapList.emptyText:Show()
        else
            mapList.emptyText:Hide()
        end
    end
end

local function BuildMainPage(parent)
    local page = CreatePageFrame(parent)
    pages[SettingsPanelView.PAGE_MAIN] = page

    controls.addonToggle = CreateCheckbox(page, page.topAnchor, LT("SettingsAddonToggle", "插件开关"), function(enabled)
        if SettingsPanelActions and SettingsPanelActions.SetAddonEnabled then
            SettingsPanelActions:SetAddonEnabled(enabled)
        end
        SettingsPanelView:RefreshState()
    end)

    controls.expansionLabel = CreateSectionLabel(page, controls.addonToggle, LT("SettingsExpansionVersion", "游戏版本"))

    local selectorGroup = CreateFrame("Frame", nil, page)
    selectorGroup:SetPoint("TOPLEFT", controls.expansionLabel, "BOTTOMLEFT", 0, 0)
    selectorGroup:SetSize(520, 28)
    selectorGroup.anchor = controls.expansionLabel
    selectorGroup.checkboxes = {}
    controls.expansionSelectors = selectorGroup

    controls.versionMapListLabel = CreateSectionLabel(page, selectorGroup, LT("SettingsMapList", "地图列表"))

    local mapList = CreateFrame("Frame", nil, page)
    mapList:SetPoint("TOPLEFT", controls.versionMapListLabel, "BOTTOMLEFT", 0, 0)
    mapList:SetSize(520, 260)
    mapList.anchor = controls.versionMapListLabel
    mapList.checkboxes = {}
    controls.versionMapList = mapList

    local emptyText = mapList:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    emptyText:SetPoint("TOPLEFT", mapList, "TOPLEFT", 0, -12)
    emptyText:SetText("-")
    mapList.emptyText = emptyText
end

local function BuildNotificationsPage(parent)
    local page = CreatePageFrame(parent)
    pages[SettingsPanelView.PAGE_NOTIFICATIONS] = page

    controls.teamNotification = CreateCheckbox(page, page.topAnchor, LT("SettingsTeamNotify", "团队通知"), function(enabled)
        if SettingsPanelActions and SettingsPanelActions.SetTeamNotificationEnabled then
            SettingsPanelActions:SetTeamNotificationEnabled(enabled)
        end
        SettingsPanelView:RefreshState()
    end)

    controls.soundAlert = CreateCheckbox(page, controls.teamNotification, LT("SettingsSoundAlert", "声音提示"), function(enabled)
        if SettingsPanelActions and SettingsPanelActions.SetSoundAlertEnabled then
            SettingsPanelActions:SetSoundAlertEnabled(enabled)
        end
        SettingsPanelView:RefreshState()
    end)

    controls.autoReport = CreateCheckbox(page, controls.soundAlert, LT("SettingsAutoReport", "自动通知"), function(enabled)
        if SettingsPanelActions and SettingsPanelActions.SetAutoTeamReportEnabled then
            SettingsPanelActions:SetAutoTeamReportEnabled(enabled)
        end
        SettingsPanelView:RefreshState()
    end)

    controls.intervalLabel, controls.intervalEditBox = CreateIntervalRow(page, controls.autoReport)
end

local function BuildAppearancePage(parent)
    local page = CreatePageFrame(parent)
    pages[SettingsPanelView.PAGE_APPEARANCE] = page

    controls.theme = CreateInlineButtonRow(
        page,
        page.topAnchor,
        LT("SettingsThemeSwitch", "界面主题"),
        "N/A",
        160,
        function()
            if SettingsPanelActions and SettingsPanelActions.CycleTheme then
                SettingsPanelActions:CycleTheme()
            end
            SettingsPanelView:RefreshState()
        end
    )
end

local function BuildDataPage(parent)
    local page = CreatePageFrame(parent)
    pages[SettingsPanelView.PAGE_DATA] = page

    controls.clearButton = CreateActionButton(page, LT("SettingsClearButton", "清除"), 120, function()
        if SettingsPanelActions and SettingsPanelActions.EnsureClearDialog then
            SettingsPanelActions:EnsureClearDialog()
        end
        if StaticPopup_Show then
            StaticPopup_Show("CRATETRACKERZK_CLEAR_DATA")
        end
    end)
    controls.clearButton:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
end

local function BuildTextPage(parent, pageKey, providerText)
    local page = CreatePageFrame(parent)
    pages[pageKey] = page

    local contentHost = CreateFrame("Frame", nil, page)
    contentHost:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    contentHost:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -24, 0)
    CreateScrollableContent(contentHost, providerText)
end

function SettingsPanelView:GetPageLabel(pageKey)
    if pageKey == self.PAGE_MAIN then
        return LT("SettingsMainPage", "主要设置")
    end
    if pageKey == self.PAGE_NOTIFICATIONS then
        return LT("SettingsMessages", "消息设置")
    end
    if pageKey == self.PAGE_APPEARANCE then
        return LT("SettingsSectionUI", "界面")
    end
    if pageKey == self.PAGE_DATA then
        return LT("SettingsSectionData", "数据")
    end
    if pageKey == self.PAGE_HELP then
        return LT("MenuHelp", "帮助")
    end
    if pageKey == self.PAGE_ABOUT then
        return LT("MenuAbout", "关于")
    end
    return tostring(pageKey)
end

function SettingsPanelView:GetDefaultPage()
    return self.PAGE_MAIN
end

function SettingsPanelView:GetPageOrder()
    return pageOrder
end

function SettingsPanelView:ResolvePageKey(tabName)
    if not tabName or tabName == TAB_SETTINGS then
        return self.PAGE_MAIN
    end
    for _, pageKey in ipairs(pageOrder) do
        if tabName == pageKey then
            return pageKey
        end
    end
    if tabName == TAB_HELP or tabName == self:GetPageLabel(self.PAGE_HELP) then
        return self.PAGE_HELP
    end
    if tabName == TAB_ABOUT or tabName == self:GetPageLabel(self.PAGE_ABOUT) then
        return self.PAGE_ABOUT
    end
    return self.PAGE_MAIN
end

function SettingsPanelView:SelectPage(pageKey)
    currentPage = self:ResolvePageKey(pageKey)
    for key, page in pairs(pages) do
        if key == currentPage then
            page:Show()
        else
            page:Hide()
        end
    end
    UpdateNavButtonStates()
end

function SettingsPanelView:RefreshState()
    local snapshot = SettingsPanelState and SettingsPanelState.GetSettingsSnapshot and SettingsPanelState:GetSettingsSnapshot() or {}

    if controls.addonToggle then
        controls.addonToggle:SetChecked(snapshot.addonEnabled == true)
        SetTextEnabled(controls.addonToggle.label, true)
    end

    if controls.teamNotification then
        controls.teamNotification:SetChecked(snapshot.teamNotificationEnabled == true)
        controls.teamNotification:SetEnabled(snapshot.teamNotificationInteractable == true)
        SetTextEnabled(controls.teamNotification.label, snapshot.teamNotificationInteractable == true)
    end

    if controls.soundAlert then
        controls.soundAlert:SetChecked(snapshot.soundAlertEnabled == true)
        controls.soundAlert:SetEnabled(snapshot.soundAlertInteractable == true)
        SetTextEnabled(controls.soundAlert.label, snapshot.soundAlertInteractable == true)
    end

    if controls.autoReport then
        controls.autoReport:SetChecked(snapshot.autoReportEnabled == true)
        controls.autoReport:SetEnabled(snapshot.autoReportInteractable == true)
        SetTextEnabled(controls.autoReport.label, snapshot.autoReportInteractable == true)
    end

    if controls.intervalEditBox and controls.intervalLabel then
        controls.intervalEditBox:SetEnabled(snapshot.autoReportIntervalInteractable == true)
        controls.intervalEditBox:SetText(tostring(snapshot.autoReportInterval or 60))
        SetTextEnabled(controls.intervalLabel, snapshot.autoReportIntervalInteractable == true)
    end

    if controls.theme then
        UpdateButtonText(controls.theme.button, snapshot.themeText or "N/A", 160)
        controls.theme.button:SetEnabled(snapshot.themeEnabled == true)
        SetTextEnabled(controls.theme.label, true)
    end

    RefreshExpansionSelectors(snapshot.expansionOptions or {}, snapshot.currentExpansionID)
    RefreshVersionMapList(snapshot.mapOptions or {}, snapshot.currentExpansionID)
end

function SettingsPanelView:Build(frame)
    if frameRef == frame then
        return frameRef
    end

    frameRef = frame
    navButtons = {}
    pages = {}
    controls = {}

    local navHost = CreateFrame("Frame", nil, frame)
    navHost:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -16)
    navHost:SetSize(720, 22)

    local lastButton = nil
    for _, pageKey in ipairs(pageOrder) do
        local button = CreateNavButton(navHost, self:GetPageLabel(pageKey), function(targetPage)
            SettingsPanelView:SelectPage(targetPage)
        end)
        button.pageKey = pageKey
        if lastButton then
            button:SetPoint("LEFT", lastButton, "RIGHT", 14, 0)
        else
            button:SetPoint("LEFT", navHost, "LEFT", 0, 0)
        end
        navButtons[pageKey] = button
        lastButton = button
    end

    local contentDivider = CreateDivider(frame, navHost, -8)
    local contentHost = CreateFrame("Frame", nil, frame)
    contentHost:SetPoint("TOPLEFT", contentDivider, "BOTTOMLEFT", 0, -14)
    contentHost:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 16)

    BuildMainPage(contentHost)
    BuildNotificationsPage(contentHost)
    BuildAppearancePage(contentHost)
    BuildDataPage(contentHost)
    BuildTextPage(contentHost, self.PAGE_HELP, GetHelpText())
    BuildTextPage(contentHost, self.PAGE_ABOUT, ABOUT_TEXT)

    frame:SetScript("OnShow", function()
        SettingsPanelView:RefreshState()
        SettingsPanelView:SelectPage(currentPage or SettingsPanelView.PAGE_MAIN)
    end)

    return frameRef
end

return SettingsPanelView

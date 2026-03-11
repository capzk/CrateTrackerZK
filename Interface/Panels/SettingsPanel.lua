local SettingsPanel = BuildEnv("CrateTrackerZKSettingsPanel")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local HelpTextProvider = BuildEnv("HelpTextProvider")
local AboutTextProvider = BuildEnv("AboutTextProvider")
local Commands = BuildEnv("Commands")
local Notification = BuildEnv("Notification")
local MainPanel = BuildEnv("MainPanel")
local Data = BuildEnv("Data")
local ExpansionConfig = BuildEnv("ExpansionConfig")
local Localization = BuildEnv("Localization")
local SettingsPanelState = BuildEnv("CrateTrackerZKSettingsPanelState")
local SettingsPanelActions = BuildEnv("CrateTrackerZKSettingsPanelActions")
local SettingsPanelLayout = BuildEnv("CrateTrackerZKSettingsPanelLayout")
local ThemeConfig = BuildEnv("ThemeConfig")

local ADDON_TITLE = "CrateTrackerZK"
local TAB_SETTINGS = "settings"
local TAB_HELP = "help"
local TAB_ABOUT = "about"
local PAGE_MAIN = "main"
local PAGE_NOTIFICATIONS = "notifications"
local PAGE_APPEARANCE = "appearance"
local PAGE_DATA = "data"
local PAGE_HELP = "help"
local PAGE_ABOUT = "about"

local category = nil
local settingsFrame = nil
local navButtons = {}
local pages = {}
local controls = {}
local currentPage = PAGE_MAIN
local isRegistered = false

local pageOrder = {
    PAGE_MAIN,
    PAGE_NOTIFICATIONS,
    PAGE_APPEARANCE,
    PAGE_DATA,
    PAGE_HELP,
    PAGE_ABOUT,
}

local function LT(key, fallback)
    local L = CrateTrackerZK and CrateTrackerZK.L
    if L and L[key] then
        return L[key]
    end
    return fallback
end

local function GetPageLabel(pageKey)
    if pageKey == PAGE_MAIN then
        return "主要设置"
    end
    if pageKey == PAGE_NOTIFICATIONS then
        return LT("SettingsTeamNotify", "通知")
    end
    if pageKey == PAGE_APPEARANCE then
        return LT("SettingsSectionUI", "界面")
    end
    if pageKey == PAGE_DATA then
        return LT("SettingsSectionData", "数据")
    end
    if pageKey == PAGE_HELP then
        return LT("MenuHelp", "帮助")
    end
    if pageKey == PAGE_ABOUT then
        return LT("MenuAbout", "关于")
    end
    return tostring(pageKey)
end

local function ResolvePageKey(tabName)
    if not tabName or tabName == TAB_SETTINGS then
        return PAGE_MAIN
    end
    if tabName == PAGE_MAIN or tabName == PAGE_NOTIFICATIONS or tabName == PAGE_APPEARANCE or tabName == PAGE_DATA or tabName == PAGE_HELP or tabName == PAGE_ABOUT then
        return tabName
    end
    if tabName == TAB_HELP or tabName == LT("MenuHelp", "帮助") then
        return PAGE_HELP
    end
    if tabName == TAB_ABOUT or tabName == LT("MenuAbout", "关于") then
        return PAGE_ABOUT
    end
    return PAGE_MAIN
end

local function CreateDivider(parent, anchor, offsetY)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY or -8)
    divider:SetSize(640, 1)
    divider:SetColorTexture(1, 1, 1, 0.12)
    return divider
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

local function GetNavColor(colorType, fallback)
    if ThemeConfig and ThemeConfig.GetSettingsColor then
        return ThemeConfig.GetSettingsColor(colorType)
    end
    return fallback
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

local function CreateNavButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:EnableMouse(true)

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", button, "CENTER", 0, 0)
    label:SetText(text or "")
    button.label = label

    local textWidth = math.ceil((label.GetStringWidth and label:GetStringWidth() or 40) + 12)
    button:SetSize(math.max(textWidth, width or 40), 22)

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
        if self.pageKey == currentPage then
            return
        end
        if onClick then
            onClick()
        end
    end)

    ApplyNavButtonVisualState(button, false, false)
    return button
end

local function UpdateNavButtonStates()
    for pageKey, button in pairs(navButtons) do
        ApplyNavButtonVisualState(button, pageKey == currentPage, button:IsMouseOver())
    end
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

local function CreateSectionLabel(parent, anchor, text)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -18)
    label:SetJustifyH("LEFT")
    label:SetText(text or "")
    return label
end

local function CreateDescription(parent, anchor, text, width)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
    label:SetWidth(width or 520)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("TOP")
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
        SettingsPanel:RefreshState()
    end)

    editBox:SetScript("OnEditFocusLost", function(self)
        if SettingsPanelActions and SettingsPanelActions.ApplyAutoTeamReportInterval then
            SettingsPanelActions:ApplyAutoTeamReportInterval(self)
        end
        SettingsPanel:RefreshState()
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

local function GetCurrentExpansionID()
    if Data and Data.GetCurrentExpansionID then
        local expansionID = Data:GetCurrentExpansionID()
        if expansionID then
            return expansionID
        end
    end
    if ExpansionConfig and ExpansionConfig.GetCurrentExpansionID then
        return ExpansionConfig:GetCurrentExpansionID()
    end
    return nil
end

local function GetAvailableExpansions()
    if ExpansionConfig and ExpansionConfig.GetAvailableExpansions then
        return ExpansionConfig:GetAvailableExpansions() or {}
    end
    return {}
end

local function GetExpansionMapIDs(expansionID)
    local result = {}
    local expansion = ExpansionConfig and ExpansionConfig.expansions and ExpansionConfig.expansions[expansionID]
    if not expansion then
        return result
    end

    for _, mapID in ipairs(expansion.mapIDs or {}) do
        if type(mapID) == "number" and not (ExpansionConfig and ExpansionConfig.IsMainCityMap and ExpansionConfig:IsMainCityMap(mapID)) then
            table.insert(result, mapID)
        end
    end

    return result
end

local function GetMapDisplayName(mapID)
    if Localization and Localization.GetMapName then
        return Localization:GetMapName(mapID)
    end
    return "Map " .. tostring(mapID)
end

local function GetHiddenMaps(expansionID)
    if Data and Data.GetHiddenMaps then
        return Data:GetHiddenMaps(expansionID)
    end
    return {}
end

local function GetHiddenRemaining(expansionID)
    if Data and Data.GetHiddenRemaining then
        return Data:GetHiddenRemaining(expansionID)
    end
    return {}
end

local function SetExpansionVersion(expansionID)
    if not expansionID or expansionID == GetCurrentExpansionID() then
        return
    end
    if Data and Data.SwitchExpansion then
        Data:SwitchExpansion(expansionID)
    elseif ExpansionConfig and ExpansionConfig.SetCurrentExpansionID then
        ExpansionConfig:SetCurrentExpansionID(expansionID)
    end
    if CrateTrackerZK and CrateTrackerZK.Reinitialize then
        CrateTrackerZK:Reinitialize()
    end
end

local function SetMapVisibleForExpansion(expansionID, mapID, visible)
    if not expansionID or type(mapID) ~= "number" then
        return
    end

    local currentExpansionID = GetCurrentExpansionID()
    if currentExpansionID == expansionID and Data and Data.GetMapByMapID then
        local mapData = Data:GetMapByMapID(mapID)
        if mapData and mapData.id then
            if visible then
                if MainPanel and MainPanel.RestoreMap then
                    MainPanel:RestoreMap(mapData.id)
                end
            else
                if MainPanel and MainPanel.HideMap then
                    MainPanel:HideMap(mapData.id)
                end
            end
            return
        end
    end

    local hiddenMaps = GetHiddenMaps(expansionID)
    local hiddenRemaining = GetHiddenRemaining(expansionID)
    if visible then
        hiddenMaps[mapID] = nil
        hiddenRemaining[mapID] = nil
    else
        hiddenMaps[mapID] = true
    end

    if currentExpansionID == expansionID and MainPanel and MainPanel.UpdateTable then
        MainPanel:UpdateTable(true)
    end
end

local function RefreshExpansionSelectors()
    local selectorGroup = controls.expansionSelectors
    if not selectorGroup then
        return
    end

    local options = GetAvailableExpansions()
    local currentExpansionID = GetCurrentExpansionID()
    local previous = nil

    for index, option in ipairs(options) do
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
                SetExpansionVersion(self.expansionID)
                SettingsPanel:RefreshState()
            end)
            selectorGroup.checkboxes[index] = checkbox
        end

        checkbox:ClearAllPoints()
        checkbox:SetPoint("TOPLEFT", previous or selectorGroup.anchor, previous and "BOTTOMLEFT" or "BOTTOMLEFT", 0, previous and -8 or -12)
        checkbox.expansionID = option.id
        checkbox.label:SetText(option.label or option.id)
        checkbox:SetChecked(option.id == currentExpansionID)
        checkbox:Show()
        previous = checkbox
    end

    for index = #options + 1, #selectorGroup.checkboxes do
        selectorGroup.checkboxes[index]:Hide()
    end
end

local function RefreshVersionMapList()
    local mapList = controls.versionMapList
    if not mapList then
        return
    end

    local expansionID = GetCurrentExpansionID()
    mapList.expansionID = expansionID
    local mapIDs = GetExpansionMapIDs(expansionID)
    local hiddenMaps = GetHiddenMaps(expansionID)
    local previous = nil

    for index, checkbox in ipairs(mapList.checkboxes) do
        checkbox:Hide()
    end

    for index, mapID in ipairs(mapIDs) do
        local checkbox = mapList.checkboxes[index]
        if not checkbox then
            checkbox = CreateFrame("CheckButton", nil, mapList, "UICheckButtonTemplate")
            local label = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            label:SetPoint("LEFT", checkbox, "RIGHT", 4, 1)
            label:SetJustifyH("LEFT")
            checkbox.label = label
            checkbox:SetScript("OnClick", function(self)
                SetMapVisibleForExpansion(mapList.expansionID, self.mapID, self:GetChecked() == true)
                SettingsPanel:RefreshState()
            end)
            mapList.checkboxes[index] = checkbox
        end

        checkbox:ClearAllPoints()
        checkbox:SetPoint("TOPLEFT", previous or mapList.anchor, previous and "BOTTOMLEFT" or "BOTTOMLEFT", 0, previous and -8 or -12)
        checkbox.mapID = mapID
        checkbox.label:SetText(GetMapDisplayName(mapID))
        checkbox:SetChecked(hiddenMaps[mapID] ~= true)
        checkbox:Show()
        previous = checkbox
    end

    if mapList.emptyText then
        if #mapIDs == 0 then
            mapList.emptyText:Show()
        else
            mapList.emptyText:Hide()
        end
    end
end

local function SelectPage(pageKey)
    currentPage = ResolvePageKey(pageKey)
    for key, page in pairs(pages) do
        if key == currentPage then
            page:Show()
        else
            page:Hide()
        end
    end
    UpdateNavButtonStates()
end

local function BuildMainPage(parent)
    local page = CreatePageFrame(parent)
    pages[PAGE_MAIN] = page

    controls.addonToggle = CreateCheckbox(page, page.topAnchor, LT("SettingsAddonToggle", "插件开关"), function(enabled)
        if Commands and Commands.HandleAddonToggle then
            Commands:HandleAddonToggle(enabled)
        end
        SettingsPanel:RefreshState()
    end)

    controls.expansionLabel = CreateSectionLabel(page, controls.addonToggle, LT("SettingsExpansionVersion", "游戏版本"))

    local selectorGroup = CreateFrame("Frame", nil, page)
    selectorGroup:SetPoint("TOPLEFT", controls.expansionLabel, "BOTTOMLEFT", 0, 0)
    selectorGroup:SetSize(320, 100)
    selectorGroup.anchor = controls.expansionLabel
    selectorGroup.checkboxes = {}
    controls.expansionSelectors = selectorGroup

    controls.versionMapListLabel = CreateSectionLabel(page, selectorGroup, "地图列表")

    local mapList = CreateFrame("Frame", nil, page)
    mapList:SetPoint("TOPLEFT", controls.versionMapListLabel, "BOTTOMLEFT", 0, 0)
    mapList:SetSize(520, 260)
    mapList.checkboxes = {}
    mapList.anchor = controls.versionMapListLabel
    controls.versionMapList = mapList

    local emptyText = mapList:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    emptyText:SetPoint("TOPLEFT", mapList, "TOPLEFT", 0, -12)
    emptyText:SetText("-")
    mapList.emptyText = emptyText

    return page
end

local function BuildNotificationsPage(parent)
    local page = CreatePageFrame(parent)
    pages[PAGE_NOTIFICATIONS] = page

    controls.teamNotification = CreateCheckbox(page, page.topAnchor, LT("SettingsTeamNotify", "团队通知"), function(enabled)
        if Notification and Notification.SetTeamNotificationEnabled then
            Notification:SetTeamNotificationEnabled(enabled)
        end
        SettingsPanel:RefreshState()
    end)

    controls.soundAlert = CreateCheckbox(page, controls.teamNotification, LT("SettingsSoundAlert", "声音提示"), function(enabled)
        if Notification and Notification.SetSoundAlertEnabled then
            Notification:SetSoundAlertEnabled(enabled)
        end
        SettingsPanel:RefreshState()
    end)

    controls.autoReport = CreateCheckbox(page, controls.soundAlert, LT("SettingsAutoReport", "自动通知"), function(enabled)
        if Notification and Notification.SetAutoTeamReportEnabled then
            Notification:SetAutoTeamReportEnabled(enabled)
        end
        SettingsPanel:RefreshState()
    end)

    controls.intervalLabel, controls.intervalEditBox = CreateIntervalRow(page, controls.autoReport)
    return page
end

local function BuildAppearancePage(parent)
    local page = CreatePageFrame(parent)
    pages[PAGE_APPEARANCE] = page

    controls.theme = CreateValueRow(
        page,
        page.topAnchor,
        LT("SettingsThemeSwitch", "界面主题"),
        LT("SettingsThemeSwitch", "界面主题"),
        140,
        function()
            if SettingsPanelActions and SettingsPanelActions.CycleTheme then
                SettingsPanelActions:CycleTheme()
            end
            SettingsPanel:RefreshState()
        end
    )

    return page
end

local function BuildDataPage(parent)
    local page = CreatePageFrame(parent)
    pages[PAGE_DATA] = page

    controls.clearButton = CreateActionButton(page, LT("SettingsClearButton", "清除"), 120, function()
        if SettingsPanelActions and SettingsPanelActions.EnsureClearDialog then
            SettingsPanelActions:EnsureClearDialog()
        end
        StaticPopup_Show("CRATETRACKERZK_CLEAR_DATA")
    end)
    controls.clearButton:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)

    return page
end

local function BuildTextPage(parent, pageKey, providerText)
    local page = CreatePageFrame(parent)
    pages[pageKey] = page

    local contentHost = CreateFrame("Frame", nil, page)
    contentHost:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    contentHost:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -24, 0)
    CreateScrollableContent(contentHost, providerText)
    return page
end

local function BuildSettingsFrame()
    if settingsFrame then
        return settingsFrame
    end

    local frame = CreateFrame("Frame", "CrateTrackerZKSystemSettingsPanel", UIParent)
    settingsFrame = frame

    local navHost = CreateFrame("Frame", nil, frame)
    navHost:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -16)
    navHost:SetSize(720, 22)

    local lastButton = nil
    for _, pageKey in ipairs(pageOrder) do
        local button = CreateNavButton(navHost, GetPageLabel(pageKey), nil, function()
            SelectPage(pageKey)
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
    BuildTextPage(contentHost, PAGE_HELP, HelpTextProvider and HelpTextProvider.GetHelpText and HelpTextProvider:GetHelpText() or "")
    BuildTextPage(contentHost, PAGE_ABOUT, AboutTextProvider and AboutTextProvider.GetAboutText and AboutTextProvider:GetAboutText() or "")

    frame:SetScript("OnShow", function()
        SettingsPanel:RefreshState()
        SelectPage(currentPage or PAGE_MAIN)
    end)

    return frame
end

local function EnsureRegistered()
    if isRegistered then
        return
    end

    local frame = BuildSettingsFrame()
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        category = Settings.RegisterCanvasLayoutCategory(frame, ADDON_TITLE, ADDON_TITLE)
        Settings.RegisterAddOnCategory(category)
        isRegistered = true
        return
    end

    error("CrateTrackerZK settings require the modern Blizzard Settings API")
end

function SettingsPanel:RefreshState()
    local addonEnabled = true
    if SettingsPanelState and SettingsPanelState.IsAddonEnabled then
        addonEnabled = SettingsPanelState:IsAddonEnabled()
    end

    local teamEnabled = false
    if SettingsPanelState and SettingsPanelState.IsTeamNotificationEnabled then
        teamEnabled = addonEnabled and SettingsPanelState:IsTeamNotificationEnabled()
    end

    local soundEnabled = false
    if SettingsPanelState and SettingsPanelState.IsSoundAlertEnabled then
        soundEnabled = addonEnabled and SettingsPanelState:IsSoundAlertEnabled()
    end

    local autoEnabled = false
    if SettingsPanelState and SettingsPanelState.IsAutoTeamReportEnabled then
        autoEnabled = addonEnabled and teamEnabled and SettingsPanelState:IsAutoTeamReportEnabled()
    end

    if controls.addonToggle then
        controls.addonToggle:SetChecked(addonEnabled)
        SetTextEnabled(controls.addonToggle.label, true)
    end

    if controls.teamNotification then
        controls.teamNotification:SetChecked(teamEnabled)
        controls.teamNotification:SetEnabled(addonEnabled)
        SetTextEnabled(controls.teamNotification.label, addonEnabled)
    end

    if controls.soundAlert then
        controls.soundAlert:SetChecked(soundEnabled)
        controls.soundAlert:SetEnabled(addonEnabled)
        SetTextEnabled(controls.soundAlert.label, addonEnabled)
    end

    if controls.autoReport then
        local autoAvailable = addonEnabled and teamEnabled
        controls.autoReport:SetChecked(autoEnabled)
        controls.autoReport:SetEnabled(autoAvailable)
        SetTextEnabled(controls.autoReport.label, autoAvailable)
    end

    if controls.intervalEditBox and controls.intervalLabel then
        local intervalEnabled = addonEnabled and teamEnabled and autoEnabled
        controls.intervalEditBox:SetEnabled(intervalEnabled)
        controls.intervalEditBox:SetText(tostring(SettingsPanelState and SettingsPanelState.GetAutoTeamReportInterval and SettingsPanelState:GetAutoTeamReportInterval() or 60))
        SetTextEnabled(controls.intervalLabel, intervalEnabled)
    end

    if controls.theme then
        local themeEnabled = SettingsPanelState and SettingsPanelState.IsThemeSwitchEnabled and SettingsPanelState:IsThemeSwitchEnabled() or false
        local themeText = SettingsPanelState and SettingsPanelState.GetCurrentThemeButtonText and SettingsPanelState:GetCurrentThemeButtonText() or "N/A"
        controls.theme.value:SetText(themeText)
        controls.theme.button:SetEnabled(themeEnabled)
        SetValueEnabled(controls.theme.value, themeEnabled)
        SetTextEnabled(controls.theme.label, true)
    end

    RefreshExpansionSelectors()
    RefreshVersionMapList()
end

function SettingsPanel:Show()
    self:ShowTab(PAGE_MAIN)
end

function SettingsPanel:Hide()
    if settingsFrame and settingsFrame:IsShown() then
        settingsFrame:Hide()
    end
end

function SettingsPanel:IsShown()
    return settingsFrame and settingsFrame:IsShown() or false
end

function SettingsPanel:Toggle()
    if self:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function SettingsPanel:ShowTab(tabName)
    EnsureRegistered()
    currentPage = ResolvePageKey(tabName)
    SelectPage(currentPage)

    if category and Settings and Settings.OpenToCategory then
        local categoryID = category.GetID and category:GetID() or category.ID or category
        Settings.OpenToCategory(categoryID)
    end
end

return SettingsPanel

local SettingsPanelView = BuildEnv("CrateTrackerZKSettingsPanelView")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local SettingsPanelState = BuildEnv("CrateTrackerZKSettingsPanelState")
local SettingsPanelActions = BuildEnv("CrateTrackerZKSettingsPanelActions")
local SettingsPanelFactory = BuildEnv("CrateTrackerZKSettingsPanelFactory")
local SettingsPanelPages = BuildEnv("CrateTrackerZKSettingsPanelPages")
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

Localization Contributors:
esMX: DarkChiken
koKR: 007bb
ruRU: ZamestoTV
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

local function UpdateButtonText(button, text, minWidth)
    if SettingsPanelFactory and SettingsPanelFactory.UpdateButtonText then
        return SettingsPanelFactory:UpdateButtonText(button, text, minWidth)
    end
end

local function GetHelpText()
    return LT("SettingsHelpText", "")
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

    if controls.leaderMode then
        controls.leaderMode:SetChecked(snapshot.leaderModeEnabled == true)
        controls.leaderMode:SetEnabled(snapshot.leaderModeInteractable == true)
        SetTextEnabled(controls.leaderMode.label, snapshot.leaderModeInteractable == true)
    end

    if controls.phaseTeamAlert then
        controls.phaseTeamAlert:SetChecked(snapshot.phaseTeamAlertEnabled == true)
        controls.phaseTeamAlert:SetEnabled(snapshot.phaseTeamAlertInteractable == true)
        SetTextEnabled(controls.phaseTeamAlert.label, snapshot.phaseTeamAlertInteractable == true)
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

    if SettingsPanelPages and SettingsPanelPages.RefreshTrackedMapGroups then
        SettingsPanelPages:RefreshTrackedMapGroups(controls, snapshot.mapGroups or {}, LT, function()
            SettingsPanelView:RefreshState()
        end)
    end
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

    local contentDivider = SettingsPanelFactory and SettingsPanelFactory.CreateDivider and SettingsPanelFactory:CreateDivider(frame, navHost, -8)
    local contentHost = CreateFrame("Frame", nil, frame)
    contentHost:SetPoint("TOPLEFT", contentDivider, "BOTTOMLEFT", 0, -14)
    contentHost:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 16)

    if SettingsPanelPages then
        SettingsPanelPages:BuildMainPage(contentHost, self.PAGE_MAIN, pages, controls, LT, function()
            SettingsPanelView:RefreshState()
        end)
        SettingsPanelPages:BuildNotificationsPage(contentHost, self.PAGE_NOTIFICATIONS, pages, controls, LT, function()
            SettingsPanelView:RefreshState()
        end, function(editBox)
            if SettingsPanelActions and SettingsPanelActions.ApplyAutoTeamReportInterval then
                SettingsPanelActions:ApplyAutoTeamReportInterval(editBox)
            end
            SettingsPanelView:RefreshState()
        end)
        SettingsPanelPages:BuildAppearancePage(contentHost, self.PAGE_APPEARANCE, pages, controls, LT, function()
            SettingsPanelView:RefreshState()
        end)
        SettingsPanelPages:BuildDataPage(contentHost, self.PAGE_DATA, pages, controls, LT)
        SettingsPanelPages:BuildTextPage(contentHost, self.PAGE_HELP, pages, GetHelpText())
        SettingsPanelPages:BuildTextPage(contentHost, self.PAGE_ABOUT, pages, ABOUT_TEXT)
    end

    frame:SetScript("OnShow", function()
        SettingsPanelView:RefreshState()
        SettingsPanelView:SelectPage(currentPage or SettingsPanelView.PAGE_MAIN)
    end)

    return frameRef
end

return SettingsPanelView

local SettingsPanel = BuildEnv("CrateTrackerZKSettingsPanel")
local SettingsPanelView = BuildEnv("CrateTrackerZKSettingsPanelView")

local ADDON_TITLE = "CrateTrackerZK"
local category = nil
local settingsFrame = nil
local isRegistered = false

local function BuildSettingsFrame()
    if settingsFrame then
        return settingsFrame
    end

    settingsFrame = CreateFrame("Frame", "CrateTrackerZKSystemSettingsPanel", UIParent)
    if SettingsPanelView and SettingsPanelView.Build then
        SettingsPanelView:Build(settingsFrame)
    end
    return settingsFrame
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
    if SettingsPanelView and SettingsPanelView.RefreshState then
        SettingsPanelView:RefreshState()
    end
end

function SettingsPanel:Show()
    local defaultPage = SettingsPanelView and SettingsPanelView.GetDefaultPage and SettingsPanelView:GetDefaultPage() or "main"
    self:ShowTab(defaultPage)
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
    local targetPage = SettingsPanelView and SettingsPanelView.ResolvePageKey and SettingsPanelView:ResolvePageKey(tabName) or tabName
    if SettingsPanelView and SettingsPanelView.SelectPage then
        SettingsPanelView:SelectPage(targetPage)
    end

    if category and Settings and Settings.OpenToCategory then
        local categoryID = category.GetID and category:GetID() or category.ID or category
        Settings.OpenToCategory(categoryID)
    end
end

return SettingsPanel

local SettingsPanelPages = BuildEnv("CrateTrackerZKSettingsPanelPages")
local SettingsPanelActions = BuildEnv("CrateTrackerZKSettingsPanelActions")
local SettingsPanelFactory = BuildEnv("CrateTrackerZKSettingsPanelFactory")

function SettingsPanelPages:RefreshExpansionSelectors(controls, expansionOptions, currentExpansionID, onRefresh)
    local selectorGroup = controls and controls.expansionSelectors
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
                if onRefresh then
                    onRefresh()
                end
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

function SettingsPanelPages:RefreshVersionMapList(controls, mapOptions, currentExpansionID, onRefresh)
    local mapList = controls and controls.versionMapList
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
                if onRefresh then
                    onRefresh()
                end
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

function SettingsPanelPages:BuildMainPage(parent, pageKey, pages, controls, lt, onRefresh)
    local page = SettingsPanelFactory:CreatePageFrame(parent)
    pages[pageKey] = page

    controls.addonToggle = SettingsPanelFactory:CreateCheckbox(page, page.topAnchor, lt("SettingsAddonToggle", "插件开关"), function(enabled)
        if SettingsPanelActions and SettingsPanelActions.SetAddonEnabled then
            SettingsPanelActions:SetAddonEnabled(enabled)
        end
        if onRefresh then
            onRefresh()
        end
    end)

    controls.expansionLabel = SettingsPanelFactory:CreateSectionLabel(page, controls.addonToggle, lt("SettingsExpansionVersion", "地图版本"))

    local selectorGroup = CreateFrame("Frame", nil, page)
    selectorGroup:SetPoint("TOPLEFT", controls.expansionLabel, "BOTTOMLEFT", 0, 0)
    selectorGroup:SetSize(520, 28)
    selectorGroup.anchor = controls.expansionLabel
    selectorGroup.checkboxes = {}
    controls.expansionSelectors = selectorGroup

    controls.versionMapListLabel = SettingsPanelFactory:CreateSectionLabel(page, selectorGroup, lt("SettingsMapList", "地图列表"))

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

function SettingsPanelPages:BuildNotificationsPage(parent, pageKey, pages, controls, lt, onRefresh, onApplyInterval)
    local page = SettingsPanelFactory:CreatePageFrame(parent)
    pages[pageKey] = page

    controls.teamNotification = SettingsPanelFactory:CreateCheckbox(page, page.topAnchor, lt("SettingsTeamNotify", "团队通知"), function(enabled)
        if SettingsPanelActions and SettingsPanelActions.SetTeamNotificationEnabled then
            SettingsPanelActions:SetTeamNotificationEnabled(enabled)
        end
        if onRefresh then
            onRefresh()
        end
    end)

    controls.soundAlert = SettingsPanelFactory:CreateCheckbox(page, controls.teamNotification, lt("SettingsSoundAlert", "声音提示"), function(enabled)
        if SettingsPanelActions and SettingsPanelActions.SetSoundAlertEnabled then
            SettingsPanelActions:SetSoundAlertEnabled(enabled)
        end
        if onRefresh then
            onRefresh()
        end
    end)

    controls.autoReport = SettingsPanelFactory:CreateCheckbox(page, controls.soundAlert, lt("SettingsAutoReport", "自动通知"), function(enabled)
        if SettingsPanelActions and SettingsPanelActions.SetAutoTeamReportEnabled then
            SettingsPanelActions:SetAutoTeamReportEnabled(enabled)
        end
        if onRefresh then
            onRefresh()
        end
    end)

    controls.intervalLabel, controls.intervalEditBox = SettingsPanelFactory:CreateIntervalRow(
        page,
        controls.autoReport,
        lt("SettingsAutoReportInterval", "通知频率（秒）"),
        onApplyInterval
    )
end

function SettingsPanelPages:BuildAppearancePage(parent, pageKey, pages, controls, lt, onRefresh)
    local page = SettingsPanelFactory:CreatePageFrame(parent)
    pages[pageKey] = page

    controls.theme = SettingsPanelFactory:CreateInlineButtonRow(
        page,
        page.topAnchor,
        lt("SettingsThemeSwitch", "界面主题"),
        "N/A",
        160,
        function()
            if SettingsPanelActions and SettingsPanelActions.CycleTheme then
                SettingsPanelActions:CycleTheme()
            end
            if onRefresh then
                onRefresh()
            end
        end
    )
end

function SettingsPanelPages:BuildDataPage(parent, pageKey, pages, controls, lt)
    local page = SettingsPanelFactory:CreatePageFrame(parent)
    pages[pageKey] = page

    controls.clearButton = SettingsPanelFactory:CreateActionButton(page, lt("SettingsClearButton", "清除"), 120, function()
        if SettingsPanelActions and SettingsPanelActions.EnsureClearDialog then
            SettingsPanelActions:EnsureClearDialog()
        end
        if StaticPopup_Show then
            StaticPopup_Show("CRATETRACKERZK_CLEAR_DATA")
        end
    end)
    controls.clearButton:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
end

function SettingsPanelPages:BuildTextPage(parent, pageKey, pages, providerText)
    local page = SettingsPanelFactory:CreatePageFrame(parent)
    pages[pageKey] = page

    local contentHost = CreateFrame("Frame", nil, page)
    contentHost:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    contentHost:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -24, 0)
    SettingsPanelFactory:CreateScrollableContent(contentHost, providerText)
end

return SettingsPanelPages

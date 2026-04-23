local SettingsPanelPages = BuildEnv("CrateTrackerZKSettingsPanelPages")
local SettingsPanelActions = BuildEnv("CrateTrackerZKSettingsPanelActions")
local SettingsPanelFactory = BuildEnv("CrateTrackerZKSettingsPanelFactory")

local function CreateMapGroupFrame(parent, lt, onRefresh)
    local group = CreateFrame("Frame", nil, parent)
    group:SetSize(520, 40)

    local divider = group:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetColorTexture(1, 1, 1, 0.12)
    divider:SetPoint("TOPLEFT", group, "TOPLEFT", 0, 0)
    divider:SetPoint("TOPRIGHT", group, "TOPRIGHT", -12, 0)
    group.divider = divider

    local title = group:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("TOPLEFT", group, "TOPLEFT", 0, -12)
    title:SetJustifyH("LEFT")
    group.title = title

    group.checkboxes = {}
    return group
end

local function CreateTrackedMapCheckbox(parent, onRefresh)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    local label = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", checkbox, "RIGHT", 4, 1)
    label:SetJustifyH("LEFT")
    if label.SetWordWrap then
        label:SetWordWrap(false)
    end
    checkbox.label = label
    checkbox:SetScript("OnClick", function(self)
        if SettingsPanelActions and SettingsPanelActions.SetTrackedMap then
            SettingsPanelActions:SetTrackedMap(self.expansionID, self.mapID, self:GetChecked() == true)
        end
        if onRefresh then
            onRefresh()
        end
    end)
    return checkbox
end

local function LayoutMapSelectionPanel(panel)
    if not panel or not panel.scroll or not panel.content then
        return
    end
    local viewWidth = panel.scroll:GetWidth() or panel.width or 520
    local contentWidth = math.max(320, math.floor(viewWidth - 28))
    panel.width = contentWidth
    panel.content:SetWidth(contentWidth)
end

function SettingsPanelPages:RefreshTrackedMapGroups(controls, mapGroups, lt, onRefresh)
    local panel = controls and controls.mapSelectionPanel
    if not panel then
        return
    end

    LayoutMapSelectionPanel(panel)

    for _, group in ipairs(panel.groups) do
        group:Hide()
        for _, checkbox in ipairs(group.checkboxes) do
            checkbox:Hide()
        end
    end

    local previous = nil
    local totalHeight = 0

    for index, groupInfo in ipairs(mapGroups or {}) do
        local group = panel.groups[index]
        if not group then
            group = CreateMapGroupFrame(panel.content, lt, onRefresh)
            panel.groups[index] = group
        end

        group:ClearAllPoints()
        if previous then
            group:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -14)
        else
            group:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, 0)
        end
        group:SetWidth(panel.width)

        group.divider:SetShown(index > 1)
        group.title:SetText(groupInfo.label or groupInfo.id or "N/A")

        local columnGap = 24
        local columnWidth = math.max(180, math.floor((panel.width - columnGap) / 2))
        local rowHeight = 30
        local baseOffsetY = -40
        for mapIndex, mapInfo in ipairs(groupInfo.maps or {}) do
            local checkbox = group.checkboxes[mapIndex]
            if not checkbox then
                checkbox = CreateTrackedMapCheckbox(group, onRefresh)
                group.checkboxes[mapIndex] = checkbox
            end

            local rowIndex = math.floor((mapIndex - 1) / 2)
            local columnIndex = (mapIndex - 1) % 2
            local xOffset = columnIndex * (columnWidth + columnGap)
            local yOffset = baseOffsetY - (rowIndex * rowHeight)

            checkbox:ClearAllPoints()
            checkbox:SetPoint("TOPLEFT", group, "TOPLEFT", xOffset, yOffset)
            checkbox.expansionID = groupInfo.id
            checkbox.mapID = mapInfo.id
            checkbox.label:SetWidth(columnWidth - 28)
            checkbox.label:SetText(mapInfo.label or tostring(mapInfo.id))
            checkbox:SetChecked(mapInfo.tracked == true)
            checkbox:Show()
        end

        for mapIndex = #(groupInfo.maps or {}) + 1, #group.checkboxes do
            group.checkboxes[mapIndex]:Hide()
        end

        local rowCount = math.max(1, math.ceil(#(groupInfo.maps or {}) / 2))
        local groupHeight = 40 + (rowCount * rowHeight)
        if index > 1 then
            groupHeight = groupHeight + 10
        end
        group:SetHeight(groupHeight)
        group:Show()

        previous = group
        totalHeight = totalHeight + groupHeight
        if index < #(mapGroups or {}) then
            totalHeight = totalHeight + 14
        end
    end

    if panel.emptyText then
        if #(mapGroups or {}) == 0 then
            panel.emptyText:Show()
        else
            panel.emptyText:Hide()
        end
    end

    local minHeight = panel.scroll:GetHeight() or panel.minHeight or 260
    panel.content:SetHeight(math.max(minHeight, totalHeight))
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

    controls.mapSelectionLabel = SettingsPanelFactory:CreateSectionLabel(page, controls.addonToggle, lt("SettingsMapSelection", "地图选择"))

    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", controls.mapSelectionLabel, "BOTTOMLEFT", 0, -10)
    scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -28, 0)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(520, 260)
    scroll:SetScrollChild(content)

    local panel = {
        scroll = scroll,
        content = content,
        groups = {},
        width = 520,
        minHeight = 260,
    }
    controls.mapSelectionPanel = panel

    local emptyText = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    emptyText:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    emptyText:SetText("-")
    panel.emptyText = emptyText

    scroll:SetScript("OnSizeChanged", function()
        LayoutMapSelectionPanel(panel)
        if onRefresh then
            onRefresh()
        end
    end)
end

function SettingsPanelPages:BuildNotificationsPage(parent, pageKey, pages, controls, lt, onRefresh, onApplyInterval)
    local page = SettingsPanelFactory:CreatePageFrame(parent)
    pages[pageKey] = page

    controls.leaderMode = SettingsPanelFactory:CreateCheckbox(page, page.topAnchor, lt("SettingsLeaderMode", "团长模式"), function(enabled)
        if SettingsPanelActions and SettingsPanelActions.SetLeaderModeEnabled then
            SettingsPanelActions:SetLeaderModeEnabled(enabled)
        end
        if onRefresh then
            onRefresh()
        end
    end, lt("SettingsLeaderModeTooltip", "开启后，团队中的可见空投通知与自动播报会优先发送到团队警告频道；如果当前没有团队警告权限，则自动回落到普通团队频道。"))

    controls.teamNotification = SettingsPanelFactory:CreateCheckbox(page, controls.leaderMode, lt("SettingsTeamNotify", "团队通知"), function(enabled)
        if SettingsPanelActions and SettingsPanelActions.SetTeamNotificationEnabled then
            SettingsPanelActions:SetTeamNotificationEnabled(enabled)
        end
        if onRefresh then
            onRefresh()
        end
    end)

    controls.phaseTeamAlert = SettingsPanelFactory:CreateCheckbox(
        page,
        controls.teamNotification,
        lt("SettingsPhaseTeamAlert", "位面变化团队报告"),
        function(enabled)
            if SettingsPanelActions and SettingsPanelActions.SetPhaseTeamAlertEnabled then
                SettingsPanelActions:SetPhaseTeamAlertEnabled(enabled)
            end
            if onRefresh then
                onRefresh()
            end
        end,
        lt(
            "SettingsPhaseTeamAlertTooltip",
            "开启后，检测到当前地图位面发生变化时，会发送“当前某地图位面发生变化”到小队或团队频道。"
        )
    )

    controls.soundAlert = SettingsPanelFactory:CreateCheckbox(page, controls.phaseTeamAlert, lt("SettingsSoundAlert", "声音提醒"), function(enabled)
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

    controls.trajectoryPredictionTest = SettingsPanelFactory:CreateCheckbox(
        page,
        controls.intervalLabel,
        lt("SettingsTrajectoryPredictionTest", "测试：轨迹预测通报与标记"),
        function(enabled)
            if SettingsPanelActions and SettingsPanelActions.SetTrajectoryPredictionTestEnabled then
                SettingsPanelActions:SetTrajectoryPredictionTestEnabled(enabled)
            end
            if onRefresh then
                onRefresh()
            end
        end
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

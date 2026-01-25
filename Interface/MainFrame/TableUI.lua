-- TableUI.lua - 表格界面

local TableUI = BuildEnv("TableUI")
local UIConfig = BuildEnv("UIConfig")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local SortingSystem = BuildEnv("SortingSystem")
local CountdownSystem = BuildEnv("CountdownSystem")
local RowStateSystem = BuildEnv("RowStateSystem")
local MainPanel = BuildEnv("MainPanel")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local L = CrateTrackerZK.L

local tableRows = {}

local function GetConfig()
    return UIConfig.values
end

local function GetColumnDebugColors(isHeader)
    local cfg = GetConfig()
    local debug = cfg.columnDebug
    if not debug or not debug.enabled then
        return nil
    end
    if isHeader and debug.headerColors then
        return debug.headerColors
    end
    return debug.colors
end

local function ApplyColumnDebug(parent, colWidths, height, colors)
    if not parent or not colors then
        return
    end
    local currentX = 0
    for index, width in ipairs(colWidths) do
        local color = colors[index]
        if color then
            local colBg = parent:CreateTexture(nil, "BORDER")
            colBg:SetSize(width, height)
            colBg:SetPoint("TOPLEFT", parent, "TOPLEFT", currentX, 0)
            colBg:SetColorTexture(color[1], color[2], color[3], color[4])
        end
        currentX = currentX + width
    end
end

function TableUI:RebuildUI(frame, headerLabels)
    if not frame then return end
    if not SortingSystem then return end

    local rows = SortingSystem:GetCurrentRows() or {}

    for _, rowFrame in pairs(tableRows) do
        if rowFrame and rowFrame:GetObjectType() == "Frame" then
            rowFrame:Hide()
            rowFrame:SetParent(nil)
        end
    end
    tableRows = {}

    if CountdownSystem then
        CountdownSystem:ClearTexts()
    end

    if RowStateSystem then
        RowStateSystem:ClearRowRefs()
    end

    local colWidths = {140, 80, 90, 90, 160}
    local rowHeight = 35
    local tableWidth = 560
    local startX = 20
    local startY = 35

    self:CreateHeaderRow(frame, headerLabels, colWidths, rowHeight, tableWidth, startX, startY)

    for displayIndex, rowInfo in ipairs(rows) do
        self:CreateDataRow(frame, rowInfo, displayIndex, colWidths, rowHeight, startX, startY)
    end

    if SortingSystem then
        SortingSystem:UpdateHeaderVisual()
    end
end

function TableUI:CreateHeaderRow(frame, headerLabels, colWidths, rowHeight, tableWidth, startX, startY)
    local cfg = GetConfig()
    local headerRowFrame = CreateFrame("Frame", nil, frame)
    headerRowFrame:SetSize(tableWidth, rowHeight - 4)
    headerRowFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", startX, -startY)
    headerRowFrame:SetFrameLevel(frame:GetFrameLevel() + 10)
    headerRowFrame:SetAlpha(1.0)

    local headerBg = headerRowFrame:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints(headerRowFrame)
    local headerColor = cfg.headerRowColor or {1, 1, 1, 0.22}
    headerBg:SetColorTexture(headerColor[1], headerColor[2], headerColor[3], headerColor[4])

    local headerDebugColors = GetColumnDebugColors(true)
    if headerDebugColors then
        ApplyColumnDebug(headerRowFrame, colWidths, rowHeight - 4, headerDebugColors)
    end

    local currentX = 0
    for colIndex, label in ipairs(headerLabels) do
        if colIndex <= 5 then
            if colIndex == 4 then
                local sortHeaderButton = self:CreateSortHeaderButton(headerRowFrame, label, colWidths[colIndex], rowHeight, currentX)
                if SortingSystem then
                    SortingSystem:SetHeaderButton(sortHeaderButton)
                end
            else
                self:CreateHeaderText(headerRowFrame, label, colIndex, colWidths[colIndex], currentX, headerBg)
            end
        end
        currentX = currentX + colWidths[colIndex]
    end

    table.insert(tableRows, headerRowFrame)
end

function TableUI:CreateSortHeaderButton(parent, label, colWidth, rowHeight, currentX)
    local cfg = GetConfig()
    local sortHeaderButton = CreateFrame("Button", nil, parent)
    sortHeaderButton:SetSize(colWidth, rowHeight - 4)
    sortHeaderButton:SetPoint("CENTER", parent, "LEFT", currentX + colWidth / 2, 0)

    local buttonBg = sortHeaderButton:CreateTexture(nil, "BACKGROUND")
    buttonBg:SetAllPoints(sortHeaderButton)
    buttonBg:SetColorTexture(0, 0, 0, 0)

    local buttonText = sortHeaderButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    buttonText:SetPoint("CENTER", sortHeaderButton, "CENTER", 0, 0)
    buttonText:SetText(label)
    buttonText:SetTextColor(cfg.textColor[1], cfg.textColor[2], cfg.textColor[3], cfg.textColor[4])
    buttonText:SetJustifyH("CENTER")
    buttonText:SetJustifyV("MIDDLE")
    buttonText:SetShadowOffset(0, 0)

    sortHeaderButton:SetScript("OnClick", function()
        if SortingSystem then
            SortingSystem:OnHeaderClick()
        end
    end)

    sortHeaderButton:SetScript("OnEnter", function()
        buttonBg:SetColorTexture(1, 1, 1, 0.25)
    end)
    sortHeaderButton:SetScript("OnLeave", function()
        buttonBg:SetColorTexture(0, 0, 0, 0)
    end)

    return sortHeaderButton
end

function TableUI:CreateHeaderText(parent, label, colIndex, colWidth, currentX, headerBg)
    local cfg = GetConfig()
    local cellText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")

    if colIndex == 1 then
        cellText:SetPoint("LEFT", headerBg, "LEFT", currentX + 15, 0)
        cellText:SetJustifyH("LEFT")
    else
        cellText:SetPoint("CENTER", headerBg, "LEFT", currentX + colWidth / 2, 0)
        cellText:SetJustifyH("CENTER")
    end

    cellText:SetText(label)
    cellText:SetJustifyV("MIDDLE")
    cellText:SetShadowOffset(0, 0)
    cellText:SetTextColor(cfg.textColor[1], cfg.textColor[2], cfg.textColor[3], cfg.textColor[4])
end

function TableUI:CreateDataRow(frame, rowInfo, displayIndex, colWidths, rowHeight, startX, startY)
    local cfg = GetConfig()
    local rowId = rowInfo.rowId
    local actualRowIndex = displayIndex + 1
    local tableWidth = 560

    local rowFrame = CreateFrame("Frame", nil, frame)
    rowFrame:SetSize(tableWidth, rowHeight - 4)
    rowFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", startX, -startY - actualRowIndex * rowHeight + rowHeight)
    rowFrame:SetFrameLevel(frame:GetFrameLevel() + 10)
    rowFrame:SetAlpha(1.0)
    rowFrame:EnableMouse(true)

    local rowBg = rowFrame:CreateTexture(nil, "BACKGROUND")
    rowBg:SetAllPoints(rowFrame)

    local rowColor = cfg.dataRowColors and cfg.dataRowColors[displayIndex]
    if rowInfo.isHidden then
        rowBg:SetColorTexture(0.5, 0.5, 0.5, 0.3)
        rowFrame:SetAlpha(0.6)
    elseif rowColor then
        rowBg:SetColorTexture(rowColor[1], rowColor[2], rowColor[3], rowColor[4])
    else
        rowBg:SetColorTexture(1, 1, 1, 0.16)
    end

    local rowDebugColors = GetColumnDebugColors(false)
    if rowDebugColors then
        ApplyColumnDebug(rowFrame, colWidths, rowHeight - 4, rowDebugColors)
    end

    if RowStateSystem then
        RowStateSystem:RegisterRowFrame(rowId, rowFrame)
        RowStateSystem:SyncRowState(rowId, rowInfo.isHidden)
    end

    rowFrame:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" and RowStateSystem then
            local currentState = RowStateSystem:GetRowState(rowId)
            if currentState.rightClicked then
                RowStateSystem:OnGlobalLeftClick()
            else
                RowStateSystem:OnGlobalLeftClick()
                RowStateSystem:OnRowRightClick(rowId)
            end
        elseif button == "LeftButton" and RowStateSystem then
            RowStateSystem:OnGlobalLeftClick()
        end
    end)

    self:CreateRowCells(rowFrame, rowInfo, colWidths, rowBg)

    local refreshBtn, notifyBtn = self:CreateActionButtons(rowFrame, rowInfo, colWidths, rowBg)
    if RowStateSystem and refreshBtn and notifyBtn then
        RowStateSystem:RegisterRowButtons(rowId, refreshBtn, notifyBtn)
    end

    table.insert(tableRows, rowFrame)
end

function TableUI:CreateRowCells(rowFrame, rowInfo, colWidths, rowBg)
    local cfg = GetConfig()
    local currentX = 0

    local phaseText = L["NotAcquired"] or "N/A"
    local phaseColor = cfg.textColor
    if rowInfo.currentPhaseID then
        phaseText = tostring(rowInfo.currentPhaseID)
        if #phaseText > 10 then
            phaseText = string.sub(phaseText, 1, 10)
        end
    end
    if rowInfo.phaseDisplayInfo and rowInfo.phaseDisplayInfo.color then
        phaseColor = {rowInfo.phaseDisplayInfo.color.r, rowInfo.phaseDisplayInfo.color.g, rowInfo.phaseDisplayInfo.color.b, 1}
    elseif rowInfo.currentPhaseID and cfg.phaseIdColor then
        phaseColor = cfg.phaseIdColor
    end

    local lastRefreshText = rowInfo.lastRefresh and UnifiedDataManager:FormatDateTime(rowInfo.lastRefresh) or (L["NoRecord"] or "--:--")
    local lastColor = cfg.textColor
    if rowInfo.lastRefresh then
        if rowInfo.isPersistent then
            lastColor = {0, 1, 0, 1}
        elseif UnifiedDataManager and UnifiedDataManager.TimeSource and rowInfo.timeSource == UnifiedDataManager.TimeSource.REFRESH_BUTTON then
            lastColor = {0.7, 1, 0.7, 1}
        end
    end
    local nextRefreshText = rowInfo.remainingTime and UnifiedDataManager:FormatTime(rowInfo.remainingTime) or (L["NoRecord"] or "--:--")

    local columns = {
        {text = rowInfo.mapName, align = "left", color = cfg.textColor},
        {text = phaseText, align = "center", color = phaseColor},
        {text = lastRefreshText, align = "center", color = lastColor},
        {text = nextRefreshText, align = "center", color = cfg.textColor, isCountdown = true},
    }

    for colIndex, colData in ipairs(columns) do
        local cellText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")

        if colIndex == 1 then
            cellText:SetPoint("LEFT", rowBg, "LEFT", currentX + 15, 0)
            cellText:SetJustifyH("LEFT")
        else
            cellText:SetPoint("CENTER", rowBg, "LEFT", currentX + colWidths[colIndex] / 2, 0)
            cellText:SetJustifyH("CENTER")
        end

        cellText:SetText(colData.text or "")
        cellText:SetJustifyV("MIDDLE")
        cellText:SetShadowOffset(0, 0)

        local textColor = colData.color or cfg.textColor
        if rowInfo.isHidden then
            cellText:SetTextColor(0.5, 0.5, 0.5, 0.8)
        else
            cellText:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
        end

        if colData.isCountdown and CountdownSystem then
            CountdownSystem:RegisterText(rowInfo.rowId, cellText)
        end

        currentX = currentX + colWidths[colIndex]
    end
end

function TableUI:CreateActionButtons(rowFrame, rowInfo, colWidths, rowBg)
    local rowId = rowInfo.rowId
    local operationColumnStart = colWidths[1] + colWidths[2] + colWidths[3] + colWidths[4]
    local operationColumnWidth = colWidths[5]
    local columnCenter = operationColumnStart + operationColumnWidth / 2
    local button1X = columnCenter - 36
    local button2X = columnCenter + 36

    local refreshText = L["Refresh"] or "刷新"
    local notifyText = L["Notify"] or "通知"

    local refreshBtn = self:CreateActionButton(rowFrame, rowBg, refreshText, button1X, function()
        if rowInfo.isHidden then
            return
        end
        if MainPanel and MainPanel.RefreshMap then
            MainPanel:RefreshMap(rowId)
        end
    end, "refresh", rowInfo.isHidden)

    local notifyBtn = self:CreateActionButton(rowFrame, rowBg, notifyText, button2X, function()
        if rowInfo.isHidden then
            return
        end
        if MainPanel and MainPanel.NotifyMapById then
            MainPanel:NotifyMapById(rowId)
        end
    end, "notify", rowInfo.isHidden)

    return refreshBtn, notifyBtn
end

function TableUI:CreateActionButton(parent, parentBg, text, x, clickHandler, buttonType, isHidden)
    local cfg = GetConfig()
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(30, 20)
    btn:SetPoint("CENTER", parentBg, "LEFT", x, 0)
    btn:SetFrameLevel(parent:GetFrameLevel() + 1)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(btn)
    local normalColor = cfg.actionButtonColors and cfg.actionButtonColors[buttonType] or {1, 1, 1, cfg.buttonAlpha}
    bg:SetColorTexture(normalColor[1], normalColor[2], normalColor[3], normalColor[4])

    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btnText:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btnText:SetText(text)
    btnText:SetJustifyH("CENTER")
    btnText:SetJustifyV("MIDDLE")
    btnText:SetShadowOffset(0, 0)

    local normalTextColor = nil
    if isHidden then
        normalTextColor = {0.5, 0.5, 0.5, 0.8}
    else
        normalTextColor = {cfg.textColor[1], cfg.textColor[2], cfg.textColor[3], cfg.textColor[4]}
    end
    btnText:SetTextColor(normalTextColor[1], normalTextColor[2], normalTextColor[3], normalTextColor[4])

    btn:SetScript("OnClick", function()
        clickHandler()
    end)

    btn:SetScript("OnEnter", function()
        if isHidden then
            return
        end
        local hoverText = cfg.actionButtonTextHoverColor or {1, 0.9, 0.2, 1}
        btnText:SetTextColor(hoverText[1], hoverText[2], hoverText[3], hoverText[4])
    end)
    btn:SetScript("OnLeave", function()
        btnText:SetTextColor(normalTextColor[1], normalTextColor[2], normalTextColor[3], normalTextColor[4])
    end)

    return btn
end

return TableUI

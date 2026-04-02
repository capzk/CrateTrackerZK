-- TableUIRenderer.lua - 表格头部与行渲染器

local TableUIRenderer = BuildEnv("TableUIRenderer")
local UIConfig = BuildEnv("ThemeConfig")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local SortingSystem = BuildEnv("SortingSystem")
local CountdownSystem = BuildEnv("CountdownSystem")
local MainPanel = BuildEnv("MainPanel")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local TableUILayoutEngine = BuildEnv("TableUILayoutEngine")
local TableUITextMetrics = BuildEnv("TableUITextMetrics")
local L = CrateTrackerZK.L

local tableRows = {}
local rowFramePool = {}
local headerRowFrame = nil
local visibleRowFrameByRowId = {}
local FIXED_ROW_HEIGHT = 29
local MAP_COL_COMPACT_MIN_CHARS = 1
local MAP_ROW_TEXT_HEIGHT_RATIO = 0.70

local function ClearArray(buffer)
    for index = #buffer, 1, -1 do
        buffer[index] = nil
    end
    return buffer
end

local function ClearMap(buffer)
    for key in pairs(buffer) do
        buffer[key] = nil
    end
    return buffer
end

local function GetConfig()
    return UIConfig
end

local function IsAddonEnabled()
    if not CRATETRACKERZK_UI_DB or CRATETRACKERZK_UI_DB.addonEnabled == nil then
        return true
    end
    return CRATETRACKERZK_UI_DB.addonEnabled == true
end

local function Clamp(value, minValue, maxValue)
    if TableUILayoutEngine and TableUILayoutEngine.Clamp then
        return TableUILayoutEngine:Clamp(value, minValue, maxValue)
    end
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function FormatPhaseDisplayText(phaseValue)
    if TableUILayoutEngine and TableUILayoutEngine.FormatPhaseDisplayText then
        return TableUILayoutEngine:FormatPhaseDisplayText(phaseValue)
    end
    return nil
end

local function ApplyTruncateNoEllipsis(fontString, text, maxWidth, minChars)
    if TableUITextMetrics and TableUITextMetrics.ApplyTruncateNoEllipsis then
        return TableUITextMetrics:ApplyTruncateNoEllipsis(fontString, text, maxWidth, minChars)
    end
end

local function GetScaledFontSize(baseSize, scale)
    local size = math.floor((baseSize or 12) * scale + 0.5)
    return Clamp(size, 8, 18)
end

local function ApplyFontScale(fontString, scale)
    if not fontString or not fontString.GetFont then
        return
    end
    if not fontString.__ctkBaseFont then
        local font, size, flags = fontString:GetFont()
        if not font then
            local defaultFont, defaultSize, defaultFlags = GameFontNormal:GetFont()
            font, size, flags = defaultFont, defaultSize, defaultFlags
        end
        fontString.__ctkBaseFont = {
            font = font,
            size = size or 12,
            flags = flags,
        }
    end
    local base = fontString.__ctkBaseFont
    fontString:SetFont(base.font, GetScaledFontSize(base.size, scale or 1), base.flags)
end

local function SetColorBuffer(buffer, r, g, b, a)
    buffer[1] = r
    buffer[2] = g
    buffer[3] = b
    buffer[4] = a
    return buffer
end

local function PrepareColumn(columns, index, colIndex, text, color, isCountdown)
    local colData = columns[index]
    if not colData then
        colData = {}
        columns[index] = colData
    end

    colData.colIndex = colIndex
    colData.text = text or ""
    colData.color = color
    colData.isCountdown = isCountdown == true
end

function TableUIRenderer:HideVisibleFrames()
    for index = 1, #tableRows do
        local frameRef = tableRows[index]
        if frameRef and frameRef.Hide then
            frameRef:Hide()
        end
    end
    ClearArray(tableRows)
    ClearMap(visibleRowFrameByRowId)
end

function TableUIRenderer:AcquireRowFrame(parent, index)
    local rowFrame = rowFramePool[index]
    if rowFrame then
        if rowFrame:GetParent() ~= parent then
            rowFrame:SetParent(parent)
        end
        return rowFrame
    end

    rowFrame = CreateFrame("Frame", nil, parent)
    rowFrame:EnableMouse(true)
    if rowFrame.SetClipsChildren then
        rowFrame:SetClipsChildren(true)
    end
    rowFrame.rowBg = rowFrame:CreateTexture(nil, "BACKGROUND")
    rowFrame.rowBg:SetAllPoints(rowFrame)
    rowFrame.cellTexts = {}

    rowFramePool[index] = rowFrame
    return rowFrame
end

function TableUIRenderer:ClearCountdownRegistration()
    if CountdownSystem then
        CountdownSystem:ClearTexts()
    end
    if SortingSystem and SortingSystem.SetHeaderButton then
        SortingSystem:SetHeaderButton(nil)
    end
end

function TableUIRenderer:ReleaseHiddenState()
    self:ClearCountdownRegistration()
    self:HideVisibleFrames()

    if headerRowFrame and headerRowFrame.sortHeaderButton then
        headerRowFrame.sortHeaderButton:Hide()
    end

    for index = 1, #rowFramePool do
        local rowFrame = rowFramePool[index]
        if rowFrame then
            rowFrame.rowId = nil
            rowFrame.__ctkDisplayIndex = nil
            rowFrame.__ctkBaseAlpha = nil
            if rowFrame.__ctkColWidths then
                ClearArray(rowFrame.__ctkColWidths)
            end
            if rowFrame.__ctkLayoutState then
                ClearMap(rowFrame.__ctkLayoutState)
            end
            if rowFrame.columnBuffer then
                for colIndex = 1, #rowFrame.columnBuffer do
                    local column = rowFrame.columnBuffer[colIndex]
                    if column then
                        column.colIndex = nil
                        column.text = nil
                        column.color = nil
                        column.isCountdown = nil
                    end
                end
                ClearArray(rowFrame.columnBuffer)
            end
            if rowFrame.phaseColorBuffer then
                ClearArray(rowFrame.phaseColorBuffer)
            end
            if rowFrame.lastColorBuffer then
                ClearArray(rowFrame.lastColorBuffer)
            end
            if rowFrame.countdownHitArea then
                rowFrame.countdownHitArea.__ctkRowId = nil
                rowFrame.countdownHitArea.__ctkIsHidden = nil
                rowFrame.countdownHitArea:Hide()
            end
        end
    end
end

function TableUIRenderer:CreateHeaderRow(parent, headerLabels, colWidths, layout)
    local cfg = GetConfig()
    if not headerRowFrame then
        headerRowFrame = CreateFrame("Frame", nil, parent)
        headerRowFrame.headerBg = headerRowFrame:CreateTexture(nil, "BACKGROUND")
        headerRowFrame.headerBg:SetAllPoints(headerRowFrame)
        headerRowFrame.headerCells = {}
    elseif headerRowFrame:GetParent() ~= parent then
        headerRowFrame:SetParent(parent)
    end

    local headerHeight = layout.headerHeight or layout.rowHeight
    headerRowFrame:SetSize(layout.tableWidth, headerHeight)
    headerRowFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", layout.startX, -layout.startY)
    headerRowFrame:SetFrameLevel(parent:GetFrameLevel() + 10)
    headerRowFrame:SetAlpha(layout.headerAlpha or 1.0)
    headerRowFrame:Show()

    local headerBg = headerRowFrame.headerBg
    headerBg:SetAllPoints(headerRowFrame)
    local headerColor = cfg.GetColor("tableHeader")
    headerBg:SetColorTexture(headerColor[1], headerColor[2], headerColor[3], headerColor[4])

    for _, cell in pairs(headerRowFrame.headerCells) do
        if cell then
            cell:Hide()
        end
    end
    if headerRowFrame.sortHeaderButton then
        headerRowFrame.sortHeaderButton:Hide()
    end

    local currentX = 0
    for colIndex, label in ipairs(headerLabels) do
        if colIndex <= 4 and (colWidths[colIndex] or 0) > 0 then
            if colIndex == 4 then
                local sortHeaderButton = self:CreateSortHeaderButton(
                    headerRowFrame,
                    label,
                    colWidths[colIndex],
                    layout,
                    currentX,
                    headerRowFrame.sortHeaderButton
                )
                headerRowFrame.sortHeaderButton = sortHeaderButton
                sortHeaderButton:Show()
                if SortingSystem then
                    SortingSystem:SetHeaderButton(sortHeaderButton)
                end
            else
                local cellText = self:CreateHeaderText(
                    headerRowFrame,
                    label,
                    colIndex,
                    colWidths[colIndex],
                    layout,
                    currentX,
                    headerBg,
                    headerRowFrame.headerCells[colIndex]
                )
                headerRowFrame.headerCells[colIndex] = cellText
                cellText:Show()
            end
        end
        currentX = currentX + (colWidths[colIndex] or 0)
    end

    tableRows[#tableRows + 1] = headerRowFrame
end

function TableUIRenderer:CreateSortHeaderButton(parent, label, colWidth, layout, currentX, existingButton)
    local cfg = GetConfig()
    local sortHeaderButton = existingButton
    if not sortHeaderButton then
        sortHeaderButton = CreateFrame("Button", nil, parent)

        local buttonBg = sortHeaderButton:CreateTexture(nil, "BACKGROUND")
        buttonBg:SetAllPoints(sortHeaderButton)
        buttonBg:SetColorTexture(0, 0, 0, 0)
        sortHeaderButton.bg = buttonBg

        local buttonText = sortHeaderButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        buttonText:SetPoint("CENTER", sortHeaderButton, "CENTER", 0, 0)
        buttonText:SetJustifyH("CENTER")
        buttonText:SetJustifyV("MIDDLE")
        buttonText:SetShadowOffset(0, 0)
        sortHeaderButton.label = buttonText

        sortHeaderButton:SetScript("OnClick", function()
            if SortingSystem then
                SortingSystem:OnHeaderClick()
            end
        end)

        sortHeaderButton:SetScript("OnEnter", function(self)
            local hoverColor = cfg.GetColor("actionButtonHover")
            if self.bg then
                self.bg:SetColorTexture(hoverColor[1], hoverColor[2], hoverColor[3], hoverColor[4])
            end
        end)
        sortHeaderButton:SetScript("OnLeave", function(self)
            if self.bg then
                self.bg:SetColorTexture(0, 0, 0, 0)
            end
        end)
    elseif sortHeaderButton:GetParent() ~= parent then
        sortHeaderButton:SetParent(parent)
    end

    local headerHeight = layout.headerHeight or layout.rowHeight
    sortHeaderButton:SetSize(colWidth, headerHeight)
    sortHeaderButton:ClearAllPoints()
    sortHeaderButton:SetPoint("CENTER", parent, "LEFT", currentX + colWidth / 2, 0)

    local buttonText = sortHeaderButton.label
    buttonText:SetText(label)
    local textColor = cfg.GetTextColor("tableHeader")
    buttonText:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
    ApplyFontScale(buttonText, layout.fontScale or 1)

    return sortHeaderButton
end

function TableUIRenderer:CreateHeaderText(parent, label, colIndex, colWidth, layout, currentX, headerBg, existingText)
    local cfg = GetConfig()
    local cellText = existingText
    if not cellText then
        cellText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    end
    if cellText.GetParent and cellText:GetParent() ~= parent then
        cellText:SetParent(parent)
    end
    cellText:ClearAllPoints()
    local leftPadding = math.floor(15 * (layout.scale or 1) + 0.5)

    if colIndex == 1 then
        cellText:SetPoint("LEFT", headerBg, "LEFT", currentX + leftPadding, 0)
        cellText:SetJustifyH("LEFT")
    else
        cellText:SetPoint("CENTER", headerBg, "LEFT", currentX + colWidth / 2, 0)
        cellText:SetJustifyH("CENTER")
    end

    cellText:SetText(label)
    cellText:SetJustifyV("MIDDLE")
    cellText:SetShadowOffset(0, 0)
    local textColor = cfg.GetTextColor("tableHeader")
    cellText:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
    ApplyFontScale(cellText, layout.fontScale or 1)
    return cellText
end

function TableUIRenderer:CreateDataRow(parent, rowState, displayIndex, colWidths, layout)
    local rowInfo = rowState and rowState.rowInfo or rowState
    local rowId = rowInfo.rowId
    local headerOffsetY = 0
    if layout.showHeader then
        headerOffsetY = (layout.headerHeight or layout.rowHeight) + (layout.headerGap or layout.rowGap)
    end
    local slotY = headerOffsetY + (rowState and rowState.slotY or ((layout.rowHeight + layout.rowGap) * (displayIndex - 1)))
    local renderHeight = math.max(1, rowState and rowState.height or layout.rowHeight)
    local renderAlpha = Clamp(rowState and rowState.alpha or 1, 0, 1)
    local rowFrame = self:AcquireRowFrame(parent, displayIndex)
    rowFrame:SetSize(layout.tableWidth, renderHeight)
    rowFrame:ClearAllPoints()
    rowFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", layout.startX, -(layout.startY + slotY))
    rowFrame:SetFrameLevel(parent:GetFrameLevel() + 10)
    rowFrame:SetAlpha(renderAlpha)
    rowFrame:Show()
    rowFrame.__ctkBaseAlpha = renderAlpha
    rowFrame.uiScale = layout.scale
    rowFrame.uiFontScale = layout.fontScale or 1
    rowFrame.uiRowHeight = renderHeight
    rowFrame.rowId = rowId
    rowFrame.__ctkDisplayIndex = displayIndex
    rowFrame.__ctkLayoutState = rowFrame.__ctkLayoutState or {}
    rowFrame.__ctkLayoutState.showPhaseColumn = layout and layout.showPhaseColumn == true
    rowFrame.__ctkLayoutState.showLastRefreshColumn = layout and layout.showLastRefreshColumn == true
    rowFrame.__ctkLayoutState.fontScale = layout and layout.fontScale or 1
    rowFrame.__ctkColWidths = rowFrame.__ctkColWidths or {}
    for index = 1, 4 do
        rowFrame.__ctkColWidths[index] = colWidths[index] or 0
    end

    local rowBg = rowFrame.rowBg
    rowBg:SetAllPoints(rowFrame)

    local rowColor = UIConfig.GetDataRowColor(displayIndex)
    if rowInfo.isHidden then
        rowBg:SetColorTexture(0.5, 0.5, 0.5, 0.3)
        rowFrame:SetAlpha(renderAlpha * 0.6)
    else
        rowBg:SetColorTexture(rowColor[1], rowColor[2], rowColor[3], rowColor[4])
    end

    self:CreateRowCells(rowFrame, rowInfo, colWidths, rowBg, rowFrame.uiFontScale, layout)

    tableRows[#tableRows + 1] = rowFrame
    visibleRowFrameByRowId[rowId] = rowFrame
end

function TableUIRenderer:RefreshVisibleRow(rowInfo)
    local rowId = rowInfo and rowInfo.rowId
    local rowFrame = rowId and visibleRowFrameByRowId[rowId] or nil
    if not rowFrame or not rowFrame.IsShown or not rowFrame:IsShown() then
        return false
    end

    local rowBg = rowFrame.rowBg
    if not rowBg then
        return false
    end

    local displayIndex = rowFrame.__ctkDisplayIndex or 1
    local rowColor = UIConfig.GetDataRowColor(displayIndex)
    local baseAlpha = rowFrame.__ctkBaseAlpha or rowFrame:GetAlpha() or 1
    if rowInfo.isHidden then
        rowBg:SetColorTexture(0.5, 0.5, 0.5, 0.3)
        rowFrame:SetAlpha(baseAlpha * 0.6)
    else
        rowBg:SetColorTexture(rowColor[1], rowColor[2], rowColor[3], rowColor[4])
        rowFrame:SetAlpha(baseAlpha)
    end

    self:CreateRowCells(
        rowFrame,
        rowInfo,
        rowFrame.__ctkColWidths or {},
        rowBg,
        rowFrame.uiFontScale or 1,
        rowFrame.__ctkLayoutState or {}
    )
    return true
end

function TableUIRenderer:CreateRowCells(rowFrame, rowInfo, colWidths, rowBg, scale, layout)
    local cfg = GetConfig()
    local currentX = 0
    local leftPadding = math.floor(15 * (scale or 1) + 0.5)
    local normalTextColor = cfg.GetTextColor("normal")
    local planeIdTextColor = cfg.GetTextColor("planeId")
    local deletedTextColor = rowInfo.isHidden and cfg.GetTextColor("deleted") or nil
    rowFrame.cellTexts = rowFrame.cellTexts or {}

    for _, cellText in pairs(rowFrame.cellTexts) do
        if cellText then
            cellText:Hide()
        end
    end

    local hasCurrentPhase = rowInfo.currentPhaseID ~= nil and rowInfo.currentPhaseID ~= ""
    local phaseText = L["NotAcquired"] or "---:---"
    local phaseColor = normalTextColor
    if hasCurrentPhase then
        phaseText = FormatPhaseDisplayText(rowInfo.currentPhaseID) or phaseText
        if rowInfo.phaseDisplayInfo and rowInfo.phaseDisplayInfo.color then
            rowFrame.phaseColorBuffer = rowFrame.phaseColorBuffer or {}
            phaseColor = SetColorBuffer(
                rowFrame.phaseColorBuffer,
                rowInfo.phaseDisplayInfo.color.r,
                rowInfo.phaseDisplayInfo.color.g,
                rowInfo.phaseDisplayInfo.color.b,
                1
            )
        else
            phaseColor = planeIdTextColor
        end
    else
        if rowInfo.lastRefreshPhase and rowInfo.lastRefreshPhase ~= "" then
            phaseText = FormatPhaseDisplayText(rowInfo.lastRefreshPhase) or phaseText
        end
    end

    local lastRefreshText = rowInfo.lastRefresh and UnifiedDataManager:FormatDateTime(rowInfo.lastRefresh) or (L["NoRecord"] or "--:--")
    local lastColor = normalTextColor
    if rowInfo.lastRefresh and not rowInfo.isPersistent then
        rowFrame.lastColorBuffer = rowFrame.lastColorBuffer or {}
        lastColor = SetColorBuffer(
            rowFrame.lastColorBuffer,
            planeIdTextColor[1],
            planeIdTextColor[2],
            planeIdTextColor[3],
            0.7
        )
    elseif hasCurrentPhase and rowInfo.lastRefresh and rowInfo.isPersistent then
        local compareStatus = rowInfo.phaseDisplayInfo and rowInfo.phaseDisplayInfo.compareStatus or nil
        if compareStatus == nil and UnifiedDataManager and UnifiedDataManager.ComparePhases then
            local compare = UnifiedDataManager:ComparePhases(rowInfo.rowId)
            compareStatus = compare and compare.status or nil
        end
        if compareStatus == "match" then
            lastColor = planeIdTextColor
        elseif compareStatus == "mismatch" then
            rowFrame.lastColorBuffer = rowFrame.lastColorBuffer or {}
            lastColor = SetColorBuffer(
                rowFrame.lastColorBuffer,
                planeIdTextColor[1],
                planeIdTextColor[2],
                planeIdTextColor[3],
                0.7
            )
        end
    end
    local nextRefreshText = rowInfo.remainingTime and UnifiedDataManager:FormatTime(rowInfo.remainingTime) or (L["NoRecord"] or "--:--")

    rowFrame.columnBuffer = rowFrame.columnBuffer or {}
    local columns = rowFrame.columnBuffer
    local columnCount = 1
    PrepareColumn(columns, columnCount, 1, rowInfo.mapName, normalTextColor, false)
    if layout and layout.showPhaseColumn then
        columnCount = columnCount + 1
        PrepareColumn(columns, columnCount, 2, phaseText, phaseColor, false)
    end
    if layout and layout.showLastRefreshColumn then
        columnCount = columnCount + 1
        PrepareColumn(columns, columnCount, 3, lastRefreshText, lastColor, false)
    end
    columnCount = columnCount + 1
    PrepareColumn(columns, columnCount, 4, nextRefreshText, normalTextColor, true)

    for columnIndex = 1, columnCount do
        local colData = columns[columnIndex]
        local colIndex = colData.colIndex
        local cellText = rowFrame.cellTexts[colIndex]
        if not cellText then
            cellText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            rowFrame.cellTexts[colIndex] = cellText
        end
        cellText:ClearAllPoints()

        if colIndex == 1 then
            cellText:SetPoint("LEFT", rowBg, "LEFT", currentX + leftPadding, 0)
            cellText:SetJustifyH("LEFT")
        else
            cellText:SetPoint("CENTER", rowBg, "LEFT", currentX + colWidths[colIndex] / 2, 0)
            cellText:SetJustifyH("CENTER")
        end

        local resolvedFontScale = layout and layout.fontScale or 1
        ApplyFontScale(cellText, resolvedFontScale)

        local textValue = colData.text or ""
        if colIndex == 1 then
            local padding = math.floor(24 * (scale or 1) + 0.5) + 2
            local maxWidth = math.max(0, colWidths[1] - padding)
            cellText:SetWidth(maxWidth)
            cellText:SetHeight(math.max(1, math.floor((rowFrame.uiRowHeight or FIXED_ROW_HEIGHT) * MAP_ROW_TEXT_HEIGHT_RATIO + 0.5)))
            if cellText.SetWordWrap then
                cellText:SetWordWrap(false)
            end
            if cellText.SetNonSpaceWrap then
                cellText:SetNonSpaceWrap(false)
            end
            if cellText.SetMaxLines then
                cellText:SetMaxLines(1)
            end
            ApplyTruncateNoEllipsis(cellText, textValue, maxWidth, MAP_COL_COMPACT_MIN_CHARS)
        else
            cellText:SetHeight(rowFrame.uiRowHeight or FIXED_ROW_HEIGHT)
            cellText:SetText(textValue)
        end
        cellText:SetJustifyV("MIDDLE")
        cellText:SetShadowOffset(0, 0)
        cellText:Show()

        local textColor = colData.color or normalTextColor
        if rowInfo.isHidden then
            cellText:SetTextColor(deletedTextColor[1], deletedTextColor[2], deletedTextColor[3], deletedTextColor[4])
        else
            cellText:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
        end

        if colData.isCountdown and CountdownSystem then
            CountdownSystem:RegisterText(rowInfo.rowId, cellText)

            local hitArea = rowFrame.countdownHitArea
            if not hitArea then
                hitArea = CreateFrame("Button", nil, rowFrame)
                hitArea:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                if hitArea.SetPropagateMouseClicks then
                    hitArea:SetPropagateMouseClicks(true)
                end
                if hitArea.SetPropagateMouseMotion then
                    hitArea:SetPropagateMouseMotion(true)
                end
                hitArea:SetScript("OnEnter", function(self)
                    if self.__ctkIsHidden then
                        return
                    end
                    if CountdownSystem and CountdownSystem.SetRowHover then
                        CountdownSystem:SetRowHover(self.__ctkRowId, true)
                    end
                end)
                hitArea:SetScript("OnLeave", function(self)
                    if CountdownSystem and CountdownSystem.SetRowHover then
                        CountdownSystem:SetRowHover(self.__ctkRowId, false)
                    end
                end)
                hitArea:SetScript("OnClick", function(self, button)
                    if self.__ctkIsHidden or not IsAddonEnabled() then
                        return
                    end
                    if MainPanel and MainPanel.NotifyMapById then
                        MainPanel:NotifyMapById(self.__ctkRowId, button)
                    end
                end)
                rowFrame.countdownHitArea = hitArea
            end

            hitArea.__ctkRowId = rowInfo.rowId
            hitArea.__ctkIsHidden = rowInfo.isHidden == true
            hitArea:SetFrameLevel(rowFrame:GetFrameLevel() + 2)
            hitArea:SetSize(colWidths[colIndex], rowFrame.uiRowHeight or FIXED_ROW_HEIGHT)
            hitArea:ClearAllPoints()
            hitArea:SetPoint("CENTER", rowBg, "LEFT", currentX + colWidths[colIndex] / 2, 0)
            hitArea:Show()
        elseif colData.isCountdown then
            if rowFrame.countdownHitArea then
                rowFrame.countdownHitArea:Hide()
            end
        end

        currentX = currentX + colWidths[colIndex]
    end
end

return TableUIRenderer

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
local measureText = nil
local BASE_FRAME_WIDTH = 600
local BASE_FRAME_HEIGHT = 335
local BASE_ROW_HEIGHT = 35
local MIN_FRAME_SCALE = 0.6
local MAX_FRAME_SCALE = 1.25

local function GetConfig()
    return UIConfig
end

local function GetTableParent(frame)
    if frame and frame.tableContainer and frame.tableContainer.GetObjectType and frame.tableContainer:GetObjectType() == "Frame" then
        return frame.tableContainer
    end
    return frame
end

local function GetMeasureText()
    if not measureText then
        measureText = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        measureText:SetText("")
    end
    return measureText
end

local function GetTextWidth(text)
    local fontString = GetMeasureText()
    fontString:SetText(text or "")
    return fontString:GetStringWidth() or 0
end

local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function GetScaleFactor(frame)
    if not frame then
        return 1
    end
    local width = frame:GetWidth() or BASE_FRAME_WIDTH
    local widthScale = width / BASE_FRAME_WIDTH
    return Clamp(widthScale, MIN_FRAME_SCALE, MAX_FRAME_SCALE)
end

local function GetScaledFontSize(baseSize, scale)
    local size = math.floor((baseSize or 12) * scale + 0.5)
    return Clamp(size, 8, 18)
end

local function ApplyFontScale(fontString, scale)
    if not fontString or not fontString.GetFont then
        return
    end
    local font, size, flags = fontString:GetFont()
    if not font then
        local defaultFont, defaultSize, defaultFlags = GameFontNormal:GetFont()
        font, size, flags = defaultFont, defaultSize, defaultFlags
    end
    fontString:SetFont(font, GetScaledFontSize(size or 12, scale or 1), flags)
end

local function GetStringLength(text)
    if type(text) ~= "string" then
        return 0
    end
    if utf8 and utf8.len then
        local ok, len = pcall(utf8.len, text)
        if ok and len then
            return len
        end
    end
    return #text
end

local function SubString(text, startIndex, endIndex)
    if utf8 and utf8.sub then
        local ok, result = pcall(utf8.sub, text, startIndex, endIndex)
        if ok and result then
            return result
        end
    end
    return string.sub(text, startIndex, endIndex)
end

local function ApplyEllipsis(fontString, text, maxWidth)
    if not fontString then
        return
    end
    if not text or text == "" then
        fontString:SetText("")
        return
    end
    fontString:SetText(text)
    if fontString:GetStringWidth() <= maxWidth then
        return
    end
    local ellipsis = "..."
    local length = GetStringLength(text)
    if length <= 0 then
        fontString:SetText(ellipsis)
        return
    end
    local low, high = 1, length
    local best = ellipsis
    while low <= high do
        local mid = math.floor((low + high) / 2)
        local candidate = SubString(text, 1, mid) .. ellipsis
        fontString:SetText(candidate)
        if fontString:GetStringWidth() <= maxWidth then
            best = candidate
            low = mid + 1
        else
            high = mid - 1
        end
    end
    fontString:SetText(best)
end

local function ScaleWidths(baseWidths, targetTotal)
    local sum = 0
    for _, width in ipairs(baseWidths) do
        sum = sum + width
    end
    if sum <= 0 then
        return baseWidths
    end
    local scaled = {}
    local used = 0
    for i, width in ipairs(baseWidths) do
        if i == #baseWidths then
            scaled[i] = math.max(1, targetTotal - used)
        else
            local value = math.floor(width * targetTotal / sum + 0.5)
            scaled[i] = math.max(1, value)
            used = used + scaled[i]
        end
    end
    return scaled
end

local function GetMaxWidth(texts)
    local maxWidth = 0
    for _, text in ipairs(texts or {}) do
        local width = GetTextWidth(text)
        if width > maxWidth then
            maxWidth = width
        end
    end
    return maxWidth
end

local function DistributeWidths(desired, minWidths, maxWidths, total)
    local clamped = {}
    local minSum = 0
    for i, width in ipairs(desired) do
        local minW = minWidths[i] or 1
        local maxW = maxWidths[i] or total
        clamped[i] = math.max(minW, math.min(maxW, width))
        minSum = minSum + minW
    end
    if minSum >= total then
        return ScaleWidths(minWidths, total)
    end
    local weights = {}
    local weightSum = 0
    for i, width in ipairs(clamped) do
        local extra = width - (minWidths[i] or 0)
        if extra < 0 then extra = 0 end
        weights[i] = extra
        weightSum = weightSum + extra
    end
    local remaining = total - minSum
    local result = {}
    local used = 0
    for i = 1, #clamped do
        local add = 0
        if weightSum > 0 then
            add = math.floor(remaining * (weights[i] / weightSum) + 0.5)
        else
            add = math.floor(remaining / #clamped + 0.5)
        end
        if i == #clamped then
            result[i] = math.max(minWidths[i], total - used)
        else
            result[i] = math.max(minWidths[i], (minWidths[i] or 0) + add)
            used = used + result[i]
        end
    end
    return result
end

local function CalculateColumnWidths(rows, headerLabels, totalWidth, scale)
    local headers = headerLabels or {}
    local notifyText = L["Notify"] or "通知"
    local noRecord = L["NoRecord"] or "--:--"
    local notAcquired = L["NotAcquired"] or "---:---"
    local widthScale = scale or 1

    local mapMax = GetTextWidth(headers[1] or "")
    for _, rowInfo in ipairs(rows or {}) do
        if rowInfo and rowInfo.mapName then
            local width = GetTextWidth(rowInfo.mapName)
            if width > mapMax then
                mapMax = width
            end
        end
    end

    local desired = {
        math.floor((mapMax + 24) * widthScale + 0.5),
        math.floor((GetMaxWidth({headers[2] or "", notAcquired, "0000-0000"}) + 20) * widthScale + 0.5),
        math.floor((GetMaxWidth({headers[3] or "", noRecord, "00:00:00"}) + 18) * widthScale + 0.5),
        math.floor((GetMaxWidth({headers[4] or "", noRecord, "00:00:00"}) + 18) * widthScale + 0.5),
        math.floor((GetMaxWidth({headers[5] or "", notifyText}) + 20) * widthScale + 0.5),
    }
    local minWidths = {
        math.floor(120 * widthScale + 0.5),
        math.floor(80 * widthScale + 0.5),
        math.floor(100 * widthScale + 0.5),
        math.floor(100 * widthScale + 0.5),
        math.floor(80 * widthScale + 0.5),
    }
    local maxWidths = {
        math.floor(260 * widthScale + 0.5),
        math.floor(140 * widthScale + 0.5),
        math.floor(160 * widthScale + 0.5),
        math.floor(160 * widthScale + 0.5),
        math.floor(140 * widthScale + 0.5),
    }
    return DistributeWidths(desired, minWidths, maxWidths, totalWidth)
end

local function CalculateTableLayout(frame, rowCount)
    local tableParent = GetTableParent(frame)
    local contentWidth = tableParent and tableParent:GetWidth() or 0
    local contentHeight = tableParent and tableParent:GetHeight() or 0

    if contentWidth <= 1 then
        local frameWidth = frame and frame:GetWidth() or BASE_FRAME_WIDTH
        contentWidth = math.max(1, math.floor(frameWidth - 20))
    end
    if contentHeight <= 1 then
        local frameHeight = frame and frame:GetHeight() or BASE_FRAME_HEIGHT
        contentHeight = math.max(1, math.floor(frameHeight - 40))
    end

    local scale = GetScaleFactor(frame)
    local baseRowHeight = math.floor(BASE_ROW_HEIGHT * scale + 0.5)
    local rowGap = math.max(0, math.floor(2 * scale + 0.5))
    local totalRows = math.max(1, (rowCount or 0) + 1)
    local availableForRows = math.max(1, contentHeight - (totalRows - 1) * rowGap)
    local fitRowHeight = math.floor(availableForRows / totalRows)
    local rowHeight = math.min(baseRowHeight, fitRowHeight)
    rowHeight = Clamp(rowHeight, 2, 44)

    local usedHeight = totalRows * rowHeight + (totalRows - 1) * rowGap
    if usedHeight > contentHeight then
        rowHeight = math.max(2, math.floor((contentHeight - (totalRows - 1) * rowGap) / totalRows))
    end

    return {
        parent = tableParent,
        scale = scale,
        rowHeight = rowHeight,
        rowGap = rowGap,
        tableWidth = math.max(1, math.floor(contentWidth + 0.5)),
        startX = 0,
        startY = 0,
    }
end

local function IsAddonEnabled()
    if not CRATETRACKERZK_UI_DB or CRATETRACKERZK_UI_DB.addonEnabled == nil then
        return true
    end
    return CRATETRACKERZK_UI_DB.addonEnabled == true
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

    local layout = CalculateTableLayout(frame, #rows)
    local colWidths = CalculateColumnWidths(rows, headerLabels, layout.tableWidth, layout.scale)

    self:CreateHeaderRow(layout.parent, headerLabels, colWidths, layout)

    for displayIndex, rowInfo in ipairs(rows) do
        self:CreateDataRow(layout.parent, rowInfo, displayIndex, colWidths, layout)
    end

    if SortingSystem then
        SortingSystem:UpdateHeaderVisual()
    end
end

function TableUI:CreateHeaderRow(parent, headerLabels, colWidths, layout)
    local cfg = GetConfig()
    local headerRowFrame = CreateFrame("Frame", nil, parent)
    headerRowFrame:SetSize(layout.tableWidth, layout.rowHeight)
    headerRowFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", layout.startX, -layout.startY)
    headerRowFrame:SetFrameLevel(parent:GetFrameLevel() + 10)
    headerRowFrame:SetAlpha(1.0)

    local headerBg = headerRowFrame:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints(headerRowFrame)
    local headerColor = cfg.GetColor("tableHeader")
    headerBg:SetColorTexture(headerColor[1], headerColor[2], headerColor[3], headerColor[4])

    local currentX = 0
    for colIndex, label in ipairs(headerLabels) do
        if colIndex <= 5 then
            if colIndex == 4 then
                local sortHeaderButton = self:CreateSortHeaderButton(headerRowFrame, label, colWidths[colIndex], layout, currentX)
                if SortingSystem then
                    SortingSystem:SetHeaderButton(sortHeaderButton)
                end
            else
                self:CreateHeaderText(headerRowFrame, label, colIndex, colWidths[colIndex], layout, currentX, headerBg)
            end
        end
        currentX = currentX + colWidths[colIndex]
    end

    table.insert(tableRows, headerRowFrame)
end

function TableUI:CreateSortHeaderButton(parent, label, colWidth, layout, currentX)
    local cfg = GetConfig()
    local sortHeaderButton = CreateFrame("Button", nil, parent)
    sortHeaderButton:SetSize(colWidth, layout.rowHeight)
    sortHeaderButton:SetPoint("CENTER", parent, "LEFT", currentX + colWidth / 2, 0)

    local buttonBg = sortHeaderButton:CreateTexture(nil, "BACKGROUND")
    buttonBg:SetAllPoints(sortHeaderButton)
    buttonBg:SetColorTexture(0, 0, 0, 0)

    local buttonText = sortHeaderButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    buttonText:SetPoint("CENTER", sortHeaderButton, "CENTER", 0, 0)
    buttonText:SetText(label)
    local textColor = cfg.GetTextColor("normal")
    buttonText:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
    buttonText:SetJustifyH("CENTER")
    buttonText:SetJustifyV("MIDDLE")
    buttonText:SetShadowOffset(0, 0)
    ApplyFontScale(buttonText, layout.scale)

    sortHeaderButton:SetScript("OnClick", function()
        if SortingSystem then
            SortingSystem:OnHeaderClick()
        end
    end)

    sortHeaderButton:SetScript("OnEnter", function()
        local hoverColor = cfg.GetColor("actionButtonHover")
        buttonBg:SetColorTexture(hoverColor[1], hoverColor[2], hoverColor[3], hoverColor[4])
    end)
    sortHeaderButton:SetScript("OnLeave", function()
        buttonBg:SetColorTexture(0, 0, 0, 0)
    end)

    return sortHeaderButton
end

function TableUI:CreateHeaderText(parent, label, colIndex, colWidth, layout, currentX, headerBg)
    local cfg = GetConfig()
    local cellText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
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
    local textColor = cfg.GetTextColor("normal")
    cellText:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
    ApplyFontScale(cellText, layout.scale)
end

function TableUI:CreateDataRow(parent, rowInfo, displayIndex, colWidths, layout)
    local rowId = rowInfo.rowId
    local actualRowIndex = displayIndex

    local slotY = (layout.rowHeight + layout.rowGap) * actualRowIndex
    local rowFrame = CreateFrame("Frame", nil, parent)
    rowFrame:SetSize(layout.tableWidth, layout.rowHeight)
    rowFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", layout.startX, -(layout.startY + slotY))
    rowFrame:SetFrameLevel(parent:GetFrameLevel() + 10)
    rowFrame:SetAlpha(1.0)
    rowFrame:EnableMouse(true)
    rowFrame.uiScale = layout.scale
    rowFrame.uiRowHeight = layout.rowHeight

    local rowBg = rowFrame:CreateTexture(nil, "BACKGROUND")
    rowBg:SetAllPoints(rowFrame)

    local rowColor = UIConfig.GetDataRowColor(displayIndex)
    if rowInfo.isHidden then
        rowBg:SetColorTexture(0.5, 0.5, 0.5, 0.3)
        rowFrame:SetAlpha(0.6)
    else
        rowBg:SetColorTexture(rowColor[1], rowColor[2], rowColor[3], rowColor[4])
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

    self:CreateRowCells(rowFrame, rowInfo, colWidths, rowBg, layout.scale)

    local notifyBtn = self:CreateActionButtons(rowFrame, rowInfo, colWidths, rowBg, layout.scale)
    if RowStateSystem and notifyBtn then
        RowStateSystem:RegisterRowButtons(rowId, notifyBtn)
    end

    table.insert(tableRows, rowFrame)
end

function TableUI:CreateRowCells(rowFrame, rowInfo, colWidths, rowBg, scale)
    local cfg = GetConfig()
    local currentX = 0
    local leftPadding = math.floor(15 * (scale or 1) + 0.5)

    local hasCurrentPhase = rowInfo.currentPhaseID ~= nil and rowInfo.currentPhaseID ~= ""
    local phaseText = L["NotAcquired"] or "---:---"
    local phaseColor = cfg.GetTextColor("normal")
    if hasCurrentPhase then
        phaseText = tostring(rowInfo.currentPhaseID)
        if #phaseText > 10 then
            phaseText = string.sub(phaseText, 1, 10)
        end
        if rowInfo.phaseDisplayInfo and rowInfo.phaseDisplayInfo.color then
            phaseColor = {rowInfo.phaseDisplayInfo.color.r, rowInfo.phaseDisplayInfo.color.g, rowInfo.phaseDisplayInfo.color.b, 1}
        else
            phaseColor = cfg.GetTextColor("planeId")
        end
    else
        if rowInfo.lastRefreshPhase and rowInfo.lastRefreshPhase ~= "" then
            phaseText = tostring(rowInfo.lastRefreshPhase)
            if #phaseText > 10 then
                phaseText = string.sub(phaseText, 1, 10)
            end
        end
    end

    local lastRefreshText = rowInfo.lastRefresh and UnifiedDataManager:FormatDateTime(rowInfo.lastRefresh) or (L["NoRecord"] or "--:--")
    local lastColor = cfg.GetTextColor("normal")
    if rowInfo.lastRefresh and not rowInfo.isPersistent then
        local base = cfg.GetTextColor("planeId")
        lastColor = {base[1], base[2], base[3], 0.7}
    elseif hasCurrentPhase and rowInfo.lastRefresh and rowInfo.isPersistent then
        local compareStatus = nil
        if UnifiedDataManager and UnifiedDataManager.ComparePhases then
            local compare = UnifiedDataManager:ComparePhases(rowInfo.rowId)
            compareStatus = compare and compare.status or nil
        end
        if compareStatus == "match" then
            lastColor = cfg.GetTextColor("planeId")
        elseif compareStatus == "mismatch" then
            local base = cfg.GetTextColor("planeId")
            lastColor = {base[1], base[2], base[3], 0.7}
        end
    end
    local nextRefreshText = rowInfo.remainingTime and UnifiedDataManager:FormatTime(rowInfo.remainingTime) or (L["NoRecord"] or "--:--")

    local columns = {
        {text = rowInfo.mapName, align = "left", color = cfg.GetTextColor("normal")},
        {text = phaseText, align = "center", color = phaseColor},
        {text = lastRefreshText, align = "center", color = lastColor},
        {text = nextRefreshText, align = "center", color = cfg.GetTextColor("normal"), isCountdown = true},
    }

    for colIndex, colData in ipairs(columns) do
        local cellText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")

        if colIndex == 1 then
            cellText:SetPoint("LEFT", rowBg, "LEFT", currentX + leftPadding, 0)
            cellText:SetJustifyH("LEFT")
        else
            cellText:SetPoint("CENTER", rowBg, "LEFT", currentX + colWidths[colIndex] / 2, 0)
            cellText:SetJustifyH("CENTER")
        end

        local textValue = colData.text or ""
        if colIndex == 1 then
            local padding = math.floor(24 * (scale or 1) + 0.5)
            local maxWidth = math.max(0, colWidths[1] - padding)
            cellText:SetWidth(maxWidth)
            if cellText.SetWordWrap then
                cellText:SetWordWrap(false)
            end
            if cellText.SetNonSpaceWrap then
                cellText:SetNonSpaceWrap(false)
            end
            if cellText.SetMaxLines then
                cellText:SetMaxLines(1)
            end
            ApplyEllipsis(cellText, textValue, maxWidth)
        else
            cellText:SetText(textValue)
        end
        cellText:SetJustifyV("MIDDLE")
        cellText:SetShadowOffset(0, 0)
        ApplyFontScale(cellText, scale)

        local textColor = colData.color or cfg.GetTextColor("normal")
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

function TableUI:CreateActionButtons(rowFrame, rowInfo, colWidths, rowBg, scale)
    local rowId = rowInfo.rowId
    local operationColumnStart = colWidths[1] + colWidths[2] + colWidths[3] + colWidths[4]
    local columnCenter = operationColumnStart + colWidths[5] / 2
    rowFrame.operationColumnCenter = columnCenter
    local notifyText = L["Notify"] or "通知"
    local notifyBtn = self:CreateActionButton(rowFrame, rowBg, notifyText, columnCenter, function()
        if rowInfo.isHidden then
            return
        end
        if MainPanel and MainPanel.NotifyMapById then
            MainPanel:NotifyMapById(rowId)
        end
    end, rowInfo.isHidden, scale)
    notifyBtn:ClearAllPoints()
    notifyBtn:SetPoint("CENTER", rowBg, "LEFT", columnCenter, 0)

    return notifyBtn
end

function TableUI:CreateActionButton(parent, parentBg, text, x, clickHandler, isHidden, scale)
    local cfg = GetConfig()
    local btn = CreateFrame("Button", nil, parent)
    local height = Clamp(math.floor(20 * (scale or 1) + 0.5), 18, 24)
    btn:SetSize(30, height)
    btn:SetPoint("CENTER", parentBg, "LEFT", x, 0)
    btn:SetFrameLevel(parent:GetFrameLevel() + 1)

    local normalColor = cfg.GetTextColor("normal")
    local hoverTextColor = {1, 0.6, 0.1, 1}

    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btnText:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btnText:SetText(text)
    btnText:SetJustifyH("CENTER")
    btnText:SetJustifyV("MIDDLE")
    btnText:SetShadowOffset(0, 0)
    ApplyFontScale(btnText, scale)
    btn.label = btnText

    local textWidth = btnText:GetStringWidth() or 0
    local minWidth = math.floor(30 * (scale or 1) + 0.5)
    local padding = math.floor(10 * (scale or 1) + 0.5)
    local targetWidth = math.max(minWidth, textWidth + padding)
    btn:SetSize(targetWidth, height)

    local normalTextColor = nil
    if isHidden then
        normalTextColor = {0.5, 0.5, 0.5, 0.8}
    else
        normalTextColor = normalColor
    end
    btnText:SetTextColor(normalTextColor[1], normalTextColor[2], normalTextColor[3], normalTextColor[4])

    btn:SetScript("OnClick", function()
        if not IsAddonEnabled() then
            return
        end
        clickHandler()
    end)

    btn:SetScript("OnEnter", function()
        if isHidden then return end
        btnText:SetTextColor(hoverTextColor[1], hoverTextColor[2], hoverTextColor[3], hoverTextColor[4])
    end)
    btn:SetScript("OnLeave", function()
        btnText:SetTextColor(normalTextColor[1], normalTextColor[2], normalTextColor[3], normalTextColor[4])
    end)

    return btn
end

return TableUI

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
local cachedColWidths = nil
local measureText = nil

local function GetConfig()
    return UIConfig
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

local function CalculateColumnWidths(rows, headerLabels)
    if cachedColWidths then
        return cachedColWidths
    end
    local totalWidth = 560
    local headers = headerLabels or {}
    local notifyText = L["Notify"] or "通知"
    local noRecord = L["NoRecord"] or "--:--"
    local notAcquired = L["NotAcquired"] or "---:---"

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
        mapMax + 24,
        GetMaxWidth({headers[2] or "", notAcquired, "0000-0000"}) + 20,
        GetMaxWidth({headers[3] or "", noRecord, "00:00:00"}) + 18,
        GetMaxWidth({headers[4] or "", noRecord, "00:00:00"}) + 18,
        GetMaxWidth({headers[5] or "", notifyText}) + 20,
    }
    local minWidths = {120, 80, 100, 100, 80}
    local maxWidths = {260, 140, 160, 160, 140}
    cachedColWidths = DistributeWidths(desired, minWidths, maxWidths, totalWidth)
    return cachedColWidths
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

    local colWidths = CalculateColumnWidths(rows, headerLabels)
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
    local headerColor = cfg.GetColor("tableHeader")
    headerBg:SetColorTexture(headerColor[1], headerColor[2], headerColor[3], headerColor[4])

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
    local textColor = cfg.GetTextColor("normal")
    buttonText:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
    buttonText:SetJustifyH("CENTER")
    buttonText:SetJustifyV("MIDDLE")
    buttonText:SetShadowOffset(0, 0)

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
    local textColor = cfg.GetTextColor("normal")
    cellText:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
end

function TableUI:CreateDataRow(frame, rowInfo, displayIndex, colWidths, rowHeight, startX, startY)
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

    self:CreateRowCells(rowFrame, rowInfo, colWidths, rowBg)

    local notifyBtn = self:CreateActionButtons(rowFrame, rowInfo, colWidths, rowBg)
    if RowStateSystem and notifyBtn then
        RowStateSystem:RegisterRowButtons(rowId, notifyBtn)
    end

    table.insert(tableRows, rowFrame)
end

function TableUI:CreateRowCells(rowFrame, rowInfo, colWidths, rowBg)
    local cfg = GetConfig()
    local currentX = 0

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
            cellText:SetPoint("LEFT", rowBg, "LEFT", currentX + 15, 0)
            cellText:SetJustifyH("LEFT")
        else
            cellText:SetPoint("CENTER", rowBg, "LEFT", currentX + colWidths[colIndex] / 2, 0)
            cellText:SetJustifyH("CENTER")
        end

        local textValue = colData.text or ""
        if colIndex == 1 then
            local maxWidth = math.max(0, colWidths[1] - 24)
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

function TableUI:CreateActionButtons(rowFrame, rowInfo, colWidths, rowBg)
    local rowId = rowInfo.rowId
    local operationColumnStart = colWidths[1] + colWidths[2] + colWidths[3] + colWidths[4]
    local columnCenter = operationColumnStart + colWidths[5] / 2
    local notifyText = L["Notify"] or "通知"
    local notifyBtn = self:CreateActionButton(rowFrame, rowBg, notifyText, columnCenter, function()
        if rowInfo.isHidden then
            return
        end
        if MainPanel and MainPanel.NotifyMapById then
            MainPanel:NotifyMapById(rowId)
        end
    end, rowInfo.isHidden)
    notifyBtn:ClearAllPoints()
    notifyBtn:SetPoint("CENTER", rowBg, "LEFT", columnCenter, 0)

    return notifyBtn
end

function TableUI:CreateActionButton(parent, parentBg, text, x, clickHandler, isHidden)
    local cfg = GetConfig()
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(30, 20)
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
    btn.label = btnText

    local textWidth = btnText:GetStringWidth() or 0
    local minWidth = 30
    local padding = 10
    local targetWidth = math.max(minWidth, textWidth + padding)
    btn:SetSize(targetWidth, 20)

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

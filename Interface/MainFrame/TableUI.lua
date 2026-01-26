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
    return UIConfig
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

    local colWidths = {160, 90, 110, 100, 100}
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
    if hasCurrentPhase and rowInfo.lastRefresh then
        if rowInfo.isPersistent then
            lastColor = {0, 1, 0, 1}
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

        cellText:SetText(colData.text or "")
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

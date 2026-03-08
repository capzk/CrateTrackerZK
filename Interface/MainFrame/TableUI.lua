-- TableUI.lua - 表格界面

local TableUI = BuildEnv("TableUI")
local UIConfig = BuildEnv("ThemeConfig")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local SortingSystem = BuildEnv("SortingSystem")
local CountdownSystem = BuildEnv("CountdownSystem")
local RowStateSystem = BuildEnv("RowStateSystem")
local MainFrame = BuildEnv("MainFrame")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local L = CrateTrackerZK.L

local tableRows = {}
local rowFramePool = {}
local headerRowFrame = nil
local measureText = nil
local BASE_FRAME_WIDTH = 600
local FIXED_ROW_HEIGHT = 34
local MIN_FRAME_SCALE = 0.6
local MAX_FRAME_SCALE = 1.0
local COMPACT_BASE_ROW_GAP = 2
local BASE_MIN_FRAME_WIDTH = 140
local COMPACT_FONT_TRANSITION_WIDTH = 80
local HEADER_COLLAPSE_TRANSITION_WIDTH = 60
local MAP_COL_FIXED_MIN_WIDTH = 120
local MAP_COL_FIXED_MAX_WIDTH = 360
local MAP_COL_BASE_PADDING = 24
local MAP_COL_SAFETY_PADDING = 6

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

local function GetFrameWidth(frame)
    if not frame or not frame.GetWidth then
        return BASE_FRAME_WIDTH
    end
    return frame:GetWidth() or BASE_FRAME_WIDTH
end

local function GetVisibilityProfile(frame)
    local width = GetFrameWidth(frame)
    local headerFullyHiddenWidth = BASE_FRAME_WIDTH - HEADER_COLLAPSE_TRANSITION_WIDTH
    local profile = {
        showHeader = true,
        showPhaseColumn = true,
        showLastRefreshColumn = true,
        showOperationColumn = true,
        phaseShortMode = false,
        showDeletedRows = true,
        contextMenuEnabled = true,
        isFullInfo = true,
    }

    if width < headerFullyHiddenWidth then
        profile.showHeader = false
    end
    if width < BASE_FRAME_WIDTH then
        profile.isFullInfo = false
    end

    if not profile.isFullInfo then
        profile.showDeletedRows = false
        profile.contextMenuEnabled = false
    end

    return profile
end

local function GetHeaderCollapseState(frame)
    local width = GetFrameWidth(frame)
    local t = Clamp((BASE_FRAME_WIDTH - width) / HEADER_COLLAPSE_TRANSITION_WIDTH, 0, 1)
    local eased = t * t * (3 - 2 * t)
    local ratio = 1 - eased
    local headerHeight = FIXED_ROW_HEIGHT * ratio
    local headerGap = COMPACT_BASE_ROW_GAP * ratio
    if headerHeight < 0.5 then
        headerHeight = 0
    end
    if headerGap < 0.5 then
        headerGap = 0
    end
    return {
        height = headerHeight,
        gap = headerGap,
        alpha = ratio,
        shown = headerHeight > 0,
    }
end

local function GetSmoothCompactFontScale(frame, baseScale, profile)
    if not profile or profile.showHeader ~= false then
        return baseScale
    end

    local frameWidth = GetFrameWidth(frame)
    local t = Clamp((BASE_FRAME_WIDTH - frameWidth) / COMPACT_FONT_TRANSITION_WIDTH, 0, 1)
    -- smoothstep: 消除阶段切换时字体缩放突兀跳变
    t = t * t * (3 - 2 * t)

    local targetScale = Clamp((baseScale or 1) * 1.15, 0.9, 1.1)
    return baseScale + (targetScale - baseScale) * t
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

local function SumColumnWidths(widths)
    local sum = 0
    for i = 1, 5 do
        sum = sum + math.max(0, widths and widths[i] or 0)
    end
    return math.max(1, math.floor(sum + 0.5))
end

local function CalculateColumnWidths(rows, headerLabels, totalWidth, scale, profile)
    local headers = headerLabels or {}
    local notifyText = L["Notify"] or "通知"
    local noRecord = L["NoRecord"] or "--:--"
    local notAcquired = L["NotAcquired"] or "---:---"
    local phaseFullText = "0000-0000"
    local phaseShortText = "0000"
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

    -- 地图列宽固定为默认宽度，不参与缩放，避免缩小时地图名被截断
    local mapDesiredWidth = math.floor(mapMax + MAP_COL_BASE_PADDING + MAP_COL_SAFETY_PADDING + 0.5)
    mapDesiredWidth = Clamp(mapDesiredWidth, MAP_COL_FIXED_MIN_WIDTH, MAP_COL_FIXED_MAX_WIDTH)

    local phaseFullDesired = math.floor((GetMaxWidth({headers[2] or "", notAcquired, phaseFullText}) + 20) * widthScale + 0.5)
    local phaseShortDesired = math.floor((GetMaxWidth({headers[2] or "", notAcquired, phaseShortText}) + 20) * widthScale + 0.5)
    local lastDesired = math.floor((GetMaxWidth({headers[3] or "", noRecord, "00:00:00"}) + 18) * widthScale + 0.5)
    local nextDesired = math.floor((GetMaxWidth({headers[4] or "", noRecord, "00:00:00"}) + 18) * widthScale + 0.5)
    local opDesired = math.floor((GetMaxWidth({headers[5] or "", notifyText}) + 20) * widthScale + 0.5)

    local phaseFullNeed = math.floor((GetMaxWidth({notAcquired, phaseFullText}) + 10) * widthScale + 0.5)
    local phaseShortNeed = math.floor((GetMaxWidth({notAcquired, phaseShortText}) + 10) * widthScale + 0.5)
    local lastNeed = math.floor((GetMaxWidth({noRecord, "00:00:00"}) + 10) * widthScale + 0.5)
    local nextNeed = math.floor((GetMaxWidth({noRecord, "00:00:00"}) + 10) * widthScale + 0.5)
    local opNeed = math.floor((GetMaxWidth({notifyText}) + 10) * widthScale + 0.5)

    if profile and profile.showHeader == false then
        local remaining = math.max(0, math.floor((totalWidth or 0) - mapDesiredWidth + 0.5))
        local showPhase = true
        local showLast = true
        local showOp = true
        local usePhaseShort = false

        if remaining < (phaseFullNeed + lastNeed + nextNeed + opNeed) then
            showLast = false
            if remaining < (phaseFullNeed + nextNeed + opNeed) then
                usePhaseShort = true
                if remaining < (phaseShortNeed + nextNeed + opNeed) then
                    showPhase = false
                    usePhaseShort = false
                    if remaining < (nextNeed + opNeed) then
                        showOp = false
                    end
                end
            end
        end

        profile.showPhaseColumn = showPhase
        profile.showLastRefreshColumn = showLast
        profile.showOperationColumn = showOp
        profile.phaseShortMode = usePhaseShort

        local desired = {
            mapDesiredWidth,
            usePhaseShort and phaseShortDesired or phaseFullDesired,
            lastDesired,
            nextDesired,
            opDesired,
        }
        local minWidths = {
            mapDesiredWidth,
            usePhaseShort and phaseShortNeed or phaseFullNeed,
            lastNeed,
            nextNeed,
            opNeed,
        }
        local maxWidths = {
            mapDesiredWidth,
            math.max(desired[2], minWidths[2]) + math.max(2, math.floor(6 * widthScale + 0.5)),
            math.max(desired[3], minWidths[3]) + math.max(2, math.floor(6 * widthScale + 0.5)),
            math.max(desired[4], minWidths[4]) + math.max(2, math.floor(6 * widthScale + 0.5)),
            math.max(desired[5], minWidths[5]) + math.max(2, math.floor(6 * widthScale + 0.5)),
        }

        local result = {0, 0, 0, 0, 0}
        result[1] = mapDesiredWidth

        local otherIndices = {}
        local otherDesired = {}
        local otherMinWidths = {}
        local otherMaxWidths = {}

        if showPhase then
            table.insert(otherIndices, 2)
            table.insert(otherDesired, desired[2])
            table.insert(otherMinWidths, math.max(1, minWidths[2]))
            table.insert(otherMaxWidths, math.max(1, maxWidths[2]))
        end
        if showLast then
            table.insert(otherIndices, 3)
            table.insert(otherDesired, desired[3])
            table.insert(otherMinWidths, math.max(1, minWidths[3]))
            table.insert(otherMaxWidths, math.max(1, maxWidths[3]))
        end
        table.insert(otherIndices, 4)
        table.insert(otherDesired, desired[4])
        table.insert(otherMinWidths, math.max(1, minWidths[4]))
        table.insert(otherMaxWidths, math.max(1, maxWidths[4]))
        if showOp then
            table.insert(otherIndices, 5)
            table.insert(otherDesired, desired[5])
            table.insert(otherMinWidths, math.max(1, minWidths[5]))
            table.insert(otherMaxWidths, math.max(1, maxWidths[5]))
        end

        local remainingWidth = math.max(1, math.floor((totalWidth or 1) - mapDesiredWidth + 0.5))
        local distributedOthers = DistributeWidths(otherDesired, otherMinWidths, otherMaxWidths, remainingWidth)
        for i, colIndex in ipairs(otherIndices) do
            result[colIndex] = distributedOthers[i] or 0
        end

        -- 主框最小宽度只保底最终形态（地图 + 下次刷新），
        -- 避免在前序阶段被锁死导致后续隐藏条件无法触发
        local minTableWidth = mapDesiredWidth + nextNeed
        profile.minTableWidth = math.max(1, math.floor(minTableWidth + 0.5))

        return result
    end

    local desired = {
        mapDesiredWidth,
        phaseFullDesired,
        lastDesired,
        nextDesired,
        opDesired,
    }
    local minWidths = {
        mapDesiredWidth,
        math.floor(72 * widthScale + 0.5),
        math.floor(88 * widthScale + 0.5),
        math.floor(92 * widthScale + 0.5),
        math.floor(72 * widthScale + 0.5),
    }
    local maxWidths = {
        mapDesiredWidth,
        math.floor(170 * widthScale + 0.5),
        math.floor(190 * widthScale + 0.5),
        math.floor(210 * widthScale + 0.5),
        math.floor(150 * widthScale + 0.5),
    }

    local visible = {
        true,
        profile and profile.showPhaseColumn == true or false,
        profile and profile.showLastRefreshColumn == true or false,
        true,
        profile and profile.showOperationColumn == true or false,
    }

    local activeIndices = {}
    local activeDesired = {}
    local activeMinWidths = {}
    local activeMaxWidths = {}

    for colIndex = 1, 5 do
        if visible[colIndex] then
            table.insert(activeIndices, colIndex)
            table.insert(activeDesired, desired[colIndex])
            table.insert(activeMinWidths, math.max(1, minWidths[colIndex]))
            table.insert(activeMaxWidths, math.max(1, maxWidths[colIndex]))
        end
    end

    if #activeIndices == 0 then
        if profile then
            profile.minTableWidth = 1
        end
        return {0, 0, 0, 0, 0}
    end

    if profile then
        local minTotal = 0
        for _, minWidth in ipairs(activeMinWidths) do
            minTotal = minTotal + math.max(1, minWidth)
        end
        profile.minTableWidth = math.max(1, math.floor(minTotal + 0.5))
    end

    local distributed = DistributeWidths(activeDesired, activeMinWidths, activeMaxWidths, totalWidth)
    local result = {0, 0, 0, 0, 0}
    for idx, colIndex in ipairs(activeIndices) do
        result[colIndex] = distributed[idx] or 0
    end

    return result
end

local function CalculateTableLayout(frame, profile)
    local tableParent = GetTableParent(frame)
    local contentWidth = tableParent and tableParent:GetWidth() or 0

    if contentWidth <= 1 then
        local frameWidth = frame and frame:GetWidth() or BASE_FRAME_WIDTH
        contentWidth = math.max(1, math.floor(frameWidth - 20))
    end

    local scale = GetScaleFactor(frame)
    local visibilityProfile = profile or GetVisibilityProfile(frame)
    local fontScale = GetSmoothCompactFontScale(frame, scale, visibilityProfile)
    local headerState = GetHeaderCollapseState(frame)

    local rowHeight = FIXED_ROW_HEIGHT
    local rowGap = COMPACT_BASE_ROW_GAP

    return {
        parent = tableParent,
        scale = fontScale,
        rowHeight = rowHeight,
        rowGap = rowGap,
        headerHeight = headerState.height,
        headerGap = headerState.gap,
        headerAlpha = headerState.alpha,
        tableWidth = math.max(1, math.floor(contentWidth + 0.5)),
        startX = 0,
        startY = 0,
        showPhaseColumn = visibilityProfile.showPhaseColumn == true,
        showLastRefreshColumn = visibilityProfile.showLastRefreshColumn == true,
        showOperationColumn = visibilityProfile.showOperationColumn == true,
        phaseShortMode = visibilityProfile.phaseShortMode == true,
        contextMenuEnabled = visibilityProfile.contextMenuEnabled == true,
        showHeader = headerState.shown,
    }
end

local function HideVisibleFrames()
    for _, frameRef in ipairs(tableRows) do
        if frameRef and frameRef.Hide then
            frameRef:Hide()
        end
    end
    tableRows = {}
end

local function AcquireRowFrame(parent, index)
    local rowFrame = rowFramePool[index]
    if rowFrame then
        if rowFrame:GetParent() ~= parent then
            rowFrame:SetParent(parent)
        end
        return rowFrame
    end

    rowFrame = CreateFrame("Frame", nil, parent)
    rowFrame:EnableMouse(true)
    rowFrame.rowBg = rowFrame:CreateTexture(nil, "BACKGROUND")
    rowFrame.rowBg:SetAllPoints(rowFrame)
    rowFrame.cellTexts = {}

    rowFrame:SetScript("OnMouseDown", function(self, button)
        local rowId = self.rowId
        if not rowId then
            return
        end
        if button == "RightButton" and RowStateSystem and self.__ctkContextMenuEnabled ~= false and (not RowStateSystem.IsContextMenuEnabled or RowStateSystem:IsContextMenuEnabled()) then
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

    rowFramePool[index] = rowFrame
    return rowFrame
end

function TableUI:RebuildUI(frame, headerLabels)
    if not frame then return end
    if not SortingSystem then return end

    local visibilityProfile = GetVisibilityProfile(frame)
    local rows = {}
    for _, rowInfo in ipairs(SortingSystem:GetCurrentRows() or {}) do
        if visibilityProfile.showDeletedRows or not rowInfo.isHidden then
            table.insert(rows, rowInfo)
        end
    end
    HideVisibleFrames()

    if CountdownSystem then
        CountdownSystem:ClearTexts()
    end

    if SortingSystem and SortingSystem.SetHeaderButton then
        SortingSystem:SetHeaderButton(nil)
    end

    if RowStateSystem then
        RowStateSystem:ClearRowRefs()
        if RowStateSystem.SetContextMenuEnabled then
            RowStateSystem:SetContextMenuEnabled(visibilityProfile.contextMenuEnabled == true)
        end
    end

    local layout = CalculateTableLayout(frame, visibilityProfile)
    local colWidths = CalculateColumnWidths(rows, headerLabels, layout.tableWidth, layout.scale, visibilityProfile)
    layout.showPhaseColumn = visibilityProfile.showPhaseColumn == true
    layout.showLastRefreshColumn = visibilityProfile.showLastRefreshColumn == true
    layout.showOperationColumn = visibilityProfile.showOperationColumn == true
    layout.phaseShortMode = visibilityProfile.phaseShortMode == true
    layout.activeTableWidth = SumColumnWidths(colWidths)

    local frameWidth = frame:GetWidth() or BASE_FRAME_WIDTH
    local requiredMinFrameWidth = BASE_MIN_FRAME_WIDTH
    if visibilityProfile.showHeader == false then
        local horizontalPadding = frameWidth - (layout.tableWidth or 0)
        if horizontalPadding < 0 then
            horizontalPadding = 0
        end
        local minTableWidth = math.max(1, visibilityProfile.minTableWidth or 1)
        requiredMinFrameWidth = math.floor(minTableWidth + horizontalPadding + 0.5)
        requiredMinFrameWidth = Clamp(requiredMinFrameWidth, BASE_MIN_FRAME_WIDTH, BASE_FRAME_WIDTH - 1)
    end

    if frame.__ctkContentMinWidth ~= requiredMinFrameWidth then
        frame.__ctkContentMinWidth = requiredMinFrameWidth
        if MainFrame and MainFrame.ApplyAdaptiveResizeBounds then
            MainFrame:ApplyAdaptiveResizeBounds(frame)
        end
    end
    if frameWidth + 0.5 < requiredMinFrameWidth then
        frame:SetWidth(requiredMinFrameWidth)
        return
    end

    if layout.showHeader then
        self:CreateHeaderRow(layout.parent, headerLabels, colWidths, layout)
    elseif headerRowFrame then
        headerRowFrame:Hide()
    end

    for displayIndex, rowInfo in ipairs(rows) do
        self:CreateDataRow(layout.parent, rowInfo, displayIndex, colWidths, layout)
    end

    for idx = #rows + 1, #rowFramePool do
        local extraFrame = rowFramePool[idx]
        if extraFrame then
            extraFrame:Hide()
        end
    end

    if SortingSystem then
        SortingSystem:UpdateHeaderVisual()
    end
end

function TableUI:CreateHeaderRow(parent, headerLabels, colWidths, layout)
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
    headerRowFrame:SetSize(layout.activeTableWidth or layout.tableWidth, headerHeight)
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
        if colIndex <= 5 and (colWidths[colIndex] or 0) > 0 then
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

    table.insert(tableRows, headerRowFrame)
end

function TableUI:CreateSortHeaderButton(parent, label, colWidth, layout, currentX, existingButton)
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
    local textColor = cfg.GetTextColor("normal")
    buttonText:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
    ApplyFontScale(buttonText, layout.scale)

    return sortHeaderButton
end

function TableUI:CreateHeaderText(parent, label, colIndex, colWidth, layout, currentX, headerBg, existingText)
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
    local textColor = cfg.GetTextColor("normal")
    cellText:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
    ApplyFontScale(cellText, layout.scale)
    return cellText
end

function TableUI:CreateDataRow(parent, rowInfo, displayIndex, colWidths, layout)
    local rowId = rowInfo.rowId
    local headerOffsetY = 0
    if layout.showHeader then
        headerOffsetY = (layout.headerHeight or layout.rowHeight) + (layout.headerGap or layout.rowGap)
    end
    local slotY = headerOffsetY + (layout.rowHeight + layout.rowGap) * (displayIndex - 1)
    local rowFrame = AcquireRowFrame(parent, displayIndex)
    rowFrame:SetSize(layout.activeTableWidth or layout.tableWidth, layout.rowHeight)
    rowFrame:ClearAllPoints()
    rowFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", layout.startX, -(layout.startY + slotY))
    rowFrame:SetFrameLevel(parent:GetFrameLevel() + 10)
    rowFrame:SetAlpha(1.0)
    rowFrame:Show()
    rowFrame.uiScale = layout.scale
    rowFrame.uiRowHeight = layout.rowHeight
    rowFrame.__ctkContextMenuEnabled = layout.contextMenuEnabled == true
    rowFrame.rowId = rowId

    local rowBg = rowFrame.rowBg
    rowBg:SetAllPoints(rowFrame)

    if rowFrame.__ctkDeleteBtn then
        rowFrame.__ctkDeleteBtn:Hide()
    end
    if rowFrame.__ctkRestoreBtn then
        rowFrame.__ctkRestoreBtn:Hide()
    end

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

    self:CreateRowCells(rowFrame, rowInfo, colWidths, rowBg, layout.scale, layout)

    local notifyBtn = nil
    if layout.showOperationColumn then
        notifyBtn = self:CreateActionButtons(rowFrame, rowInfo, colWidths, rowBg, layout.scale)
    elseif rowFrame.notifyBtn then
        rowFrame.notifyBtn:Hide()
    end
    if RowStateSystem then
        RowStateSystem:RegisterRowButtons(rowId, notifyBtn)
    end

    table.insert(tableRows, rowFrame)
end

function TableUI:CreateRowCells(rowFrame, rowInfo, colWidths, rowBg, scale, layout)
    local cfg = GetConfig()
    local currentX = 0
    local leftPadding = math.floor(15 * (scale or 1) + 0.5)
    rowFrame.cellTexts = rowFrame.cellTexts or {}

    for _, cellText in pairs(rowFrame.cellTexts) do
        if cellText then
            cellText:Hide()
        end
    end

    local hasCurrentPhase = rowInfo.currentPhaseID ~= nil and rowInfo.currentPhaseID ~= ""
    local phaseText = L["NotAcquired"] or "---:---"
    local phaseColor = cfg.GetTextColor("normal")
    local phaseMaxLength = (layout and layout.phaseShortMode) and 4 or 10
    if hasCurrentPhase then
        phaseText = tostring(rowInfo.currentPhaseID)
        if #phaseText > phaseMaxLength then
            phaseText = string.sub(phaseText, 1, phaseMaxLength)
        end
        if rowInfo.phaseDisplayInfo and rowInfo.phaseDisplayInfo.color then
            phaseColor = {rowInfo.phaseDisplayInfo.color.r, rowInfo.phaseDisplayInfo.color.g, rowInfo.phaseDisplayInfo.color.b, 1}
        else
            phaseColor = cfg.GetTextColor("planeId")
        end
    else
        if rowInfo.lastRefreshPhase and rowInfo.lastRefreshPhase ~= "" then
            phaseText = tostring(rowInfo.lastRefreshPhase)
            if #phaseText > phaseMaxLength then
                phaseText = string.sub(phaseText, 1, phaseMaxLength)
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
        {colIndex = 1, text = rowInfo.mapName, align = "left", color = cfg.GetTextColor("normal")},
    }
    if layout and layout.showPhaseColumn then
        table.insert(columns, {colIndex = 2, text = phaseText, align = "center", color = phaseColor})
    end
    if layout and layout.showLastRefreshColumn then
        table.insert(columns, {colIndex = 3, text = lastRefreshText, align = "center", color = lastColor})
    end
    table.insert(columns, {colIndex = 4, text = nextRefreshText, align = "center", color = cfg.GetTextColor("normal"), isCountdown = true})

    for _, colData in ipairs(columns) do
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

        ApplyFontScale(cellText, scale)

        local textValue = colData.text or ""
        if colIndex == 1 then
            local padding = math.floor(24 * (scale or 1) + 0.5) + 2
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
        cellText:Show()

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

return TableUI

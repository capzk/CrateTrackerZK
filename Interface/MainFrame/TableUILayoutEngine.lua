-- TableUILayoutEngine.lua - 表格布局计算引擎

local TableUILayoutEngine = BuildEnv("TableUILayoutEngine")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local TableUITextMetrics = BuildEnv("TableUITextMetrics")
local L = CrateTrackerZK and CrateTrackerZK.L or {}

local BASE_FRAME_WIDTH = 600
local FIXED_ROW_HEIGHT = 29
local COMPACT_BASE_ROW_GAP = 4
local BASE_MIN_FRAME_WIDTH = 100
local FRAME_HORIZONTAL_PADDING = 24
local FRAME_VERTICAL_PADDING = 37
local INNER_TABLE_SIDE_MARGIN = 4
local PARTIAL_ROW_MIN_ALPHA = 0.18
local HEADER_COLLAPSE_TRANSITION_WIDTH = 60
local MAP_COL_BASE_PADDING = 24
local MAP_COL_SAFETY_PADDING = 6
local PHASE_DISPLAY_MAX_LENGTH = 4

local function ClearArray(buffer)
    if type(buffer) ~= "table" then
        return {}
    end
    for index = #buffer, 1, -1 do
        buffer[index] = nil
    end
    return buffer
end

local function GetReusableArray(owner, fieldName)
    local buffer = owner[fieldName]
    if not buffer then
        buffer = {}
        owner[fieldName] = buffer
    else
        ClearArray(buffer)
    end
    return buffer
end

local function ResetColumnMetrics(outMetrics)
    local metrics = type(outMetrics) == "table" and outMetrics or {}
    metrics.mapMaxTextWidth = 0
    metrics.phaseHeaderWidth = 0
    metrics.lastHeaderWidth = 0
    metrics.nextHeaderWidth = 0
    metrics.notAcquiredWidth = 0
    metrics.noRecordWidth = 0
    metrics.timeWidth = 0
    metrics.phaseFullDesiredTextWidth = 0
    metrics.phaseShortDesiredTextWidth = 0
    metrics.phaseFullNeedTextWidth = 0
    metrics.phaseShortNeedTextWidth = 0
    return metrics
end

function TableUILayoutEngine:Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function TableUILayoutEngine:SmoothStep(t)
    local value = self:Clamp(t or 0, 0, 1)
    return value * value * (3 - 2 * value)
end

function TableUILayoutEngine:ComputeRowsBlockHeight(rowCount, rowHeight, rowGap)
    if (rowCount or 0) <= 0 then
        return 0
    end
    return (rowCount * rowHeight) + math.max(0, rowCount - 1) * rowGap
end

function TableUILayoutEngine:GetBaselineFrameWidth(frame)
    local contentMax = frame and tonumber(frame.__ctkContentMaxWidth) or nil
    if contentMax then
        return self:Clamp(math.floor(contentMax + 0.5), BASE_MIN_FRAME_WIDTH, BASE_FRAME_WIDTH)
    end
    return BASE_FRAME_WIDTH
end

function TableUILayoutEngine:GetScaledChromeMetrics(scale)
    return {
        scale = 1,
        edgeGap = 8,
        titleHeight = 22,
        horizontalPadding = FRAME_HORIZONTAL_PADDING,
        verticalPadding = FRAME_VERTICAL_PADDING,
    }
end

function TableUILayoutEngine:GetScaledRowMetrics(scale)
    return FIXED_ROW_HEIGHT, COMPACT_BASE_ROW_GAP
end

function TableUILayoutEngine:GetDefaultFrameHeightForRowCount(rowCount, allowHeaderSpace)
    local headerTransitionHeight = (allowHeaderSpace == true) and (FIXED_ROW_HEIGHT + COMPACT_BASE_ROW_GAP) or 0
    return self:ComputeRowsBlockHeight(math.max(0, rowCount or 0), FIXED_ROW_HEIGHT, COMPACT_BASE_ROW_GAP)
        + headerTransitionHeight
        + FRAME_VERTICAL_PADDING
end

function TableUILayoutEngine:GetScaleFactor(frame, rowCount, allowHeaderSpace)
    if frame and rowCount ~= nil then
        frame.__ctkBaselineFrameHeight = self:GetDefaultFrameHeightForRowCount(rowCount, allowHeaderSpace)
    end
    return 1
end

function TableUILayoutEngine:GetFrameWidth(frame)
    if not frame or not frame.GetWidth then
        return BASE_FRAME_WIDTH
    end
    return frame:GetWidth() or BASE_FRAME_WIDTH
end

function TableUILayoutEngine:GetFrameHeight(frame)
    if not frame or not frame.GetHeight then
        return 0
    end
    return frame:GetHeight() or 0
end

function TableUILayoutEngine:GetVisibilityProfile(frame)
    local width = self:GetFrameWidth(frame)
    local baselineWidth = self:GetBaselineFrameWidth(frame)
    local headerFullyHiddenWidth = baselineWidth - HEADER_COLLAPSE_TRANSITION_WIDTH
    local profile = {
        showHeader = true,
        showPhaseColumn = true,
        showLastRefreshColumn = true,
        phaseShortMode = false,
        showDeletedRows = false,
        isFullInfo = true,
        compactByWidth = false,
    }

    profile.compactByWidth = width < headerFullyHiddenWidth
    if profile.compactByWidth then
        profile.showHeader = false
    end
    if width < baselineWidth then
        profile.isFullInfo = false
    end
    if not profile.isFullInfo then
        profile.showDeletedRows = false
    end

    return profile
end

function TableUILayoutEngine:GetHeaderWidthRatio(frame)
    local width = self:GetFrameWidth(frame)
    local baselineWidth = self:GetBaselineFrameWidth(frame)
    local t = self:Clamp((baselineWidth - width) / HEADER_COLLAPSE_TRANSITION_WIDTH, 0, 1)
    return 1 - self:SmoothStep(t)
end

function TableUILayoutEngine:GetHeaderCollapseState(frame, profile, layoutScale, rowHeight, rowGap)
    local widthRatio = self:GetHeaderWidthRatio(frame)
    local heightRatio = self:Clamp((profile and profile.headerAlphaByHeight) or 1, 0, 1)
    local ratio = math.min(widthRatio, heightRatio)
    local baseRowHeight = rowHeight or FIXED_ROW_HEIGHT
    local baseRowGap = rowGap == nil and COMPACT_BASE_ROW_GAP or rowGap
    local headerHeight = baseRowHeight * ratio
    local headerGap = baseRowGap * ratio
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

local function GetTextWidth(text)
    if TableUITextMetrics and TableUITextMetrics.GetTextWidth then
        return TableUITextMetrics:GetTextWidth(text)
    end
    return 0
end

function TableUILayoutEngine:ScaleWidths(baseWidths, targetTotal, outWidths)
    local sum = 0
    for _, width in ipairs(baseWidths) do
        sum = sum + width
    end
    if sum <= 0 then
        local passthrough = type(outWidths) == "table" and outWidths or {}
        ClearArray(passthrough)
        for index = 1, #baseWidths do
            passthrough[index] = baseWidths[index]
        end
        return passthrough
    end
    local scaled = type(outWidths) == "table" and outWidths or {}
    ClearArray(scaled)
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

function TableUILayoutEngine:FormatPhaseDisplayText(phaseValue, maxLength)
    if phaseValue == nil or phaseValue == "" then
        return nil
    end
    local text = tostring(phaseValue)
    local displayMaxLength = math.max(1, tonumber(maxLength) or PHASE_DISPLAY_MAX_LENGTH)
    if #text > displayMaxLength then
        text = string.sub(text, 1, displayMaxLength)
    end
    return text
end

function TableUILayoutEngine:CollectColumnMetrics(rows, headerLabels, outMetrics)
    local headers = headerLabels or {}
    local noRecord = L and L["NoRecord"] or "--:--"
    local notAcquired = L and L["NotAcquired"] or "---:---"
    local metrics = ResetColumnMetrics(outMetrics)

    metrics.mapMaxTextWidth = GetTextWidth(headers[1] or "")
    metrics.phaseHeaderWidth = GetTextWidth(headers[2] or "")
    metrics.lastHeaderWidth = GetTextWidth(headers[3] or "")
    metrics.nextHeaderWidth = GetTextWidth(headers[4] or "")
    metrics.notAcquiredWidth = GetTextWidth(notAcquired)
    metrics.noRecordWidth = GetTextWidth(noRecord)
    metrics.timeWidth = GetTextWidth("00:00:00")
    metrics.phaseFullDesiredTextWidth = math.max(metrics.phaseHeaderWidth, metrics.notAcquiredWidth)
    metrics.phaseShortDesiredTextWidth = math.max(metrics.phaseHeaderWidth, metrics.notAcquiredWidth)
    metrics.phaseFullNeedTextWidth = metrics.notAcquiredWidth
    metrics.phaseShortNeedTextWidth = metrics.notAcquiredWidth

    for _, rowInfo in ipairs(rows or {}) do
        if rowInfo and rowInfo.mapName then
            local mapWidth = GetTextWidth(rowInfo.mapName)
            if mapWidth > metrics.mapMaxTextWidth then
                metrics.mapMaxTextWidth = mapWidth
            end
        end

        local phaseValue = nil
        if rowInfo then
            if rowInfo.currentPhaseID ~= nil and rowInfo.currentPhaseID ~= "" then
                phaseValue = rowInfo.currentPhaseID
            elseif rowInfo.lastRefreshPhase and rowInfo.lastRefreshPhase ~= "" then
                phaseValue = rowInfo.lastRefreshPhase
            end
        end

        local phaseFullText = self:FormatPhaseDisplayText(phaseValue, PHASE_DISPLAY_MAX_LENGTH)
        if phaseFullText and phaseFullText ~= "" then
            local phaseFullWidth = GetTextWidth(phaseFullText)
            if phaseFullWidth > metrics.phaseFullDesiredTextWidth then
                metrics.phaseFullDesiredTextWidth = phaseFullWidth
            end
            if phaseFullWidth > metrics.phaseFullNeedTextWidth then
                metrics.phaseFullNeedTextWidth = phaseFullWidth
            end
        end

        local phaseShortText = self:FormatPhaseDisplayText(phaseValue, PHASE_DISPLAY_MAX_LENGTH)
        if phaseShortText and phaseShortText ~= "" then
            local phaseShortWidth = GetTextWidth(phaseShortText)
            if phaseShortWidth > metrics.phaseShortDesiredTextWidth then
                metrics.phaseShortDesiredTextWidth = phaseShortWidth
            end
            if phaseShortWidth > metrics.phaseShortNeedTextWidth then
                metrics.phaseShortNeedTextWidth = phaseShortWidth
            end
        end
    end

    return metrics
end

function TableUILayoutEngine:DistributeWidths(desired, minWidths, maxWidths, total, outWidths)
    local clamped = GetReusableArray(self, "__ctkDistributeClampedBuffer")
    local minSum = 0
    for i, width in ipairs(desired) do
        local minW = minWidths[i] or 1
        local maxW = maxWidths[i] or total
        clamped[i] = math.max(minW, math.min(maxW, width))
        minSum = minSum + minW
    end
    if minSum >= total then
        return self:ScaleWidths(minWidths, total, outWidths)
    end
    local weights = GetReusableArray(self, "__ctkDistributeWeightsBuffer")
    local weightSum = 0
    for i, width in ipairs(clamped) do
        local extra = width - (minWidths[i] or 0)
        if extra < 0 then extra = 0 end
        weights[i] = extra
        weightSum = weightSum + extra
    end
    local remaining = total - minSum
    local result = type(outWidths) == "table" and outWidths or {}
    ClearArray(result)
    local used = 0
    for i = 1, #clamped do
        local add = 0
        if weightSum > 0 then
            add = math.floor(remaining * (weights[i] / weightSum) + 0.5)
        else
            add = math.floor(remaining / #clamped + 0.5)
        end
        if i == #clamped then
            result[i] = total - used
        else
            result[i] = (minWidths[i] or 0) + add
            used = used + result[i]
        end
    end
    return result
end

function TableUILayoutEngine:SumColumnWidths(widths)
    local total = 0
    for _, width in ipairs(widths or {}) do
        total = total + (width or 0)
    end
    return total
end

function TableUILayoutEngine:CalculateColumnWidths(rows, headerLabels, totalWidth, scale, profile, outWidths, columnMetrics)
    local widthScale = scale or 1
    local metrics = columnMetrics or self:CollectColumnMetrics(rows, headerLabels, self.__ctkColumnMetricsBuffer)

    local mapNaturalWidth = math.max(1, math.floor(metrics.mapMaxTextWidth + MAP_COL_BASE_PADDING + MAP_COL_SAFETY_PADDING + 0.5))
    local mapCompactMinWidth = mapNaturalWidth
    if profile then
        profile.mapNaturalWidth = mapNaturalWidth
        profile.mapCompactMinWidth = mapCompactMinWidth
    end

    local phaseFullDesired = math.floor((metrics.phaseFullDesiredTextWidth + 20) * widthScale + 0.5)
    local phaseShortDesired = math.floor((metrics.phaseShortDesiredTextWidth + 20) * widthScale + 0.5)
    local lastDesired = math.floor((math.max(metrics.lastHeaderWidth, metrics.noRecordWidth, metrics.timeWidth) + 18) * widthScale + 0.5)
    local nextDesired = math.floor((math.max(metrics.nextHeaderWidth, metrics.noRecordWidth, metrics.timeWidth) + 18) * widthScale + 0.5)
    local phaseFullNeed = math.floor((metrics.phaseFullNeedTextWidth + 10) * widthScale + 0.5)
    local phaseShortNeed = math.floor((metrics.phaseShortNeedTextWidth + 10) * widthScale + 0.5)
    local lastNeed = math.floor((math.max(metrics.noRecordWidth, metrics.timeWidth) + 10) * widthScale + 0.5)
    local nextNeed = math.floor((math.max(metrics.noRecordWidth, metrics.timeWidth) + 10) * widthScale + 0.5)

    if profile and profile.compactByWidth == true then
        local remaining = math.max(0, math.floor((totalWidth or 0) - mapNaturalWidth + 0.5))
        local showPhase = true
        local showLast = true
        local usePhaseShort = false

        if remaining < (phaseFullNeed + lastNeed + nextNeed) then
            showLast = false
            if remaining < (phaseFullNeed + nextNeed) then
                usePhaseShort = true
                if remaining < (phaseShortNeed + nextNeed) then
                    showPhase = false
                    usePhaseShort = false
                end
            end
        end

        profile.showPhaseColumn = showPhase
        profile.showLastRefreshColumn = showLast
        profile.phaseShortMode = usePhaseShort

        local desired = GetReusableArray(self, "__ctkDesiredWidthsBuffer")
        desired[1] = mapNaturalWidth
        desired[2] = usePhaseShort and phaseShortDesired or phaseFullDesired
        desired[3] = lastDesired
        desired[4] = nextDesired
        local minWidths = GetReusableArray(self, "__ctkMinWidthsBuffer")
        minWidths[1] = mapCompactMinWidth
        minWidths[2] = usePhaseShort and phaseShortNeed or phaseFullNeed
        minWidths[3] = lastNeed
        minWidths[4] = nextNeed
        local maxWidths = GetReusableArray(self, "__ctkMaxWidthsBuffer")
        maxWidths[1] = mapNaturalWidth
        maxWidths[2] = math.max(desired[2], minWidths[2]) + math.max(2, math.floor(6 * widthScale + 0.5))
        maxWidths[3] = math.max(desired[3], minWidths[3]) + math.max(2, math.floor(6 * widthScale + 0.5))
        maxWidths[4] = math.max(desired[4], minWidths[4]) + math.max(2, math.floor(6 * widthScale + 0.5))

        local result = type(outWidths) == "table" and outWidths or {0, 0, 0, 0}
        ClearArray(result)

        local otherIndices = GetReusableArray(self, "__ctkOtherIndicesBuffer")
        local otherDesired = GetReusableArray(self, "__ctkOtherDesiredBuffer")
        local otherMinWidths = GetReusableArray(self, "__ctkOtherMinWidthsBuffer")
        local otherMaxWidths = GetReusableArray(self, "__ctkOtherMaxWidthsBuffer")
        local otherCount = 0

        if showPhase then
            otherCount = otherCount + 1
            otherIndices[otherCount] = 2
            otherDesired[otherCount] = desired[2]
            otherMinWidths[otherCount] = math.max(1, minWidths[2])
            otherMaxWidths[otherCount] = math.max(1, maxWidths[2])
        end
        if showLast then
            otherCount = otherCount + 1
            otherIndices[otherCount] = 3
            otherDesired[otherCount] = desired[3]
            otherMinWidths[otherCount] = math.max(1, minWidths[3])
            otherMaxWidths[otherCount] = math.max(1, maxWidths[3])
        end
        otherCount = otherCount + 1
        otherIndices[otherCount] = 4
        otherDesired[otherCount] = desired[4]
        otherMinWidths[otherCount] = math.max(1, minWidths[4])
        otherMaxWidths[otherCount] = math.max(1, maxWidths[4])

        local otherMinTotal = 0
        for _, width in ipairs(otherMinWidths) do
            otherMinTotal = otherMinTotal + math.max(1, width or 0)
        end
        local mapWidth = math.floor((totalWidth or 1) - otherMinTotal + 0.5)
        mapWidth = self:Clamp(mapWidth, mapCompactMinWidth, mapNaturalWidth)
        result[1] = mapWidth

        local remainingWidth = math.max(1, math.floor((totalWidth or 1) - mapWidth + 0.5))
        local distributedOthers = self:DistributeWidths(otherDesired, otherMinWidths, otherMaxWidths, remainingWidth, GetReusableArray(self, "__ctkDistributedOthersBuffer"))
        for i, colIndex in ipairs(otherIndices) do
            result[colIndex] = distributedOthers[i] or 0
        end

        local minTableWidth = mapNaturalWidth + nextNeed
        profile.minTableWidth = math.max(1, math.floor(minTableWidth + 0.5))

        return result
    end

    local result = type(outWidths) == "table" and outWidths or {0, 0, 0, 0}
    ClearArray(result)

    local showPhase = profile and profile.showPhaseColumn == true or false
    local showLast = profile and profile.showLastRefreshColumn == true or false
    local showNext = true

    result[1] = math.max(mapCompactMinWidth, mapNaturalWidth)
    if showPhase then
        result[2] = math.max(phaseFullNeed, phaseFullDesired)
    end
    if showLast then
        result[3] = math.max(lastNeed, lastDesired)
    end
    if showNext then
        result[4] = math.max(nextNeed, nextDesired)
    end

    local availableWidth = math.max(1, math.floor((totalWidth or 0) + 0.5))
    local naturalTotal = self:SumColumnWidths(result)
    if naturalTotal > availableWidth then
        local activeIndices = GetReusableArray(self, "__ctkActiveIndicesBuffer")
        local activeDesired = GetReusableArray(self, "__ctkActiveDesiredBuffer")
        local activeMinWidths = GetReusableArray(self, "__ctkActiveMinWidthsBuffer")
        local activeMaxWidths = GetReusableArray(self, "__ctkActiveMaxWidthsBuffer")
        local activeCount = 0

        activeCount = activeCount + 1
        activeIndices[activeCount] = 1
        activeDesired[activeCount] = result[1]
        activeMinWidths[activeCount] = math.max(1, mapCompactMinWidth)
        activeMaxWidths[activeCount] = math.max(1, result[1])

        if showPhase then
            activeCount = activeCount + 1
            activeIndices[activeCount] = 2
            activeDesired[activeCount] = result[2]
            activeMinWidths[activeCount] = math.max(1, phaseFullNeed)
            activeMaxWidths[activeCount] = math.max(1, result[2])
        end
        if showLast then
            activeCount = activeCount + 1
            activeIndices[activeCount] = 3
            activeDesired[activeCount] = result[3]
            activeMinWidths[activeCount] = math.max(1, lastNeed)
            activeMaxWidths[activeCount] = math.max(1, result[3])
        end
        if showNext then
            activeCount = activeCount + 1
            activeIndices[activeCount] = 4
            activeDesired[activeCount] = result[4]
            activeMinWidths[activeCount] = math.max(1, nextNeed)
            activeMaxWidths[activeCount] = math.max(1, result[4])
        end

        local distributed = self:DistributeWidths(activeDesired, activeMinWidths, activeMaxWidths, availableWidth, GetReusableArray(self, "__ctkDistributedActiveBuffer"))
        ClearArray(result)
        for index, colIndex in ipairs(activeIndices) do
            result[colIndex] = distributed[index] or 0
        end
    end

    if profile then
        profile.minTableWidth = self:SumColumnWidths(result)
    end

    return result
end

function TableUILayoutEngine:CalculateTableLayout(frame, profile, layoutScale, chromeMetrics, verticalMetrics, getTableParent)
    local tableParent = getTableParent(frame)
    local contentWidth = tableParent and tableParent:GetWidth() or 0
    if contentWidth <= 1 then
        local frameWidth = frame and frame:GetWidth() or BASE_FRAME_WIDTH
        local fallbackPadding = chromeMetrics and chromeMetrics.horizontalPadding or FRAME_HORIZONTAL_PADDING
        contentWidth = math.max(1, math.floor(frameWidth - fallbackPadding + 0.5))
    end
    local tableWidth = math.max(1, math.floor(contentWidth - (INNER_TABLE_SIDE_MARGIN * 2) + 0.5))

    local rowHeight = verticalMetrics and verticalMetrics.rowHeight or FIXED_ROW_HEIGHT
    local rowGap = verticalMetrics and verticalMetrics.rowGap or COMPACT_BASE_ROW_GAP
    local visibilityProfile = profile or self:GetVisibilityProfile(frame)
    local headerState = self:GetHeaderCollapseState(frame, visibilityProfile, layoutScale, rowHeight, rowGap)

    return {
        parent = tableParent,
        scale = 1,
        fontScale = 1,
        rowHeight = rowHeight,
        rowGap = rowGap,
        headerHeight = headerState.height,
        headerGap = headerState.gap,
        headerAlpha = headerState.alpha,
        tableWidth = tableWidth,
        startX = INNER_TABLE_SIDE_MARGIN,
        startY = 0,
        showPhaseColumn = visibilityProfile.showPhaseColumn == true,
        showLastRefreshColumn = visibilityProfile.showLastRefreshColumn == true,
        phaseShortMode = visibilityProfile.phaseShortMode == true,
        showHeader = headerState.shown,
    }
end

function TableUILayoutEngine:GetTransitionRatio(rawRatio)
    local clampedRatio = self:Clamp(rawRatio or 0, 0, 1)
    return self:SmoothStep(clampedRatio)
end

function TableUILayoutEngine:GetPartialRowAlpha(partialRowRatio)
    local ratio = self:Clamp(partialRowRatio or 0, 0, 1)
    if ratio <= 0 then
        return 1
    end
    return PARTIAL_ROW_MIN_ALPHA + ((1 - PARTIAL_ROW_MIN_ALPHA) * self:SmoothStep(ratio))
end

function TableUILayoutEngine:GetContentHeight(frame, tableParent)
    local verticalPadding = frame and tonumber(frame.__ctkChromeVerticalPadding) or FRAME_VERTICAL_PADDING
    local contentHeight = tableParent and tableParent:GetHeight() or 0
    if contentHeight and contentHeight > 1 then
        return contentHeight
    end
    local frameHeight = self:GetFrameHeight(frame)
    return math.max(0, math.floor(frameHeight - verticalPadding + 0.5))
end

function TableUILayoutEngine:BuildVerticalMetrics(frame, rowCount, rowHeight, rowGap, tableParent, allowHeaderSpace, headerWidthRatio)
    local safeRowCount = math.max(0, rowCount or 0)
    local safeRowHeight = rowHeight or FIXED_ROW_HEIGHT
    local safeRowGap = rowGap or COMPACT_BASE_ROW_GAP
    local contentHeight = self:GetContentHeight(frame, tableParent)
    local fullRowsHeight = self:ComputeRowsBlockHeight(safeRowCount, safeRowHeight, safeRowGap)
    local fullHeaderSpace = (allowHeaderSpace == true) and (safeRowHeight + safeRowGap) or 0
    local headerReserveRatio = self:Clamp(headerWidthRatio or 0, 0, 1)
    local headerTransitionHeight = fullHeaderSpace * headerReserveRatio
    local headerAlphaByHeight = 1
    local headerTransitionRatio = nil
    local visibleRowCount = safeRowCount
    local fullVisibleRowCount = safeRowCount
    local partialRowRatio = 0
    local partialRowRawRatio = nil
    local partialRowAlpha = 1
    local effectiveRowHeight = safeRowHeight
    local effectiveRowGap = safeRowGap
    local renderedTableHeight = fullRowsHeight + headerTransitionHeight
    local snapCollapseTableHeight = nil
    local snapExpandTableHeight = nil

    if safeRowCount <= 0 then
        headerAlphaByHeight = 0
        visibleRowCount = 0
        fullVisibleRowCount = 0
        renderedTableHeight = 0
    else
        if headerTransitionHeight > 0 and contentHeight > (fullRowsHeight + 0.5) then
            if contentHeight >= (fullRowsHeight + headerTransitionHeight - 0.5) then
                headerAlphaByHeight = 1
                renderedTableHeight = fullRowsHeight + headerTransitionHeight
            else
                local availableHeaderSpace = math.max(0, contentHeight - fullRowsHeight)
                local rawHeaderRatio = self:Clamp(availableHeaderSpace / math.max(1, fullHeaderSpace), 0, 1)
                headerTransitionRatio = rawHeaderRatio
                headerAlphaByHeight = self:GetTransitionRatio(rawHeaderRatio)
                renderedTableHeight = fullRowsHeight + (fullHeaderSpace * headerAlphaByHeight)
                snapCollapseTableHeight = fullRowsHeight
                snapExpandTableHeight = fullRowsHeight + fullHeaderSpace
            end
        else
            headerAlphaByHeight = 0
            renderedTableHeight = fullRowsHeight

            local rowUnit = effectiveRowHeight + effectiveRowGap
            local exactRowSlots = self:Clamp((contentHeight + effectiveRowGap) / math.max(1, rowUnit), 0, safeRowCount)
            fullVisibleRowCount = math.floor(exactRowSlots + 0.0001)
            local rawPartialRowRatio = exactRowSlots - fullVisibleRowCount
            partialRowRawRatio = rawPartialRowRatio
            local collapsedTableHeight = self:ComputeRowsBlockHeight(fullVisibleRowCount, effectiveRowHeight, effectiveRowGap)
            local expandedTableHeight = self:ComputeRowsBlockHeight(
                math.min(safeRowCount, fullVisibleRowCount + 1),
                effectiveRowHeight,
                effectiveRowGap
            )
            partialRowRatio = self:GetTransitionRatio(rawPartialRowRatio)

            if fullVisibleRowCount >= safeRowCount then
                fullVisibleRowCount = safeRowCount
                partialRowRatio = 0
                visibleRowCount = safeRowCount
            elseif fullVisibleRowCount <= 0 then
                fullVisibleRowCount = 0
                partialRowRatio = 0
                visibleRowCount = 0
            else
                visibleRowCount = fullVisibleRowCount + (partialRowRatio > 0 and 1 or 0)
            end

            partialRowAlpha = partialRowRatio > 0 and self:GetPartialRowAlpha(partialRowRatio) or 1
            if visibleRowCount <= 0 then
                renderedTableHeight = 0
            elseif partialRowRatio > 0 and visibleRowCount > fullVisibleRowCount then
                snapCollapseTableHeight = self:ComputeRowsBlockHeight(fullVisibleRowCount, effectiveRowHeight, effectiveRowGap)
                snapExpandTableHeight = self:ComputeRowsBlockHeight(
                    math.min(safeRowCount, fullVisibleRowCount + 1),
                    effectiveRowHeight,
                    effectiveRowGap
                )
                if fullVisibleRowCount <= 0 then
                    renderedTableHeight = effectiveRowHeight * partialRowRatio
                else
                    renderedTableHeight = self:ComputeRowsBlockHeight(fullVisibleRowCount, effectiveRowHeight, effectiveRowGap)
                        + (effectiveRowGap * partialRowRatio)
                        + (effectiveRowHeight * partialRowRatio)
                end
            else
                renderedTableHeight = self:ComputeRowsBlockHeight(visibleRowCount, effectiveRowHeight, effectiveRowGap)
            end
        end
    end

    local minTableHeight = safeRowCount > 0 and safeRowHeight or 0
    local maxTableHeight = fullRowsHeight + headerTransitionHeight
    local effectiveHeaderRatio = math.min(headerReserveRatio, headerAlphaByHeight)
    local partialTransitionActive = partialRowRawRatio ~= nil and partialRowRawRatio > 0.02 and partialRowRawRatio < 0.98
    local headerTransitionActive = headerTransitionRatio ~= nil and headerTransitionRatio > 0.02 and headerTransitionRatio < 0.98
    local fullyHiddenRowCount = math.max(0, safeRowCount - math.max(0, fullVisibleRowCount or 0))
    local hasFullyHiddenRow = fullyHiddenRowCount >= 1
    local shouldAutoCompactSort = safeRowCount > 1
        and hasFullyHiddenRow
        and not partialTransitionActive
        and not headerTransitionActive
        and effectiveHeaderRatio <= 0.001

    return {
        contentHeight = contentHeight,
        fullRowsHeight = fullRowsHeight,
        headerAlphaByHeight = headerAlphaByHeight,
        headerTransitionRatio = headerTransitionRatio,
        visibleRowCount = visibleRowCount,
        fullVisibleRowCount = fullVisibleRowCount,
        partialRowRatio = partialRowRatio,
        partialRowRawRatio = partialRowRawRatio,
        partialRowAlpha = partialRowAlpha,
        snapCollapseTableHeight = snapCollapseTableHeight,
        snapExpandTableHeight = snapExpandTableHeight,
        rowHeight = effectiveRowHeight,
        rowGap = effectiveRowGap,
        renderedTableHeight = renderedTableHeight,
        minTableHeight = minTableHeight,
        maxTableHeight = maxTableHeight,
        shouldAutoCompactSort = shouldAutoCompactSort,
    }
end

return TableUILayoutEngine

-- TableUILayoutEngine.lua - 表格布局计算引擎

local TableUILayoutEngine = BuildEnv("TableUILayoutEngine")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local Data = BuildEnv("Data")
local TableUITextMetrics = BuildEnv("TableUITextMetrics")
local L = CrateTrackerZK and CrateTrackerZK.L or {}

local BASE_FRAME_WIDTH = 600
local FIXED_ROW_HEIGHT = 29
local COMPACT_BASE_ROW_GAP = 4
local BASE_MIN_FRAME_WIDTH = 100
local FRAME_HORIZONTAL_PADDING = 24
local FRAME_VERTICAL_PADDING = 37
local INNER_TABLE_SIDE_MARGIN = 4
local MIN_PARTIAL_ROW_RATIO = 0.35
local HEADER_COLLAPSE_TRANSITION_WIDTH = 60
local MAP_COL_BASE_PADDING = 24
local MAP_COL_SAFETY_PADDING = 6
local PHASE_DISPLAY_MAX_LENGTH = 4

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

local function GetScaledTextWidth(text, scale)
    if TableUITextMetrics and TableUITextMetrics.GetScaledTextWidth then
        return TableUITextMetrics:GetScaledTextWidth(text, scale)
    end
    return 0
end

function TableUILayoutEngine:ScaleWidths(baseWidths, targetTotal)
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

function TableUILayoutEngine:GetMaxWidth(texts)
    local maxWidth = 0
    for _, text in ipairs(texts or {}) do
        local width = GetTextWidth(text)
        if width > maxWidth then
            maxWidth = width
        end
    end
    return maxWidth
end

function TableUILayoutEngine:FormatPhaseDisplayText(phaseValue)
    if phaseValue == nil or phaseValue == "" then
        return nil
    end
    local text = tostring(phaseValue)
    if #text > PHASE_DISPLAY_MAX_LENGTH then
        text = string.sub(text, 1, PHASE_DISPLAY_MAX_LENGTH)
    end
    return text
end

function TableUILayoutEngine:BuildPhaseWidthSamples(rows, fullMaxLength, shortMaxLength)
    local fullSamples = {}
    local shortSamples = {}
    local fullCap = math.max(1, fullMaxLength or 10)
    local shortCap = math.max(1, shortMaxLength or 4)

    for _, rowInfo in ipairs(rows or {}) do
        local phaseValue = nil
        if rowInfo then
            if rowInfo.currentPhaseID ~= nil and rowInfo.currentPhaseID ~= "" then
                phaseValue = tostring(rowInfo.currentPhaseID)
            elseif rowInfo.lastRefreshPhase and rowInfo.lastRefreshPhase ~= "" then
                phaseValue = tostring(rowInfo.lastRefreshPhase)
            end
        end

        local displayText = self:FormatPhaseDisplayText(phaseValue)
        if displayText and displayText ~= "" then
            table.insert(fullSamples, string.sub(displayText, 1, fullCap))
            table.insert(shortSamples, string.sub(displayText, 1, shortCap))
        end
    end

    return fullSamples, shortSamples
end

function TableUILayoutEngine:DistributeWidths(desired, minWidths, maxWidths, total)
    local clamped = {}
    local minSum = 0
    for i, width in ipairs(desired) do
        local minW = minWidths[i] or 1
        local maxW = maxWidths[i] or total
        clamped[i] = math.max(minW, math.min(maxW, width))
        minSum = minSum + minW
    end
    if minSum >= total then
        return self:ScaleWidths(minWidths, total)
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

function TableUILayoutEngine:CalculateColumnWidths(rows, headerLabels, totalWidth, scale, profile)
    local headers = headerLabels or {}
    local noRecord = L and L["NoRecord"] or "--:--"
    local notAcquired = L and L["NotAcquired"] or "---:---"
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

    local mapNaturalWidth = math.max(1, math.floor(mapMax + MAP_COL_BASE_PADDING + MAP_COL_SAFETY_PADDING + 0.5))
    local mapCompactMinWidth = mapNaturalWidth
    if profile then
        profile.mapNaturalWidth = mapNaturalWidth
        profile.mapCompactMinWidth = mapCompactMinWidth
    end

    local phaseFullSamples, phaseShortSamples = self:BuildPhaseWidthSamples(rows, PHASE_DISPLAY_MAX_LENGTH, PHASE_DISPLAY_MAX_LENGTH)
    local phaseFullDesiredSamples = {headers[2] or "", notAcquired}
    local phaseShortDesiredSamples = {headers[2] or "", notAcquired}
    local phaseFullNeedSamples = {notAcquired}
    local phaseShortNeedSamples = {notAcquired}
    for _, text in ipairs(phaseFullSamples) do
        table.insert(phaseFullDesiredSamples, text)
        table.insert(phaseFullNeedSamples, text)
    end
    for _, text in ipairs(phaseShortSamples) do
        table.insert(phaseShortDesiredSamples, text)
        table.insert(phaseShortNeedSamples, text)
    end

    local phaseFullDesired = math.floor((self:GetMaxWidth(phaseFullDesiredSamples) + 20) * widthScale + 0.5)
    local phaseShortDesired = math.floor((self:GetMaxWidth(phaseShortDesiredSamples) + 20) * widthScale + 0.5)
    local lastDesired = math.floor((self:GetMaxWidth({headers[3] or "", noRecord, "00:00:00"}) + 18) * widthScale + 0.5)
    local nextDesired = math.floor((self:GetMaxWidth({headers[4] or "", noRecord, "00:00:00"}) + 18) * widthScale + 0.5)
    local phaseFullNeed = math.floor((self:GetMaxWidth(phaseFullNeedSamples) + 10) * widthScale + 0.5)
    local phaseShortNeed = math.floor((self:GetMaxWidth(phaseShortNeedSamples) + 10) * widthScale + 0.5)
    local lastNeed = math.floor((self:GetMaxWidth({noRecord, "00:00:00"}) + 10) * widthScale + 0.5)
    local nextNeed = math.floor((self:GetMaxWidth({noRecord, "00:00:00"}) + 10) * widthScale + 0.5)

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

        local desired = {
            mapNaturalWidth,
            usePhaseShort and phaseShortDesired or phaseFullDesired,
            lastDesired,
            nextDesired,
        }
        local minWidths = {
            mapCompactMinWidth,
            usePhaseShort and phaseShortNeed or phaseFullNeed,
            lastNeed,
            nextNeed,
        }
        local maxWidths = {
            mapNaturalWidth,
            math.max(desired[2], minWidths[2]) + math.max(2, math.floor(6 * widthScale + 0.5)),
            math.max(desired[3], minWidths[3]) + math.max(2, math.floor(6 * widthScale + 0.5)),
            math.max(desired[4], minWidths[4]) + math.max(2, math.floor(6 * widthScale + 0.5)),
        }

        local result = {0, 0, 0, 0}

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

        local otherMinTotal = 0
        for _, width in ipairs(otherMinWidths) do
            otherMinTotal = otherMinTotal + math.max(1, width or 0)
        end
        local mapWidth = math.floor((totalWidth or 1) - otherMinTotal + 0.5)
        mapWidth = self:Clamp(mapWidth, mapCompactMinWidth, mapNaturalWidth)
        result[1] = mapWidth

        local remainingWidth = math.max(1, math.floor((totalWidth or 1) - mapWidth + 0.5))
        local distributedOthers = self:DistributeWidths(otherDesired, otherMinWidths, otherMaxWidths, remainingWidth)
        for i, colIndex in ipairs(otherIndices) do
            result[colIndex] = distributedOthers[i] or 0
        end

        local minTableWidth = mapNaturalWidth + nextNeed
        profile.minTableWidth = math.max(1, math.floor(minTableWidth + 0.5))

        return result
    end

    local result = {0, 0, 0, 0}

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
        local activeIndices = {}
        local activeDesired = {}
        local activeMinWidths = {}
        local activeMaxWidths = {}

        table.insert(activeIndices, 1)
        table.insert(activeDesired, result[1])
        table.insert(activeMinWidths, math.max(1, mapCompactMinWidth))
        table.insert(activeMaxWidths, math.max(1, result[1]))

        if showPhase then
            table.insert(activeIndices, 2)
            table.insert(activeDesired, result[2])
            table.insert(activeMinWidths, math.max(1, phaseFullNeed))
            table.insert(activeMaxWidths, math.max(1, result[2]))
        end
        if showLast then
            table.insert(activeIndices, 3)
            table.insert(activeDesired, result[3])
            table.insert(activeMinWidths, math.max(1, lastNeed))
            table.insert(activeMaxWidths, math.max(1, result[3]))
        end
        if showNext then
            table.insert(activeIndices, 4)
            table.insert(activeDesired, result[4])
            table.insert(activeMinWidths, math.max(1, nextNeed))
            table.insert(activeMaxWidths, math.max(1, result[4]))
        end

        local distributed = self:DistributeWidths(activeDesired, activeMinWidths, activeMaxWidths, availableWidth)
        result = {0, 0, 0, 0}
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

function TableUILayoutEngine:GetRowsBlockHeight(rowCount, rowHeight, rowGap)
    if (rowCount or 0) <= 0 then
        return 0
    end
    return (rowCount * rowHeight) + math.max(0, rowCount - 1) * rowGap
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
    local fullRowsHeight = self:GetRowsBlockHeight(safeRowCount, safeRowHeight, safeRowGap)
    local fullHeaderSpace = (allowHeaderSpace == true) and (safeRowHeight + safeRowGap) or 0
    local headerReserveRatio = self:Clamp(headerWidthRatio or 0, 0, 1)
    local headerTransitionHeight = fullHeaderSpace * headerReserveRatio
    local headerAlphaByHeight = 1
    local visibleRowCount = safeRowCount
    local fullVisibleRowCount = safeRowCount
    local partialRowRatio = 0
    local partialRowAlpha = 1
    local effectiveRowHeight = safeRowHeight
    local effectiveRowGap = safeRowGap
    local renderedTableHeight = fullRowsHeight + headerTransitionHeight

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
                headerAlphaByHeight = self:Clamp(availableHeaderSpace / math.max(1, fullHeaderSpace), 0, 1)
                renderedTableHeight = fullRowsHeight + (fullHeaderSpace * headerAlphaByHeight)
            end
        else
            headerAlphaByHeight = 0
            renderedTableHeight = fullRowsHeight

            local rowUnit = effectiveRowHeight + effectiveRowGap
            local exactRowSlots = self:Clamp((contentHeight + effectiveRowGap) / math.max(1, rowUnit), 0, safeRowCount)
            fullVisibleRowCount = math.floor(exactRowSlots + 0.0001)
            partialRowRatio = exactRowSlots - fullVisibleRowCount
            if partialRowRatio < MIN_PARTIAL_ROW_RATIO then
                partialRowRatio = 0
            end

            if fullVisibleRowCount >= safeRowCount then
                fullVisibleRowCount = safeRowCount
                partialRowRatio = 0
                visibleRowCount = safeRowCount
            elseif fullVisibleRowCount <= 0 then
                fullVisibleRowCount = 0
                partialRowRatio = 0
                visibleRowCount = 0
            else
                visibleRowCount = fullVisibleRowCount + (partialRowRatio >= MIN_PARTIAL_ROW_RATIO and 1 or 0)
            end

            partialRowAlpha = partialRowRatio > 0 and self:SmoothStep(partialRowRatio) or 1
            if visibleRowCount <= 0 then
                renderedTableHeight = 0
            elseif partialRowRatio > 0 and visibleRowCount > fullVisibleRowCount then
                if fullVisibleRowCount <= 0 then
                    renderedTableHeight = effectiveRowHeight * partialRowRatio
                else
                    renderedTableHeight = self:GetRowsBlockHeight(fullVisibleRowCount, effectiveRowHeight, effectiveRowGap)
                        + (effectiveRowGap * partialRowRatio)
                        + (effectiveRowHeight * partialRowRatio)
                end
            else
                renderedTableHeight = self:GetRowsBlockHeight(visibleRowCount, effectiveRowHeight, effectiveRowGap)
            end
        end
    end

    local minTableHeight = safeRowCount > 0 and safeRowHeight or 0
    local maxTableHeight = fullRowsHeight + headerTransitionHeight
    local effectiveHeaderRatio = math.min(headerReserveRatio, headerAlphaByHeight)
    local shouldAutoCompactSort = safeRowCount > 1 and effectiveHeaderRatio <= 0.001 and contentHeight <= (fullRowsHeight + 0.5)

    return {
        contentHeight = contentHeight,
        fullRowsHeight = fullRowsHeight,
        headerAlphaByHeight = headerAlphaByHeight,
        visibleRowCount = visibleRowCount,
        fullVisibleRowCount = fullVisibleRowCount,
        partialRowRatio = partialRowRatio,
        partialRowAlpha = partialRowAlpha,
        rowHeight = effectiveRowHeight,
        rowGap = effectiveRowGap,
        renderedTableHeight = renderedTableHeight,
        minTableHeight = minTableHeight,
        maxTableHeight = maxTableHeight,
        shouldAutoCompactSort = shouldAutoCompactSort,
    }
end

return TableUILayoutEngine

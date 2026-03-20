-- TableUIRebuildEngine.lua - 表格重建流程引擎

local TableUIRebuildEngine = BuildEnv("TableUIRebuildEngine")

local function ResolveReleaseSnapHeight(chromeMetrics, verticalMetrics)
    if not chromeMetrics or not verticalMetrics then
        return nil
    end

    local verticalPadding = tonumber(chromeMetrics.verticalPadding) or 0
    local targetTableHeight = nil

    local headerRatio = tonumber(verticalMetrics.headerTransitionRatio)
    if headerRatio and headerRatio > 0 and headerRatio < 1 then
        if headerRatio >= 0.5 then
            targetTableHeight = verticalMetrics.snapExpandTableHeight
        else
            targetTableHeight = verticalMetrics.snapCollapseTableHeight
        end
    end

    if not targetTableHeight then
        local partialRatio = tonumber(verticalMetrics.partialRowRawRatio)
        if partialRatio and partialRatio > 0 and partialRatio < 1 then
            if partialRatio >= 0.5 then
                targetTableHeight = verticalMetrics.snapExpandTableHeight
            else
                targetTableHeight = verticalMetrics.snapCollapseTableHeight
            end
        end
    end

    if type(targetTableHeight) ~= "number" then
        return nil
    end

    return math.max(1, math.floor(targetTableHeight + verticalPadding + 0.5))
end

local function ResolveReleaseSnapWidth(frame, deps)
    if not frame or not deps then
        return nil
    end

    local baselineWidth = math.min(
        tonumber(frame.__ctkContentMaxWidth) or deps.baseFrameWidth or 600,
        deps.baseFrameWidth or 600
    )
    local transitionWidth = 60
    local compactBoundaryWidth = baselineWidth - transitionWidth
    local currentWidth = deps.GetFrameWidth(frame)

    if currentWidth >= baselineWidth - 0.5 then
        return nil
    end
    if currentWidth <= compactBoundaryWidth + 0.5 then
        return nil
    end

    local ratio = (baselineWidth - currentWidth) / math.max(1, transitionWidth)
    if ratio >= 0.5 then
        return math.max(deps.baseMinFrameWidth or 100, math.floor(compactBoundaryWidth + 0.5))
    end
    return math.floor(baselineWidth + 0.5)
end

function TableUIRebuildEngine:Rebuild(tableUI, frame, headerLabels, deps)
    if not frame or not deps or not deps.SortingSystem then
        return
    end

    local visibilityProfile = deps.GetVisibilityProfile(frame)
    local rebuildDepth = frame.__ctkResizeRebuildDepth or 0
    local tableParent = deps.GetTableParent(frame)

    local function BuildVisibleRows()
        local visibleRows = {}
        for _, rowInfo in ipairs(deps.SortingSystem:GetCurrentRows() or {}) do
            if visibilityProfile.showDeletedRows or not rowInfo.isHidden then
                table.insert(visibleRows, rowInfo)
            end
        end
        return visibleRows
    end

    local rows = BuildVisibleRows()
    local layoutScale = deps.GetScaleFactor(frame, #rows, visibilityProfile.showHeader == true)
    local chromeMetrics = deps.GetScaledChromeMetrics(1)
    local rowHeight, rowGap = deps.GetScaledRowMetrics(1)
    local headerWidthRatio = visibilityProfile.showHeader == true and deps.GetHeaderWidthRatio(frame) or 0

    frame.__ctkLayoutScale = layoutScale
    frame.__ctkChromeHorizontalPadding = chromeMetrics.horizontalPadding
    frame.__ctkChromeVerticalPadding = chromeMetrics.verticalPadding
    frame.__ctkBaselineFrameHeight = deps.GetDefaultFrameHeightForRowCount(#rows, visibilityProfile.showHeader == true)

    local verticalMetrics = deps.BuildVerticalMetrics(
        frame,
        #rows,
        rowHeight,
        rowGap,
        tableParent,
        visibilityProfile.showHeader == true,
        headerWidthRatio
    )

    local frameWidth = deps.GetFrameWidth(frame)
    local frameHeight = deps.GetFrameHeight(frame)
    local sizingStartHeight = tonumber(frame.__ctkSizingStartHeight) or frameHeight
    local autoHeightSyncValue = tonumber(frame.__ctkAutoHeightSyncValue) or nil
    local manualHeightReference = autoHeightSyncValue or sizingStartHeight
    local manualSizingHeightDelta = math.abs(frameHeight - manualHeightReference)
    local shouldAutoCompactSort = nil
    if frame.isSizing then
        shouldAutoCompactSort = deps.SortingSystem.IsCompactAutoSortEnabled
            and deps.SortingSystem:IsCompactAutoSortEnabled()
            or false
    else
        shouldAutoCompactSort = verticalMetrics.shouldAutoCompactSort == true
    end
    if deps.SortingSystem and deps.SortingSystem.SetCompactAutoSortEnabled then
        local sortChanged = deps.SortingSystem:SetCompactAutoSortEnabled(shouldAutoCompactSort)
        if sortChanged then
            rows = BuildVisibleRows()
            verticalMetrics = deps.BuildVerticalMetrics(
                frame,
                #rows,
                rowHeight,
                rowGap,
                tableParent,
                visibilityProfile.showHeader == true,
                headerWidthRatio
            )
        end
    end
    local releaseHeightSnap = ResolveReleaseSnapHeight(chromeMetrics, verticalMetrics)
    if releaseHeightSnap then
        frame.__ctkReleaseSnapHeight = releaseHeightSnap
    else
        frame.__ctkReleaseSnapHeight = nil
    end
    local releaseWidthSnap = ResolveReleaseSnapWidth(frame, deps)
    if releaseWidthSnap then
        frame.__ctkReleaseSnapWidth = releaseWidthSnap
    else
        frame.__ctkReleaseSnapWidth = nil
    end
    visibilityProfile.headerAlphaByHeight = verticalMetrics.headerAlphaByHeight

    local layout = deps.CalculateTableLayout(frame, visibilityProfile, layoutScale, chromeMetrics, verticalMetrics)
    local colWidths = deps.CalculateColumnWidths(rows, headerLabels, layout.tableWidth, layout.fontScale, visibilityProfile)
    local mapNaturalWidth = visibilityProfile.mapNaturalWidth or (colWidths[1] or 0)
    local mapCompressed = ((colWidths[1] or 0) + 0.5) < mapNaturalWidth
    if frame.__ctkMapColumnCompressed ~= mapCompressed then
        frame.__ctkMapColumnCompressed = mapCompressed
        if deps.MainFrame and deps.MainFrame.ApplyScaledChrome then
            deps.MainFrame:ApplyScaledChrome(frame)
        end
    end

    layout.scale = 1
    layout.fontScale = 1
    layout.showPhaseColumn = visibilityProfile.showPhaseColumn == true
    layout.showLastRefreshColumn = visibilityProfile.showLastRefreshColumn == true
    layout.phaseShortMode = visibilityProfile.phaseShortMode == true
    layout.activeTableWidth = deps.SumColumnWidths(colWidths)
    layout.startX = deps.innerTableSideMargin

    local userControlledWidth = frame.__ctkWidthControlledByUser == true
    local userControlledHeight = frame.__ctkHeightControlledByUser == true
    local horizontalPadding = chromeMetrics.horizontalPadding
    local defaultProfile = {
        showHeader = true,
        showPhaseColumn = true,
        showLastRefreshColumn = true,
        phaseShortMode = false,
        showDeletedRows = false,
        isFullInfo = true,
    }
    local defaultTableWidthHint = math.max(1, math.floor((deps.baseFrameWidth - deps.frameHorizontalPadding - (deps.innerTableSideMargin * 2)) + 0.5))
    local defaultColWidths = deps.CalculateColumnWidths(rows, headerLabels, defaultTableWidthHint, 1, defaultProfile)
    local defaultTableWidth = deps.SumColumnWidths(defaultColWidths)
    local desiredFrameWidth = math.floor(defaultTableWidth + horizontalPadding + (deps.innerTableSideMargin * 2) + 0.5)
    desiredFrameWidth = deps.Clamp(desiredFrameWidth, deps.baseMinFrameWidth, deps.baseFrameWidth)

    local requiredMinFrameWidth = deps.baseMinFrameWidth
    if visibilityProfile.compactByWidth == true then
        local minTableWidth = math.max(1, visibilityProfile.minTableWidth or 1)
        requiredMinFrameWidth = math.floor(minTableWidth + horizontalPadding + (deps.innerTableSideMargin * 2) + 0.5)
        requiredMinFrameWidth = deps.Clamp(requiredMinFrameWidth, deps.baseMinFrameWidth, deps.baseFrameWidth - 1)
    end

    local requiredMaxFrameWidth = deps.Clamp(desiredFrameWidth, requiredMinFrameWidth, deps.baseFrameWidth)
    local requiredMinFrameHeight = math.max(1, math.floor((verticalMetrics.minTableHeight + chromeMetrics.verticalPadding) + 0.5))
    local requiredMaxFrameHeight = math.max(requiredMinFrameHeight, math.floor((verticalMetrics.maxTableHeight + chromeMetrics.verticalPadding) + 0.5))
    local debugPayload = {
        frameWidth = math.floor(frameWidth + 0.5),
        frameHeight = math.floor(frameHeight + 0.5),
        minWidth = requiredMinFrameWidth,
        minHeight = requiredMinFrameHeight,
        maxWidth = requiredMaxFrameWidth,
        maxHeight = requiredMaxFrameHeight,
        desiredWidth = desiredFrameWidth,
        desiredHeight = requiredMaxFrameHeight,
        activeTableWidth = layout.activeTableWidth,
        defaultTableWidth = defaultTableWidth,
        userControlled = userControlledWidth,
        userControlledHeight = userControlledHeight,
        layoutScale = layoutScale,
        autoCompactSort = shouldAutoCompactSort,
        showHeader = visibilityProfile.showHeader == true,
        isSizing = frame.isSizing == true,
        visibleRows = verticalMetrics.visibleRowCount,
    }

    if frame.__ctkContentMinWidth ~= requiredMinFrameWidth
        or frame.__ctkContentMaxWidth ~= requiredMaxFrameWidth
        or frame.__ctkContentMinHeight ~= requiredMinFrameHeight
        or frame.__ctkContentMaxHeight ~= requiredMaxFrameHeight then
        frame.__ctkContentMinWidth = requiredMinFrameWidth
        frame.__ctkContentMaxWidth = requiredMaxFrameWidth
        frame.__ctkContentMinHeight = requiredMinFrameHeight
        frame.__ctkContentMaxHeight = requiredMaxFrameHeight
        if deps.MainFrame and deps.MainFrame.ApplyAdaptiveResizeBounds then
            deps.MainFrame:ApplyAdaptiveResizeBounds(frame)
        end
        if deps.MainFrame and deps.MainFrame.ApplyScaledChrome then
            deps.MainFrame:ApplyScaledChrome(frame)
        end
    end

    if userControlledWidth and not frame.isSizing and frameWidth + 0.5 >= requiredMaxFrameWidth then
        frame.__ctkWidthControlledByUser = false
        userControlledWidth = false
        if deps.MainFrame and deps.MainFrame.PersistFrameSize then
            deps.MainFrame:PersistFrameSize(frame)
        end
        deps.EmitResizeDebug(frame, "exit-user", debugPayload)
    end
    if userControlledHeight and not frame.isSizing and frameHeight + 0.5 >= requiredMaxFrameHeight then
        frame.__ctkHeightControlledByUser = false
        userControlledHeight = false
        if deps.MainFrame and deps.MainFrame.PersistFrameSize then
            deps.MainFrame:PersistFrameSize(frame)
        end
    end

    local targetWidth = frameWidth
    local targetHeight = frameHeight
    local resizeStage = "stable"
    local sizingAutoHeightSync = frame.isSizing
        and userControlledHeight ~= true
        and requiredMaxFrameHeight < (frameHeight - 0.5)

    if not userControlledWidth and not frame.isSizing and math.abs(targetWidth - desiredFrameWidth) > 0.5 then
        targetWidth = desiredFrameWidth
        resizeStage = "snap-default-width"
    end
    if not userControlledHeight and not frame.isSizing and math.abs(targetHeight - requiredMaxFrameHeight) > 0.5 then
        targetHeight = requiredMaxFrameHeight
        if resizeStage == "stable" then
            resizeStage = "snap-default-height"
        end
    end
    if sizingAutoHeightSync and math.abs(targetHeight - requiredMaxFrameHeight) > 0.5 then
        targetHeight = requiredMaxFrameHeight
        frame.__ctkAutoHeightSyncValue = targetHeight
        if resizeStage == "stable" then
            resizeStage = "sync-height-with-header-reserve"
        end
    elseif frame.isSizing and manualSizingHeightDelta > 2 then
        frame.__ctkAutoHeightSyncValue = nil
    end

    if targetWidth + 0.5 < requiredMinFrameWidth then
        targetWidth = requiredMinFrameWidth
        if resizeStage == "stable" then
            resizeStage = "clamp-min-width"
        end
    elseif targetWidth - 0.5 > requiredMaxFrameWidth then
        targetWidth = requiredMaxFrameWidth
        if resizeStage == "stable" then
            resizeStage = "clamp-max-width"
        end
    end

    if targetHeight + 0.5 < requiredMinFrameHeight then
        targetHeight = requiredMinFrameHeight
        if resizeStage == "stable" then
            resizeStage = "clamp-min-height"
        end
    elseif targetHeight - 0.5 > requiredMaxFrameHeight then
        targetHeight = requiredMaxFrameHeight
        if resizeStage == "stable" then
            resizeStage = "clamp-max-height"
        end
    end

    local resized = math.abs(targetWidth - frameWidth) > 0.5 or math.abs(targetHeight - frameHeight) > 0.5
    if resized then
        deps.EmitResizeDebug(frame, resizeStage, debugPayload)
        frame:SetSize(targetWidth, targetHeight)
        if deps.MainFrame and deps.MainFrame.PersistFrameSize then
            deps.MainFrame:PersistFrameSize(frame)
        end
        if rebuildDepth < 3 then
            frame.__ctkResizeRebuildDepth = rebuildDepth + 1
            tableUI:RebuildUI(frame, headerLabels)
            frame.__ctkResizeRebuildDepth = rebuildDepth
            return
        end
    end

    deps.EmitResizeDebug(frame, "stable", debugPayload)

    local rowsToRender = {}
    local fullVisibleRowCount = math.max(0, math.min(verticalMetrics.fullVisibleRowCount or 0, #rows))
    local partialRowRatio = deps.Clamp(verticalMetrics.partialRowRatio or 0, 0, 1)
    local currentSlotY = 0

    for idx = 1, fullVisibleRowCount do
        if idx > 1 then
            currentSlotY = currentSlotY + layout.rowGap
        end
        rowsToRender[#rowsToRender + 1] = {
            rowInfo = rows[idx],
            slotY = currentSlotY,
            height = layout.rowHeight,
            alpha = 1,
        }
        currentSlotY = currentSlotY + layout.rowHeight
    end

    if partialRowRatio > 0 and (fullVisibleRowCount + 1) <= #rows then
        if fullVisibleRowCount > 0 then
            currentSlotY = currentSlotY + (layout.rowGap * partialRowRatio)
        end
        rowsToRender[#rowsToRender + 1] = {
            rowInfo = rows[fullVisibleRowCount + 1],
            slotY = currentSlotY,
            height = math.max(1, layout.rowHeight * partialRowRatio),
            alpha = verticalMetrics.partialRowAlpha or partialRowRatio,
        }
    end

    deps.HideVisibleFrames()
    deps.ClearCountdownRegistration()

    if layout.showHeader then
        tableUI:CreateHeaderRow(layout.parent, headerLabels, colWidths, layout)
    end

    for displayIndex, rowState in ipairs(rowsToRender) do
        tableUI:CreateDataRow(layout.parent, rowState, displayIndex, colWidths, layout)
    end

    if deps.SortingSystem then
        deps.SortingSystem:UpdateHeaderVisual()
    end
end

return TableUIRebuildEngine

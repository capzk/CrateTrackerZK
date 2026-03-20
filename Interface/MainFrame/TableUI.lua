-- TableUI.lua - 表格界面

local TableUI = BuildEnv("TableUI")
local TableUILayoutEngine = BuildEnv("TableUILayoutEngine")
local TableUIRebuildEngine = BuildEnv("TableUIRebuildEngine")
local TableUIRenderer = BuildEnv("TableUIRenderer")
local TableUITextMetrics = BuildEnv("TableUITextMetrics")
local UIConfig = BuildEnv("ThemeConfig")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local SortingSystem = BuildEnv("SortingSystem")
local CountdownSystem = BuildEnv("CountdownSystem")
local MainFrame = BuildEnv("MainFrame")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local L = CrateTrackerZK.L

local BASE_FRAME_WIDTH = 600
local FIXED_ROW_HEIGHT = 29
local BASE_MIN_FRAME_WIDTH = 100
local INNER_TABLE_SIDE_MARGIN = 4
local MAP_COL_COMPACT_MIN_CHARS = 1
local RESIZE_DEBUG_ENABLED = false

local function GetConfig()
    return UIConfig
end

local function EmitResizeDebug(frame, stage, payload)
    if not RESIZE_DEBUG_ENABLED then
        return
    end
    if not frame then
        return
    end
    local signature = table.concat({
        tostring(stage or ""),
        tostring(payload and payload.frameWidth or ""),
        tostring(payload and payload.minWidth or ""),
        tostring(payload and payload.maxWidth or ""),
        tostring(payload and payload.desiredWidth or ""),
        tostring(payload and payload.activeTableWidth or ""),
        tostring(payload and payload.defaultTableWidth or ""),
        tostring(payload and payload.userControlled or ""),
        tostring(payload and payload.showHeader or ""),
        tostring(payload and payload.isSizing or ""),
    }, "|")
    if frame.__ctkLastResizeDebugSignature == signature then
        return
    end
    frame.__ctkLastResizeDebugSignature = signature

    local msg = string.format(
        "CTK Resize[%s] cur=%s min=%s max=%s desired=%s active=%s default=%s user=%s header=%s sizing=%s",
        tostring(stage or "state"),
        tostring(payload and payload.frameWidth or "nil"),
        tostring(payload and payload.minWidth or "nil"),
        tostring(payload and payload.maxWidth or "nil"),
        tostring(payload and payload.desiredWidth or "nil"),
        tostring(payload and payload.activeTableWidth or "nil"),
        tostring(payload and payload.defaultTableWidth or "nil"),
        tostring(payload and payload.userControlled or "nil"),
        tostring(payload and payload.showHeader or "nil"),
        tostring(payload and payload.isSizing or "nil")
    )

    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(msg)
    elseif print then
        print(msg)
    end
end

local function IsAddonEnabled()
    if not CRATETRACKERZK_UI_DB or CRATETRACKERZK_UI_DB.addonEnabled == nil then
        return true
    end
    return CRATETRACKERZK_UI_DB.addonEnabled == true
end

local function GetTableParent(frame)
    if frame and frame.tableContainer and frame.tableContainer.GetObjectType and frame.tableContainer:GetObjectType() == "Frame" then
        return frame.tableContainer
    end
    return frame
end

local function GetTextWidth(text)
    if TableUITextMetrics and TableUITextMetrics.GetTextWidth then
        return TableUITextMetrics:GetTextWidth(text)
    end
    return 0
end

local function GetReferenceTextWidth(referenceFontString, text)
    if TableUITextMetrics and TableUITextMetrics.GetReferenceTextWidth then
        return TableUITextMetrics:GetReferenceTextWidth(referenceFontString, text)
    end
    return 0
end

local function GetScaledTextWidth(text, scale)
    if TableUITextMetrics and TableUITextMetrics.GetScaledTextWidth then
        return TableUITextMetrics:GetScaledTextWidth(text, scale)
    end
    return 0
end

local function Clamp(value, minValue, maxValue)
    if TableUILayoutEngine and TableUILayoutEngine.Clamp then
        return TableUILayoutEngine:Clamp(value, minValue, maxValue)
    end
    return value
end

local function SmoothStep(t)
    if TableUILayoutEngine and TableUILayoutEngine.SmoothStep then
        return TableUILayoutEngine:SmoothStep(t)
    end
    return Clamp(t or 0, 0, 1)
end

local function ComputeRowsBlockHeight(rowCount, rowHeight, rowGap)
    if TableUILayoutEngine and TableUILayoutEngine.ComputeRowsBlockHeight then
        return TableUILayoutEngine:ComputeRowsBlockHeight(rowCount, rowHeight, rowGap)
    end
    return 0
end

local function GetBaselineFrameWidth(frame)
    if TableUILayoutEngine and TableUILayoutEngine.GetBaselineFrameWidth then
        return TableUILayoutEngine:GetBaselineFrameWidth(frame)
    end
    return BASE_FRAME_WIDTH
end

local function GetScaledChromeMetrics(scale)
    if TableUILayoutEngine and TableUILayoutEngine.GetScaledChromeMetrics then
        return TableUILayoutEngine:GetScaledChromeMetrics(scale)
    end
    return { scale = 1, edgeGap = 8, titleHeight = 22, horizontalPadding = 24, verticalPadding = 37 }
end

local function GetScaledRowMetrics(scale)
    if TableUILayoutEngine and TableUILayoutEngine.GetScaledRowMetrics then
        return TableUILayoutEngine:GetScaledRowMetrics(scale)
    end
    return FIXED_ROW_HEIGHT, 2
end

local function GetDefaultFrameHeightForRowCount(rowCount, allowHeaderSpace)
    if TableUILayoutEngine and TableUILayoutEngine.GetDefaultFrameHeightForRowCount then
        return TableUILayoutEngine:GetDefaultFrameHeightForRowCount(rowCount, allowHeaderSpace)
    end
    return 0
end

local function GetScaleFactor(frame, rowCount, allowHeaderSpace)
    if TableUILayoutEngine and TableUILayoutEngine.GetScaleFactor then
        return TableUILayoutEngine:GetScaleFactor(frame, rowCount, allowHeaderSpace)
    end
    return 1
end

local function GetFrameWidth(frame)
    if not frame or not frame.GetWidth then
        return BASE_FRAME_WIDTH
    end
    return frame:GetWidth() or BASE_FRAME_WIDTH
end

local function GetFrameHeight(frame)
    if not frame or not frame.GetHeight then
        return 0
    end
    return frame:GetHeight() or 0
end

local function GetVisibilityProfile(frame)
    if TableUILayoutEngine and TableUILayoutEngine.GetVisibilityProfile then
        return TableUILayoutEngine:GetVisibilityProfile(frame)
    end
    return { showHeader = true, showPhaseColumn = true, showLastRefreshColumn = true, phaseShortMode = false, showDeletedRows = false, isFullInfo = true, compactByWidth = false }
end

local function GetHeaderWidthRatio(frame)
    if TableUILayoutEngine and TableUILayoutEngine.GetHeaderWidthRatio then
        return TableUILayoutEngine:GetHeaderWidthRatio(frame)
    end
    return 1
end

local function GetHeaderCollapseState(frame, profile, layoutScale, rowHeight, rowGap)
    if TableUILayoutEngine and TableUILayoutEngine.GetHeaderCollapseState then
        return TableUILayoutEngine:GetHeaderCollapseState(frame, profile, layoutScale, rowHeight, rowGap)
    end
    return { height = 0, gap = 0, alpha = 0, shown = false }
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

local function ApplyTruncateNoEllipsis(fontString, text, maxWidth, minChars)
    if TableUITextMetrics and TableUITextMetrics.ApplyTruncateNoEllipsis then
        return TableUITextMetrics:ApplyTruncateNoEllipsis(fontString, text, maxWidth, minChars)
    end
end

local function ScaleWidths(baseWidths, targetTotal)
    if TableUILayoutEngine and TableUILayoutEngine.ScaleWidths then
        return TableUILayoutEngine:ScaleWidths(baseWidths, targetTotal)
    end
    return baseWidths
end

local function GetMaxWidth(texts)
    if TableUILayoutEngine and TableUILayoutEngine.GetMaxWidth then
        return TableUILayoutEngine:GetMaxWidth(texts)
    end
    return 0
end

local function FormatPhaseDisplayText(phaseValue)
    if TableUILayoutEngine and TableUILayoutEngine.FormatPhaseDisplayText then
        return TableUILayoutEngine:FormatPhaseDisplayText(phaseValue)
    end
    return nil
end

local function BuildPhaseWidthSamples(rows, fullMaxLength, shortMaxLength)
    if TableUILayoutEngine and TableUILayoutEngine.BuildPhaseWidthSamples then
        return TableUILayoutEngine:BuildPhaseWidthSamples(rows, fullMaxLength, shortMaxLength)
    end
    return {}, {}
end

local function DistributeWidths(desired, minWidths, maxWidths, total)
    if TableUILayoutEngine and TableUILayoutEngine.DistributeWidths then
        return TableUILayoutEngine:DistributeWidths(desired, minWidths, maxWidths, total)
    end
    return desired
end

local function SumColumnWidths(widths)
    if TableUILayoutEngine and TableUILayoutEngine.SumColumnWidths then
        return TableUILayoutEngine:SumColumnWidths(widths)
    end
    return 1
end

local function CalculateColumnWidths(rows, headerLabels, totalWidth, scale, profile)
    if TableUILayoutEngine and TableUILayoutEngine.CalculateColumnWidths then
        return TableUILayoutEngine:CalculateColumnWidths(rows, headerLabels, totalWidth, scale, profile)
    end
    return {0, 0, 0, 0}
end

local function CalculateTableLayout(frame, profile, layoutScale, chromeMetrics, verticalMetrics)
    if TableUILayoutEngine and TableUILayoutEngine.CalculateTableLayout then
        return TableUILayoutEngine:CalculateTableLayout(frame, profile, layoutScale, chromeMetrics, verticalMetrics, GetTableParent)
    end
    return { parent = GetTableParent(frame), scale = 1, fontScale = 1, rowHeight = FIXED_ROW_HEIGHT, rowGap = 2, headerHeight = 0, headerGap = 0, headerAlpha = 0, tableWidth = 1, startX = INNER_TABLE_SIDE_MARGIN, startY = 0, showPhaseColumn = true, showLastRefreshColumn = true, phaseShortMode = false, showHeader = false }
end

local function GetRowsBlockHeight(rowCount, rowHeight, rowGap)
    if TableUILayoutEngine and TableUILayoutEngine.GetRowsBlockHeight then
        return TableUILayoutEngine:GetRowsBlockHeight(rowCount, rowHeight, rowGap)
    end
    return 0
end

local function GetContentHeight(frame, tableParent)
    if TableUILayoutEngine and TableUILayoutEngine.GetContentHeight then
        return TableUILayoutEngine:GetContentHeight(frame, tableParent)
    end
    return 0
end

local function BuildVerticalMetrics(frame, rowCount, rowHeight, rowGap, tableParent, allowHeaderSpace, headerWidthRatio)
    if TableUILayoutEngine and TableUILayoutEngine.BuildVerticalMetrics then
        return TableUILayoutEngine:BuildVerticalMetrics(frame, rowCount, rowHeight, rowGap, tableParent, allowHeaderSpace, headerWidthRatio)
    end
    return { contentHeight = 0, fullRowsHeight = 0, headerAlphaByHeight = 0, visibleRowCount = 0, fullVisibleRowCount = 0, partialRowRatio = 0, partialRowAlpha = 1, rowHeight = FIXED_ROW_HEIGHT, rowGap = 2, renderedTableHeight = 0, minTableHeight = 0, maxTableHeight = 0, shouldAutoCompactSort = false }
end

local function HideVisibleFrames()
    if TableUIRenderer and TableUIRenderer.HideVisibleFrames then
        return TableUIRenderer:HideVisibleFrames()
    end
end

local function AcquireRowFrame(parent, index)
    if TableUIRenderer and TableUIRenderer.AcquireRowFrame then
        return TableUIRenderer:AcquireRowFrame(parent, index)
    end
    return nil
end

function TableUI:RebuildUI(frame, headerLabels)
    if TableUIRebuildEngine and TableUIRebuildEngine.Rebuild then
        return TableUIRebuildEngine:Rebuild(self, frame, headerLabels, {
            SortingSystem = SortingSystem,
            MainFrame = MainFrame,
            baseFrameWidth = BASE_FRAME_WIDTH,
            baseMinFrameWidth = BASE_MIN_FRAME_WIDTH,
            innerTableSideMargin = INNER_TABLE_SIDE_MARGIN,
            frameHorizontalPadding = 24,
            GetTableParent = GetTableParent,
            GetVisibilityProfile = GetVisibilityProfile,
            GetScaleFactor = GetScaleFactor,
            GetScaledChromeMetrics = GetScaledChromeMetrics,
            GetScaledRowMetrics = GetScaledRowMetrics,
            GetHeaderWidthRatio = GetHeaderWidthRatio,
            GetDefaultFrameHeightForRowCount = GetDefaultFrameHeightForRowCount,
            BuildVerticalMetrics = BuildVerticalMetrics,
            CalculateTableLayout = CalculateTableLayout,
            CalculateColumnWidths = CalculateColumnWidths,
            SumColumnWidths = SumColumnWidths,
            GetFrameWidth = GetFrameWidth,
            GetFrameHeight = GetFrameHeight,
            Clamp = Clamp,
            EmitResizeDebug = EmitResizeDebug,
            HideVisibleFrames = HideVisibleFrames,
            ClearCountdownRegistration = function()
                if TableUIRenderer and TableUIRenderer.ClearCountdownRegistration then
                    TableUIRenderer:ClearCountdownRegistration()
                end
            end,
        })
    end
end

function TableUI:CreateHeaderRow(parent, headerLabels, colWidths, layout)
    if TableUIRenderer and TableUIRenderer.CreateHeaderRow then
        return TableUIRenderer:CreateHeaderRow(parent, headerLabels, colWidths, layout)
    end
end

function TableUI:CreateSortHeaderButton(parent, label, colWidth, layout, currentX, existingButton)
    if TableUIRenderer and TableUIRenderer.CreateSortHeaderButton then
        return TableUIRenderer:CreateSortHeaderButton(parent, label, colWidth, layout, currentX, existingButton)
    end
    return existingButton
end

function TableUI:CreateHeaderText(parent, label, colIndex, colWidth, layout, currentX, headerBg, existingText)
    if TableUIRenderer and TableUIRenderer.CreateHeaderText then
        return TableUIRenderer:CreateHeaderText(parent, label, colIndex, colWidth, layout, currentX, headerBg, existingText)
    end
    return existingText
end

function TableUI:CreateDataRow(parent, rowState, displayIndex, colWidths, layout)
    if TableUIRenderer and TableUIRenderer.CreateDataRow then
        return TableUIRenderer:CreateDataRow(parent, rowState, displayIndex, colWidths, layout)
    end
end

function TableUI:CreateRowCells(rowFrame, rowInfo, colWidths, rowBg, scale, layout)
    if TableUIRenderer and TableUIRenderer.CreateRowCells then
        return TableUIRenderer:CreateRowCells(rowFrame, rowInfo, colWidths, rowBg, scale, layout)
    end
end

return TableUI

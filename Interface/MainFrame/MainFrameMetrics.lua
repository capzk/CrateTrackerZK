-- MainFrameMetrics.lua - 主框架尺寸与布局度量

local MainFrameMetrics = BuildEnv("MainFrameMetrics")
local Data = BuildEnv("Data")

MainFrameMetrics.FRAME_CFG = {
    width = 600,
    height = 335,
    minScale = 0.6,
    maxScale = 1.0,
    minWidth = 100,
    minHeight = 1,
    maxWidth = 600,
    maxHeight = 419,
}

MainFrameMetrics.WIDTH_PROFILE_VERSION = 4
MainFrameMetrics.UI_STATE_MIGRATION_VERSION = 1
MainFrameMetrics.RESIZE_LAYOUT_NOTIFY_INTERVAL = 0.016
MainFrameMetrics.RESIZE_LAYOUT_PIXEL_STEP = 1

local COMPACT_FIXED_ROW_HEIGHT = 29
local COMPACT_BASE_ROW_GAP = 4
local HEADER_COLLAPSE_TRANSITION_WIDTH = 60
local FIXED_TITLE_HEIGHT = 22
local FIXED_CONTENT_TOP_GAP = 7
local FIXED_CONTENT_BOTTOM_GAP = 8

function MainFrameMetrics:Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function MainFrameMetrics:GetChromeMetrics(scale)
    local resolvedScale = scale or 1
    return {
        scale = resolvedScale,
        titleHeight = FIXED_TITLE_HEIGHT,
        edgeGap = FIXED_CONTENT_BOTTOM_GAP,
        tableInset = FIXED_CONTENT_BOTTOM_GAP,
        tableTopInset = FIXED_TITLE_HEIGHT + FIXED_CONTENT_TOP_GAP,
        buttonSize = 16,
        buttonInsetX = 12,
        buttonInsetY = 3,
        dotSize = 2,
        dotOffset = 3,
        closeLineWidth = 8,
        closeLineHeight = 1,
        handleSize = 16,
        handleInset = 2,
        sideWidth = 20,
        bottomHeight = 30,
        buttonGap = 7,
    }
end

function MainFrameMetrics:GetConfiguredMapCount()
    if Data and Data.GetAllMaps then
        local maps = Data:GetAllMaps()
        if maps and #maps > 0 then
            return #maps
        end
    end
    if Data and Data.MAP_CONFIG and Data.MAP_CONFIG.current_maps then
        local count = #Data.MAP_CONFIG.current_maps
        if count > 0 then
            return count
        end
    end
    return 7
end

function MainFrameMetrics:GetCompactVisibleMapCount()
    if Data and Data.GetAllMaps then
        local maps = Data:GetAllMaps()
        if maps and #maps > 0 then
            local hiddenMaps = (Data.GetHiddenMaps and Data:GetHiddenMaps()) or {}
            local visibleCount = 0
            for _, mapData in ipairs(maps) do
                if mapData and mapData.mapID and not hiddenMaps[mapData.mapID] then
                    visibleCount = visibleCount + 1
                end
            end
            if visibleCount > 0 then
                return visibleCount
            end
        end
    end
    return math.max(1, self:GetConfiguredMapCount())
end

function MainFrameMetrics:GetAdaptiveBaseHeight()
    local baseMapCount = 7
    local perMapHeight = 39
    local mapCount = self:GetConfiguredMapCount()
    return self.FRAME_CFG.height + (mapCount - baseMapCount) * perMapHeight
end

function MainFrameMetrics:GetAdaptiveHeightBounds()
    local baseHeight = self:GetAdaptiveBaseHeight()
    local minHeight = self.FRAME_CFG.minHeight
    local maxHeight = math.floor(baseHeight * self.FRAME_CFG.maxScale + 0.5)
    if minHeight > maxHeight then
        minHeight, maxHeight = maxHeight, minHeight
    end
    return minHeight, maxHeight
end

function MainFrameMetrics:GetAdaptiveDefaultHeight()
    local baseHeight = self:GetAdaptiveBaseHeight()
    local minHeight, maxHeight = self:GetAdaptiveHeightBounds()
    return self:Clamp(math.floor(baseHeight + 0.5), minHeight, maxHeight)
end

function MainFrameMetrics:GetHeaderTransitionExtraHeight(width)
    local safeWidth = width or self.FRAME_CFG.width
    if safeWidth >= self.FRAME_CFG.width then
        return COMPACT_FIXED_ROW_HEIGHT + COMPACT_BASE_ROW_GAP
    end
    if HEADER_COLLAPSE_TRANSITION_WIDTH <= 0 then
        return 0
    end
    local t = self:Clamp((self.FRAME_CFG.width - safeWidth) / HEADER_COLLAPSE_TRANSITION_WIDTH, 0, 1)
    local eased = t * t * (3 - 2 * t)
    local ratio = 1 - eased
    local headerHeight = COMPACT_FIXED_ROW_HEIGHT * ratio
    local headerGap = COMPACT_BASE_ROW_GAP * ratio
    if headerHeight < 0.5 then
        headerHeight = 0
    end
    if headerGap < 0.5 then
        headerGap = 0
    end
    return headerHeight + headerGap
end

function MainFrameMetrics:GetCompactFixedHeight(width)
    local rowCount = self:GetCompactVisibleMapCount()
    local chromeMetrics = self:GetChromeMetrics(1)
    local rowsHeight = rowCount * COMPACT_FIXED_ROW_HEIGHT + math.max(0, rowCount - 1) * COMPACT_BASE_ROW_GAP
    local headerExtra = self:GetHeaderTransitionExtraHeight(width)
    return rowsHeight + headerExtra + chromeMetrics.tableTopInset + chromeMetrics.tableInset
end

function MainFrameMetrics:GetAdaptiveHeightForWidth(width)
    local baseHeight = self:GetAdaptiveBaseHeight()
    local minHeight, maxHeight = self:GetAdaptiveHeightBounds()
    local safeWidth = width or self.FRAME_CFG.width
    local scale = self:Clamp(safeWidth / self.FRAME_CFG.width, self.FRAME_CFG.minScale, self.FRAME_CFG.maxScale)

    local targetHeight
    if safeWidth < self.FRAME_CFG.width then
        targetHeight = math.floor(self:GetCompactFixedHeight(safeWidth) + 0.5)
    else
        targetHeight = math.floor(baseHeight * scale + 0.5)
    end

    return self:Clamp(targetHeight, minHeight, maxHeight), scale
end

function MainFrameMetrics:ApplyFontScale(fontString, scale, minSize, maxSize)
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
    local scaled = math.floor(base.size * (scale or 1) + 0.5)
    scaled = self:Clamp(scaled, minSize or 8, maxSize or 18)
    fontString:SetFont(base.font, scaled, base.flags)
end

function MainFrameMetrics:GetFrameScale(frame)
    return 1
end

function MainFrameMetrics:GetEffectiveMinWidth(frame)
    local contentMin = frame and tonumber(frame.__ctkContentMinWidth) or nil
    if contentMin then
        return self:Clamp(math.floor(contentMin + 0.5), self.FRAME_CFG.minWidth, self.FRAME_CFG.maxWidth)
    end
    return self.FRAME_CFG.minWidth
end

function MainFrameMetrics:GetEffectiveMaxWidth(frame, minWidth)
    local resolvedMinWidth = minWidth or self:GetEffectiveMinWidth(frame)
    local contentMax = frame and tonumber(frame.__ctkContentMaxWidth) or nil
    if contentMax then
        local clamped = self:Clamp(math.floor(contentMax + 0.5), self.FRAME_CFG.minWidth, self.FRAME_CFG.maxWidth)
        return math.max(resolvedMinWidth, clamped)
    end
    return self.FRAME_CFG.maxWidth
end

function MainFrameMetrics:GetEffectiveMinHeight(frame)
    local _, adaptiveMax = self:GetAdaptiveHeightBounds()
    local contentMin = frame and tonumber(frame.__ctkContentMinHeight) or nil
    if contentMin then
        return self:Clamp(math.floor(contentMin + 0.5), self.FRAME_CFG.minHeight, adaptiveMax)
    end
    return self.FRAME_CFG.minHeight
end

function MainFrameMetrics:GetEffectiveMaxHeight(frame, minHeight)
    local _, adaptiveMax = self:GetAdaptiveHeightBounds()
    local resolvedMinHeight = minHeight or self:GetEffectiveMinHeight(frame)
    local contentMax = frame and tonumber(frame.__ctkContentMaxHeight) or nil
    if contentMax then
        local clamped = self:Clamp(math.floor(contentMax + 0.5), self.FRAME_CFG.minHeight, adaptiveMax)
        return math.max(resolvedMinHeight, clamped)
    end
    return math.max(resolvedMinHeight, adaptiveMax)
end

function MainFrameMetrics:IsAtMinimumWidth(frame)
    if not frame or not frame.GetWidth then
        return false
    end
    local width = frame:GetWidth() or self.FRAME_CFG.width
    local minWidth = self:GetEffectiveMinWidth(frame)
    return width <= (minWidth + 1)
end

return MainFrameMetrics

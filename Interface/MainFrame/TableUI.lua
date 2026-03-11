-- TableUI.lua - 表格界面

local TableUI = BuildEnv("TableUI")
local UIConfig = BuildEnv("ThemeConfig")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local SortingSystem = BuildEnv("SortingSystem")
local CountdownSystem = BuildEnv("CountdownSystem")
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
local BASE_MIN_FRAME_WIDTH = 100
local FRAME_HORIZONTAL_PADDING = 24
local FRAME_VERTICAL_PADDING = 46
local COMPACT_FONT_TRANSITION_WIDTH = 80
local HEADER_COLLAPSE_TRANSITION_WIDTH = 60
local MAP_COL_COMPACT_MIN_CHARS = 1
local MAP_COL_BASE_PADDING = 24
local MAP_COL_SAFETY_PADDING = 6
local UTF8_CHAR_PATTERN = "[%z\1-\127\194-\244][\128-\191]*"
local TEXT_WIDTH_CACHE_LIMIT = 1024
local TRUNCATE_CACHE_LIMIT = 2048
local textWidthCache = {}
local textWidthCacheSize = 0
local scaledTextWidthCache = {}
local scaledTextWidthCacheSize = 0
local referenceTextWidthCache = {}
local referenceTextWidthCacheSize = 0
local truncateCache = {}
local truncateCacheSize = 0
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

local function GetMeasureText()
    if not measureText then
        measureText = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        measureText:SetText("")
    end
    return measureText
end

local function MakeFontSignatureFromValues(font, size, flags)
    return table.concat({
        tostring(font or ""),
        tostring(size or 0),
        tostring(flags or ""),
    }, "|")
end

local function MakeFontSignature(fontString)
    if not fontString or not fontString.GetFont then
        return "default"
    end
    local font, size, flags = fontString:GetFont()
    return MakeFontSignatureFromValues(font, size, flags)
end

local function PutCache(cacheName, key, value)
    if cacheName == "textWidth" then
        if textWidthCache[key] == nil then
            if textWidthCacheSize >= TEXT_WIDTH_CACHE_LIMIT then
                textWidthCache = {}
                textWidthCacheSize = 0
            end
            textWidthCacheSize = textWidthCacheSize + 1
        end
        textWidthCache[key] = value
        return
    end
    if cacheName == "scaledTextWidth" then
        if scaledTextWidthCache[key] == nil then
            if scaledTextWidthCacheSize >= TEXT_WIDTH_CACHE_LIMIT then
                scaledTextWidthCache = {}
                scaledTextWidthCacheSize = 0
            end
            scaledTextWidthCacheSize = scaledTextWidthCacheSize + 1
        end
        scaledTextWidthCache[key] = value
        return
    end
    if cacheName == "referenceTextWidth" then
        if referenceTextWidthCache[key] == nil then
            if referenceTextWidthCacheSize >= TEXT_WIDTH_CACHE_LIMIT then
                referenceTextWidthCache = {}
                referenceTextWidthCacheSize = 0
            end
            referenceTextWidthCacheSize = referenceTextWidthCacheSize + 1
        end
        referenceTextWidthCache[key] = value
        return
    end
    if cacheName == "truncate" then
        if truncateCache[key] == nil then
            if truncateCacheSize >= TRUNCATE_CACHE_LIMIT then
                truncateCache = {}
                truncateCacheSize = 0
            end
            truncateCacheSize = truncateCacheSize + 1
        end
        truncateCache[key] = value
    end
end

local function GetTextWidth(text)
    local normalizedText = text or ""
    local fontString = GetMeasureText()
    local font, size, flags = GameFontNormal:GetFont()
    local fontSignature = MakeFontSignatureFromValues(font, size, flags)
    local cacheKey = fontSignature .. "|" .. normalizedText
    local cached = textWidthCache[cacheKey]
    if cached ~= nil then
        return cached
    end
    if font then
        fontString:SetFont(font, size or 12, flags)
    end
    fontString:SetText(normalizedText)
    local width = fontString:GetStringWidth() or 0
    PutCache("textWidth", cacheKey, width)
    return width
end

local function GetReferenceTextWidth(referenceFontString, text)
    local normalizedText = text or ""
    local measure = GetMeasureText()
    local fontSignature = "default"
    if referenceFontString and referenceFontString.GetFont then
        local font, size, flags = referenceFontString:GetFont()
        fontSignature = MakeFontSignatureFromValues(font, size, flags)
        if font then
            measure:SetFont(font, size or 12, flags)
        end
    end
    local cacheKey = fontSignature .. "|" .. normalizedText
    local cached = referenceTextWidthCache[cacheKey]
    if cached ~= nil then
        return cached
    end
    measure:SetText(normalizedText)
    local width = measure:GetStringWidth() or 0
    PutCache("referenceTextWidth", cacheKey, width)
    return width
end

local function GetScaledTextWidth(text, scale)
    local normalizedText = text or ""
    local normalizedScale = math.floor(((scale or 1) * 100) + 0.5) / 100
    local measure = GetMeasureText()
    local font, baseSize, flags = GameFontNormal:GetFont()
    local fontSignature = MakeFontSignatureFromValues(font, baseSize, flags)
    local cacheKey = table.concat({
        fontSignature,
        tostring(normalizedScale),
        normalizedText,
    }, "|")
    local cached = scaledTextWidthCache[cacheKey]
    if cached ~= nil then
        return cached
    end
    if font then
        local scaledSize = math.floor((baseSize or 12) * normalizedScale + 0.5)
        if scaledSize < 8 then
            scaledSize = 8
        elseif scaledSize > 18 then
            scaledSize = 18
        end
        measure:SetFont(font, scaledSize, flags)
    end
    measure:SetText(normalizedText)
    local width = measure:GetStringWidth() or 0
    PutCache("scaledTextWidth", cacheKey, width)
    return width
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

local function GetBaselineFrameWidth(frame)
    local contentMax = frame and tonumber(frame.__ctkContentMaxWidth) or nil
    if contentMax then
        return Clamp(math.floor(contentMax + 0.5), BASE_MIN_FRAME_WIDTH, BASE_FRAME_WIDTH)
    end
    return BASE_FRAME_WIDTH
end

local function GetScaleFactor(frame)
    if not frame then
        return 1
    end
    local baselineWidth = GetBaselineFrameWidth(frame)
    local width = frame:GetWidth() or BASE_FRAME_WIDTH
    if not frame.isSizing and frame.__ctkWidthControlledByUser ~= true then
        width = math.max(width, baselineWidth)
    end
    local widthScale = width / math.max(1, baselineWidth)
    return Clamp(widthScale, MIN_FRAME_SCALE, MAX_FRAME_SCALE)
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
    local width = GetFrameWidth(frame)
    local baselineWidth = GetBaselineFrameWidth(frame)
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

local function GetHeaderCollapseState(frame, profile)
    local width = GetFrameWidth(frame)
    local baselineWidth = GetBaselineFrameWidth(frame)
    local t = Clamp((baselineWidth - width) / HEADER_COLLAPSE_TRANSITION_WIDTH, 0, 1)
    local eased = t * t * (3 - 2 * t)
    local widthRatio = 1 - eased
    local heightRatio = Clamp((profile and profile.headerAlphaByHeight) or 1, 0, 1)
    local ratio = math.min(widthRatio, heightRatio)
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
    local baselineWidth = GetBaselineFrameWidth(frame)
    local t = Clamp((baselineWidth - frameWidth) / COMPACT_FONT_TRANSITION_WIDTH, 0, 1)
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
    local count = 0
    for _ in string.gmatch(text, UTF8_CHAR_PATTERN) do
        count = count + 1
    end
    if count > 0 then
        return count
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

    if type(text) ~= "string" or text == "" then
        return ""
    end

    local startPos = tonumber(startIndex) or 1
    local endPos = tonumber(endIndex) or math.huge
    if endPos < startPos then
        return ""
    end

    local chars = {}
    local idx = 0
    for char in string.gmatch(text, UTF8_CHAR_PATTERN) do
        idx = idx + 1
        if idx >= startPos and idx <= endPos then
            chars[#chars + 1] = char
        elseif idx > endPos then
            break
        end
    end

    if #chars > 0 then
        return table.concat(chars)
    end

    return string.sub(text, startIndex, endIndex)
end

local function ApplyTruncateNoEllipsis(fontString, text, maxWidth, minChars)
    if not fontString then
        return
    end
    if not text or text == "" then
        fontString:SetText("")
        return
    end
    if maxWidth <= 0 then
        fontString:SetText("")
        return
    end

    if GetReferenceTextWidth(fontString, text) <= maxWidth then
        fontString:SetText(text)
        return
    end
    local length = GetStringLength(text)
    if length <= 0 then
        fontString:SetText("")
        return
    end

    local minVisible = math.min(math.max(1, minChars or 1), length)
    local normalizedWidth = math.max(0, math.floor(maxWidth + 0.5))
    local truncateCacheKey = table.concat({
        MakeFontSignature(fontString),
        tostring(normalizedWidth),
        tostring(minVisible),
        text,
    }, "|")
    local cachedValue = truncateCache[truncateCacheKey]
    if cachedValue ~= nil then
        fontString:SetText(cachedValue)
        return
    end

    local low, high = minVisible, length
    local best = SubString(text, 1, minVisible)

    if GetReferenceTextWidth(fontString, best) > maxWidth then
        fontString:SetText(best)
        return
    end

    while low <= high do
        local mid = math.floor((low + high) / 2)
        local candidate = SubString(text, 1, mid)
        if GetReferenceTextWidth(fontString, candidate) <= maxWidth then
            best = candidate
            low = mid + 1
        else
            high = mid - 1
        end
    end
    fontString:SetText(best)
    PutCache("truncate", truncateCacheKey, best)
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

local function BuildPhaseWidthSamples(rows, fullMaxLength, shortMaxLength)
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

        if phaseValue and phaseValue ~= "" then
            table.insert(fullSamples, string.sub(phaseValue, 1, fullCap))
            table.insert(shortSamples, string.sub(phaseValue, 1, shortCap))
        end
    end

    return fullSamples, shortSamples
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
    for i = 1, 4 do
        sum = sum + math.max(0, widths and widths[i] or 0)
    end
    return math.max(1, math.floor(sum + 0.5))
end

local function CalculateColumnWidths(rows, headerLabels, totalWidth, scale, profile)
    local headers = headerLabels or {}
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

    -- 地图名列固定为内容自然宽度，不参与压缩；
    -- 缩窗时优先通过隐藏其他列来适配。
    local mapNaturalWidth = math.max(1, math.floor(mapMax + MAP_COL_BASE_PADDING + MAP_COL_SAFETY_PADDING + 0.5))
    local mapCompactMinWidth = mapNaturalWidth
    if profile then
        profile.mapNaturalWidth = mapNaturalWidth
        profile.mapCompactMinWidth = mapCompactMinWidth
    end

    local phaseFullSamples, phaseShortSamples = BuildPhaseWidthSamples(rows, 10, 4)
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

    local phaseFullDesired = math.floor((GetMaxWidth(phaseFullDesiredSamples) + 20) * widthScale + 0.5)
    local phaseShortDesired = math.floor((GetMaxWidth(phaseShortDesiredSamples) + 20) * widthScale + 0.5)
    local lastDesired = math.floor((GetMaxWidth({headers[3] or "", noRecord, "00:00:00"}) + 18) * widthScale + 0.5)
    local nextDesired = math.floor((GetMaxWidth({headers[4] or "", noRecord, "00:00:00"}) + 18) * widthScale + 0.5)
    local phaseFullNeed = math.floor((GetMaxWidth(phaseFullNeedSamples) + 10) * widthScale + 0.5)
    local phaseShortNeed = math.floor((GetMaxWidth(phaseShortNeedSamples) + 10) * widthScale + 0.5)
    local lastNeed = math.floor((GetMaxWidth({noRecord, "00:00:00"}) + 10) * widthScale + 0.5)
    local nextNeed = math.floor((GetMaxWidth({noRecord, "00:00:00"}) + 10) * widthScale + 0.5)

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
        mapWidth = Clamp(mapWidth, mapCompactMinWidth, mapNaturalWidth)
        result[1] = mapWidth

        local remainingWidth = math.max(1, math.floor((totalWidth or 1) - mapWidth + 0.5))
        local distributedOthers = DistributeWidths(otherDesired, otherMinWidths, otherMaxWidths, remainingWidth)
        for i, colIndex in ipairs(otherIndices) do
            result[colIndex] = distributedOthers[i] or 0
        end

        -- 主框最小宽度保底最终形态（地图 + 下次刷新），
        -- 地图列不压缩，因此使用 mapNaturalWidth 作为硬下限。
        local minTableWidth = mapNaturalWidth + nextNeed
        profile.minTableWidth = math.max(1, math.floor(minTableWidth + 0.5))

        return result
    end

    local result = {0, 0, 0, 0}

    local showPhase = profile and profile.showPhaseColumn == true or false
    local showLast = profile and profile.showLastRefreshColumn == true or false
    local showNext = true

    -- 默认状态按内容自适应：列宽只容纳自身内容，不额外分配空白空间
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
    local naturalTotal = SumColumnWidths(result)
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

        local distributed = DistributeWidths(activeDesired, activeMinWidths, activeMaxWidths, availableWidth)
        result = {0, 0, 0, 0}
        for index, colIndex in ipairs(activeIndices) do
            result[colIndex] = distributed[index] or 0
        end
    end

    if profile then
        profile.minTableWidth = SumColumnWidths(result)
    end

    return result
end

local function CalculateTableLayout(frame, profile)
    local tableParent = GetTableParent(frame)
    local contentWidth = tableParent and tableParent:GetWidth() or 0

    if contentWidth <= 1 then
        local frameWidth = frame and frame:GetWidth() or BASE_FRAME_WIDTH
        contentWidth = math.max(1, math.floor(frameWidth - FRAME_HORIZONTAL_PADDING + 0.5))
    end

    local scale = GetScaleFactor(frame)
    local visibilityProfile = profile or GetVisibilityProfile(frame)
    local fontScale = GetSmoothCompactFontScale(frame, scale, visibilityProfile)
    local headerState = GetHeaderCollapseState(frame, visibilityProfile)

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
        phaseShortMode = visibilityProfile.phaseShortMode == true,
        showHeader = headerState.shown,
    }
end

local function GetRowsBlockHeight(rowCount, rowHeight, rowGap)
    if (rowCount or 0) <= 0 then
        return 0
    end
    return (rowCount * rowHeight) + math.max(0, rowCount - 1) * rowGap
end

local function GetContentHeight(frame, tableParent)
    local contentHeight = tableParent and tableParent:GetHeight() or 0
    if contentHeight and contentHeight > 1 then
        return contentHeight
    end
    local frameHeight = GetFrameHeight(frame)
    return math.max(0, math.floor(frameHeight - FRAME_VERTICAL_PADDING + 0.5))
end

local function BuildVerticalMetrics(frame, rowCount, rowHeight, rowGap, tableParent, allowHeaderSpace)
    local safeRowCount = math.max(0, rowCount or 0)
    local safeRowHeight = rowHeight or FIXED_ROW_HEIGHT
    local safeRowGap = rowGap or COMPACT_BASE_ROW_GAP
    local contentHeight = GetContentHeight(frame, tableParent)
    local fullRowsHeight = GetRowsBlockHeight(safeRowCount, safeRowHeight, safeRowGap)
    local headerTransitionHeight = (allowHeaderSpace == true) and (safeRowHeight + safeRowGap) or 0
    local headerAlphaByHeight = 1
    local visibleRowCount = safeRowCount

    if safeRowCount <= 0 then
        headerAlphaByHeight = 0
        visibleRowCount = 0
    else
        if headerTransitionHeight <= 0 then
            headerAlphaByHeight = 0
            local rowUnit = safeRowHeight + safeRowGap
            local fittedRows = math.floor((contentHeight + safeRowGap) / math.max(1, rowUnit))
            visibleRowCount = Clamp(fittedRows, 1, safeRowCount)
        elseif contentHeight <= (fullRowsHeight + 0.5) then
            headerAlphaByHeight = 0
            local rowUnit = safeRowHeight + safeRowGap
            local fittedRows = math.floor((contentHeight + safeRowGap) / math.max(1, rowUnit))
            visibleRowCount = Clamp(fittedRows, 1, safeRowCount)
        else
            local t = Clamp((fullRowsHeight + headerTransitionHeight - contentHeight) / math.max(1, headerTransitionHeight), 0, 1)
            t = t * t * (3 - 2 * t)
            headerAlphaByHeight = 1 - t
            visibleRowCount = safeRowCount
        end
    end

    local minTableHeight = safeRowCount > 0 and safeRowHeight or 0
    local maxTableHeight = fullRowsHeight + headerTransitionHeight
    local shouldAutoCompactSort = safeRowCount > 1 and headerAlphaByHeight <= 0.001 and contentHeight <= (fullRowsHeight + 0.5)

    return {
        contentHeight = contentHeight,
        fullRowsHeight = fullRowsHeight,
        headerAlphaByHeight = headerAlphaByHeight,
        visibleRowCount = visibleRowCount,
        minTableHeight = minTableHeight,
        maxTableHeight = maxTableHeight,
        shouldAutoCompactSort = shouldAutoCompactSort,
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

    rowFramePool[index] = rowFrame
    return rowFrame
end

function TableUI:RebuildUI(frame, headerLabels)
    if not frame then return end
    if not SortingSystem then return end

    local visibilityProfile = GetVisibilityProfile(frame)
    local rebuildDepth = frame.__ctkResizeRebuildDepth or 0
    local tableParent = GetTableParent(frame)

    local function BuildVisibleRows()
        local visibleRows = {}
        for _, rowInfo in ipairs(SortingSystem:GetCurrentRows() or {}) do
            if visibilityProfile.showDeletedRows or not rowInfo.isHidden then
                table.insert(visibleRows, rowInfo)
            end
        end
        return visibleRows
    end

    local rows = BuildVisibleRows()
    local verticalMetrics = BuildVerticalMetrics(
        frame,
        #rows,
        FIXED_ROW_HEIGHT,
        COMPACT_BASE_ROW_GAP,
        tableParent,
        visibilityProfile.showHeader == true
    )
    local shouldAutoCompactSort = (frame.__ctkHeightControlledByUser == true or frame.isSizing == true) and verticalMetrics.shouldAutoCompactSort
    if SortingSystem and SortingSystem.SetCompactAutoSortEnabled then
        local sortChanged = SortingSystem:SetCompactAutoSortEnabled(shouldAutoCompactSort)
        if sortChanged then
            rows = BuildVisibleRows()
            verticalMetrics = BuildVerticalMetrics(
                frame,
                #rows,
                FIXED_ROW_HEIGHT,
                COMPACT_BASE_ROW_GAP,
                tableParent,
                visibilityProfile.showHeader == true
            )
        end
    end
    visibilityProfile.headerAlphaByHeight = verticalMetrics.headerAlphaByHeight

    local layout = CalculateTableLayout(frame, visibilityProfile)
    local colWidths = CalculateColumnWidths(rows, headerLabels, layout.tableWidth, layout.scale, visibilityProfile)
    local mapNaturalWidth = visibilityProfile.mapNaturalWidth or (colWidths[1] or 0)
    local mapCompressed = ((colWidths[1] or 0) + 0.5) < mapNaturalWidth
    if frame.__ctkMapColumnCompressed ~= mapCompressed then
        frame.__ctkMapColumnCompressed = mapCompressed
        if MainFrame and MainFrame.ApplyScaledChrome then
            MainFrame:ApplyScaledChrome(frame)
        end
    end
    layout.showPhaseColumn = visibilityProfile.showPhaseColumn == true
    layout.showLastRefreshColumn = visibilityProfile.showLastRefreshColumn == true
    layout.phaseShortMode = visibilityProfile.phaseShortMode == true
    layout.activeTableWidth = SumColumnWidths(colWidths)
    local userControlledWidth = frame.__ctkWidthControlledByUser == true
    local userControlledHeight = frame.__ctkHeightControlledByUser == true

    local frameWidth = frame:GetWidth() or BASE_FRAME_WIDTH
    local frameHeight = GetFrameHeight(frame)
    local horizontalPadding = FRAME_HORIZONTAL_PADDING
    local defaultProfile = {
        showHeader = true,
        showPhaseColumn = true,
        showLastRefreshColumn = true,
        phaseShortMode = false,
        showDeletedRows = false,
        isFullInfo = true,
    }
    local defaultTableWidthHint = math.max(1, math.floor((BASE_FRAME_WIDTH - FRAME_HORIZONTAL_PADDING) + 0.5))
    local defaultColWidths = CalculateColumnWidths(rows, headerLabels, defaultTableWidthHint, 1, defaultProfile)
    local defaultTableWidth = SumColumnWidths(defaultColWidths)
    local desiredFrameWidth = math.floor(defaultTableWidth + horizontalPadding + 0.5)
    desiredFrameWidth = Clamp(desiredFrameWidth, BASE_MIN_FRAME_WIDTH, BASE_FRAME_WIDTH)

    local requiredMinFrameWidth = BASE_MIN_FRAME_WIDTH
    if visibilityProfile.compactByWidth == true then
        local minTableWidth = math.max(1, visibilityProfile.minTableWidth or 1)
        requiredMinFrameWidth = math.floor(minTableWidth + horizontalPadding + 0.5)
        requiredMinFrameWidth = Clamp(requiredMinFrameWidth, BASE_MIN_FRAME_WIDTH, BASE_FRAME_WIDTH - 1)
    end

    local requiredMaxFrameWidth = Clamp(desiredFrameWidth, requiredMinFrameWidth, BASE_FRAME_WIDTH)
    local requiredMinFrameHeight = math.max(1, math.floor((verticalMetrics.minTableHeight + FRAME_VERTICAL_PADDING) + 0.5))
    local requiredMaxFrameHeight = math.max(requiredMinFrameHeight, math.floor((verticalMetrics.maxTableHeight + FRAME_VERTICAL_PADDING) + 0.5))
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
        if MainFrame and MainFrame.ApplyAdaptiveResizeBounds then
            MainFrame:ApplyAdaptiveResizeBounds(frame)
        end
        -- 最小宽度阈值变化后，立即同步标题栏显隐状态；
        -- 否则登录/重载时可能因未触发 OnSizeChanged 而残留旧状态。
        if MainFrame and MainFrame.ApplyScaledChrome then
            MainFrame:ApplyScaledChrome(frame)
        end
    end

    if userControlledWidth and not frame.isSizing and frameWidth + 0.5 >= requiredMaxFrameWidth then
        frame.__ctkWidthControlledByUser = false
        userControlledWidth = false
        if MainFrame and MainFrame.PersistFrameSize then
            MainFrame:PersistFrameSize(frame)
        end
        EmitResizeDebug(frame, "exit-user", debugPayload)
    end
    if userControlledHeight and not frame.isSizing and frameHeight + 0.5 >= requiredMaxFrameHeight then
        frame.__ctkHeightControlledByUser = false
        userControlledHeight = false
        if MainFrame and MainFrame.PersistFrameSize then
            MainFrame:PersistFrameSize(frame)
        end
    end

    local targetWidth = frameWidth
    local targetHeight = frameHeight
    local resizeStage = "stable"

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
        EmitResizeDebug(frame, resizeStage, debugPayload)
        frame:SetSize(targetWidth, targetHeight)
        if MainFrame and MainFrame.PersistFrameSize then
            MainFrame:PersistFrameSize(frame)
        end
        if rebuildDepth < 3 then
            frame.__ctkResizeRebuildDepth = rebuildDepth + 1
            self:RebuildUI(frame, headerLabels)
            frame.__ctkResizeRebuildDepth = rebuildDepth
            return
        end
        -- 兜底：达到递归上限时仍继续渲染，避免出现“仅拖拽中可见，松手后空白”。
    end

    EmitResizeDebug(frame, "stable", debugPayload)

    local rowsToRender = rows
    local visibleRowCount = math.max(0, math.min(verticalMetrics.visibleRowCount or #rows, #rows))
    if visibleRowCount < #rows then
        rowsToRender = {}
        for idx = 1, visibleRowCount do
            rowsToRender[#rowsToRender + 1] = rows[idx]
        end
    end

    HideVisibleFrames()

    if CountdownSystem then
        CountdownSystem:ClearTexts()
    end

    if SortingSystem and SortingSystem.SetHeaderButton then
        SortingSystem:SetHeaderButton(nil)
    end

    if layout.showHeader then
        self:CreateHeaderRow(layout.parent, headerLabels, colWidths, layout)
    elseif headerRowFrame then
        headerRowFrame:Hide()
    end

    for displayIndex, rowInfo in ipairs(rowsToRender) do
        self:CreateDataRow(layout.parent, rowInfo, displayIndex, colWidths, layout)
    end

    for idx = #rowsToRender + 1, #rowFramePool do
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
    rowFrame.rowId = rowId

    local rowBg = rowFrame.rowBg
    rowBg:SetAllPoints(rowFrame)

    local rowColor = UIConfig.GetDataRowColor(displayIndex)
    if rowInfo.isHidden then
        rowBg:SetColorTexture(0.5, 0.5, 0.5, 0.3)
        rowFrame:SetAlpha(0.6)
    else
        rowBg:SetColorTexture(rowColor[1], rowColor[2], rowColor[3], rowColor[4])
    end

    self:CreateRowCells(rowFrame, rowInfo, colWidths, rowBg, layout.scale, layout)

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
            ApplyTruncateNoEllipsis(cellText, textValue, maxWidth, MAP_COL_COMPACT_MIN_CHARS)
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

            local hitArea = rowFrame.countdownHitArea
            if not hitArea then
                hitArea = CreateFrame("Button", nil, rowFrame)
                hitArea:RegisterForClicks("LeftButtonUp")
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
                    if button ~= "LeftButton" then
                        return
                    end
                    if self.__ctkIsHidden or not IsAddonEnabled() then
                        return
                    end
                    if MainPanel and MainPanel.NotifyMapById then
                        MainPanel:NotifyMapById(self.__ctkRowId)
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

return TableUI

-- TableUITextMetrics.lua - 表格文本测量与截断工具

local TableUITextMetrics = BuildEnv("TableUITextMetrics")

local measureText = nil
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

function TableUITextMetrics:GetTextWidth(text)
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

function TableUITextMetrics:GetReferenceTextWidth(referenceFontString, text)
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

function TableUITextMetrics:GetScaledTextWidth(text, scale)
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

function TableUITextMetrics:ApplyTruncateNoEllipsis(fontString, text, maxWidth, minChars)
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

    if self:GetReferenceTextWidth(fontString, text) <= maxWidth then
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

    if self:GetReferenceTextWidth(fontString, best) > maxWidth then
        fontString:SetText(best)
        return
    end

    while low <= high do
        local mid = math.floor((low + high) / 2)
        local candidate = SubString(text, 1, mid)
        if self:GetReferenceTextWidth(fontString, candidate) <= maxWidth then
            best = candidate
            low = mid + 1
        else
            high = mid - 1
        end
    end
    fontString:SetText(best)
    PutCache("truncate", truncateCacheKey, best)
end

return TableUITextMetrics

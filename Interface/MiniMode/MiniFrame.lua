-- MiniFrame.lua - 极简模式窗口

local MiniFrame = BuildEnv("MiniFrame")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local UIConfig = BuildEnv("UIConfig")
local MainPanel = BuildEnv("MainPanel")
local Data = BuildEnv("Data")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local L = CrateTrackerZK.L

local frame = nil
local rowFrames = {}
local updateTicker = nil
local resizeTimer = nil
local measureText = nil
local hoverFrame = nil

local MINI_CFG = {
    width = 240,
    height = 210,
    minWidth = 200,
    minHeight = 140,
    maxWidth = 520,
    maxHeight = 520,
    paddingX = 14,
    paddingY = 12,
    dragHeight = 0,
    rowHeight = 24,
    minRowHeight = 20,
    rowGap = 4,
    namePadding = 6,
    timeWidth = 80,
    rowBg = {1, 1, 1, 0.06},
    rowBgAlt = {1, 1, 1, 0.10},
}

local function LT(key, fallback)
    if L and L[key] then
        return L[key]
    end
    return fallback
end

local function EnsureMiniDB()
    if not CRATETRACKERZK_UI_DB or type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {}
    end
    CRATETRACKERZK_UI_DB.miniMode = CRATETRACKERZK_UI_DB.miniMode or {}
    return CRATETRACKERZK_UI_DB.miniMode
end

local function GetCollapsedRowLimit()
    local db = EnsureMiniDB()
    local value = tonumber(db.collapsedRows)
    if not value or value < 1 then
        return 7
    end
    return math.floor(value)
end

local function GetBackgroundColor()
    if UIConfig and UIConfig.GetColor then
        local color = UIConfig.GetColor("mainFrameBackground")
        if color then
            return color
        end
    end
    return {0, 0, 0, 0.05}
end

local function GetRowBackgroundColor(index)
    if UIConfig and UIConfig.GetDataRowColor then
        local color = UIConfig.GetDataRowColor(index)
        if color then
            return color
        end
    end
    if (index or 0) % 2 == 0 then
        return MINI_CFG.rowBgAlt
    end
    return MINI_CFG.rowBg
end

local function GetScaleFactor()
    if not frame then
        return 1
    end
    local w = frame:GetWidth() or MINI_CFG.width
    local h = frame:GetHeight() or MINI_CFG.height
    local scaleW = w / MINI_CFG.width
    local scaleH = h / MINI_CFG.height
    local scale = math.min(scaleW, scaleH)
    if scale < 0.8 then scale = 0.8 end
    if scale > 1.4 then scale = 1.4 end
    return scale
end

local function GetFrameTopLeft()
    if not frame then
        return nil, nil
    end
    local left = frame:GetLeft()
    local top = frame:GetTop()
    if not left or not top then
        return nil, nil
    end
    return left, top
end

local function RestoreFrameTopLeft(left, top)
    if not frame or not left or not top then
        return
    end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

local function GetScaledFontSize(baseSize, scale)
    local size = math.floor(baseSize * scale + 0.5)
    if size < 10 then size = 10 end
    if size > 18 then size = 18 end
    return size
end

local function ApplyFontScale(fontString, scale)
    if not fontString or not fontString.GetFont then
        return
    end
    local font, size, flags = fontString:GetFont()
    if not font then
        local defaultFont, defaultSize, defaultFlags = GameFontNormal:GetFont()
        font, size, flags = defaultFont, defaultSize, defaultFlags
    end
    size = size or 12
    local scaled = GetScaledFontSize(size, scale)
    fontString:SetFont(font, scaled, flags)
end

local function SaveFramePosition()
    local db = EnsureMiniDB()
    local point, _, _, x, y = frame:GetPoint()
    db.position = { point = point, x = x, y = y }
end

local function SaveFrameSize()
    local db = EnsureMiniDB()
    db.size = { width = frame:GetWidth(), height = frame:GetHeight() }
end

local function ApplySavedState()
    local db = EnsureMiniDB()
    if db.size and db.size.width and db.size.height then
        frame:SetSize(db.size.width, db.size.height)
    else
        frame:SetSize(MINI_CFG.width, MINI_CFG.height)
    end
    if db.position then
        frame:ClearAllPoints()
        frame:SetPoint(db.position.point or "CENTER", UIParent, db.position.point or "CENTER", db.position.x or 0, db.position.y or 0)
    else
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function GetMeasureText()
    if not measureText then
        measureText = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        measureText:SetText("")
    end
    return measureText
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

local function IsHiddenMap(mapData)
    if not mapData then return false end
    local hiddenMaps = CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.hiddenMaps or {}
    return hiddenMaps and hiddenMaps[mapData.mapID] == true
end

local function GetHiddenRemaining(mapData)
    if not mapData then return nil end
    local hiddenRemaining = CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.hiddenRemaining or {}
    local value = hiddenRemaining and hiddenRemaining[mapData.mapID]
    if value and value < 0 then
        value = 0
    end
    return value
end

local function FormatRemaining(seconds)
    if UnifiedDataManager and UnifiedDataManager.FormatTime then
        return UnifiedDataManager:FormatTime(seconds)
    end
    if not seconds or seconds < 0 then
        return LT("NoRecord", "--:--")
    end
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d", minutes, secs)
end

local function GetCountdownColor(seconds, isHidden)
    if isHidden then
        return 0.5, 0.5, 0.5, 0.8
    end
    if not UIConfig or not UIConfig.GetTextColor then
        return 1, 1, 1, 1
    end
    if seconds == nil then
        local normal = UIConfig.GetTextColor("normal")
        return normal[1], normal[2], normal[3], normal[4]
    end
    if UIConfig.criticalTime and seconds <= UIConfig.criticalTime then
        local critical = UIConfig.GetTextColor("countdownCritical")
        return critical[1], critical[2], critical[3], critical[4]
    end
    if UIConfig.warningTime and seconds <= UIConfig.warningTime then
        local warning = UIConfig.GetTextColor("countdownWarning")
        return warning[1], warning[2], warning[3], warning[4]
    end
    local normal = UIConfig.GetTextColor("countdownNormal")
    return normal[1], normal[2], normal[3], normal[4]
end

local function GetNormalTextColor()
    if UIConfig and UIConfig.GetTextColor then
        return UIConfig.GetTextColor("normal")
    end
    return {1, 1, 1, 1}
end

local function GetRemainingForMap(mapData)
    if not mapData or not UnifiedDataManager or not UnifiedDataManager.GetRemainingTime then
        return nil
    end
    local remaining = UnifiedDataManager:GetRemainingTime(mapData.id)
    if remaining and remaining < 0 then
        remaining = 0
    end
    return remaining
end

local function BuildSortedRows()
    if not Data or not Data.GetAllMaps then
        return {}
    end
    local rows = {}
    for _, mapData in ipairs(Data:GetAllMaps() or {}) do
        if mapData and not IsHiddenMap(mapData) then
            local remaining = GetRemainingForMap(mapData)
            table.insert(rows, { mapData = mapData, remaining = remaining })
        end
    end
    table.sort(rows, function(a, b)
        local ar = a.remaining
        local br = b.remaining
        if ar == nil and br == nil then
            return (a.mapData.mapID or 0) < (b.mapData.mapID or 0)
        elseif ar == nil then
            return false
        elseif br == nil then
            return true
        end
        if ar == br then
            return (a.mapData.mapID or 0) < (b.mapData.mapID or 0)
        end
        return ar < br
    end)
    return rows
end

local function ExtractRowIds(rows)
    local ids = {}
    for i, row in ipairs(rows or {}) do
        ids[i] = row.mapData and row.mapData.id or nil
    end
    return ids
end

local function IsSameOrder(a, b)
    if not a or not b or #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

local function ClearRows()
    for _, row in ipairs(rowFrames) do
        if row and row:GetObjectType() == "Frame" then
            row:Hide()
            row:SetParent(nil)
        end
    end
    rowFrames = {}
end

local tooltipDefaults = nil

local function ApplyTooltipStyle()
    if not GameTooltip or not GameTooltip.SetBackdropColor then
        return
    end
    if not tooltipDefaults and GameTooltip.GetBackdropColor then
        local r, g, b, a = GameTooltip:GetBackdropColor()
        local br, bg, bb, ba = 1, 1, 1, 1
        if GameTooltip.GetBackdropBorderColor then
            br, bg, bb, ba = GameTooltip:GetBackdropBorderColor()
        end
        tooltipDefaults = {r = r, g = g, b = b, a = a, br = br, bg = bg, bb = bb, ba = ba}
    end
    local bg = GetBackgroundColor()
    GameTooltip:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
end

local function RestoreTooltipStyle()
    if not tooltipDefaults or not GameTooltip or not GameTooltip.SetBackdropColor then
        return
    end
    GameTooltip:SetBackdropColor(tooltipDefaults.r, tooltipDefaults.g, tooltipDefaults.b, tooltipDefaults.a)
    if GameTooltip.SetBackdropBorderColor then
        GameTooltip:SetBackdropBorderColor(tooltipDefaults.br, tooltipDefaults.bg, tooltipDefaults.bb, tooltipDefaults.ba)
    end
end

local function ShowUnifiedTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    ApplyTooltipStyle()
    GameTooltip:ClearLines()
    GameTooltip:AddLine(LT("MiniModeTooltipLine1", "右键发送通知"), 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

local function HideTooltip()
    if GameTooltip then
        GameTooltip:Hide()
    end
    RestoreTooltipStyle()
end

local function ShowChrome()
    if frame and frame.miniBackgroundFrame then
        frame.miniBackgroundFrame:Show()
    end
    if frame and frame.miniBackground then
        frame.miniBackground:Show()
    end
    if frame and frame.miniResizeHandle then
        frame.miniResizeHandle:Show()
        frame.miniResizeHandle:EnableMouse(true)
    end
end

local function HideChrome()
    if frame and frame.miniBackground then
        frame.miniBackground:Hide()
    end
    if frame and frame.miniBackgroundFrame then
        frame.miniBackgroundFrame:Hide()
    end
    if frame and frame.miniResizeHandle then
        frame.miniResizeHandle:Hide()
        frame.miniResizeHandle:EnableMouse(false)
    end
end

local function IsHovering()
    if frame and frame.miniResizeHandle and frame.miniResizeHandle:IsMouseOver() then
        return true
    end
    if hoverFrame and hoverFrame:IsMouseOver() then
        return true
    end
    return false
end

local function UpdateHoverState(owner)
    if not frame or frame.isMoving or frame.isSizing then
        return
    end
    if IsHovering() then
        if not MiniFrame.isHovering then
            MiniFrame.isHovering = true
            MiniFrame:Expand()
            ShowChrome()
            ShowUnifiedTooltip(owner or frame)
        end
    else
        if MiniFrame.isHovering then
            MiniFrame.isHovering = false
            HideChrome()
            HideTooltip()
            MiniFrame:Collapse()
        end
    end
end

function MiniFrame:UpdateCountdowns()
    if not frame or not frame:IsShown() then return end
    if not Data or not Data.GetMap then return end

    local visibleCount = #rowFrames
    local desiredCount = #(self.sortedRows or {})
    if self.isCollapsed then
        local limit = GetCollapsedRowLimit()
        desiredCount = math.max(1, math.min(limit, desiredCount))
    end
    if visibleCount ~= desiredCount then
        self:RebuildRows()
        return
    end

    for index, row in ipairs(rowFrames) do
        local mapData = Data:GetMap(row.rowId)
        if mapData then
            if IsHiddenMap(mapData) then
                self:RebuildRows()
                return
            end
            local mapName = Data.GetMapDisplayName and Data:GetMapDisplayName(mapData) or (mapData.mapID and tostring(mapData.mapID) or "")
            row.mapName = mapName
            local nameWidth = row.nameText:GetWidth() or 0
            ApplyEllipsis(row.nameText, mapName, nameWidth)

            local remaining = GetRemainingForMap(mapData)

            local timeText = FormatRemaining(remaining)
            row.timeText:SetText(timeText)
            local r, g, b, a = GetCountdownColor(remaining, false)
            row.timeText:SetTextColor(r, g, b, a)

            local normal = GetNormalTextColor()
            row.nameText:SetTextColor(normal[1], normal[2], normal[3], normal[4])
            row:SetAlpha(1.0)

            local bgColor = GetRowBackgroundColor(index)
            row.bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
        end
    end
end

function MiniFrame:RebuildRows()
    if not frame then return end
    if not Data or not Data.GetAllMaps then return end

    ClearRows()

    local sortedRows = BuildSortedRows()
    self.sortedRows = sortedRows
    self.sortedRowIds = ExtractRowIds(sortedRows)

    local visibleCount = #sortedRows
    if self.isCollapsed then
        local limit = GetCollapsedRowLimit()
        visibleCount = math.max(1, math.min(limit, visibleCount))
    end

    local scale = self.overrideScale or GetScaleFactor()
    local contentWidth = math.max(1, frame:GetWidth() - MINI_CFG.paddingX * 2)
    local contentHeight = math.max(1, frame:GetHeight() - MINI_CFG.dragHeight - MINI_CFG.paddingY * 2)
    local rowCount = math.max(1, visibleCount)
    local scaledGap = math.max(1, math.floor((MINI_CFG.rowGap or 0) * scale + 0.5))
    local totalGap = math.max(0, rowCount - 1) * scaledGap
    local availableHeight = math.max(1, contentHeight - totalGap)
    local idealRowHeight = math.floor(availableHeight / math.max(1, rowCount))
    local scaledMinRowHeight = math.max(12, math.floor(MINI_CFG.minRowHeight * scale + 0.5))
    local scaledRowHeight = math.floor(MINI_CFG.rowHeight * scale + 0.5)
    local rowHeight = scaledRowHeight
    if not self.isCollapsed then
        rowHeight = math.max(scaledMinRowHeight, math.min(scaledRowHeight, idealRowHeight))
    end
    local startY = MINI_CFG.paddingY + MINI_CFG.dragHeight
    local timeWidth = math.max(60, math.floor(MINI_CFG.timeWidth * scale + 0.5))
    local nameWidth = math.max(40, contentWidth - timeWidth - MINI_CFG.namePadding * 2)
    self.layout = {
        startY = startY,
        rowHeight = rowHeight,
        rowGap = scaledGap,
        visibleCount = visibleCount,
    }

    for index = 1, visibleCount do
        local rowInfo = sortedRows[index]
        local mapData = rowInfo and rowInfo.mapData or nil
        if not mapData then
            break
        end
        local rowFrame = CreateFrame("Frame", nil, frame)
        rowFrame:SetSize(contentWidth, rowHeight)
        rowFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", MINI_CFG.paddingX, -startY - (index - 1) * (rowHeight + scaledGap))
        rowFrame:SetFrameLevel(frame:GetFrameLevel() + 2)
        rowFrame:EnableMouse(false)
        rowFrame.rowId = mapData.id
        rowFrame.mapId = mapData.mapID

        local rowBg = rowFrame:CreateTexture(nil, "BACKGROUND")
        rowBg:SetAllPoints(rowFrame)
        local bgColor = GetRowBackgroundColor(index)
        rowBg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
        rowFrame.bg = rowBg

        local nameText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("LEFT", rowFrame, "LEFT", MINI_CFG.namePadding, 0)
        nameText:SetWidth(nameWidth)
        nameText:SetJustifyH("LEFT")
        nameText:SetJustifyV("MIDDLE")
        nameText:SetShadowOffset(0, 0)
        ApplyFontScale(nameText, scale)

        local timeText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        timeText:SetPoint("RIGHT", rowFrame, "RIGHT", -MINI_CFG.namePadding, 0)
        timeText:SetWidth(timeWidth)
        timeText:SetJustifyH("RIGHT")
        timeText:SetJustifyV("MIDDLE")
        timeText:SetShadowOffset(0, 0)
        ApplyFontScale(timeText, scale)

        rowFrame.nameText = nameText
        rowFrame.timeText = timeText

        table.insert(rowFrames, rowFrame)
    end

    self:UpdateCountdowns()
end

function MiniFrame:EnsureSorted()
    local rows = BuildSortedRows()
    local ids = ExtractRowIds(rows)
    if not IsSameOrder(ids, self.sortedRowIds) then
        self.sortedRows = rows
        self.sortedRowIds = ids
        self:RebuildRows()
        return true
    end
    self.sortedRows = rows
    return false
end

function MiniFrame:Collapse()
    if not frame or self.isCollapsed then return end
    if not self.sortedRows then
        self.sortedRows = BuildSortedRows()
        self.sortedRowIds = ExtractRowIds(self.sortedRows)
    end
    self.lastExpandedScale = self.lastExpandedScale or GetScaleFactor()
    self.overrideScale = self.lastExpandedScale
    self.isCollapsed = true
    local keepRows = GetCollapsedRowLimit()
    local totalRows = #(self.sortedRows or {})
    local showRows = math.max(1, math.min(keepRows, totalRows))
    local scale = self.overrideScale or 1
    local rowHeight = math.floor(MINI_CFG.rowHeight * scale + 0.5)
    local rowGap = math.max(0, math.floor((MINI_CFG.rowGap or 0) * scale + 0.5))
    local height = MINI_CFG.paddingY * 2 + showRows * rowHeight + math.max(0, showRows - 1) * rowGap + MINI_CFG.dragHeight
    local left, top = GetFrameTopLeft()
    frame:SetHeight(height)
    RestoreFrameTopLeft(left, top)
    HideChrome()
    HideTooltip()
    self:RebuildRows()
end

function MiniFrame:Expand()
    if not frame or not self.isCollapsed then return end
    self.isCollapsed = false
    self.overrideScale = nil
    local db = EnsureMiniDB()
    local size = db.size or {}
    local width = size.width or MINI_CFG.width
    local height = size.height or MINI_CFG.height
    local left, top = GetFrameTopLeft()
    frame:SetSize(width, height)
    RestoreFrameTopLeft(left, top)
    self.lastExpandedScale = GetScaleFactor()
    ShowChrome()
    self:RebuildRows()
end

function MiniFrame:StartTicker()
    if updateTicker then
        updateTicker:Cancel()
    end
    updateTicker = C_Timer.NewTicker(1, function()
        if not frame or not frame:IsShown() then
            return
        end
        if self:EnsureSorted() then
            return
        end
        self:UpdateCountdowns()
    end)
end

function MiniFrame:StopTicker()
    if updateTicker then
        updateTicker:Cancel()
        updateTicker = nil
    end
end

function MiniFrame:Create()
    if frame then return frame end

    frame = CreateFrame("Frame", "CrateTrackerZKMiniFrame", UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClipsChildren(true)
    frame:SetClampedToScreen(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(MINI_CFG.minWidth, MINI_CFG.minHeight, MINI_CFG.maxWidth, MINI_CFG.maxHeight)
    else
        if frame.SetMinResize then
            frame:SetMinResize(MINI_CFG.minWidth, MINI_CFG.minHeight)
        end
        if frame.SetMaxResize then
            frame:SetMaxResize(MINI_CFG.maxWidth, MINI_CFG.maxHeight)
        end
    end

    ApplySavedState()

    local bgFrame = CreateFrame("Frame", nil, frame)
    bgFrame:SetAllPoints(frame)
    bgFrame:SetFrameLevel(frame:GetFrameLevel())
    local bg = bgFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bgFrame)
    local bgColor = GetBackgroundColor()
    bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
    frame.miniBackground = bg
    frame.miniBackgroundFrame = bgFrame
    hoverFrame = CreateFrame("Frame", nil, frame)
    hoverFrame:SetAllPoints(frame)
    hoverFrame:SetFrameLevel(frame:GetFrameLevel() + 5)
    hoverFrame:EnableMouse(true)
    hoverFrame:RegisterForDrag("LeftButton")
    hoverFrame:SetScript("OnDragStart", function()
        frame.isMoving = true
        frame:StartMoving()
    end)
    hoverFrame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        frame.isMoving = false
        SaveFramePosition()
        UpdateHoverState(frame)
    end)
    hoverFrame:SetScript("OnEnter", function()
        UpdateHoverState(frame)
    end)
    hoverFrame:SetScript("OnLeave", function()
        UpdateHoverState(frame)
    end)
    hoverFrame:SetScript("OnMouseDown", function(_, button)
        if button ~= "RightButton" then
            return
        end
        local layout = self.layout
        if not layout or not self.sortedRows then
            self:RebuildRows()
            layout = self.layout
        end
        if not layout or not self.sortedRows then
            return
        end
        local left = frame:GetLeft()
        local top = frame:GetTop()
        if not left or not top then
            return
        end
        local cx, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local localY = top - cy
        local rowStride = layout.rowHeight + (layout.rowGap or 0)
        local startY = layout.startY or 0
        local index = math.floor((localY - startY) / rowStride) + 1
        if index < 1 or index > (layout.visibleCount or 0) then
            return
        end
        local rowTop = startY + (index - 1) * rowStride
        if localY < rowTop or localY > rowTop + layout.rowHeight then
            return
        end
        local rowInfo = self.sortedRows[index]
        local mapData = rowInfo and rowInfo.mapData or nil
        if mapData and not IsHiddenMap(mapData) then
            if MainPanel and MainPanel.NotifyMapById then
                MainPanel:NotifyMapById(mapData.id)
                HideTooltip()
            end
        end
    end)

    local resizeHandle = CreateFrame("Button", nil, frame)
    resizeHandle:SetSize(16, 16)
    resizeHandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    resizeHandle:SetFrameLevel(frame:GetFrameLevel() + 20)
    resizeHandle:EnableMouse(true)
    if resizeHandle.SetHitRectInsets then
        resizeHandle:SetHitRectInsets(-4, -4, -4, -4)
    end
    resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeHandle:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            frame.isSizing = true
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    local function StopSizing()
        if not frame.isSizing then
            return
        end
        frame.isSizing = false
        frame:StopMovingOrSizing()
        SaveFrameSize()
        self:RebuildRows()
        if not frame:IsMouseOver() then
            self:Collapse()
        end
    end
    resizeHandle:SetScript("OnMouseUp", function()
        StopSizing()
    end)
    resizeHandle:SetScript("OnEnter", function()
        UpdateHoverState(frame)
    end)
    resizeHandle:SetScript("OnLeave", function()
        UpdateHoverState(frame)
    end)
    frame:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            StopSizing()
        end
    end)
    frame.miniResizeHandle = resizeHandle

    frame:SetScript("OnShow", function()
        HideChrome()
        self.isHovering = false
        self:Collapse()
        self:StartTicker()
    end)
    frame:SetScript("OnHide", function()
        self:StopTicker()
        HideTooltip()
        HideChrome()
    end)
    frame:SetScript("OnSizeChanged", function()
        if resizeTimer then
            resizeTimer:Cancel()
        end
        resizeTimer = C_Timer.NewTimer(0.05, function()
            self:RebuildRows()
        end)
    end)
    frame:SetScript("OnUpdate", nil)

    frame:Hide()
    return frame
end

function MiniFrame:Show()
    if not frame then
        self:Create()
    end
    frame:Show()
    frame:Raise()
end

function MiniFrame:Hide()
    if frame then
        frame:Hide()
    end
end

function MiniFrame:IsShown()
    return frame and frame:IsShown()
end

function MiniFrame:Toggle()
    if self:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

return MiniFrame

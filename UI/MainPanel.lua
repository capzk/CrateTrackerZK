-- MainPanel - TableDemo 样式固定布局版本（无滚动、自适应），保留原数据/逻辑

local ADDON_NAME = "CrateTrackerZK"
local CrateTrackerZK = BuildEnv(ADDON_NAME)
local L = CrateTrackerZK.L
local Logger = BuildEnv("Logger")
local Data = BuildEnv("Data")
local Utils = BuildEnv("Utils")
local TimerManager = BuildEnv("TimerManager")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local Notification = BuildEnv("Notification")
local MapTracker = BuildEnv("MapTracker")
local IconDetector = BuildEnv("IconDetector")
local Area = BuildEnv("Area")
local Help = BuildEnv("Help")
local About = BuildEnv("About")

-- 安全执行
local function SafeExecute(func, ...)
    local ok, res = pcall(func, ...)
    if not ok and Logger then
        Logger:Error("MainPanel", "错误", tostring(res))
    end
    return ok and res or nil
end

-- 固定布局参数（TableDemo 同款）
local Layout = {
    FRAME_WIDTH = 620,
    FRAME_HEIGHT = 340,
    ROW_HEIGHT = 35,
    HEADER_HEIGHT = 24,   -- 调低表头高度
    BUTTON_WIDTH = 65,
    BUTTON_HEIGHT = 25,
    BUTTON_SPACING = 10,
    PADDING = 8,          -- 轻微边距，避免挤压
    TITLE_OFFSET_Y = -35, -- 稍微下移但不过度
}

local Columns = {
    { key = "map",   width = 95,  title = L["MapName"] or "MapName" },
    { key = "phase", width = 130, title = L["PhaseID"] or "PhaseID" },  -- 增加位面列宽，避免位面ID被挤压
    { key = "last",  width = 110, title = L["LastRefresh"] or "Last" },
    { key = "next",  width = 95,  title = L["NextRefresh"] or "Next" }, -- 收紧下次刷新列，给操作列留空间
    { key = "ops",   width = 140, title = L["Operation"] or "Ops" },
}

local function GetTableWidth()
    local w = 0
    for _, col in ipairs(Columns) do
        w = w + (col.width or 0)
    end
    return w
end

local function Utf8Truncate(str, maxChars)
    if not str then return "" end
    local bytes = #str
    local len, pos = 0, 1
    while pos <= bytes do
        len = len + 1
        if len > maxChars then
            return str:sub(1, pos - 1), true
        end
        local b = str:byte(pos)
        if b >= 240 then
            pos = pos + 4
        elseif b >= 224 then
            pos = pos + 3
        elseif b >= 192 then
            pos = pos + 2
        else
            pos = pos + 1
        end
    end
    return str, false
end

local function Utf8Len(str)
    if not str then return 0 end
    local len, pos = 0, 1
    local bytes = #str
    while pos <= bytes do
        len = len + 1
        local b = str:byte(pos)
        if b >= 240 then
            pos = pos + 4
        elseif b >= 224 then
            pos = pos + 3
        elseif b >= 192 then
            pos = pos + 2
        else
            pos = pos + 1
        end
    end
    return len
end

local function EllipsizeToWidth(fs, text, maxWidth)
    fs:SetText(text or "")
    if not maxWidth or fs:GetStringWidth() <= maxWidth then
        return
    end
    local fullText = text or ""
    local len = Utf8Len(fullText)
    for i = len - 1, 1, -1 do
        local candidate = Utf8Truncate(fullText, i)
        candidate = candidate .. "..."
        fs:SetText(candidate)
        if fs:GetStringWidth() <= maxWidth then
            return
        end
    end
end

-- Dialog（帮助/关于）
local Dialog = {}
Dialog.__index = Dialog

function Dialog:new(title, width, height)
    local o = {
        title = title or "",
        width = width or 520,
        height = height or 420,
        frame = nil,
        scrollFrame = nil,
        contentText = nil,
    }
    setmetatable(o, Dialog)
    return o
end

function Dialog:Create()
    if self.frame then return self.frame end
    local f = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplate")
    f:SetSize(self.width, self.height)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(1000)
    f:SetToplevel(true)
    if f.TitleText then f.TitleText:SetText(self.title) end
    if f.CloseButton then f.CloseButton:SetScript("OnClick", function() f:Hide() end) end
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -32)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 12)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(self.width - 40, self.height - 40)
    scroll:SetScrollChild(content)

    -- 使用EditBox替代FontString，支持文字选择和复制
    local editBox = CreateFrame("EditBox", nil, content)
    editBox:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -4)
    editBox:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, -4)
    editBox:SetFontObject("GameFontNormal")
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:EnableMouse(true)
    editBox:SetScript("OnEscapePressed", function() editBox:ClearFocus() end)
    editBox:SetScript("OnEditFocusLost", function() editBox:HighlightText(0, 0) end)
    
    -- 设置为只读模式，但允许选择和复制
    editBox:SetScript("OnTextChanged", function(self)
        if self.ignoreTextChanged then return end
        self.ignoreTextChanged = true
        self:SetText(self.originalText or "")
        self.ignoreTextChanged = false
    end)

    self.frame = f
    self.scrollFrame = scroll
    self.contentText = editBox
    return f
end

function Dialog:SetTitle(title)
    self.title = title or self.title
    if self.frame and self.frame.TitleText then
        self.frame.TitleText:SetText(self.title)
    end
end

function Dialog:SetContent(txt)
    if not self.frame then self:Create() end
    if self.contentText then
        self.contentText.originalText = txt or ""
        self.contentText.ignoreTextChanged = true
        self.contentText:SetText(txt or "")
        self.contentText.ignoreTextChanged = false
    end
    C_Timer.After(0.05, function()
        if not self.scrollFrame or not self.contentText then return end
        -- EditBox使用GetHeight()而不是GetStringHeight()
        local h = self.contentText:GetHeight() + 20
        local viewH = self.scrollFrame:GetHeight()
        local child = self.scrollFrame:GetScrollChild()
        if child then child:SetHeight(math.max(h, viewH)) end
        local sb = self.scrollFrame.ScrollBar
        if sb then
            if h > viewH + 1 then sb:Show() else sb:Hide() self.scrollFrame:SetVerticalScroll(0) end
        end
    end)
end

function Dialog:Show()
    if not self.frame then self:Create() end
    self.frame:Show()
end

-- 数据准备
local function PrepareTableData()
    local maps = (Data and Data.GetAllMaps) and Data:GetAllMaps() or {}
    local now = time()
    local hiddenSet = CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.hiddenMaps or {}
    local items = {}
    for _, mapData in ipairs(maps) do
        if mapData then
            -- 直接使用UnifiedDataManager获取所有数据
            local displayTime = UnifiedDataManager and UnifiedDataManager.GetDisplayTime and UnifiedDataManager:GetDisplayTime(mapData.id);
            local remainingTime = UnifiedDataManager and UnifiedDataManager.GetRemainingTime and UnifiedDataManager:GetRemainingTime(mapData.id);
            local nextRefreshTime = UnifiedDataManager and UnifiedDataManager.GetNextRefreshTime and UnifiedDataManager:GetNextRefreshTime(mapData.id);
            
            -- 如果UnifiedDataManager没有数据，使用Data模块的数据作为回退
            if not displayTime and mapData.lastRefresh then
                displayTime = {
                    time = mapData.lastRefresh,
                    source = "icon_detection",
                    isPersistent = true
                };
                
                -- 更新下次刷新时间（如果需要）
                if mapData.nextRefresh and mapData.nextRefresh <= now then
                    Data:UpdateNextRefresh(mapData.id, mapData);
                end
                
                -- 计算剩余时间
                if mapData.nextRefresh then
                    remainingTime = mapData.nextRefresh - now;
                    if remainingTime < 0 then remainingTime = 0; end
                end
                nextRefreshTime = mapData.nextRefresh;
            end
            
            -- 处理隐藏地图的冻结剩余时间
            local frozenSet = CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.hiddenRemaining or {}
            local hiddenRemaining = (mapData.mapID and frozenSet[mapData.mapID]) or nil
            if hiddenRemaining ~= nil then
                remainingTime = hiddenRemaining
            end
            if remainingTime and remainingTime < 0 then remainingTime = 0 end
            
            -- 获取位面显示信息：仅显示实时位面ID（Phase模块提供），颜色由比对结果决定
            local phaseDisplayInfo = UnifiedDataManager and UnifiedDataManager.GetPhaseDisplayInfo and UnifiedDataManager:GetPhaseDisplayInfo(mapData.id);
            local currentPhaseID = mapData.currentPhaseID;
            
            table.insert(items, {
                originalIndex = #items + 1,
                id = mapData.id,
                mapID = mapData.mapID,
                mapName = Data:GetMapDisplayName(mapData),
                lastRefresh = displayTime and displayTime.time or mapData.lastRefresh,
                nextRefresh = nextRefreshTime or mapData.nextRefresh,
                remainingTime = remainingTime,
                currentPhaseID = currentPhaseID,
                lastRefreshPhase = mapData.lastRefreshPhase,
                isHidden = hiddenSet and hiddenSet[mapData.mapID] or false,
                isFrozen = hiddenRemaining ~= nil,
                timeSource = displayTime and displayTime.source or nil,
                isPersistent = displayTime and displayTime.isPersistent or false,
                phaseDisplayInfo = phaseDisplayInfo, -- 新增位面显示信息
            })
        end
    end
    return items
end

-- Button helper
local function CreateButton(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width or Layout.BUTTON_WIDTH, height or Layout.BUTTON_HEIGHT)
    btn:SetText(text or "")
    btn:SetNormalFontObject("GameFontNormalSmall")
    btn:SetHighlightFontObject("GameFontHighlightSmall")
    btn:SetDisabledFontObject("GameFontDisableSmall")
    return btn
end
-- TableWidget（无滚动）
local TableWidget = {}
TableWidget.__index = TableWidget

function TableWidget:new(parent, callbacks)
    local o = {
        parent = parent,
        callbacks = callbacks or {},
        frame = nil,
        headerFrame = nil,
        contentFrame = nil,
        rowFrames = {},
        sortState = { column = nil, order = nil },
    }
    setmetatable(o, TableWidget)
    return o
end

local function FormatPhase(item)
    local text = L["NotAcquired"] or "N/A"
    local color = {1, 1, 1}

    if item.currentPhaseID then
        text = tostring(item.currentPhaseID)
        if #text > 10 then text = string.sub(text, 1, 10) end
        if item.phaseDisplayInfo and item.phaseDisplayInfo.color then
            color = { item.phaseDisplayInfo.color.r, item.phaseDisplayInfo.color.g, item.phaseDisplayInfo.color.b }
        end
    end

    return text, color
end

local function CreateHeader(self)
    local header = CreateFrame("Frame", nil, self.frame)
    header:SetHeight(Layout.HEADER_HEIGHT)
    header:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)

    local bg = header:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.08, 0.08, 0.08, 0.9)

    local separator = header:CreateTexture(nil, "BORDER")
    separator:SetHeight(1)
    separator:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    separator:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    separator:SetColorTexture(0.2, 0.2, 0.2, 1)

    local totalWidth = GetTableWidth()
    local headerWidth = header:GetWidth() or totalWidth
    local x = math.max((headerWidth - totalWidth) / 2, 0)
    for _, col in ipairs(Columns) do
        if col.key == "last" or col.key == "next" then
            local btn = CreateFrame("Button", nil, header)
            btn:SetSize(col.width, Layout.HEADER_HEIGHT)
            btn:SetPoint("LEFT", header, "LEFT", x, 0)
            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetText(col.title)
            text:SetPoint("CENTER")
            text:SetWidth(col.width - 8)
            text:SetJustifyH("CENTER")
            text:SetJustifyV("MIDDLE")
            text:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
            text:SetWordWrap(false)
            text:SetMaxLines(1)
            local indicator = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            indicator:SetPoint("RIGHT", text, "RIGHT", 15, 0)
            indicator:SetText("")
            btn.sortField = col.key
            btn.indicator = indicator
            btn:SetScript("OnClick", function() self:ToggleSort(col.key) end)
            btn:SetScript("OnEnter", function() text:SetTextColor(1,1,1,1) end)
            btn:SetScript("OnLeave", function() text:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b) end)
        else
            local text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetText(col.title)
            text:SetPoint("CENTER", header, "LEFT", x + col.width / 2, 0)
            text:SetWidth(col.width - 8)
            text:SetJustifyH("CENTER")
            text:SetJustifyV("MIDDLE")
            text:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
            text:SetWordWrap(false)
            text:SetMaxLines(1)
        end
        x = x + col.width
    end
    return header
end

function TableWidget:Create()
    return SafeExecute(function()
        self.frame = CreateFrame("Frame", nil, self.parent)
        local tableHeight = Layout.HEADER_HEIGHT + Layout.ROW_HEIGHT * 7
        -- 左右留出一致的边距，保证表格在主窗口内对称居中
        self.frame:SetPoint("TOPLEFT", self.parent, "TOPLEFT", Layout.PADDING, Layout.TITLE_OFFSET_Y)
        self.frame:SetPoint("TOPRIGHT", self.parent, "TOPRIGHT", -Layout.PADDING, Layout.TITLE_OFFSET_Y)
        self.frame:SetHeight(tableHeight)
        self.frame:EnableMouse(true)

        self.headerFrame = CreateHeader(self)
        if self.headerFrame then self.headerFrame:EnableMouse(true) end
        self.contentFrame = CreateFrame("Frame", nil, self.frame)
        self.contentFrame:SetPoint("TOPLEFT", self.headerFrame, "BOTTOMLEFT", 0, -2)
        self.contentFrame:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)
        self.contentFrame:EnableMouse(true)
        return self.frame
    end)
end
function TableWidget:ToggleSort(col)
    if self.sortState.column == col then
        if self.sortState.order == "desc" then
            self.sortState.order = "asc"
        elseif self.sortState.order == "asc" then
            self.sortState.column = nil
            self.sortState.order = nil
        else
            self.sortState.order = "desc"
        end
    else
        self.sortState.column = col
        self.sortState.order = "desc"
    end
    self:UpdateIndicators()
    self:Refresh(self.cachedData or {})
end

function TableWidget:UpdateIndicators()
    if not self.headerFrame then return end
    for i = 1, self.headerFrame:GetNumChildren() do
        local child = select(i, self.headerFrame:GetChildren())
        if child and child.indicator and child.sortField then
            if child.sortField == self.sortState.column then
                child.indicator:SetText(self.sortState.order == "asc" and "^" or "v")
            else
                child.indicator:SetText("")
            end
        end
    end
end

function TableWidget:SortItems(items)
    local active, hidden = {}, {}
    for _, v in ipairs(items) do
        if v and v.isHidden then
            table.insert(hidden, v)
        else
            table.insert(active, v)
        end
    end

    local col = self.sortState.column
    local order = self.sortState.order
    if col and order then
        -- 拆分有数据行与无数据行（无数据行排在有数据行之后，不参与排序）
        local dataRows, emptyRows = {}, {}
        local function hasData(item)
            if col == "last" then
                return item.lastRefresh ~= nil
            elseif col == "next" then
                return item.remainingTime ~= nil
            end
            return true
        end
        for _, v in ipairs(active) do
            if hasData(v) then
                table.insert(dataRows, v)
            else
                table.insert(emptyRows, v)
            end
        end

        table.sort(dataRows, function(a, b)
            if not a and not b then return false end
            if a and not b then return true end
            if b and not a then return false end

            local function key(item)
                if col == "last" then
                    return item.lastRefresh or 0
                elseif col == "next" then
                    return item.remainingTime or -1
                else
                    return item.originalIndex or 0
                end
            end

            local va, vb = key(a), key(b)
            if va == vb then
                return (a.originalIndex or 0) < (b.originalIndex or 0)
            end
            if order == "asc" then
                return va < vb
            else
                return va > vb
            end
        end)

        table.sort(emptyRows, function(a, b)
            return (a.originalIndex or 0) < (b.originalIndex or 0)
        end)

        active = {}
        for _, v in ipairs(dataRows) do table.insert(active, v) end
        for _, v in ipairs(emptyRows) do table.insert(active, v) end
    end

    table.sort(hidden, function(a, b)
        return (a.originalIndex or 0) < (b.originalIndex or 0)
    end)

    local merged = {}
    for _, v in ipairs(active) do table.insert(merged, v) end
    for _, v in ipairs(hidden) do table.insert(merged, v) end
    return merged
end

function TableWidget:ClearRows()
    for _, row in ipairs(self.rowFrames) do
        if row.animTimer then
            row.animTimer:Cancel()
            row.animTimer = nil
        end
        if row.actionFrame then row.actionFrame:Hide() end
        -- 不再隐藏按钮，因为它们会被重新创建
        if row.frame then row.frame:Hide() end
    end
    self.rowFrames = {}
end
function TableWidget:CreateRow(item, index)
    local row = CreateFrame("Frame", nil, self.contentFrame)
    row:SetHeight(Layout.ROW_HEIGHT)
    row:SetPoint("TOPLEFT", self.contentFrame, "TOPLEFT", 0, -(index - 1) * Layout.ROW_HEIGHT)
    row:SetPoint("TOPRIGHT", self.contentFrame, "TOPRIGHT", 0, -(index - 1) * Layout.ROW_HEIGHT)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, index % 2 == 0 and 0.1 or 0.2)

    local totalWidth = GetTableWidth()
    local rowWidth = row:GetWidth() or totalWidth
    local x = math.max((rowWidth - totalWidth) / 2, 0)
    local function addText(col, text, color, alignLeft)
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        if alignLeft then
            fs:SetPoint("LEFT", row, "LEFT", x + 6, 0)
            fs:SetWidth(col.width - 10)
            fs:SetJustifyH("LEFT")
        else
            fs:SetPoint("CENTER", row, "LEFT", x + col.width / 2, 0)
            fs:SetWidth(col.width - 10)
            fs:SetJustifyH("CENTER")
        end
        fs:SetJustifyV("MIDDLE")
        fs:SetText(text or "")
        fs:SetWordWrap(false)
        fs:SetMaxLines(1)
        if color then fs:SetTextColor(unpack(color)) end
        x = x + col.width
        return fs
    end

    local mapColor = item.isHidden and {GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b} or {1,1,1}
    local mapCol = Columns[1]
    local mapFS = addText(mapCol, "", mapColor, false)  -- 地图名称居中显示
    EllipsizeToWidth(mapFS, item.mapName or "", (mapCol.width or 0) - 10)

    local phaseText, phaseColor = FormatPhase(item)
    if item.isHidden then phaseColor = {GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b} end
    local phaseFS = addText(Columns[2], phaseText, phaseColor)

    local lastText = item.lastRefresh and UnifiedDataManager:FormatTimeForDisplay(item.lastRefresh) or (L["NoRecord"] or "--:--")
    local lastColor = {1, 1, 1}
    if item.lastRefresh then
        -- 持久化时间：绿色；刷新按钮的临时时间：更浅的绿色；无记录：保持白色
        if item.isPersistent then
            lastColor = {0, 1, 0}
        elseif item.timeSource == UnifiedDataManager.TimeSource.REFRESH_BUTTON then
            lastColor = {0.7, 1, 0.7}
        end
    end
    if item.isHidden then
        lastColor = {GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b}
    end
    
    local lastFS = addText(Columns[3], lastText, lastColor)

    local remainingText = item.remainingTime and UnifiedDataManager:FormatTime(item.remainingTime) or (L["NoRecord"] or "--:--")
    local remColor = {1,1,1}
    if item.remainingTime then
        if item.remainingTime < 300 then remColor = {1, 0, 0}
        elseif item.remainingTime < 900 then remColor = {1, 0.5, 0}
        else remColor = {0, 1, 0} end
    end
    if item.isHidden then remColor = {GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b} end
    local remainingFS = addText(Columns[4], remainingText, remColor)

    local opFrame = CreateFrame("Frame", nil, row)
    opFrame:SetSize(Columns[5].width, Layout.ROW_HEIGHT)
    opFrame:SetPoint("LEFT", row, "LEFT", x, 0)

    local refreshBtn, notifyBtn
    -- 始终创建按钮，但根据隐藏状态设置启用/禁用
    local totalButtonWidth = Layout.BUTTON_WIDTH * 2 + Layout.BUTTON_SPACING
    local startX = (Columns[5].width - totalButtonWidth) / 2
    
    refreshBtn = CreateButton(opFrame, L["Refresh"])
    refreshBtn:SetPoint("LEFT", opFrame, "LEFT", startX, 0)
    
    notifyBtn = CreateButton(opFrame, L["Notify"])
    notifyBtn:SetPoint("LEFT", opFrame, "LEFT", startX + Layout.BUTTON_WIDTH + Layout.BUTTON_SPACING, 0)
    
    if item.isHidden then
        -- 隐藏状态：禁用按钮，显示灰色效果，不响应点击
        refreshBtn:SetEnabled(false)
        notifyBtn:SetEnabled(false)
    else
        -- 正常状态：启用按钮，设置点击事件
        refreshBtn:SetEnabled(true)
        notifyBtn:SetEnabled(true)
        refreshBtn:SetScript("OnClick", function()
            if self.callbacks.onRefresh then self.callbacks.onRefresh(item.id) end
        end)
        notifyBtn:SetScript("OnClick", function()
            if self.callbacks.onNotify then self.callbacks.onNotify(item.id) end
        end)
    end

    row:EnableMouse(true)
    row:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and MainPanel and MainPanel.ClearTempAction then
            if not (MainPanel.tempActionFrame and MainPanel.tempActionFrame:IsShown() and MainPanel.tempActionFrame:IsMouseOver()) then
                MainPanel:ClearTempAction()
            end
        end
    end)
    row:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" and self.callbacks.onRightClick then
            self.callbacks.onRightClick(item.id, item.isHidden, opFrame, refreshBtn, notifyBtn, row)
        end
    end)
    row:SetScript("OnEnter", function()
        bg:SetColorTexture(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b, 0.2)
    end)
    row:SetScript("OnLeave", function()
        bg:SetColorTexture(0, 0, 0, index % 2 == 0 and 0.1 or 0.2)
    end)

    table.insert(self.rowFrames, {
        frame = row,
        refreshBtn = refreshBtn,
        notifyBtn = notifyBtn,
        actionFrame = nil,
        index = index,
        id = item.id,
        mapID = item.mapID,
        mapFS = mapFS,
        phaseFS = phaseFS,
        lastFS = lastFS,
        remainingFS = remainingFS,
    })
end
function TableWidget:GetRowFrameById(mapId)
    for _, row in ipairs(self.rowFrames) do
        if row.id == mapId or row.mapID == mapId then
            return row
        end
    end
end

function TableWidget:ApplyHiddenStyle(mapId)
    local row = self:GetRowFrameById(mapId)
    if not row then return end
    local gray = {GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b}
    for _, fs in ipairs({row.mapFS, row.phaseFS, row.lastFS, row.remainingFS}) do
        if fs then fs:SetTextColor(unpack(gray)) end
    end
    -- 禁用按钮而不是隐藏，显示灰色效果
    if row.refreshBtn then row.refreshBtn:SetEnabled(false) end
    if row.notifyBtn then row.notifyBtn:SetEnabled(false) end
end

function TableWidget:AnimateRowToBottom(mapId, onComplete)
    local row = self:GetRowFrameById(mapId)
    if not row or not row.frame or not row.index then
        if onComplete then onComplete() end
        return
    end
    local total = #self.rowFrames
    if total <= 1 then
        if onComplete then onComplete() end
        return
    end
    local startY = -(row.index - 1) * Layout.ROW_HEIGHT
    local targetY = -(total - 1) * Layout.ROW_HEIGHT
    local duration, frameRate = 0.35, 30
    local tickTime = 1 / frameRate
    local elapsed = 0
    if row.animTimer then row.animTimer:Cancel() end
    row.animTimer = C_Timer.NewTicker(tickTime, function(t)
        elapsed = elapsed + tickTime
        local progress = math.min(elapsed / duration, 1)
        local eased = 1 - (1 - progress) * (1 - progress) * (1 - progress)
        local y = startY + (targetY - startY) * eased
        row.frame:ClearAllPoints()
        row.frame:SetPoint("TOPLEFT", self.contentFrame, "TOPLEFT", 0, y)
        row.frame:SetPoint("TOPRIGHT", self.contentFrame, "TOPRIGHT", 0, y)
        if progress >= 1 then
            if row.animTimer then row.animTimer:Cancel() end
            row.animTimer = nil
            if onComplete then onComplete() end
        end
    end)
end

function TableWidget:Refresh(data)
    self.cachedData = data or {}
    SafeExecute(function()
        self:ClearRows()
        local sorted = self:SortItems(self.cachedData)
        for i, item in ipairs(sorted) do
            self:CreateRow(item, i)
        end
        -- 确保内容区域有足够高度（默认7行）
        local n = #sorted
        local minH = Layout.ROW_HEIGHT * 7
        local h = math.max(n * Layout.ROW_HEIGHT, minH)
        self.contentFrame:SetHeight(h)
        self.frame:SetHeight(Layout.HEADER_HEIGHT + h + 2)
    end)
end

function TableWidget:UpdateCountdowns()
    for _, row in ipairs(self.rowFrames) do
        if row and row.id and row.remainingFS then
            local isHidden = CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.hiddenMaps and row.mapID and CRATETRACKERZK_UI_DB.hiddenMaps[row.mapID]
            local frozenRemaining = CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.hiddenRemaining and row.mapID and CRATETRACKERZK_UI_DB.hiddenRemaining[row.mapID]
            
            if isHidden then
                -- 隐藏地图：倒计时固定为灰色，使用冻结值；无冻结值时显示默认占位
                local val = frozenRemaining
                if val and val < 0 then val = 0 end
                local text = (val ~= nil and UnifiedDataManager:FormatTime(val)) or (L["NoRecord"] or "--:--")
                row.remainingFS:SetText(text)
                row.remainingFS:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
            else
                -- 直接使用UnifiedDataManager获取剩余时间
                local remaining = UnifiedDataManager and UnifiedDataManager.GetRemainingTime and UnifiedDataManager:GetRemainingTime(row.id);
                
                -- 如果UnifiedDataManager没有数据，使用Data模块作为回退
                if not remaining then
                    local mapData = Data:GetMap(row.id)
                    if mapData then
                        -- 检查是否需要更新过期的nextRefresh时间
                        local now = time()
                        if mapData.nextRefresh and mapData.lastRefresh and mapData.nextRefresh <= now then
                            Data:UpdateNextRefresh(mapData.id, mapData)
                        end
                        -- 直接计算剩余时间
                        if mapData.nextRefresh then
                            remaining = mapData.nextRefresh - now;
                            if remaining < 0 then remaining = 0; end
                        end
                    end
                end
                
                local text = remaining and UnifiedDataManager:FormatTime(remaining) or (L["NoRecord"] or "--:--")
                local color = {1,1,1}
                if remaining then
                    if remaining < 300 then color = {1,0,0}
                    elseif remaining < 900 then color = {1,0.5,0}
                    else color = {0,1,0} end
                end
                row.remainingFS:SetText(text)
                row.remainingFS:SetTextColor(unpack(color))
            end
        end
    end
end
-- MainPanel --------------------------------------------------
local MainPanel = BuildEnv("MainPanel")
MainPanel.lastNotifyClickTime = {}
MainPanel.NOTIFY_BUTTON_COOLDOWN = 0.5
MainPanel.tempActionButton = nil
MainPanel.tempActionFrame = nil
MainPanel.tempTargetRow = nil
MainPanel.clickGuard = nil

local function BuildMenu(parent)
    local menuButton = CreateFrame("Button", nil, parent)
    menuButton:SetSize(20, 20)
    -- 相对于关闭按钮，向左偏移更多距离避免重叠，并微调垂直位置实现完美居中
    menuButton:SetPoint("RIGHT", parent.CloseButton, "LEFT", -16, 2)
    menuButton:SetHitRectInsets(-4, -4, -4, -4)

    local menuText = menuButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    menuText:SetPoint("CENTER")
    menuText:SetText("...") -- 使用普通省略号，避免粗体超出
    menuText:SetTextColor(0.85, 0.85, 0.85, 1)

    menuButton:SetScript("OnEnter", function() menuText:SetTextColor(1,1,1,1) end)
    menuButton:SetScript("OnLeave", function() menuText:SetTextColor(0.85,0.85,0.85,1) end)
    menuButton:SetScript("OnMouseDown", function() menuText:SetTextColor(0.65,0.65,0.65,1) end)
    menuButton:SetScript("OnMouseUp", function()
        local over = menuButton:IsMouseOver()
        menuText:SetTextColor(over and 1 or 0.85, over and 1 or 0.85, over and 1 or 0.85, 1)
    end)

    local menuFrame = CreateFrame("Frame", nil, UIParent)
    menuFrame:SetSize(120, 60)
    menuFrame:SetFrameStrata("DIALOG")
    local border = menuFrame:CreateTexture(nil, "BORDER")
    border:SetAllPoints()
    border:SetColorTexture(0.2, 0.2, 0.2, 1)
    local bg = menuFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", border, "TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", -1, 1)
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)
    menuFrame:Hide()

    local function createItem(text, order, onclick)
        local b = CreateFrame("Button", nil, menuFrame)
        b:SetSize(118, 26)
        b:SetPoint("TOP", menuFrame, "TOP", 0, -2 - (order - 1) * 26)
        local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetPoint("CENTER")
        t:SetText(text)
        t:SetTextColor(0.9,0.9,0.9,1)
        local h = b:CreateTexture(nil, "HIGHLIGHT")
        h:SetAllPoints()
        h:SetColorTexture(1,1,1,0.1)
        b:SetScript("OnClick", function()
            menuFrame:Hide()
            onclick()
        end)
    end

    createItem(L["MenuHelp"] or "Help", 1, function() MainPanel:ShowHelpDialog() end)
    createItem(L["MenuAbout"] or "About", 2, function() MainPanel:ShowAboutDialog() end)

    menuButton:SetScript("OnClick", function()
        if menuFrame:IsShown() then
            menuFrame:Hide()
        else
            menuFrame:ClearAllPoints()
            menuFrame:SetPoint("TOPRIGHT", menuButton, "BOTTOMRIGHT", 0, -4)
            menuFrame:Show()
        end
    end)
end

function MainPanel:CreateMainFrame()
    if CrateTrackerZKFrame then return CrateTrackerZKFrame end
    local frame = CreateFrame("Frame", "CrateTrackerZKFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(Layout.FRAME_WIDTH, Layout.FRAME_HEIGHT)
    if CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.position then
        local pos = CRATETRACKERZK_UI_DB.position
        frame:SetPoint(pos.point, pos.x, pos.y)
    else
        frame:SetPoint("CENTER")
    end
    frame.TitleText:SetText(L["MainPanelTitle"] or "CrateTrackerZK")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        CRATETRACKERZK_UI_DB = CRATETRACKERZK_UI_DB or {}
        CRATETRACKERZK_UI_DB.position = { point = point, x = x, y = y }
    end)
    frame.CloseButton:SetScript("OnClick", function()
        frame:Hide()
        if CrateTrackerZKFloatingButton then
            CrateTrackerZKFloatingButton:Show()
        elseif CrateTrackerZK and CrateTrackerZK.CreateFloatingButton then
            CrateTrackerZK:CreateFloatingButton()
        end
    end)

    BuildMenu(frame)

    local content = frame
    -- 移除手动输入功能：不再传递onEditTime回调
    self.tableWidget = TableWidget:new(content, {
        onRefresh = function(mapId) self:RefreshMap(mapId) end,
        onNotify = function(mapId) self:NotifyMapById(mapId) end,
        onRightClick = function(mapId, isHidden, opFrame, refreshBtn, notifyBtn, rowFrame) self:OnRowRightClick(mapId, isHidden, opFrame, refreshBtn, notifyBtn, rowFrame) end,
        onRowLeave = function() self:ClearTempAction() end,
    })
    self.tableWidget:Create()
    -- 仅表格区域监听左键关闭临时按钮
    local function bindTableClickClose(target)
        if target and target.SetScript then
            target:EnableMouse(true)
            target:SetScript("OnMouseDown", function(_, btn)
                if btn == "LeftButton" and self.tempActionFrame and self.tempActionFrame:IsShown() then
                    if not self.tempActionFrame:IsMouseOver() then
                        self:ClearTempAction()
                    end
                end
            end)
        end
    end
    bindTableClickClose(self.tableWidget.frame)
    bindTableClickClose(self.tableWidget.headerFrame)
    bindTableClickClose(self.tableWidget.contentFrame)
    frame:SetScript("OnMouseDown", function(_, btn)
        if (btn == "LeftButton" or btn == "RightButton") and self.tempActionFrame then
            if not self.tempActionFrame:IsMouseOver() then
                self:ClearTempAction()
            end
        end
    end)

    -- 初次填充数据
    self:UpdateTable(true)

    -- 每秒仅更新倒计时文本
    self:StartUpdateTimer()

    self.mainFrame = frame
    self.helpDialog = Dialog:new(L["MenuHelp"] or "Help", 600, 500)
    self.aboutDialog = Dialog:new(L["MenuAbout"] or "About", 520, 420)
    frame:Hide()
    return frame
end

function MainPanel:StartUpdateTimer()
    if self.updateTimer then return end
    self.updateTimer = C_Timer.NewTicker(1, function()
        if CrateTrackerZKFrame and CrateTrackerZKFrame:IsShown() and self.tableWidget then
            self.tableWidget:UpdateCountdowns()
        end
    end)
end

function MainPanel:StopUpdateTimer()
    if self.updateTimer then
        self.updateTimer:Cancel()
        self.updateTimer = nil
    end
end
function MainPanel:Toggle()
    if not CrateTrackerZKFrame then self:CreateMainFrame() end
    if CrateTrackerZKFrame:IsShown() then
        CrateTrackerZKFrame:Hide()
        if CrateTrackerZKFloatingButton then CrateTrackerZKFloatingButton:Show() end
    else
        CrateTrackerZKFrame:Show()
        self:UpdateTable(true)
        if CrateTrackerZKFloatingButton then CrateTrackerZKFloatingButton:Hide() end
    end
end

function MainPanel:UpdateTable(skipVisibilityCheck)
    if not self.tableWidget then return end
    if not skipVisibilityCheck and (not CrateTrackerZKFrame or not CrateTrackerZKFrame:IsShown()) then
        return
    end
    local data = PrepareTableData()
    self.tableWidget:Refresh(data)
end

function MainPanel:RefreshMap(mapId)
    if not mapId then 
        Logger:Debug("MainPanel", "错误", "RefreshMap: mapId为空")
        return false 
    end
    local mapData = Data:GetMap(mapId)
    if not mapData then 
        Logger:Debug("MainPanel", "错误", string.format("RefreshMap: 找不到地图数据，mapId=%s", tostring(mapId)))
        return false 
    end
    local now = time()
    
    Logger:Debug("MainPanel", "刷新", string.format("RefreshMap开始：mapId=%d，时间=%d", mapId, now))
    
    -- 直接调用TimerManager:StartTimer，它会处理UnifiedDataManager的调用
    local success = false
    if TimerManager and TimerManager.StartTimer then
        Logger:Debug("MainPanel", "调试", string.format("调用TimerManager:StartTimer，mapId=%d，source=%s", 
            mapId, TimerManager.detectionSources.REFRESH_BUTTON))
        success = TimerManager:StartTimer(mapId, TimerManager.detectionSources.REFRESH_BUTTON, now)
        if success then
            Logger:Debug("MainPanel", "成功", string.format("RefreshMap成功：mapId=%d", mapId))
            self:UpdateTable(true)
            return true
        else
            Logger:Error("MainPanel", "错误", string.format("刷新时间设置失败：mapId=%d", mapId))
            return false
        end
    else
        -- 回退到原有逻辑
        Logger:Debug("MainPanel", "回退", "TimerManager不可用，使用原有逻辑")
        mapData.lastRefresh = now
        mapData.currentAirdropObjectGUID = nil
        mapData.currentAirdropTimestamp = nil
        Data:UpdateNextRefresh(mapId, mapData)
        self:UpdateTable(true)
        return true
    end
end

function MainPanel:NotifyMapById(mapId)
    if not mapId then return end
    local now = GetTime()
    local last = self.lastNotifyClickTime[mapId] or 0
    if now - last < self.NOTIFY_BUTTON_COOLDOWN then return end
    self.lastNotifyClickTime[mapId] = now
    local mapData = Data:GetMap(mapId)
    if mapData then self:NotifyMapRefresh(mapData) end
end

function MainPanel:NotifyMapRefresh(mapData)
    if not Notification or not mapData then return end
    local currentMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or (Area and Area:GetCurrentMapId() or nil)
    local isAirdropActive = false
    if currentMapID and MapTracker and MapTracker.GetTargetMapData then
        local target = MapTracker:GetTargetMapData(currentMapID)
        if target and target.id == mapData.id then
            if IconDetector and IconDetector.DetectIcon then
                local res = IconDetector:DetectIcon(currentMapID)
                if res and res.detected then isAirdropActive = true end
            end
        end
    end
    Notification:NotifyMapRefresh(mapData, isAirdropActive)
end

-- 右键删除/恢复：点击任意位置还原，删除带下移动画
function MainPanel:OnRowRightClick(mapId, isHidden, opFrame, refreshBtn, notifyBtn, rowFrame)
    if not mapId then return end
    self:ClearTempAction()

    local actionFrame = CreateFrame("Frame", nil, opFrame or UIParent)
    actionFrame:SetSize(90, Layout.ROW_HEIGHT)
    actionFrame:SetPoint("CENTER", opFrame or UIParent, "CENTER", 0, 0)
    actionFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    actionFrame:SetFrameLevel((opFrame and opFrame:GetFrameLevel() or 0) + 50)

    -- 隐藏按钮（现在按钮始终存在）
    if refreshBtn then refreshBtn:Hide() end
    if notifyBtn then notifyBtn:Hide() end

    local btnText = isHidden and (L["Restore"] or "Restore") or (L["Delete"] or "Delete")
    local btn = CreateButton(actionFrame, btnText, 80, 25)
    btn:SetPoint("CENTER", actionFrame, "CENTER", 0, 0)
    btn:SetScript("OnClick", function()
        if isHidden then
            self:RestoreMap(mapId)
            self:ClearTempAction()
            self:UpdateTable(true)
        else
            self:HideMap(mapId)
            if self.tableWidget then
                self.tableWidget:ApplyHiddenStyle(mapId)
                self.tableWidget:AnimateRowToBottom(mapId, function()
                    self:UpdateTable(true)
                end)
            else
                self:UpdateTable(true)
            end
            self:ClearTempAction(true)
        end
    end)

    self.tempActionButton = btn
    self.tempActionFrame = actionFrame
    self.tempTargetRow = { refreshBtn = refreshBtn, notifyBtn = notifyBtn, rowFrame = rowFrame }

    -- 表格区域左键点击已处理，这里不创建全屏拦截
end

function MainPanel:ClearTempAction(keepButtonsHidden)
    if self.tempActionButton then
        self.tempActionButton:Hide()
        self.tempActionButton = nil
    end
    if self.tempActionFrame then
        self.tempActionFrame:Hide()
        self.tempActionFrame = nil
    end
    if self.tempTargetRow then
        if not keepButtonsHidden and self.tempTargetRow.refreshBtn then
            self.tempTargetRow.refreshBtn:Show()
        end
        if not keepButtonsHidden and self.tempTargetRow.notifyBtn then
            self.tempTargetRow.notifyBtn:Show()
        end
        self.tempTargetRow = nil
    end
    if self.clickGuard then
        self.clickGuard:Hide()
    end
end

function MainPanel:HideMap(mapId)
    if not mapId then return end
    CRATETRACKERZK_UI_DB = CRATETRACKERZK_UI_DB or {}
    CRATETRACKERZK_UI_DB.hiddenMaps = CRATETRACKERZK_UI_DB.hiddenMaps or {}
    CRATETRACKERZK_UI_DB.hiddenRemaining = CRATETRACKERZK_UI_DB.hiddenRemaining or {}
    local mapData = Data:GetMap(mapId)
    if mapData then
        CRATETRACKERZK_UI_DB.hiddenMaps[mapData.mapID] = true
        local remaining = UnifiedDataManager:GetRemainingTime(mapData.id)
        if remaining and remaining < 0 then remaining = 0 end
        CRATETRACKERZK_UI_DB.hiddenRemaining[mapData.mapID] = remaining
    end
end

function MainPanel:RestoreMap(mapId)
    if not mapId then return end
    if CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.hiddenMaps then
        local mapData = Data:GetMap(mapId)
        if mapData then
            CRATETRACKERZK_UI_DB.hiddenMaps[mapData.mapID] = nil
            if CRATETRACKERZK_UI_DB.hiddenRemaining then
                CRATETRACKERZK_UI_DB.hiddenRemaining[mapData.mapID] = nil
            end
        end
    end
end

function MainPanel:ShowHelpDialog()
    if not self.helpDialog then
        self.helpDialog = Dialog:new(L["MenuHelp"] or "Help", 600, 500)
    end
    
    -- 使用已引用的Help模块
    local helpText = Help and Help.GetHelpText and Help:GetHelpText() or (L["HelpText"] or "Help text not available")
    
    self.helpDialog:SetTitle(L["MenuHelp"] or "Help")
    self.helpDialog:SetContent(helpText)
    self.helpDialog:Show()
end

function MainPanel:ShowAboutDialog()
    if not self.aboutDialog then
        self.aboutDialog = Dialog:new(L["MenuAbout"] or "About", 520, 420)
    end
    
    -- 使用统一的About模块
    local aboutText = About and About.GetAboutText and About:GetAboutText() or "About information not available"
    
    self.aboutDialog:SetTitle(L["MenuAbout"] or "About")
    self.aboutDialog:SetContent(aboutText)
    self.aboutDialog:Show()
end

return MainPanel

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;
local MainPanel = BuildEnv('MainPanel')

-- 按钮点击防抖（防止快速连续点击）
MainPanel.lastNotifyClickTime = {};
MainPanel.NOTIFY_BUTTON_COOLDOWN = 0.5; -- 按钮点击冷却时间（秒）

local locale = GetLocale();
local isChineseLocale = (locale == "zhCN" or locale == "zhTW");

local Layout = {
    FRAME_WIDTH  = isChineseLocale and 550 or 590,
    FRAME_HEIGHT = 320,
    
    TABLE = {
        HEADER_HEIGHT = 32,
        ROW_HEIGHT = 32,
        COL_WIDTH = 90,
        MAP_COL_WIDTH = isChineseLocale and 80 or 105,
        OPERATION_COL_WIDTH = 150,
        COL_SPACING = 5,
        COL_COUNT = 5,
        FONT_SIZE = tonumber(L["UIFontSize"]) or 15,
        COLS = {
            { key = "map",       titleKey = "Map" },
            { key = "phase",     titleKey = "Phase" },
            { key = "last",      titleKey = "LastRefresh" },
            { key = "next",      titleKey = "NextRefresh" },
            { key = "operation", titleKey = "Operation" },
        },
    },
    
    BUTTONS = {
        REFRESH_WIDTH = isChineseLocale and 65 or 75,
        REFRESH_HEIGHT = 26,
        NOTIFY_WIDTH = isChineseLocale and 65 or 75,
        NOTIFY_HEIGHT = 26,
        BUTTON_SPACING = 70,
    },
    TITLE_BAR = {
        HEIGHT = 32,
        BUTTON_SIZE = 20,
        BUTTON_SPACING = 4,
        BUTTON_OFFSET_RIGHT = 8,
        DROPDOWN_ITEM_HEIGHT = 28,
    },
};

do
    Layout.TABLE.COL_WIDTHS = {};
    for i = 1, Layout.TABLE.COL_COUNT do
        if i == Layout.TABLE.COL_COUNT then
            Layout.TABLE.COL_WIDTHS[i] = Layout.TABLE.OPERATION_COL_WIDTH;
        elseif i == 1 then
            Layout.TABLE.COL_WIDTHS[i] = Layout.TABLE.MAP_COL_WIDTH;
        else
            Layout.TABLE.COL_WIDTHS[i] = Layout.TABLE.COL_WIDTH;
        end
    end
    
    Layout.TABLE.WIDTH = 0;
    for i = 1, Layout.TABLE.COL_COUNT do
        Layout.TABLE.WIDTH = Layout.TABLE.WIDTH + Layout.TABLE.COL_WIDTHS[i];
        if i < Layout.TABLE.COL_COUNT then
            Layout.TABLE.WIDTH = Layout.TABLE.WIDTH + Layout.TABLE.COL_SPACING;
        end
    end
    
    Layout.TABLE.COL_OFFSETS = {};
    local offset = 0;
    for i = 1, Layout.TABLE.COL_COUNT do
        Layout.TABLE.COL_OFFSETS[i] = offset;
        offset = offset + Layout.TABLE.COL_WIDTHS[i];
        if i < Layout.TABLE.COL_COUNT then
            offset = offset + Layout.TABLE.COL_SPACING;
        end
    end
    
    local titleBarHeight = Layout.TITLE_BAR.HEIGHT;
    local bottomPadding = 40;
    local contentHeight = Layout.FRAME_HEIGHT - titleBarHeight - bottomPadding;
    local tableHeight = contentHeight;
    
    Layout.TABLE.PADDING_X = (Layout.FRAME_WIDTH - Layout.TABLE.WIDTH) / 2;
    Layout.TABLE.PADDING_TOP = titleBarHeight;
    Layout.TABLE.HEIGHT = tableHeight;
end

local function CreateTableCell(parent, colIndex, rowHeight, isHeader)
    if colIndex < 1 or colIndex > Layout.TABLE.COL_COUNT then return nil end;
    
    local cell = CreateFrame('Frame', nil, parent);
    local width = Layout.TABLE.COL_WIDTHS[colIndex];
    local offsetX = Layout.TABLE.COL_OFFSETS[colIndex];
    
    cell:SetSize(width, rowHeight);
    cell:SetPoint('LEFT', parent, 'LEFT', offsetX, 0);
    
    local fontName = isHeader and 'GameFontHighlight' or 'GameFontNormal';
    local textObj = cell:CreateFontString(nil, 'ARTWORK', fontName);
    if colIndex == 1 then
        textObj:SetPoint('LEFT', cell, 'LEFT', 4, 0);
        textObj:SetPoint('RIGHT', cell, 'RIGHT', -2, 0);
        textObj:SetPoint('TOP', cell, 'TOP', 0, 0);
        textObj:SetPoint('BOTTOM', cell, 'BOTTOM', 0, 0);
        textObj:SetJustifyH('LEFT');
    else
        textObj:SetAllPoints(cell);
        textObj:SetJustifyH('CENTER');
    end
    textObj:SetJustifyV('MIDDLE');
    local font, size, flags = textObj:GetFont();
    textObj:SetFont(font, Layout.TABLE.FONT_SIZE, flags);
    if colIndex == 1 then
        textObj:SetNonSpaceWrap(false);
        local textWidth = width - 6;
        if textWidth > 0 then
            textObj:SetWidth(textWidth);
            textObj:SetMaxLines(1);
        end
    end
    cell.Text = textObj;
    
    return cell;
end

local function CreateTableRow(parent, rowIndex, rowHeight)
    local row = CreateFrame('Frame', nil, parent);
    row:SetSize(Layout.TABLE.WIDTH, rowHeight);
    
    row.bg = row:CreateTexture(nil, 'BACKGROUND');
    row.bg:SetAllPoints();
    
    row.columns = {};
    for j = 1, Layout.TABLE.COL_COUNT do
        local cell = CreateTableCell(row, j, rowHeight, false);
        row.columns[j] = cell;
        
        if j == 3 then
            cell.Text:SetTextColor(0.4, 0.8, 1);
            cell:EnableMouse(true);
        elseif j == 5 then
            cell.Text:Hide();
        else
            cell.Text:SetTextColor(1, 1, 1);
        end
    end
    
    local opCell = row.columns[5];
    
    row.refreshBtn = CreateFrame('Button', nil, opCell, 'UIPanelButtonTemplate');
    row.refreshBtn:SetSize(Layout.BUTTONS.REFRESH_WIDTH, Layout.BUTTONS.REFRESH_HEIGHT);
    row.refreshBtn:SetText(L["Refresh"]);
    row.refreshBtn:SetHitRectInsets(-6, -6, -4, -4);
    local refreshFont, refreshSize, refreshFlags = row.refreshBtn.Text:GetFont();
    row.refreshBtn.Text:SetFont(refreshFont, Layout.TABLE.FONT_SIZE, refreshFlags);
    row.refreshBtn:SetPoint('CENTER', opCell, 'CENTER', -Layout.BUTTONS.BUTTON_SPACING / 2, 0);
    
    row.notifyBtn = CreateFrame('Button', nil, opCell, 'UIPanelButtonTemplate');
    row.notifyBtn:SetSize(Layout.BUTTONS.NOTIFY_WIDTH, Layout.BUTTONS.NOTIFY_HEIGHT);
    row.notifyBtn:SetText(L["Notify"]);
    row.notifyBtn:SetHitRectInsets(-6, -6, -4, -4);
    local notifyFont, notifySize, notifyFlags = row.notifyBtn.Text:GetFont();
    row.notifyBtn.Text:SetFont(notifyFont, Layout.TABLE.FONT_SIZE, notifyFlags);
    row.notifyBtn:SetPoint('CENTER', opCell, 'CENTER', Layout.BUTTONS.BUTTON_SPACING / 2, 0);
    
    row.mapDataRef = {};
    
    row.columns[3]:SetScript('OnMouseUp', function()
        if row.mapDataRef.mapId then
            MainPanel:EditLastRefresh(row.mapDataRef.mapId);
        end
    end);
    
    row.refreshBtn:SetScript('OnClick', function()
        -- 确保 mapDataRef 存在且 mapId 有效
        if row.mapDataRef and row.mapDataRef.mapId then
            MainPanel:RefreshMap(row.mapDataRef.mapId);
        else
            -- 如果 mapDataRef 无效，尝试从当前显示的数据获取
            -- 这种情况应该很少发生，但作为安全措施
            Logger:Error("MainPanel", "错误", "Refresh button: Unable to get map ID, please try again later");
        end
    end);
    
    row.notifyBtn:SetScript('OnClick', function()
        -- 按钮点击防抖：防止快速连续点击
        local mapId = row.mapDataRef and row.mapDataRef.mapId;
        if not mapId then
            Logger:Error("MainPanel", "错误", "Notify button: Unable to get map ID");
            return;
        end
        
        local currentTime = GetTime(); -- 使用 GetTime() 获取更精确的时间
        local lastClickTime = MainPanel.lastNotifyClickTime[mapId] or 0;
        local timeSinceLastClick = currentTime - lastClickTime;
        
        if timeSinceLastClick < MainPanel.NOTIFY_BUTTON_COOLDOWN then
            -- 在冷却期内，忽略点击
            Logger:Debug("MainPanel", "调试", string.format("通知按钮点击过快（距离上次 %.2f 秒，需要 %.2f 秒），忽略", 
                timeSinceLastClick, MainPanel.NOTIFY_BUTTON_COOLDOWN));
            return;
        end
        
        -- 记录点击时间
        MainPanel.lastNotifyClickTime[mapId] = currentTime;
        
        -- 直接从 Data 模块获取最新数据，避免使用可能过时的 mapDataRef
        if Data then
            local mapData = Data:GetMap(mapId);
            if mapData then
                MainPanel:NotifyMapRefresh(mapData);
            else
                Logger:Error("MainPanel", "错误", string.format("Unable to get map data, Map ID=%s", tostring(mapId)));
            end
        else
            Logger:Error("MainPanel", "错误", "Data module not loaded");
        end
    end);
    
    return row;
end

local function CreateTable(frame)
    local tableContainer = CreateFrame('Frame', nil, frame);
    tableContainer:SetSize(Layout.TABLE.WIDTH, Layout.TABLE.HEIGHT);
    tableContainer:SetPoint('TOPLEFT', frame, 'TOPLEFT', Layout.TABLE.PADDING_X, -Layout.TABLE.PADDING_TOP);
    
    local tableHeader = CreateFrame('Frame', nil, tableContainer);
    tableHeader:SetSize(Layout.TABLE.WIDTH, Layout.TABLE.HEADER_HEIGHT);
    tableHeader:SetPoint('TOPLEFT', tableContainer, 'TOPLEFT', 0, 0);
    
    local headerBg = tableHeader:CreateTexture(nil, 'BACKGROUND');
    headerBg:SetAllPoints();
    headerBg:SetColorTexture(0.12, 0.12, 0.12, 0.95);
    
    local headerCells = {};
    for i = 1, Layout.TABLE.COL_COUNT do
        local col = Layout.TABLE.COLS[i];
        local cell = CreateTableCell(tableHeader, i, Layout.TABLE.HEADER_HEIGHT, true);
        cell.Text:SetText(L[col.titleKey]);
        
        if i == 3 or i == 4 then
            local highlight = cell:CreateTexture(nil, 'HIGHLIGHT');
            highlight:SetTexture([[Interface\PaperDollInfoFrame\UI-Character-Tab-Highlight]]);
            highlight:SetBlendMode('ADD');
            highlight:SetAllPoints();
            
            local sortField = (i == 3) and 'lastRefresh' or 'remaining';
            cell.sortField = sortField;
            cell:EnableMouse(true);
            cell:SetScript('OnMouseUp', function() MainPanel:SortTable(sortField) end);
        end
        
        headerCells[i] = cell;
    end
    
    local tableContent = CreateFrame('Frame', nil, tableContainer);
    tableContent:SetSize(Layout.TABLE.WIDTH, tableContainer:GetHeight() - Layout.TABLE.HEADER_HEIGHT);
    tableContent:SetPoint('TOPLEFT', tableContainer, 'TOPLEFT', 0, -Layout.TABLE.HEADER_HEIGHT);
    
    frame.tableContainer = tableContainer;
    frame.tableHeader = tableHeader;
    frame.tableContent = tableContent;
    frame.headerCells = headerCells;
    frame.tableRows = {};
    
    return tableContainer;
end

function MainPanel:CreateMainFrame()
    if CrateTrackerZKFrame then return CrateTrackerZKFrame end
    
    if MainPanel.updateTimer then
        MainPanel.updateTimer:Cancel();
        MainPanel.updateTimer = nil;
    end
    
    local frame = CreateFrame('Frame', 'CrateTrackerZKFrame', UIParent, 'BasicFrameTemplateWithInset');
    frame:SetSize(Layout.FRAME_WIDTH, Layout.FRAME_HEIGHT);
    
    if CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.position then
        local pos = CRATETRACKERZK_UI_DB.position;
        frame:SetPoint(pos.point, pos.x, pos.y);
    else
        frame:SetPoint('CENTER');
    end
    
    frame.TitleText:SetText(L["MainPanelTitle"]);
    
    if frame.CloseButton then
        frame.CloseButton:SetScript('OnClick', function()
            frame:Hide();
            if CrateTrackerZKFloatingButton then
                CrateTrackerZKFloatingButton:Show();
            elseif CrateTrackerZK and CrateTrackerZK.CreateFloatingButton then
                CrateTrackerZK:CreateFloatingButton();
            end
        end);
    end
    
    frame:SetMovable(true);
    frame:EnableMouse(true);
    
    if frame.TitleRegion then
        frame.TitleRegion:RegisterForDrag('LeftButton');
        local originalOnDragStop = frame.TitleRegion:GetScript('OnDragStop');
        frame.TitleRegion:SetScript('OnDragStop', function(self)
            if originalOnDragStop then
                originalOnDragStop(self);
            end
            frame:StopMovingOrSizing();
            local point, _, _, x, y = frame:GetPoint();
            if CRATETRACKERZK_UI_DB then
                CRATETRACKERZK_UI_DB.position = { point = point, x = x, y = y };
            end
        end);
    else
        frame:RegisterForDrag('LeftButton');
        frame:SetScript('OnDragStart', frame.StartMoving);
        frame:SetScript('OnDragStop', function(self)
            self:StopMovingOrSizing();
            local point, _, _, x, y = self:GetPoint();
            if CRATETRACKERZK_UI_DB then
                CRATETRACKERZK_UI_DB.position = { point = point, x = x, y = y };
            end
        end);
    end
    
    self:CreateInfoButton(frame);
    CreateTable(frame);
    
    frame.sortField = nil;
    frame.sortOrder = nil; -- nil = 默认顺序, 'asc' = 正序, 'desc' = 倒序
    
    MainPanel.updateTimer = C_Timer.NewTicker(1, function() MainPanel:UpdateTable() end);
    
    function frame:Toggle() MainPanel:Toggle() end
    MainPanel.mainFrame = frame;
    return frame;
end

function MainPanel:SortTable(field)
    local frame = self.mainFrame;
    if not frame then return end
    
    -- 三种状态循环：正序 -> 倒序 -> 默认顺序 -> 正序
    if frame.sortField == field then
        -- 同一个字段，在三种状态间循环
        if frame.sortOrder == 'asc' then
            frame.sortOrder = 'desc';  -- 正序 -> 倒序
        elseif frame.sortOrder == 'desc' then
            frame.sortField = nil;     -- 倒序 -> 默认顺序（清除排序）
            frame.sortOrder = nil;
        else
            -- 这种情况不应该发生，但作为安全措施
            frame.sortField = field;
            frame.sortOrder = 'asc';
        end
    else
        -- 不同字段，设置为新字段的正序
        frame.sortField = field;
        frame.sortOrder = 'asc';
    end
    
    self:UpdateTable();
end


local function CreateSortComparator(sortField, sortOrder)
    return function(a, b)
        if not a or not b then
            if not a then return false end
            if not b then return true end
        end
        
        local aVal = a[sortField];
        local bVal = b[sortField];
        
        if not aVal and not bVal then
            return false;
        end
        if not aVal then
            return false;
        end
        if not bVal then
            return true;
        end
        
        if sortOrder == 'asc' then
            return aVal < bVal;
        else
            return aVal > bVal;
        end
    end;
end

local function PrepareTableData()
    if not Data then return {} end
    
    local maps = Data:GetAllMaps();
    if not maps then return {} end
    
    local currentTime = time();
    local mapArray = {};
    for _, mapData in ipairs(maps) do
        if mapData then
            -- 检查并更新已过期的刷新时间（倒计时结束后自动计算下一个刷新时间）
            -- 优化：只在真正过期时才更新，避免频繁调用
            if mapData.nextRefresh and mapData.lastRefresh and mapData.nextRefresh <= currentTime then
                Data:UpdateNextRefresh(mapData.id, mapData);
            end
            
            -- 优化：直接计算剩余时间，避免不必要的复制
            local remaining = Data:CalculateRemainingTime(mapData.nextRefresh);
            
            -- 只复制需要的数据字段，减少内存占用
            local mapDataCopy = {
                id = mapData.id,
                mapID = mapData.mapID,
                interval = mapData.interval,
                instance = mapData.instance,
                lastInstance = mapData.lastInstance,
                lastRefreshInstance = mapData.lastRefreshInstance,
                lastRefresh = mapData.lastRefresh,
                nextRefresh = mapData.nextRefresh,
                remaining = remaining,
                _original = mapData
            };
            table.insert(mapArray, mapDataCopy);
        end
    end
    return mapArray;
end

function MainPanel:UpdateTable()
    local frame = self.mainFrame;
    if not frame or not frame:IsShown() then return end
    
    -- UI只负责显示，不处理数据
    -- 数据更新应该由定时器或其他模块负责
    -- UI更新信息限流很长，避免刷屏（关键信息在其他模块输出）
    Logger:DebugLimited("ui_update:table", "MainPanel", "界面", "更新表格显示");
    local mapArray = PrepareTableData();
    
    -- 只有在有排序字段且排序顺序不为 nil 时才排序
    if frame.sortField and frame.sortOrder and (frame.sortField == 'lastRefresh' or frame.sortField == 'remaining') then
        local comparator = CreateSortComparator(frame.sortField, frame.sortOrder);
        table.sort(mapArray, comparator);
    end
    
    local rowHeight = Layout.TABLE.ROW_HEIGHT;
    for i = 1, #frame.tableRows do
        frame.tableRows[i]:Hide();
    end
    
    for i, mapData in ipairs(mapArray) do
        local row = frame.tableRows[i];
        if not row then
            row = CreateTableRow(frame.tableContent, i, rowHeight);
            frame.tableRows[i] = row;
        end
        
        row:ClearAllPoints();
        row:SetPoint('TOPLEFT', frame.tableContent, 'TOPLEFT', 0, -(i - 1) * rowHeight);
        
        if not row.mapDataRef then
            row.mapDataRef = {};
        end
        row.mapDataRef.mapId = mapData.id;
        row.mapDataRef.mapData = mapData._original or mapData;
        
        row.bg:SetColorTexture(0.1, 0.1, 0.1, i % 2 == 0 and 0.5 or 0.3);
        
        row.columns[1].Text:SetText(Data:GetMapDisplayName(mapData));
        
        local instanceID = mapData.instance;
        local instanceText = L["NotAcquired"] or "N/A";
        local color = {1, 1, 1};
        
        if instanceID then
            instanceText = tostring(instanceID):sub(-5);
            -- 使用 DetectionState 模块检查空投状态
            local isAirdrop = false;
            if DetectionState then
                local state = DetectionState:GetState(mapData.id);
                isAirdrop = (state and state.status == DetectionState.STATES.PROCESSED);
            end
            local currentTime = time();
            local isBeforeRefresh = mapData.nextRefresh and currentTime < mapData.nextRefresh;
            
            if mapData.nextRefresh and currentTime >= mapData.nextRefresh then
                color = {1, 1, 1};
            elseif isAirdrop then
                color = {0, 1, 0};
            elseif isBeforeRefresh and mapData.lastRefreshInstance and instanceID ~= mapData.lastRefreshInstance then
                color = {1, 0, 0};
            else
                color = {0, 1, 0};
            end
        end
        row.columns[2].Text:SetText(instanceText);
        row.columns[2].Text:SetTextColor(unpack(color));
        
        local lastRefreshText = mapData.lastRefresh and Data:FormatDateTime(mapData.lastRefresh) or (L["NoRecord"] or "--:--");
        row.columns[3].Text:SetText(lastRefreshText);
        
        local remaining = mapData.remaining;
        local remainingText = remaining and Data:FormatTime(remaining, true) or (L["NoRecord"] or "--:--");
        row.columns[4].Text:SetText(remainingText);
        if remaining then
            if remaining < 300 then row.columns[4].Text:SetTextColor(1, 0, 0)
            elseif remaining < 900 then row.columns[4].Text:SetTextColor(1, 0.5, 0)
            else row.columns[4].Text:SetTextColor(0, 1, 0) end
        else
            row.columns[4].Text:SetTextColor(1, 1, 1)
        end
        
        row:Show();
    end
end

function MainPanel:RefreshMap(mapId)
    if not mapId then
        Logger:Error("MainPanel", "错误", "Invalid map ID: " .. tostring(mapId));
        return false;
    end
    
    local mapData = Data:GetMap(mapId);
    if not mapData then
        Logger:Error("MainPanel", "错误", string.format(L["ErrorCannotGetMapData"], tostring(mapId)));
        return false;
    end
    
    Logger:Debug("MainPanel", "用户操作", string.format("用户点击刷新按钮：地图ID=%d，地图=%s", 
        mapId, Data:GetMapDisplayName(mapData)));
    
    -- 立即更新内存数据，用于UI显示
    local currentTimestamp = time();
    mapData.lastRefresh = currentTimestamp;
    mapData.lastRefreshInstance = mapData.instance;
    Data:UpdateNextRefresh(mapId, mapData);
    
    -- 立即更新UI显示
    self:UpdateTable();
    
    -- 异步处理数据保存（刷新按钮已经更新了内存数据和UI，StartTimer只需要保存数据）
    C_Timer.After(0, function()
        if TimerManager then
            TimerManager:StartTimer(mapId, TimerManager.detectionSources.REFRESH_BUTTON, currentTimestamp);
        end
    end);
    
    Logger:Debug("MainPanel", "用户操作", "刷新按钮操作成功");
    return true;
end

function MainPanel:EditLastRefresh(mapId)
    local mapData = Data:GetMap(mapId);
    if not mapData then return end
    
    StaticPopupDialogs['CRATETRACKERZK_EDIT_LASTREFRESH'] = {
        text = L["InputTimeHint"],
        button1 = L["Confirm"],
        button2 = L["Cancel"],
        hasEditBox = true,
        OnAccept = function(sf) 
            local input = sf.EditBox:GetText();
            MainPanel:ProcessInput(mapId, input);
        end,
        EditBoxOnEnterPressed = function(editBox)
            local input = editBox:GetText();
            local success = MainPanel:ProcessInput(mapId, input);
            if success then
                StaticPopup_Hide('CRATETRACKERZK_EDIT_LASTREFRESH');
            end
        end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    };
    StaticPopup_Show('CRATETRACKERZK_EDIT_LASTREFRESH');
end

function MainPanel:ProcessInput(mapId, input)
    local mapData = Data:GetMap(mapId);
    Logger:Debug("MainPanel", "用户操作", string.format("用户手动输入时间：地图ID=%d，地图=%s，输入=%s", 
        mapId, mapData and Data:GetMapDisplayName(mapData) or "未知", input));
    
    -- UI只负责调用统一的接口，不直接处理数据
    if not TimerManager then
        Logger:Error("MainPanel", "错误", "TimerManager module not loaded");
        return false;
    end
    
    -- 解析时间输入（这是UI输入验证，不是数据处理）
    local hh, mm, ss = Utils.ParseTimeInput(input);
    if not hh then 
        Logger:Error("MainPanel", "错误", "Time format error, please enter HH:MM:SS or HHMMSS format"); 
        return false;
    end
    
    -- 转换为时间戳（这是UI输入转换，不是数据处理）
    local ts = Utils.GetTimestampFromTime(hh, mm, ss);
    if not ts then 
        Logger:Error("MainPanel", "错误", "Unable to create valid timestamp"); 
        return false;
    end
    
    Logger:Debug("MainPanel", "用户操作", string.format("时间解析成功：%02d:%02d:%02d -> 时间戳=%d", hh, mm, ss, ts));
    
    -- 通过统一接口处理数据
    local success = TimerManager:StartTimer(mapId, TimerManager.detectionSources.MANUAL_INPUT, ts);
    -- StartTimer 内部已调用 UpdateUI() -> UpdateTable()，无需重复调用
    
    if success then
        Logger:Debug("MainPanel", "用户操作", "手动输入时间操作成功");
    end
    
    return success;
end

function MainPanel:NotifyMapRefresh(mapData)
    if Notification then 
        Notification:NotifyMapRefresh(mapData)
    else 
        Logger:Error("MainPanel", "错误", "Notification module not loaded")
    end
end

function MainPanel:Toggle()
    if not CrateTrackerZKFrame then self:CreateMainFrame() end
    if CrateTrackerZKFrame:IsShown() then
        CrateTrackerZKFrame:Hide();
        if CrateTrackerZKFloatingButton then
            CrateTrackerZKFloatingButton:Show();
        elseif CrateTrackerZK and CrateTrackerZK.CreateFloatingButton then
            CrateTrackerZK:CreateFloatingButton();
        end
    else
        CrateTrackerZKFrame:Show();
        self:UpdateTable();
        if CrateTrackerZKFloatingButton then CrateTrackerZKFloatingButton:Hide() end
    end
end

function MainPanel:CreateInfoButton(parentFrame)
    local config = Layout.TITLE_BAR;
    
    local buttonSize = 20;
    if parentFrame.CloseButton then
        buttonSize = parentFrame.CloseButton:GetWidth();
    end
    
    local menuButton = CreateFrame('Button', nil, parentFrame);
    menuButton:SetSize(buttonSize, buttonSize);
    
    if parentFrame.CloseButton then
        menuButton:SetPoint('TOPRIGHT', parentFrame.CloseButton, 'TOPLEFT', -config.BUTTON_SPACING, 0);
    else
        menuButton:SetPoint('TOPRIGHT', parentFrame, 'TOPRIGHT', -config.BUTTON_OFFSET_RIGHT - buttonSize - config.BUTTON_SPACING, -6);
    end
    
    local iconColor = {0.8, 0.8, 0.8, 1};
    local dotSize = 4;
    local dotSpacing = 5;
    
    local function CreateDot(parent, offsetX, offsetY)
        local dot = parent:CreateTexture(nil, 'ARTWORK');
        dot:SetSize(dotSize, dotSize);
        dot:SetPoint('CENTER', parent, 'CENTER', offsetX, offsetY);
        dot:SetColorTexture(unpack(iconColor));
        return dot;
    end
    
    menuButton.dot1 = CreateDot(menuButton, -dotSpacing, 0);
    menuButton.dot2 = CreateDot(menuButton, 0, 0);
    menuButton.dot3 = CreateDot(menuButton, dotSpacing, 0);
    
    local function UpdateIconColor(r, g, b, a)
        a = a or 1;
        menuButton.dot1:SetColorTexture(r, g, b, a);
        menuButton.dot2:SetColorTexture(r, g, b, a);
        menuButton.dot3:SetColorTexture(r, g, b, a);
    end
    
    menuButton:SetScript('OnEnter', function(self)
        UpdateIconColor(1, 1, 1, 1);
    end);
    
    menuButton:SetScript('OnLeave', function(self)
        UpdateIconColor(0.8, 0.8, 0.8, 1);
    end);
    
    menuButton:SetScript('OnMouseDown', function(self)
        UpdateIconColor(0.5, 0.5, 0.5, 1);
    end);
    
    menuButton:SetScript('OnMouseUp', function(self)
        UpdateIconColor(1, 1, 1, 1);
    end);
    
    local dropdownMenu = CreateFrame('Frame', nil, parentFrame);
    dropdownMenu:SetSize(120, 1);
    dropdownMenu:SetPoint('TOPRIGHT', menuButton, 'BOTTOMRIGHT', 0, -2);
    dropdownMenu:SetFrameStrata('DIALOG');
    dropdownMenu:Hide();
    
    local bg = dropdownMenu:CreateTexture(nil, 'BACKGROUND');
    bg:SetAllPoints();
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.95);
    
    local borderSize = 1;
    local borderColor = {0.5, 0.5, 0.5, 1};
    
    local topBorder = dropdownMenu:CreateTexture(nil, 'BORDER');
    topBorder:SetPoint('TOPLEFT', dropdownMenu, 'TOPLEFT', 0, 0);
    topBorder:SetPoint('TOPRIGHT', dropdownMenu, 'TOPRIGHT', 0, 0);
    topBorder:SetHeight(borderSize);
    topBorder:SetColorTexture(unpack(borderColor));
    
    local bottomBorder = dropdownMenu:CreateTexture(nil, 'BORDER');
    bottomBorder:SetPoint('BOTTOMLEFT', dropdownMenu, 'BOTTOMLEFT', 0, 0);
    bottomBorder:SetPoint('BOTTOMRIGHT', dropdownMenu, 'BOTTOMRIGHT', 0, 0);
    bottomBorder:SetHeight(borderSize);
    bottomBorder:SetColorTexture(unpack(borderColor));
    
    local leftBorder = dropdownMenu:CreateTexture(nil, 'BORDER');
    leftBorder:SetPoint('TOPLEFT', dropdownMenu, 'TOPLEFT', 0, 0);
    leftBorder:SetPoint('BOTTOMLEFT', dropdownMenu, 'BOTTOMLEFT', 0, 0);
    leftBorder:SetWidth(borderSize);
    leftBorder:SetColorTexture(unpack(borderColor));
    
    local rightBorder = dropdownMenu:CreateTexture(nil, 'BORDER');
    rightBorder:SetPoint('TOPRIGHT', dropdownMenu, 'TOPRIGHT', 0, 0);
    rightBorder:SetPoint('BOTTOMRIGHT', dropdownMenu, 'BOTTOMRIGHT', 0, 0);
    rightBorder:SetWidth(borderSize);
    rightBorder:SetColorTexture(unpack(borderColor));
    
    local menuItems = {
        {
            text = L["MenuHelp"],
            func = function()
                if Info then
                    Info:ShowIntroduction();
                end
                dropdownMenu:Hide();
            end,
        },
        {
            text = L["MenuAbout"],
            func = function()
                if Info then
                    Info:ShowAnnouncement();
                end
                dropdownMenu:Hide();
            end,
        },
    };
    
    local itemHeight = config.DROPDOWN_ITEM_HEIGHT;
    local menuButtons = {};
    for i, item in ipairs(menuItems) do
        local itemButton = CreateFrame('Button', nil, dropdownMenu);
        itemButton:SetSize(120, itemHeight);
        itemButton:SetPoint('TOPLEFT', dropdownMenu, 'TOPLEFT', 0, -(i - 1) * itemHeight);
        
        local text = itemButton:CreateFontString(nil, 'OVERLAY', 'GameFontNormal');
        text:SetAllPoints();
        text:SetJustifyH('LEFT');
        text:SetJustifyV('MIDDLE');
        text:SetText(item.text);
        text:SetTextColor(1, 1, 1, 1);
        
        local highlight = itemButton:CreateTexture(nil, 'HIGHLIGHT');
        highlight:SetAllPoints();
        highlight:SetColorTexture(1, 1, 1, 0.2);
        
        itemButton:SetScript('OnClick', item.func);
        
        table.insert(menuButtons, itemButton);
    end
    
    dropdownMenu:SetHeight(#menuItems * itemHeight);
    
    menuButton:SetScript('OnClick', function(self, button)
        if dropdownMenu:IsShown() then
            dropdownMenu:Hide();
        else
            dropdownMenu:Show();
        end
    end);
    
    local function CloseMenu()
        if dropdownMenu:IsShown() then
            dropdownMenu:Hide();
        end
    end
    
    if not parentFrame.clickFrame then
        local clickFrame = CreateFrame('Frame', nil, UIParent);
        clickFrame:SetScript('OnMouseDown', function(self, button)
            if button == 'LeftButton' and dropdownMenu:IsShown() then
                local x, y = GetCursorPosition();
                local scale = UIParent:GetEffectiveScale();
                x = x / scale;
                y = y / scale;
                
                local menuX, menuY = dropdownMenu:GetCenter();
                local menuWidth = dropdownMenu:GetWidth();
                local menuHeight = dropdownMenu:GetHeight();
                
                if menuX and menuY then
                    if not (x >= menuX - menuWidth/2 and x <= menuX + menuWidth/2 and
                            y >= menuY - menuHeight/2 and y <= menuY + menuHeight/2) then
                        CloseMenu();
                    end
                end
            end
        end);
        parentFrame.clickFrame = clickFrame;
    end
    
    parentFrame.menuButton = menuButton;
    parentFrame.dropdownMenu = dropdownMenu;
end

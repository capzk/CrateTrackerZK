-- CrateTrackerZK - 主面板
local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;
local MainPanel = BuildEnv('MainPanel')

-- 检测当前语言，用于动态调整列宽
local locale = GetLocale();
local isChineseLocale = (locale == "zhCN" or locale == "zhTW");

local Layout = {
    -- 根据语言动态设置主窗口宽度：中文550px，英文590px（英文地图名称较长，需要更多空间）
    FRAME_WIDTH  = isChineseLocale and 550 or 590,
    FRAME_HEIGHT = 320,
    
    TABLE = {
        HEADER_HEIGHT = 32,
        ROW_HEIGHT = 32,
        COL_WIDTH = 90,
        -- 根据语言动态设置地图名称列宽度：中文80px，英文105px（英文地图名较长，需要更多显示空间）
        MAP_COL_WIDTH = isChineseLocale and 80 or 105,
        OPERATION_COL_WIDTH = 150,
        COL_SPACING = 5,
        COL_COUNT = 5,
        -- 从本地化文件读取字体大小，如果未定义则使用默认值 15
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
        -- 根据语言动态调整按钮宽度：中文65px，英文75px（英文文字较长）
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
            -- 最后一列：操作列
            Layout.TABLE.COL_WIDTHS[i] = Layout.TABLE.OPERATION_COL_WIDTH;
        elseif i == 1 then
            -- 第一列：地图名称列，根据语言动态设置宽度
            Layout.TABLE.COL_WIDTHS[i] = Layout.TABLE.MAP_COL_WIDTH;
        else
            -- 其他列：使用默认宽度
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
    -- 底部整体预留空白（窗口内容区域与表格底部之间）
    local bottomPadding = 40;
    local contentHeight = Layout.FRAME_HEIGHT - titleBarHeight - bottomPadding;
    -- 表格高度等于内容高度，行高变小后自然会在底部留下更多空白
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
    -- 第一列（地图名称）左对齐，其他列居中对齐
    if colIndex == 1 then
        -- 左对齐时添加左边距，避免文字贴边
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
    -- 设置更大的字体
    local font, size, flags = textObj:GetFont();
    textObj:SetFont(font, Layout.TABLE.FONT_SIZE, flags);
    -- 第一列（地图名称）设置文本显示：左对齐，超出部分隐藏
    if colIndex == 1 then
        textObj:SetNonSpaceWrap(false);
        -- 设置文本宽度限制，超出部分隐藏（不显示"..."）
        local textWidth = width - 6; -- 减去左右边距（4+2）
        if textWidth > 0 then
            textObj:SetWidth(textWidth);
            -- 设置最大行数为1，防止换行
            textObj:SetMaxLines(1);
        end
    end
    cell.Text = textObj;
    
    return cell;
end

local function CreateTableRow(parent, rowIndex, rowHeight)
    local row = CreateFrame('Frame', nil, parent);
    row:SetSize(Layout.TABLE.WIDTH, rowHeight);
    row:SetPoint('TOPLEFT', parent, 'TOPLEFT', 0, -(rowIndex - 1) * rowHeight);
    
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
    -- 放宽可点击区域，避免用户点在按钮边缘时第一次无响应
    row.refreshBtn:SetHitRectInsets(-6, -6, -4, -4);
    -- 调整按钮文字字体大小
    local refreshFont, refreshSize, refreshFlags = row.refreshBtn.Text:GetFont();
    row.refreshBtn.Text:SetFont(refreshFont, Layout.TABLE.FONT_SIZE, refreshFlags);
    row.refreshBtn:SetPoint('CENTER', opCell, 'CENTER', -Layout.BUTTONS.BUTTON_SPACING / 2, 0);
    
    row.notifyBtn = CreateFrame('Button', nil, opCell, 'UIPanelButtonTemplate');
    row.notifyBtn:SetSize(Layout.BUTTONS.NOTIFY_WIDTH, Layout.BUTTONS.NOTIFY_HEIGHT);
    row.notifyBtn:SetText(L["Notify"]);
    -- 放宽可点击区域
    row.notifyBtn:SetHitRectInsets(-6, -6, -4, -4);
    -- 调整按钮文字字体大小
    local notifyFont, notifySize, notifyFlags = row.notifyBtn.Text:GetFont();
    row.notifyBtn.Text:SetFont(notifyFont, Layout.TABLE.FONT_SIZE, notifyFlags);
    row.notifyBtn:SetPoint('CENTER', opCell, 'CENTER', Layout.BUTTONS.BUTTON_SPACING / 2, 0);
    
    return row;
end

local function CreateTable(frame)
    local tableContainer = CreateFrame('Frame', nil, frame);
    tableContainer:SetSize(Layout.TABLE.WIDTH, Layout.TABLE.HEIGHT);
    tableContainer:SetPoint('TOPLEFT', frame, 'TOPLEFT', Layout.TABLE.PADDING_X, -Layout.TABLE.PADDING_TOP);
    
    local tableHeader = CreateFrame('Frame', nil, tableContainer);
    tableHeader:SetSize(Layout.TABLE.WIDTH, Layout.TABLE.HEADER_HEIGHT);
    tableHeader:SetPoint('TOPLEFT', tableContainer, 'TOPLEFT', 0, 0);
    
    -- 整体表头背景，柔和区分表头区域
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
            -- 确保悬浮按钮显示
            if CrateTrackerZKFloatingButton then
                CrateTrackerZKFloatingButton:Show();
            elseif CrateTrackerZK and CrateTrackerZK.CreateFloatingButton then
                -- 如果按钮不存在，尝试创建
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
    frame.sortOrder = 'asc';
    
    MainPanel.updateTimer = C_Timer.NewTicker(1, function() MainPanel:UpdateTable() end);
    
    function frame:Toggle() MainPanel:Toggle() end
    MainPanel.mainFrame = frame;
    return frame;
end

function MainPanel:SortTable(field)
    local frame = self.mainFrame;
    if not frame then return end
    
    if frame.sortField == field then
        frame.sortOrder = frame.sortOrder == 'asc' and 'desc' or 'asc';
    else
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
    
    local mapArray = {};
    for _, mapData in ipairs(maps) do
        if mapData then
            mapData.remaining = Data:CalculateRemainingTime(mapData.nextRefresh);
            table.insert(mapArray, mapData);
        end
    end
    return mapArray;
end

function MainPanel:UpdateTable()
    local frame = self.mainFrame;
    if not frame or not frame:IsShown() then return end
    
    if Data and Data.CheckAndUpdateRefreshTimes then
        Data:CheckAndUpdateRefreshTimes();
    end
    
    local mapArray = PrepareTableData();
    
    if frame.sortField and (frame.sortField == 'lastRefresh' or frame.sortField == 'remaining') then
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
        
        row.bg:SetColorTexture(0.1, 0.1, 0.1, i % 2 == 0 and 0.5 or 0.3);
        
        row.columns[1].Text:SetText(Data:GetMapDisplayName(mapData));
        
        local instanceID = mapData.instance;
        local instanceText = "N/A";
        local color = {1, 1, 1};
        
        if instanceID then
            instanceText = tostring(instanceID):sub(-5);
            local isAirdrop = (TimerManager and TimerManager.mapIconDetected and TimerManager.mapIconDetected[mapData.id]);
            local currentTime = time();
            local isBeforeRefresh = mapData.nextRefresh and currentTime < mapData.nextRefresh;
            
            if mapData.nextRefresh and currentTime >= mapData.nextRefresh then
                -- 已刷新，显示白色
                color = {1, 1, 1};
            elseif isAirdrop then
                -- 空投进行中，显示绿色
                color = {0, 1, 0};
            elseif isBeforeRefresh and mapData.lastRefreshInstance and instanceID ~= mapData.lastRefreshInstance then
                -- 空投刷新前，且上次刷新时有位面ID记录，且当前位面ID和上次空投刷新时位面ID不同，显示红色
                -- 注意：如果 lastRefreshInstance 为 nil（首次获取位面ID，还没有刷新记录），则显示绿色
                color = {1, 0, 0};
            else
                -- 其他情况（包括首次获取位面ID，还没有刷新记录的情况），显示绿色
                color = {0, 1, 0};
            end
        end
        row.columns[2].Text:SetText(instanceText);
        row.columns[2].Text:SetTextColor(unpack(color));
        
        -- UI显示：如果无数据则显示 "--:--"，否则显示格式化后的时间
        local lastRefreshText = mapData.lastRefresh and Data:FormatDateTime(mapData.lastRefresh) or "--:--";
        row.columns[3].Text:SetText(lastRefreshText);
        row.columns[3]:SetScript('OnMouseUp', function() MainPanel:EditLastRefresh(mapData.id) end);
        
        local remaining = mapData.remaining;
        -- UI显示：如果无数据则显示 "--:--"，否则显示格式化后的时间
        local remainingText = remaining and Data:FormatTime(remaining, true) or "--:--";
        row.columns[4].Text:SetText(remainingText);
        if remaining then
            if remaining < 300 then row.columns[4].Text:SetTextColor(1, 0, 0)
            elseif remaining < 900 then row.columns[4].Text:SetTextColor(1, 0.5, 0)
            else row.columns[4].Text:SetTextColor(0, 1, 0) end
        else
            row.columns[4].Text:SetTextColor(1, 1, 1)
        end
        
        row.refreshBtn:SetScript('OnClick', function() MainPanel:RefreshMap(mapData.id) end);
        row.notifyBtn:SetScript('OnClick', function() MainPanel:NotifyMapRefresh(mapData) end);
        
        row:Show();
    end
end

function MainPanel:RefreshMap(mapId)
    if TimerManager then
        TimerManager:StartTimer(mapId, TimerManager.detectionSources.REFRESH_BUTTON);
    else
        Data:SetLastRefresh(mapId);
    end
    self:UpdateTable();
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
        timeout = 0, whileDead = true, hideOnEscape = true,
    };
    StaticPopup_Show('CRATETRACKERZK_EDIT_LASTREFRESH');
end

function MainPanel:ProcessInput(mapId, input)
    local hh, mm, ss = Utils.ParseTimeInput(input);
    if not hh then Utils.PrintError(L["TimeFormatError"]); return end
    
    local ts = Utils.GetTimestampFromTime(hh, mm, ss);
    if not ts then Utils.PrintError(L["TimestampError"]); return end
    
    if TimerManager then
        TimerManager:StartTimer(mapId, TimerManager.detectionSources.MANUAL_INPUT, ts);
    else
        Data:SetLastRefresh(mapId, ts);
    end
    self:UpdateTable();
end

function MainPanel:NotifyMapRefresh(mapData)
    if Notification then Notification:NotifyMapRefresh(mapData) else Utils.PrintError(L["NotificationModuleNotLoaded"]) end
end

function MainPanel:Toggle()
    if not CrateTrackerZKFrame then self:CreateMainFrame() end
    if CrateTrackerZKFrame:IsShown() then
        CrateTrackerZKFrame:Hide();
        -- 确保悬浮按钮显示
        if CrateTrackerZKFloatingButton then
            CrateTrackerZKFloatingButton:Show();
        elseif CrateTrackerZK and CrateTrackerZK.CreateFloatingButton then
            -- 如果按钮不存在，尝试创建
            CrateTrackerZK:CreateFloatingButton();
        end
    else
        CrateTrackerZKFrame:Show();
        self:UpdateTable();
        if CrateTrackerZKFloatingButton then CrateTrackerZKFloatingButton:Hide() end
    end
end

-- ============================================================================
-- 标题栏按钮创建
-- ============================================================================

-- 创建帮助按钮（使用问号图标，简单可点击元素）
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
    
    parentFrame.menuButton = menuButton;
    parentFrame.dropdownMenu = dropdownMenu;
end

-- 空投物资追踪器主面板实现文件

-- 确保BuildEnv函数存在
if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

-- 定义MainPanel命名空间
local MainPanel = BuildEnv('MainPanel')

-- 确保Data命名空间存在
if not Data then
    Data = {};
    Data.maps = {};
end

-- 模拟魔兽世界API（仅用于语法检查）
if not CreateFrame then
    CreateFrame = function() return { CreateFontString = function() return {} end, SetSize = function() end, SetPoint = function() end, SetScript = function() end, StartMoving = function() end, StopMovingOrSizing = function() end, Hide = function() end, Show = function() end, IsShown = function() return false end } end;
    CreateFontString = function() return {} end;
    UIParent = {};
    StaticPopupDialogs = {};
    StaticPopup_Show = function() return {} end;
    C_Timer = C_Timer or { NewTicker = function() return {} end };
end

-- 创建主框架
function MainPanel:CreateMainFrame()
    -- 检查主框架是否已存在
    if CrateTrackerFrame then
        return CrateTrackerFrame;
    end
    
    -- 停止之前可能存在的计时器
    if MainPanel.updateTimer then
        MainPanel.updateTimer:Cancel();
        MainPanel.updateTimer = nil;
    end
    
    -- 创建主框架
    local frame = CreateFrame('Frame', 'CrateTrackerFrame', UIParent, 'BasicFrameTemplateWithInset');
    frame:SetSize(680, 350);
    
    -- 加载保存的位置
    if CRATETRACKER_UI_DB and CRATETRACKER_UI_DB.position then
        local pos = CRATETRACKER_UI_DB.position;
        frame:SetPoint(pos.point, pos.x, pos.y);
    else
        frame:SetPoint('CENTER');
    end
    
    frame:SetMovable(true);
    frame:EnableMouse(true);
    frame:RegisterForDrag('LeftButton');
    frame:SetScript('OnDragStart', frame.StartMoving);
    
    -- 保存位置的函数
    local function SavePosition(self)
        self:StopMovingOrSizing();
        local point, _, _, x, y = self:GetPoint();
        if CRATETRACKER_UI_DB then
            CRATETRACKER_UI_DB.position = { point = point, x = x, y = y };
        end
    end
    
    frame:SetScript('OnDragStop', SavePosition);
    
    -- 设置标题
    frame.TitleText:SetText('|cff00ff88[空投物资追踪器]|r');
    
    -- 设置关闭按钮
    frame.CloseButton:SetScript('OnClick', function() 
        frame:Hide(); 
        -- 显示浮动按钮
        if CrateTrackerFloatingButton then
            CrateTrackerFloatingButton:Show();
        end
    end);
    
    -- 创建插件简介按钮（右上角，关闭按钮左侧，与关闭按钮同一水平线）
    local introButton = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate');
    introButton:SetSize(80, 22);
    introButton:SetPoint('TOPRIGHT', frame.CloseButton, 'TOPLEFT', -5, 0);
    introButton:SetText('插件简介');
    introButton:SetScript('OnClick', function()
        if Info then
            Info:ShowIntroduction();
        else
            Utils.PrintError("信息模块未加载");
        end
    end);
    
    -- 创建公告按钮（右上角，插件简介按钮左侧，与关闭按钮同一水平线）
    local announcementButton = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate');
    announcementButton:SetSize(70, 22);
    announcementButton:SetPoint('TOPRIGHT', introButton, 'TOPLEFT', -5, 0);
    announcementButton:SetText('公告');
    announcementButton:SetScript('OnClick', function()
        if Info then
            Info:ShowAnnouncement();
        else
            Utils.PrintError("信息模块未加载");
        end
    end);
    
    -- 创建内容容器
    local content = CreateFrame('Frame', nil, frame, 'InsetFrameTemplate3');
    content:SetPoint('TOPLEFT', 20, -40);
    content:SetPoint('BOTTOMRIGHT', -20, 20);
    
    -- 创建表格容器
    -- 计算实际所需的表格宽度（所有列宽之和）
    local totalTableWidth = 100 + 50 + 120 + 120 + 100 + 105; -- 595像素
    
    frame.tableContainer = CreateFrame('Frame', nil, content);
    frame.tableContainer:SetSize(totalTableWidth, 200);
    frame.tableContainer:SetPoint('CENTER', 0, 0);
    
    -- 创建表格背景
    frame.tableBackground = CreateFrame('Frame', nil, frame.tableContainer);
    frame.tableBackground:SetSize(totalTableWidth, 1);
    frame.tableBackground:SetPoint('TOP', 0, 0);
    
    -- 创建表格头部
    frame.tableHeader = CreateFrame('Frame', nil, frame.tableBackground);
    frame.tableHeader:SetSize(totalTableWidth, 30);
    frame.tableHeader:SetPoint('TOPLEFT', 0, 0);
    
    -- 启动定时更新计时器（每秒更新一次）
    MainPanel.updateTimer = C_Timer.NewTicker(1, function()
        MainPanel:UpdateTable();
    end);
    
    -- 设置表头背景
    local headerBg = frame.tableHeader:CreateTexture(nil, 'BACKGROUND');
    headerBg:SetAllPoints();
    headerBg:SetColorTexture(0.1, 0.3, 0.1, 0.5);
    
    -- 创建表头列
    local headerTexts = {'地图', '位面', '上次刷新', '下次刷新', '剩余时间', '操作'};
    local headerWidths = {100, 50, 120, 120, 100, 105}; -- 操作列宽度与表格行一致，确保能容纳两个按钮
    local currentX = 0;
    
    -- 排序状态
    frame.sortField = nil;
    frame.sortOrder = 'asc';
    
    -- 创建SortButton类
    local function CreateSortButton(parent, text, width, onClick)
        local button = CreateFrame('Button', nil, parent);
        button:SetSize(width, 24);
        button:SetPoint('LEFT', currentX, 0);
        currentX = currentX + width;
        
        -- 设置按钮纹理
        local tLeft = button:CreateTexture(nil, 'BACKGROUND');
        tLeft:SetTexture([[Interface\FriendsFrame\WhoFrame-ColumnTabs]]);
        tLeft:SetTexCoord(0, 0.078125, 0, 0.75);
        tLeft:SetSize(5, 24);
        tLeft:SetPoint('TOPLEFT');
        
        local tRight = button:CreateTexture(nil, 'BACKGROUND');
        tRight:SetTexture([[Interface\FriendsFrame\WhoFrame-ColumnTabs]]);
        tRight:SetTexCoord(0.90625, 0.96875, 0, 0.75);
        tRight:SetSize(4, 24);
        tRight:SetPoint('TOPRIGHT');
        
        local tMid = button:CreateTexture(nil, 'BACKGROUND');
        tMid:SetTexture([[Interface\FriendsFrame\WhoFrame-ColumnTabs]]);
        tMid:SetTexCoord(0.078125, 0.90625, 0, 0.75);
        tMid:SetPoint('TOPLEFT', tLeft, 'TOPRIGHT');
        tMid:SetPoint('BOTTOMRIGHT', tRight, 'BOTTOMLEFT');
        
        -- 设置按钮文本
        local textObj = button:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight');
        textObj:SetPoint('CENTER');
        textObj:SetText(text);
        textObj:SetJustifyH('CENTER');
        textObj:SetJustifyV('MIDDLE');
        button:SetFontString(textObj);
        button:SetHeight(30);
        
        -- 创建箭头指示器
        local arrow = button:CreateTexture(nil, 'OVERLAY');
        arrow:SetTexture([[Interface\Buttons\UI-SortArrow]]);
        arrow:SetTexCoord(0, 0.5625, 0, 1.0);
        arrow:SetSize(9, 8);
        arrow:SetPoint('LEFT', textObj, 'RIGHT', 3, -2);
        arrow:Hide();
        button.Arrow = arrow;
        
        -- 设置高亮纹理
        button:SetHighlightTexture([[Interface\PaperDollInfoFrame\UI-Character-Tab-Highlight]], 'ADD');
        button:GetHighlightTexture():SetHeight(30);
        button:GetHighlightTexture():ClearAllPoints();
        button:GetHighlightTexture():SetPoint('LEFT');
        button:GetHighlightTexture():SetPoint('RIGHT', 4, 0);
        
        -- 设置点击事件
        button:SetScript('OnClick', onClick);
        
        return button;
    end
    
    frame.headerColumns = {};
    
    -- 创建可点击的表头按钮
    frame.headerColumns[1] = CreateSortButton(frame.tableHeader, headerTexts[1], headerWidths[1], function() MainPanel:SortTable('mapName') end);
    frame.headerColumns[2] = CreateSortButton(frame.tableHeader, headerTexts[2], headerWidths[2], function() MainPanel:SortTable('instance') end);
    frame.headerColumns[3] = CreateSortButton(frame.tableHeader, headerTexts[3], headerWidths[3], function() MainPanel:SortTable('lastRefresh') end);
    frame.headerColumns[4] = CreateSortButton(frame.tableHeader, headerTexts[4], headerWidths[4], function() MainPanel:SortTable('nextRefresh') end);
    frame.headerColumns[5] = CreateSortButton(frame.tableHeader, headerTexts[5], headerWidths[5], function() MainPanel:SortTable('remaining') end);
    
    -- 创建操作列表头按钮，与其他表头保持一致样式
    frame.headerColumns[6] = CreateSortButton(frame.tableHeader, headerTexts[6], headerWidths[6], function() end);
    -- 禁用排序功能，因为操作列不需要排序
    frame.headerColumns[6]:SetScript('OnClick', nil);
    frame.headerColumns[6]:Disable();
    
    -- 移除添加地图区域
    
    -- 创建列宽信息
    -- 调整列宽，移除了刷新间隔列，设置最小操作列宽度以容纳两个按钮
    frame.columnWidths = {100, 50, 120, 120, 100, 105};  -- 地图、位面、上次刷新、下次刷新、剩余时间、操作
    
    -- 创建表格内容区域
    frame.tableRows = {};
    
    -- 添加显示/隐藏方法
    function frame:Toggle()
        if self:IsShown() then
            self:Hide();
        else
            self:Show();
            MainPanel:UpdateTable();
        end
    end
    
    -- 保存引用
    MainPanel.mainFrame = frame;
    
    return frame;
end

-- 排序表格
function MainPanel:SortTable(field)
    local frame = MainPanel.mainFrame;
    if not frame then return end;
    
    -- 切换排序方向或设置新的排序字段
    if frame.sortField == field then
        frame.sortOrder = frame.sortOrder == 'asc' and 'desc' or 'asc';
    else
        frame.sortField = field;
        frame.sortOrder = 'asc';
    end
    
    -- 更新箭头指示器
    for _, button in ipairs(frame.headerColumns) do
        if button.Arrow then
            button.Arrow:Hide();
        end
    end
    
    if frame.headerColumns[1].Arrow then -- 确保是排序按钮
        local button = frame.headerColumns[1];
        if field == 'mapName' then
            button = frame.headerColumns[1];
        elseif field == 'instance' then
            button = frame.headerColumns[2];
        elseif field == 'lastRefresh' then
            button = frame.headerColumns[3];
        elseif field == 'nextRefresh' then
            button = frame.headerColumns[4];
        elseif field == 'remaining' then
            button = frame.headerColumns[5];
        end
        
        if button.Arrow then
            if frame.sortOrder == 'asc' then
                button.Arrow:SetTexCoord(0, 0.5625, 1, 0);
            else
                button.Arrow:SetTexCoord(0, 0.5625, 0, 1);
            end
            button.Arrow:Show();
        end
    end
    
    -- 更新表格
    MainPanel:UpdateTable();
end

-- 更新表格内容
function MainPanel:UpdateTable()
    local frame = MainPanel.mainFrame;
    if not frame then return end;
    
    -- 检查并更新所有地图的下次刷新时间（处理循环刷新）
    Data:CheckAndUpdateRefreshTimes();
    
    -- 获取数据
    local maps = Data:GetAllMaps();
    
    -- 将映射转换为数组以便排序
    local mapArray = {};
    for _, mapData in ipairs(maps) do
        -- 添加剩余时间作为临时字段用于排序
        mapData.remaining = Data:CalculateRemainingTime(mapData.nextRefresh);
        table.insert(mapArray, mapData);
    end
    
    -- 应用排序
    if frame.sortField then
        table.sort(mapArray, function(a, b)
            local aVal, bVal = a[frame.sortField], b[frame.sortField];
            
            -- 特殊处理剩余时间排序：没有时间信息的排到最下面
            if frame.sortField == 'remaining' then
                -- 如果两个都没有时间信息，保持原顺序
                if not aVal and not bVal then return false end;
                -- 如果a没有时间信息，a排到后面
                if not aVal then return false end;
                -- 如果b没有时间信息，b排到后面
                if not bVal then return true end;
                -- 都有时间信息，按升序排序（剩余时间少的在前）
                return aVal < bVal;
            end
            
            -- 其他字段的排序逻辑
            -- 处理nil值
            if not aVal and not bVal then return false end;
            if not aVal then return frame.sortOrder == 'asc' end;
            if not bVal then return frame.sortOrder == 'desc' end;
            
            -- 应用排序
            if frame.sortOrder == 'asc' then
                return aVal < bVal;
            else
                return aVal > bVal;
            end
        end);
    end
    
    -- 计算表格高度
    local rowHeight = 32; -- 增加行高，使上下行更宽松
    local tableHeight = math.max(120, #mapArray * rowHeight);
    frame.tableBackground:SetHeight(tableHeight);
    
    -- 调整表格容器高度
    local newContainerHeight = math.min(#mapArray * rowHeight + 50, 300);
    frame.tableContainer:SetHeight(newContainerHeight);
    
    -- 清除现有行
    for i = 1, #frame.tableRows do
        frame.tableRows[i]:Hide();
    end
    
    -- 创建新行
    for i, mapData in ipairs(mapArray) do
        local row = frame.tableRows[i];
        if not row then
            row = CreateFrame('Frame', nil, frame.tableBackground);
            frame.tableRows[i] = row;
            
            row:SetSize(frame.tableBackground:GetWidth(), rowHeight);
            row:SetPoint('TOP', 0, -i*rowHeight); -- 从顶部开始排列，确保水平居中
            
            -- 创建行背景
            row.bg = row:CreateTexture(nil, 'BACKGROUND');
            row.bg:SetAllPoints();
            row.bg:SetColorTexture(0.1, 0.1, 0.1, 0.5);
            
            -- 创建列
            row.columns = {};
            local currentX = 0;
            
            for j = 1, 6 do
                local col = row:CreateFontString(nil, 'ARTWORK', 'GameFontNormal');
                col:SetSize(frame.columnWidths[j], rowHeight);
                col:SetPoint('LEFT', currentX, 0);
                col:SetJustifyH('CENTER');
                col:SetJustifyV('MIDDLE');
                
                -- 为上次刷新时间列添加点击编辑功能（现在是第3列）
                if j == 3 then
                    -- 保存mapData.id到局部变量，避免闭包引用问题
                    local mapId = mapData.id;
                    col:SetScript('OnMouseUp', function() 
                        MainPanel:EditLastRefresh(mapId, col);
                    end);
                    col:SetTextColor(0.4, 0.8, 1); -- 设置为可点击的蓝色
                    col:EnableMouse(true);
                else
                    col:SetTextColor(1, 1, 1);
                end
                
                row.columns[j] = col;
                currentX = currentX + frame.columnWidths[j];
            end
            
            -- 设置刷新按钮（在操作列内左侧，垂直居中）
            row.refreshBtn = CreateFrame('Button', nil, row, 'UIPanelButtonTemplate');
            row.refreshBtn:SetSize(50, 26);
            row.refreshBtn:SetText('刷新');
            row.refreshBtn:SetScript('OnClick', function() MainPanel:RefreshMap(mapData.id); end);
            
            -- 添加通知按钮（在操作列内右侧，垂直居中）
            row.notifyBtn = CreateFrame('Button', nil, row, 'UIPanelButtonTemplate');
            row.notifyBtn:SetSize(50, 26);
            row.notifyBtn:SetText('通知');
            row.notifyBtn:SetScript('OnClick', function() 
                -- 保存地图数据引用到按钮，以便后续使用
                row.notifyBtn.mapData = mapData;
                MainPanel:NotifyMapRefresh(mapData); 
            end);
            
            -- 计算并设置按钮位置，使两个按钮在操作列中居中显示
            local btnSpacing = 5; -- 按钮之间的间距
            local totalBtnWidth = row.refreshBtn:GetWidth() + btnSpacing + row.notifyBtn:GetWidth();
            local startX = (frame.columnWidths[6] - totalBtnWidth) / 2;
            
            row.refreshBtn:SetPoint('LEFT', currentX - frame.columnWidths[6] + startX, 0);
            row.refreshBtn:SetPoint('TOP', 0, -3); -- 调整垂直位置以确保居中
            
            row.notifyBtn:SetPoint('LEFT', row.refreshBtn, 'RIGHT', btnSpacing, 0);
            row.notifyBtn:SetPoint('TOP', 0, -3); -- 调整垂直位置以确保居中
            
        else
            row:SetPoint('TOPLEFT', 0, -i*rowHeight);
        end
        
        -- 更新行背景
        if i % 2 == 0 then
            row.bg:SetColorTexture(0.2, 0.2, 0.2, 0.5);
        else
            row.bg:SetColorTexture(0.1, 0.1, 0.1, 0.5);
        end
        
        -- 更新列数据
        row.columns[1]:SetText(mapData.mapName);
        
        -- 更新位面ID显示（只显示最后5位，并根据条件设置颜色）
        local instanceID = mapData.instance;
        local lastInstance = mapData.lastInstance;  -- 上一次位面ID（用于判断位面是否变化）
        local nextRefresh = mapData.nextRefresh;
        local currentTime = time();
        local instanceText, textColor;
        
        if not instanceID then
            instanceText = "未获取";
            textColor = {1, 1, 1}; -- 白色（未获取）
        else
            -- 只显示最后5位
            instanceText = tostring(instanceID);
            if #instanceText > 5 then
                instanceText = string.sub(instanceText, -5);
            end
            
            -- 设置颜色逻辑：
            -- 1. 首次获取位面ID：白色显示
            -- 2. 位面发生变化时：红色显示
            -- 3. 一旦检测到空投进行中：显示绿色（即使位面变化了也显示绿色）
            -- 4. 直到再次变化才显示红色（如果空投已结束且位面变化）
            -- 5. 位面ID相比较之前无变化：绿色显示
            
            if nextRefresh and currentTime >= nextRefresh then
                -- 已过刷新时间，显示白色
                textColor = {1, 1, 1}; -- 白色
            elseif not lastInstance then
                -- 没有上一次位面ID记录，显示白色（首次获取）
                textColor = {1, 1, 1}; -- 白色
            else
                -- 首先检查是否检测到空投进行中
                local isAirdropActive = false;
                if TimerManager and TimerManager.mapIconDetected and TimerManager.mapIconDetected[mapData.id] == true then
                    isAirdropActive = true;
                elseif TimerManager and TimerManager.npcSpeechDetected and TimerManager.npcSpeechDetected[mapData.id] == true then
                    isAirdropActive = true;
                end
                
                -- 如果检测到空投进行中，显示绿色（无论位面是否变化）
                if isAirdropActive then
                    textColor = {0, 1, 0}; -- 绿色（空投进行中）
                else
                    -- 没有检测到空投进行中，检查位面是否变化
                    if instanceID ~= lastInstance then
                        -- 位面发生变化，显示红色
                        textColor = {1, 0, 0}; -- 红色（位面变化）
                    else
                        -- 位面无变化，显示绿色
                        textColor = {0, 1, 0}; -- 绿色（位面无变化）
                    end
                end
            end
        end
        
        row.columns[2]:SetText(instanceText);
        row.columns[2]:SetTextColor(textColor[1], textColor[2], textColor[3]);
        
        row.columns[3]:SetText(Data:FormatDateTime(mapData.lastRefresh));
        row.columns[4]:SetText(Data:FormatDateTime(mapData.nextRefresh));
        
        -- 更新剩余时间（只显示分和秒）
        local remaining = Data:CalculateRemainingTime(mapData.nextRefresh);
        row.columns[5]:SetText(Data:FormatTime(remaining, true));
        
        -- 设置剩余时间颜色
        if remaining and remaining < 1100 then
            row.columns[5]:SetTextColor(1, 0.5, 0);
        elseif remaining and remaining < 550 then
            row.columns[5]:SetTextColor(1, 0, 0);
        else
            row.columns[5]:SetTextColor(0, 1, 0);
        end
        
        -- 更新按钮脚本
        row.refreshBtn:SetScript('OnClick', function() MainPanel:RefreshMap(mapData.id); end);
        
        -- 更新通知按钮脚本
        if row.notifyBtn then
            row.notifyBtn.mapData = mapData;
            row.notifyBtn:SetScript('OnClick', function() MainPanel:NotifyMapRefresh(mapData); end);
        end
        
        row:Show();
    end
end

-- 刷新地图
function MainPanel:RefreshMap(mapId)
    local mapData = Data:GetMap(mapId);
    if Utils and Utils.Debug then
        Utils.Debug("用户操作: 点击刷新按钮", "地图ID=" .. mapId, "地图名称=" .. (mapData and mapData.mapName or "未知"));
    end
    
    if TimerManager then
        TimerManager:StartTimer(mapId, TimerManager.detectionSources.REFRESH_BUTTON);
    else
        Data:SetLastRefresh(mapId);
    end
    MainPanel:UpdateTable();
end

-- 编辑上次刷新时间
function MainPanel:EditLastRefresh(mapId, parentFrame)
    local mapData = Data:GetMap(mapId);
    if not mapData then 
        if Utils and Utils.Debug then
            Utils.Debug("用户操作: 尝试编辑刷新时间失败", "地图ID=" .. mapId, "原因=地图数据不存在");
        end
        return 
    end
    
    if Utils and Utils.Debug then
        Utils.Debug("用户操作: 打开编辑刷新时间对话框", "地图ID=" .. mapId, "地图名称=" .. mapData.mapName);
    end
    
    -- 创建静态对话框
    StaticPopupDialogs['CRATETRACKER_EDIT_LASTREFRESH'] = {
        text = '请输入上次刷新时间 (HH:MM:SS 或 HHMMSS):',
        button1 = '确定',
        button2 = '取消',
        hasEditBox = true,
        editBoxWidth = 200,
        OnAccept = function(self, data, data2) 
            local input = self.EditBox:GetText();
            MainPanel:ProcessLastRefreshInput(mapId, input);
        end,
        OnCancel = function(self) end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    };
    
    -- 显示对话框，预设当前时间
    StaticPopup_Show('CRATETRACKER_EDIT_LASTREFRESH', nil, nil, mapData);
end

-- 处理上次刷新时间输入
function MainPanel:ProcessLastRefreshInput(mapId, input)
    if not input or input == '' then 
        if Utils and Utils.Debug then
            Utils.Debug("用户操作: 输入刷新时间为空", "地图ID=" .. mapId);
        end
        return 
    end
    
    if Utils and Utils.Debug then
        Utils.Debug("用户操作: 处理手动输入刷新时间", "地图ID=" .. mapId, "输入=" .. input);
    end
    
    -- 解析输入时间
    local hh, mm, ss = Utils.ParseTimeInput(input);
    if not hh then
        if Utils and Utils.Debug then
            Utils.Debug("用户操作: 时间格式解析失败", "输入=" .. input);
        end
        Utils.PrintError('时间格式错误，请输入HH:MM:SS或HHMMSS格式');
        return;
    end
    
    if Utils and Utils.Debug then
        Utils.Debug("时间解析成功", "时=" .. hh, "分=" .. mm, "秒=" .. ss);
    end
    
    -- 创建时间戳
    local lastRefresh = Utils.GetTimestampFromTime(hh, mm, ss);
    if not lastRefresh then
        if Utils and Utils.Debug then
            Utils.Debug("时间戳创建失败", "时=" .. hh, "分=" .. mm, "秒=" .. ss);
        end
        Utils.PrintError('无法创建有效的时间戳');
        return;
    end
    
    if Utils and Utils.Debug then
        local timeStr = date("%H:%M:%S", lastRefresh);
        Utils.Debug("时间戳创建成功", "时间戳=" .. lastRefresh, "时间=" .. timeStr);
    end
    
    -- 通过TimerManager更新刷新时间
    if TimerManager then
        TimerManager:StartTimer(mapId, TimerManager.detectionSources.MANUAL_INPUT, lastRefresh);
    else
        -- 更新地图数据
        Data:UpdateLastRefresh(mapId, lastRefresh);
    end
    
    -- 更新UI
    MainPanel:UpdateTable();
end

-- 通知功能：向团队/小队/自己发送地图刷新时间通知（使用Notification模块）
function MainPanel:NotifyMapRefresh(mapData)
    if not mapData then 
        if Debug and Debug:IsEnabled() then
            Debug:Print("用户操作: 通知功能调用失败", "原因=地图数据为空");
        end
        return 
    end
    
    if Debug and Debug:IsEnabled() then
        Debug:Print("用户操作: 点击通知按钮", "地图名称=" .. mapData.mapName);
    end
    
    -- 使用Notification模块发送通知
    if Notification then
        Notification:NotifyMapRefresh(mapData);
    else
        Utils.PrintError("通知模块未加载");
    end
end

-- 切换UI显示状态
function MainPanel:Toggle()
    if Utils and Utils.Debug then
        Utils.Debug("用户操作: 切换主面板显示状态");
    end
    
    if not CrateTrackerFrame then
        -- 如果框架不存在，创建它
        if Utils and Utils.Debug then
            Utils.Debug("主面板不存在，正在创建");
        end
        MainPanel:CreateMainFrame();
    end
    
    if CrateTrackerFrame then
        if CrateTrackerFrame:IsShown() then
            if Utils and Utils.Debug then
                Utils.Debug("用户操作: 关闭主面板");
            end
            CrateTrackerFrame:Hide();
            -- 显示浮动按钮
            if CrateTrackerFloatingButton then
                CrateTrackerFloatingButton:Show();
            end
        else
            if Utils and Utils.Debug then
                Utils.Debug("用户操作: 打开主面板");
            end
            CrateTrackerFrame:Show();
            MainPanel:UpdateTable();
            -- 隐藏浮动按钮
            if CrateTrackerFloatingButton then
                CrateTrackerFloatingButton:Hide();
            end
        end
        return true;
    end
    return false;
end
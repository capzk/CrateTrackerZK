-- CrateTrackerZK - 悬浮按钮模块
local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;

-- 调试函数
local function DebugPrint(msg, ...)
    if Debug and Debug:IsEnabled() then
        Debug:Print(msg, ...);
    end
end

-- 创建浮动按钮
function CrateTrackerZK:CreateFloatingButton()
    -- 确保数据库结构完整
    if not CRATETRACKERZK_UI_DB then
        -- 理想情况下应该在 Core 中初始化，但这里做个保险
        return;
    end
    
    -- 确保 minimapButton 结构存在
    if not CRATETRACKERZK_UI_DB.minimapButton then
        CRATETRACKERZK_UI_DB.minimapButton = {};
    end
    if not CRATETRACKERZK_UI_DB.minimapButton.position then
        CRATETRACKERZK_UI_DB.minimapButton.position = { point = "TOPLEFT", x = 50, y = -50 };
    end
    
    -- 检查按钮是否已存在
    if CrateTrackerZKFloatingButton then
        -- 如果按钮已存在，确保它在正确的位置并显示
        local pos = CRATETRACKERZK_UI_DB.minimapButton.position;
        
        -- 兼容处理：检查位置结构类型
        local point, x, y;
        if type(pos) == "table" then
            if pos.point then
                -- 新结构
                point = pos.point;
                x = pos.x or 0;
                y = pos.y or 0;
            else
                -- 旧结构兼容处理
                local left = pos.left or 50;
                local top = pos.top or -50;
                point = "TOPLEFT";
                x = left;
                y = top;
                
                -- 更新为新结构
                pos.point = point;
                pos.x = x;
                pos.y = y;
                pos.left = nil;
                pos.top = nil;
            end
        else
            -- pos不是表，使用默认值
            point = "TOPLEFT";
            x = 50;
            y = -50;
            
            -- 更新数据库
            CRATETRACKERZK_UI_DB.minimapButton.position = { point = point, x = x, y = y };
        end
        
        CrateTrackerZKFloatingButton:ClearAllPoints();
        CrateTrackerZKFloatingButton:SetPoint(point, UIParent, point, x, y);
        
        -- 确保按钮显示
        if not (CrateTrackerZKFrame and CrateTrackerZKFrame:IsShown()) then
            DebugPrint("显示浮动按钮");
            CrateTrackerZKFloatingButton:Show();
        else
            DebugPrint("主窗口已显示，隐藏浮动按钮");
            CrateTrackerZKFloatingButton:Hide();
        end
        
        return CrateTrackerZKFloatingButton;
    end
    
    DebugPrint("创建浮动按钮");
    
    -- 创建浮动按钮，使用UIMenuButtonStretchTemplate模板实现圆角效果
    local button = CreateFrame("Button", "CrateTrackerZKFloatingButton", UIParent, "UIMenuButtonStretchTemplate");
    button:SetSize(140, 32); -- 增大按钮尺寸以适应更长的文字
    
    -- 设置按钮层级（确保按钮显示在最前面）
    button:SetFrameStrata("HIGH");
    button:SetFrameLevel(100);
    
    -- 加载保存的位置
    local pos = CRATETRACKERZK_UI_DB.minimapButton.position;
    
    -- 兼容处理：检查位置结构类型
    local point, x, y;
    if type(pos) == "table" then
        if pos.point then
            -- 新结构
            point = pos.point;
            x = pos.x or 0;
            y = pos.y or 0;
        else
            -- 旧结构兼容处理
            local left = pos.left or 50;
            local top = pos.top or -50;
            point = "TOPLEFT";
            x = left;
            y = top;
            
            -- 更新为新结构
            pos.point = point;
            pos.x = x;
            pos.y = y;
            pos.left = nil;
            pos.top = nil;
            
            DebugPrint("转换旧位置结构为新结构: " .. point .. ", x=" .. x .. ", y=" .. y);
        end
    else
        -- pos不是表，使用默认值
        point = "TOPLEFT";
        x = 50;
        y = -50;
        
        -- 更新数据库
        CRATETRACKERZK_UI_DB.minimapButton.position = { point = point, x = x, y = y };
        DebugPrint("使用默认位置: " .. point .. ", x=" .. x .. ", y=" .. y);
    end
    
    -- 设置按钮到保存的位置
    button:ClearAllPoints();
    button:SetPoint(point, UIParent, point, x, y);
    
    -- 设置按钮属性
    button:SetMovable(true);
    button:EnableMouse(true);
    button:RegisterForDrag("LeftButton");
    button:SetText("CrateTrackerZK");
    
    -- 设置按钮文本属性
    button:SetNormalFontObject(GameFontNormal);
    button:SetHighlightFontObject(GameFontHighlight);
    button:SetDisabledFontObject(GameFontDisable);
    button.Text:SetTextColor(1, 1, 1); -- 设置文本颜色为白色
    
    -- 设置按钮状态
    button:Enable(); -- 确保按钮是启用状态
    
    -- 根据主窗口状态决定按钮初始显示状态
    if CrateTrackerZKFrame and CrateTrackerZKFrame:IsShown() then
        button:Hide(); -- 主窗口已显示，隐藏按钮
    else
        button:Show(); -- 主窗口未显示，显示按钮
    end
    
    -- 设置背景颜色
    local bgTexture = button:GetNormalTexture();
    if bgTexture then
        bgTexture:SetVertexColor(0, 0.5, 0.5, 1); -- 青绿色背景
        bgTexture:Show();
    end
    
    -- 设置高亮状态
    local highlightTexture = button:GetHighlightTexture();
    if highlightTexture then
        highlightTexture:SetVertexColor(0.2, 0.7, 0.7, 1); -- 高亮时的颜色
        highlightTexture:Show();
    end
    
    -- 设置禁用状态
    local disabledTexture = button:GetDisabledTexture();
    if disabledTexture then
        disabledTexture:SetVertexColor(0.3, 0.3, 0.3, 0.5); -- 禁用时的颜色
        disabledTexture:Hide();
    end
    
    -- 设置点击状态
    local pushedTexture = button:GetPushedTexture();
    if pushedTexture then
        pushedTexture:SetVertexColor(0, 0.3, 0.3, 1); -- 点击时的颜色
        pushedTexture:Hide();
    end
    
    -- 设置拖动事件
    button:SetScript("OnDragStart", function(self)
        DebugPrint("用户操作: 开始拖动浮动按钮");
        self:StartMoving();
    end);
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing();
        
        -- 获取屏幕尺寸
        local screenWidth = GetScreenWidth();
        local screenHeight = GetScreenHeight();
        
        -- 获取按钮当前位置和尺寸
        local left = self:GetLeft() or 0;
        local right = self:GetRight() or self:GetWidth();
        local top = self:GetTop() or 0;
        local bottom = self:GetBottom() or -self:GetHeight();
        
        -- 智能选择最合适的锚点
        local point;
        local x, y;
        
        -- 水平方向锚点选择
        local distToLeft = left;
        local distToRight = screenWidth - right;
        local distToCenter = math.abs((left + right) / 2 - screenWidth / 2);
        
        if distToLeft < distToRight and distToLeft < distToCenter then
            point = "LEFT";
            x = left;
        elseif distToRight < distToCenter then
            point = "RIGHT";
            x = right - screenWidth;
        else
            point = "";
            x = (left + right) / 2 - screenWidth / 2;
        end
        
        -- 垂直方向锚点选择
        local distToBottom = bottom;
        local distToTop = screenHeight - top;
        local distToMiddle = math.abs((bottom + top) / 2 - screenHeight / 2);
        
        if distToBottom < distToTop and distToBottom < distToMiddle then
            point = "BOTTOM" .. point;
            y = bottom;
        elseif distToTop < distToMiddle then
            point = "TOP" .. point;
            y = top - screenHeight;
        else
            y = (bottom + top) / 2 - screenHeight / 2;
        end
        
        -- 如果没有选择到锚点，使用CENTER
        if point == "" then
            point = "CENTER";
        end
        
        -- 确保按钮在屏幕范围内
        if point:find("LEFT") then
            x = math.max(0, x);
        elseif point:find("RIGHT") then
            x = math.min(0, x);
        end
        
        if point:find("TOP") then
            y = math.min(0, y);
        elseif point:find("BOTTOM") then
            y = math.max(0, y);
        end
        
        -- 保存位置
        if CRATETRACKERZK_UI_DB then
            local pos = CRATETRACKERZK_UI_DB.minimapButton.position;
            pos.point = point;
            pos.x = x;
            pos.y = y;
            DebugPrint("用户操作: 拖动浮动按钮结束", "锚点=" .. point, "x=" .. x, "y=" .. y);
        end
        
        -- 应用最终位置
        self:ClearAllPoints();
        self:SetPoint(point, UIParent, point, x, y);
    end);
    
    -- 设置点击事件
    button:SetScript("OnClick", function()
        DebugPrint("点击了浮动按钮");
        if MainPanel then
            MainPanel:Toggle();
        end
    end);
    
    -- 设置鼠标悬停提示
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
        GameTooltip:SetText(L["FloatingButtonTooltipTitle"]);
        GameTooltip:AddLine(L["FloatingButtonTooltipLine1"]);
        GameTooltip:AddLine(L["FloatingButtonTooltipLine2"]);
        GameTooltip:Show();
    end);
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide();
    end);
    
    -- 保存引用
    CrateTrackerZK.floatingButton = button;
    
    return button;
end


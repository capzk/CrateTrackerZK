local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;

local function DebugPrint(msg, ...)
    Logger:Debug("FloatingButton", "调试", msg, ...);
end

function CrateTrackerZK:CreateFloatingButton()
    if not CRATETRACKERZK_UI_DB then
        CRATETRACKERZK_UI_DB = {};
    end
    if type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {};
    end
    
    if not CRATETRACKERZK_UI_DB.minimapButton then
        CRATETRACKERZK_UI_DB.minimapButton = {};
    end
    if not CRATETRACKERZK_UI_DB.minimapButton.position then
        CRATETRACKERZK_UI_DB.minimapButton.position = { point = "TOPLEFT", x = 50, y = -50 };
    end
    
    if CrateTrackerZKFloatingButton then
        local pos = CRATETRACKERZK_UI_DB.minimapButton.position;
        
        local point, x, y;
        if type(pos) == "table" and pos.point then
            point = pos.point;
            x = pos.x or 0;
            y = pos.y or 0;
        else
            point = "TOPLEFT";
            x = 50;
            y = -50;
            CRATETRACKERZK_UI_DB.minimapButton.position = { point = point, x = x, y = y };
        end
        
        CrateTrackerZKFloatingButton:ClearAllPoints();
        CrateTrackerZKFloatingButton:SetPoint(point, UIParent, point, x, y);
        
        if not (CrateTrackerZKFrame and CrateTrackerZKFrame:IsShown()) then
            DebugPrint("[浮动按钮] 显示浮动按钮");
            CrateTrackerZKFloatingButton:Show();
        else
            DebugPrint("[浮动按钮] 主窗口已显示，隐藏浮动按钮");
            CrateTrackerZKFloatingButton:Hide();
        end
        
        return CrateTrackerZKFloatingButton;
    end
    
    DebugPrint("[浮动按钮] 创建浮动按钮");
    
    local button = CreateFrame("Button", "CrateTrackerZKFloatingButton", UIParent, "UIMenuButtonStretchTemplate");
    button:SetSize(140, 32);
    
    button:SetFrameStrata("HIGH");
    button:SetFrameLevel(100);
    
    local pos = CRATETRACKERZK_UI_DB.minimapButton.position;
    
    local point, x, y;
    if type(pos) == "table" and pos.point then
        point = pos.point;
        x = pos.x or 0;
        y = pos.y or 0;
        else
            point = "TOPLEFT";
            x = 50;
            y = -50;
            CRATETRACKERZK_UI_DB.minimapButton.position = { point = point, x = x, y = y };
            DebugPrint("[浮动按钮] 使用默认位置：" .. point .. ", x=" .. x .. ", y=" .. y);
    end
    
    button:ClearAllPoints();
    button:SetPoint(point, UIParent, point, x, y);
    
    button:SetMovable(true);
    button:EnableMouse(true);
    button:RegisterForDrag("LeftButton");
    button:SetText("CrateTrackerZK");
    
    button:SetNormalFontObject(GameFontNormal);
    button:SetHighlightFontObject(GameFontHighlight);
    button:SetDisabledFontObject(GameFontDisable);
    button.Text:SetTextColor(1, 1, 1);
    
    button:Enable();
    
    if CrateTrackerZKFrame and CrateTrackerZKFrame:IsShown() then
        button:Hide();
    else
        button:Show();
    end
    
    local bgTexture = button:GetNormalTexture();
    if bgTexture then
        bgTexture:SetVertexColor(0, 0.5, 0.5, 1);
        bgTexture:Show();
    end
    
    local highlightTexture = button:GetHighlightTexture();
    if highlightTexture then
        highlightTexture:SetVertexColor(0.2, 0.7, 0.7, 1);
        highlightTexture:Show();
    end
    
    local disabledTexture = button:GetDisabledTexture();
    if disabledTexture then
        disabledTexture:SetVertexColor(0.3, 0.3, 0.3, 0.5);
        disabledTexture:Hide();
    end
    
    local pushedTexture = button:GetPushedTexture();
    if pushedTexture then
        pushedTexture:SetVertexColor(0, 0.3, 0.3, 1);
        pushedTexture:Hide();
    end
    
    button:SetScript("OnDragStart", function(self)
        DebugPrint("[浮动按钮] 用户操作：开始拖动浮动按钮");
        self:StartMoving();
    end);
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing();
        
        local screenWidth = GetScreenWidth();
        local screenHeight = GetScreenHeight();
        
        local left = self:GetLeft() or 0;
        local right = self:GetRight() or self:GetWidth();
        local top = self:GetTop() or 0;
        local bottom = self:GetBottom() or -self:GetHeight();
        
        local point;
        local x, y;
        
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
        
        if point == "" then
            point = "CENTER";
        end
        
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
        
        if CRATETRACKERZK_UI_DB then
            local pos = CRATETRACKERZK_UI_DB.minimapButton.position;
            pos.point = point;
            pos.x = x;
            pos.y = y;
            DebugPrint("[浮动按钮] 用户操作：停止拖动浮动按钮", "锚点=" .. point, "x=" .. x, "y=" .. y);
        end
        
        self:ClearAllPoints();
        self:SetPoint(point, UIParent, point, x, y);
    end);
    
    button:SetScript("OnClick", function()
        DebugPrint("[浮动按钮] 用户操作：点击浮动按钮");
        if MainPanel then
            MainPanel:Toggle();
        end
    end);
    
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
    
    CrateTrackerZK.floatingButton = button;
    
    return button;
end


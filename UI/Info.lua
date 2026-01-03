if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local CrateTrackerZK = BuildEnv("CrateTrackerZK");
local L = CrateTrackerZK.L;
local Info = BuildEnv('Info');
local Help = BuildEnv("Help");
local About = BuildEnv("About");

Info.isInitialized = false;
Info.currentFrame = nil;

local ADDON_NAME = "CrateTrackerZK";

local function BuildAboutText()
    return About and About.GetAboutText and About:GetAboutText() or "About information not available"
end


function Info:Initialize()
    if self.isInitialized then
        return;
    end
    self.isInitialized = true;
    -- 调试模式下显示初始化信息
    Logger:DebugLimited("info:init_complete", "Info", "初始化", "信息模块已初始化");
end

function Info:ShowAnnouncement()
    if not self.isInitialized then
        self:Initialize();
    end
    
    if self.currentFrame == 'announcement' then
        self:HideAll();
        return;
    end
    
    self:HideAll();
    
    if not self.announcementFrame then
        self:CreateAnnouncementFrame();
    end
    
    if CrateTrackerZKFrame and CrateTrackerZKFrame.tableContainer then
        CrateTrackerZKFrame.tableContainer:Hide();
    end
    
    self.announcementFrame:Show();
    self.currentFrame = 'announcement';
    
    Logger:Debug("Info", "调试", "用户操作：打开关于界面");
end

function Info:ShowIntroduction()
    if not self.isInitialized then
        self:Initialize();
    end
    
    if self.currentFrame == 'introduction' then
        self:HideAll();
        return;
    end
    
    self:HideAll();
    
    if not self.introductionFrame then
        self:CreateIntroductionFrame();
    end
    
    if CrateTrackerZKFrame and CrateTrackerZKFrame.tableContainer then
        CrateTrackerZKFrame.tableContainer:Hide();
    end
    
    self.introductionFrame:Show();
    self.currentFrame = 'introduction';
    
    Logger:Debug("Info", "调试", "用户操作：打开帮助界面");
end

function Info:HideAll()
    if self.announcementFrame then
        self.announcementFrame:Hide();
    end
    
    if self.introductionFrame then
        self.introductionFrame:Hide();
    end
    
    if CrateTrackerZKFrame and CrateTrackerZKFrame.tableContainer then
        CrateTrackerZKFrame.tableContainer:Show();
    end
    
    self.currentFrame = nil;
    
    Logger:Debug("Info", "调试", "用户操作：返回主界面");
end

function Info:CreateAnnouncementFrame()
    local frame = CrateTrackerZKFrame;
    if not frame then
        return;
    end
    
    local announcementFrame = CreateFrame('Frame', nil, frame);
    announcementFrame:SetPoint('TOPLEFT', frame, 'TOPLEFT', 20, -40);
    announcementFrame:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -20, 20);
    announcementFrame:Hide();
    
    local scrollFrame = CreateFrame('ScrollFrame', nil, announcementFrame, 'UIPanelScrollFrameTemplate');
    scrollFrame:SetPoint('TOPLEFT', announcementFrame, 'TOPLEFT', 10, -10);
    scrollFrame:SetPoint('BOTTOMRIGHT', announcementFrame, 'BOTTOMRIGHT', -30, 50);
    
    local content = CreateFrame('Frame', nil, scrollFrame);
    content:SetSize(1, 1);
    content:SetPoint('TOPLEFT', scrollFrame, 'TOPLEFT', 0, 0);
    
    -- 使用EditBox替代FontString，支持文字选择和复制
    local contentText = CreateFrame('EditBox', nil, content);
    contentText:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, 0);
    contentText:SetPoint('TOPRIGHT', content, 'TOPRIGHT', 0, 0);
    contentText:SetFontObject('GameFontHighlightLeft');
    contentText:SetMultiLine(true);
    contentText:SetAutoFocus(false);
    contentText:EnableMouse(true);
    contentText:SetScript('OnEscapePressed', function() contentText:ClearFocus() end);
    contentText:SetScript('OnEditFocusLost', function() contentText:HighlightText(0, 0) end);
    
    -- 设置为只读模式，但允许选择和复制
    local originalText = BuildAboutText();
    contentText:SetScript('OnTextChanged', function(self)
        if self.ignoreTextChanged then return end
        self.ignoreTextChanged = true
        self:SetText(originalText)
        self.ignoreTextChanged = false
    end);
    
    contentText.ignoreTextChanged = true;
    contentText:SetText(originalText);
    contentText.ignoreTextChanged = false;
    
    scrollFrame:SetScript('OnSizeChanged', function(self)
        self:GetScrollChild():SetWidth(self:GetWidth() - 10);
    end);
    
    local function UpdateContentHeight()
        local textHeight = contentText:GetHeight();
        if textHeight > 0 then
            content:SetHeight(textHeight + 40);
        end
    end
    
    scrollFrame:SetScrollChild(content);
    
    C_Timer.After(0.1, UpdateContentHeight);
    C_Timer.After(0.2, UpdateContentHeight);
    
    local backButton = CreateFrame('Button', nil, announcementFrame, 'UIPanelButtonTemplate');
    backButton:SetSize(100, 30);
    backButton:SetPoint('BOTTOM', announcementFrame, 'BOTTOM', 0, 10);
    backButton:SetText(L["Return"]);
    backButton:SetScript('OnClick', function()
        Info:HideAll();
    end);
    
    self.announcementFrame = announcementFrame;
end

function Info:CreateIntroductionFrame()
    local frame = CrateTrackerZKFrame;
    if not frame then
        return;
    end
    
    local introductionFrame = CreateFrame('Frame', nil, frame);
    introductionFrame:SetPoint('TOPLEFT', frame, 'TOPLEFT', 20, -40);
    introductionFrame:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -20, 20);
    introductionFrame:Hide();
    
    local scrollFrame = CreateFrame('ScrollFrame', nil, introductionFrame, 'UIPanelScrollFrameTemplate');
    scrollFrame:SetPoint('TOPLEFT', introductionFrame, 'TOPLEFT', 10, -10);
    scrollFrame:SetPoint('BOTTOMRIGHT', introductionFrame, 'BOTTOMRIGHT', -30, 50);
    
    local content = CreateFrame('Frame', nil, scrollFrame);
    content:SetSize(1, 1);
    content:SetPoint('TOPLEFT', scrollFrame, 'TOPLEFT', 0, 0);
    
    -- 使用EditBox替代FontString，支持文字选择和复制
    local contentText = CreateFrame('EditBox', nil, content);
    contentText:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, 0);
    contentText:SetPoint('TOPRIGHT', content, 'TOPRIGHT', 0, 0);
    contentText:SetFontObject('GameFontHighlightLeft');
    contentText:SetMultiLine(true);
    contentText:SetAutoFocus(false);
    contentText:EnableMouse(true);
    contentText:SetScript('OnEscapePressed', function() contentText:ClearFocus() end);
    contentText:SetScript('OnEditFocusLost', function() contentText:HighlightText(0, 0) end);
    
    -- 使用已引用的Help模块
    local helpText = Help and Help.GetHelpText and Help:GetHelpText() or (L["HelpText"] or "Help text not available")
    
    -- 设置为只读模式，但允许选择和复制
    contentText:SetScript('OnTextChanged', function(self)
        if self.ignoreTextChanged then return end
        self.ignoreTextChanged = true
        self:SetText(helpText)
        self.ignoreTextChanged = false
    end);
    
    contentText.ignoreTextChanged = true;
    contentText:SetText(helpText);
    contentText.ignoreTextChanged = false;
    
    scrollFrame:SetScript('OnSizeChanged', function(self)
        self:GetScrollChild():SetWidth(self:GetWidth() - 10);
    end);
    
    local function UpdateContentHeight()
        local textHeight = contentText:GetHeight();
        if textHeight > 0 then
            content:SetHeight(textHeight + 40);
        end
    end
    
    scrollFrame:SetScrollChild(content);
    
    C_Timer.After(0.1, UpdateContentHeight);
    C_Timer.After(0.2, UpdateContentHeight);
    
    local backButton = CreateFrame('Button', nil, introductionFrame, 'UIPanelButtonTemplate');
    backButton:SetSize(100, 30);
    backButton:SetPoint('BOTTOM', introductionFrame, 'BOTTOM', 0, 10);
    backButton:SetText(L["Return"]);
    backButton:SetScript('OnClick', function()
        Info:HideAll();
    end);
    
    self.introductionFrame = introductionFrame;
end


return Info;


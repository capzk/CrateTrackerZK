-- CrateTrackerZK - 信息界面模块
if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local CrateTrackerZK = BuildEnv("CrateTrackerZK");
local L = CrateTrackerZK.L;
local Info = BuildEnv('Info');

if not Debug then
    error("Info: Debug module not loaded!");
end

Info.isInitialized = false;
Info.currentFrame = nil;

local function RemoveColorCodes(text)
    if not text then return "" end;
    text = text:gsub('|c[0-9a-fA-F]+', '');
    text = text:gsub('|r', '');
    return text;
end

function Info:Initialize()
    if self.isInitialized then
        return;
    end
    self.isInitialized = true;
    Debug:Print("信息模块已初始化");
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
    
    if Debug:IsEnabled() then
        Debug:Print("用户操作: 打开公告界面");
    end
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
    
    if Debug:IsEnabled() then
        Debug:Print("用户操作: 打开插件简介界面");
    end
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
    
    if Debug:IsEnabled() then
        Debug:Print("用户操作: 返回主界面");
    end
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
    
    local contentText = content:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightLeft');
    contentText:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, 0);
    contentText:SetPoint('TOPRIGHT', content, 'TOPRIGHT', 0, 0);
    contentText:SetJustifyH('LEFT');
    contentText:SetJustifyV('TOP');
    contentText:SetWordWrap(true);
    contentText:SetSpacing(2);
    
    local plainText = RemoveColorCodes(L["AnnouncementText"]);
    contentText:SetText(plainText);
    
    scrollFrame:SetScript('OnSizeChanged', function(self)
        self:GetScrollChild():SetWidth(self:GetWidth() - 10);
    end);
    
    local function UpdateContentHeight()
        local textHeight = contentText:GetStringHeight();
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
    
    local contentText = content:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightLeft');
    contentText:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, 0);
    contentText:SetPoint('TOPRIGHT', content, 'TOPRIGHT', 0, 0);
    contentText:SetJustifyH('LEFT');
    contentText:SetJustifyV('TOP');
    contentText:SetWordWrap(true);
    contentText:SetSpacing(2);
    
    local plainText = RemoveColorCodes(L["IntroductionText"]);
    contentText:SetText(plainText);
    
    scrollFrame:SetScript('OnSizeChanged', function(self)
        self:GetScrollChild():SetWidth(self:GetWidth() - 10);
    end);
    
    local function UpdateContentHeight()
        local textHeight = contentText:GetStringHeight();
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


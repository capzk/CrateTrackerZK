if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local CrateTrackerZK = BuildEnv("CrateTrackerZK");
local L = CrateTrackerZK.L;
local Info = BuildEnv('Info');

-- Info.lua 不再依赖 Debug 模块，使用 Logger 模块

Info.isInitialized = false;
Info.currentFrame = nil;

local ADDON_NAME = "CrateTrackerZK";

local function GetAddonVersion()
    if not GetAddOnMetadata then
        return "1.1.3-beta";
    end
    
    local version = GetAddOnMetadata(ADDON_NAME, "Version");
    if version and version ~= "" then
        return version;
    end
    
    for i = 1, GetNumAddOns() do
        local name = GetAddOnInfo(i);
        if name == ADDON_NAME then
            local metaVersion = GetAddOnMetadata(i, "Version");
            if metaVersion and metaVersion ~= "" then
                return metaVersion;
            end
        end
    end
    
    return "1.1.3-beta";
end

local function BuildAboutText()
    local version = GetAddonVersion();
    return string.format([[
Version: %s
Project: https://github.com/capzk/CrateTrackerZK
License: MIT license
Author: capzk
Contact: capzk@outlook.com
]], version);
end

local HELP_TEXT = [[
可用命令：

/ctk help        显示可用命令
/ctk team on/off 开启/关闭团队通知
/ctk clear       清除本地数据并重新初始化

如何获取位面ID：

要获取当前位面ID，您只需将鼠标指向任意NPC。位面ID将自动检测并显示在主面板中。

重要提示：

如果插件升级后出现任何问题，请彻底删除此插件目录并重新安装。

Available Commands:

/ctk help        Show available commands
/ctk team on/off Enable or disable team notifications
/ctk clear       Clear local data and reinitialize

How to Get Phasing ID:

To get the current phasing ID, point your mouse at any NPC. The phasing ID will be automatically detected and displayed in the main panel.

Important Notes:

If you encounter any issues after updating the addon, please completely delete the addon folder and reinstall it from scratch.
]];

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
    
    local contentText = content:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightLeft');
    contentText:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, 0);
    contentText:SetPoint('TOPRIGHT', content, 'TOPRIGHT', 0, 0);
    contentText:SetJustifyH('LEFT');
    contentText:SetJustifyV('TOP');
    contentText:SetWordWrap(true);
    contentText:SetSpacing(2);
    
    contentText:SetText(BuildAboutText());
    
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
    
    contentText:SetText(HELP_TEXT);
    
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


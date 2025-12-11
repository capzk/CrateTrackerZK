-- 空投物资追踪器 - 信息界面模块
-- 负责管理公告和插件简介界面的显示

-- 确保BuildEnv函数存在
if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

-- 定义Info命名空间
local Info = BuildEnv('Info');

-- 确保Debug命名空间存在
if not Debug then
    error("Info: Debug module not loaded!");
end
-- 确保InfoText命名空间存在
if not InfoText then
    error("Info: InfoText module not loaded!");
end

Info.isInitialized = false;
Info.currentFrame = nil; -- 当前显示的界面（'announcement' 或 'introduction' 或 nil）

-- 初始化信息模块
function Info:Initialize()
    if self.isInitialized then
        return;
    end
    self.isInitialized = true;
    Debug:Print("信息模块已初始化");
end

-- 显示公告界面
function Info:ShowAnnouncement()
    if not self.isInitialized then
        self:Initialize();
    end
    
    -- 如果当前显示的是公告，则关闭它（切换功能）
    if self.currentFrame == 'announcement' then
        self:HideAll();
        return;
    end
    
    -- 关闭其他界面
    self:HideAll();
    
    -- 创建公告界面（如果不存在）
    if not self.announcementFrame then
        self:CreateAnnouncementFrame();
    end
    
    -- 隐藏主表格
    if CrateTrackerFrame and CrateTrackerFrame.tableContainer then
        CrateTrackerFrame.tableContainer:Hide();
    end
    
    -- 显示公告界面
    self.announcementFrame:Show();
    self.currentFrame = 'announcement';
    
    if Debug:IsEnabled() then
        Debug:Print("用户操作: 打开公告界面");
    end
end

-- 显示插件简介界面
function Info:ShowIntroduction()
    if not self.isInitialized then
        self:Initialize();
    end
    
    -- 如果当前显示的是简介，则关闭它（切换功能）
    if self.currentFrame == 'introduction' then
        self:HideAll();
        return;
    end
    
    -- 关闭其他界面
    self:HideAll();
    
    -- 创建简介界面（如果不存在）
    if not self.introductionFrame then
        self:CreateIntroductionFrame();
    end
    
    -- 隐藏主表格
    if CrateTrackerFrame and CrateTrackerFrame.tableContainer then
        CrateTrackerFrame.tableContainer:Hide();
    end
    
    -- 显示简介界面
    self.introductionFrame:Show();
    self.currentFrame = 'introduction';
    
    if Debug:IsEnabled() then
        Debug:Print("用户操作: 打开插件简介界面");
    end
end

-- 隐藏所有信息界面，显示主表格
function Info:HideAll()
    -- 隐藏公告界面
    if self.announcementFrame then
        self.announcementFrame:Hide();
    end
    
    -- 隐藏简介界面
    if self.introductionFrame then
        self.introductionFrame:Hide();
    end
    
    -- 显示主表格
    if CrateTrackerFrame and CrateTrackerFrame.tableContainer then
        CrateTrackerFrame.tableContainer:Show();
    end
    
    self.currentFrame = nil;
    
    if Debug:IsEnabled() then
        Debug:Print("用户操作: 返回主界面");
    end
end

-- 创建公告界面
function Info:CreateAnnouncementFrame()
    local frame = CrateTrackerFrame;
    if not frame then
        return;
    end
    
    -- 创建公告容器
    local announcementFrame = CreateFrame('Frame', nil, frame);
    announcementFrame:SetPoint('TOPLEFT', frame, 'TOPLEFT', 20, -40);
    announcementFrame:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -20, 20);
    announcementFrame:Hide();
    
    -- 创建标题
    local title = announcementFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge');
    title:SetPoint('TOP', announcementFrame, 'TOP', 0, -10);
    title:SetText('|cff00ff88插件公告|r');
    
    -- 创建滚动框架
    local scrollFrame = CreateFrame('ScrollFrame', nil, announcementFrame, 'UIPanelScrollFrameTemplate');
    scrollFrame:SetPoint('TOPLEFT', announcementFrame, 'TOPLEFT', 10, -40); -- 从容器左上角开始，留出标题空间
    scrollFrame:SetPoint('BOTTOMRIGHT', announcementFrame, 'BOTTOMRIGHT', -30, 50); -- 右边留30像素给滚动条，底部留50像素给返回按钮
    
    -- 创建内容容器
    local content = CreateFrame('Frame', nil, scrollFrame);
    content:SetSize(1, 1);
    content:SetPoint('TOPLEFT', scrollFrame, 'TOPLEFT', 0, 0);
    
    -- 创建内容文本
    local contentText = content:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightLeft');
    contentText:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, 0);
    contentText:SetPoint('TOPRIGHT', content, 'TOPRIGHT', 0, 0); -- 使用TOPRIGHT锚点自动填充宽度
    contentText:SetJustifyH('LEFT');
    contentText:SetJustifyV('TOP');
    contentText:SetWordWrap(true);
    contentText:SetSpacing(2); -- 添加行间距
    
    -- 改进的颜色代码移除函数，保留换行符
    -- 使用更通用的正则表达式匹配所有可能的颜色代码格式
    local function RemoveColorCodes(text)
        if not text then return "" end;
        -- 移除所有 |c 开头的颜色代码（匹配 |c 后跟任意数量的十六进制字符）
        text = text:gsub('|c[0-9a-fA-F]+', ''); -- 移除 |c 和后面的十六进制字符
        text = text:gsub('|r', ''); -- 移除 |r
        -- 确保换行符被保留
        return text;
    end
    
    local plainText = RemoveColorCodes(InfoText.Announcement);
    contentText:SetText(plainText);
    
    -- 当滚动框架大小改变时，更新内容容器宽度
    scrollFrame:SetScript('OnSizeChanged', function(self)
        self:GetScrollChild():SetWidth(self:GetWidth() - 10); -- 只减10像素，给滚动条留空间
    end);
    
    -- 更新高度的函数
    local function UpdateContentHeight()
        local textHeight = contentText:GetStringHeight();
        if textHeight > 0 then
            content:SetHeight(textHeight + 40); -- 增加底部边距
        end
    end
    
    scrollFrame:SetScrollChild(content);
    
    -- 延迟更新高度，确保文本已渲染
    C_Timer.After(0.1, UpdateContentHeight);
    C_Timer.After(0.2, UpdateContentHeight); -- 二次更新确保正确
    
    -- 创建返回按钮
    local backButton = CreateFrame('Button', nil, announcementFrame, 'UIPanelButtonTemplate');
    backButton:SetSize(100, 30);
    backButton:SetPoint('BOTTOM', announcementFrame, 'BOTTOM', 0, 10);
    backButton:SetText('返回');
    backButton:SetScript('OnClick', function()
        Info:HideAll();
    end);
    
    self.announcementFrame = announcementFrame;
end

-- 创建插件简介界面
function Info:CreateIntroductionFrame()
    local frame = CrateTrackerFrame;
    if not frame then
        return;
    end
    
    -- 创建简介容器
    local introductionFrame = CreateFrame('Frame', nil, frame);
    introductionFrame:SetPoint('TOPLEFT', frame, 'TOPLEFT', 20, -40);
    introductionFrame:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -20, 20);
    introductionFrame:Hide();
    
    -- 创建标题
    local title = introductionFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge');
    title:SetPoint('TOP', introductionFrame, 'TOP', 0, -10);
    title:SetText('|cff00ff88插件简介|r');
    
    -- 创建滚动框架
    local scrollFrame = CreateFrame('ScrollFrame', nil, introductionFrame, 'UIPanelScrollFrameTemplate');
    scrollFrame:SetPoint('TOPLEFT', introductionFrame, 'TOPLEFT', 10, -40); -- 从容器左上角开始，留出标题空间
    scrollFrame:SetPoint('BOTTOMRIGHT', introductionFrame, 'BOTTOMRIGHT', -30, 50); -- 右边留30像素给滚动条，底部留50像素给返回按钮
    
    -- 创建内容容器
    local content = CreateFrame('Frame', nil, scrollFrame);
    content:SetSize(1, 1);
    content:SetPoint('TOPLEFT', scrollFrame, 'TOPLEFT', 0, 0);
    
    -- 创建内容文本
    local contentText = content:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightLeft');
    contentText:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, 0);
    contentText:SetPoint('TOPRIGHT', content, 'TOPRIGHT', 0, 0); -- 使用TOPRIGHT锚点自动填充宽度
    contentText:SetJustifyH('LEFT');
    contentText:SetJustifyV('TOP');
    contentText:SetWordWrap(true);
    contentText:SetSpacing(2); -- 添加行间距
    
    -- 改进的颜色代码移除函数，保留换行符
    -- 使用更通用的正则表达式匹配所有可能的颜色代码格式
    local function RemoveColorCodes(text)
        if not text then return "" end;
        -- 移除所有 |c 开头的颜色代码（匹配 |c 后跟任意数量的十六进制字符）
        text = text:gsub('|c[0-9a-fA-F]+', ''); -- 移除 |c 和后面的十六进制字符
        text = text:gsub('|r', ''); -- 移除 |r
        -- 确保换行符被保留
        return text;
    end
    
    local plainText = RemoveColorCodes(InfoText.Introduction);
    contentText:SetText(plainText);
    
    -- 当滚动框架大小改变时，更新内容容器宽度
    scrollFrame:SetScript('OnSizeChanged', function(self)
        self:GetScrollChild():SetWidth(self:GetWidth() - 10); -- 只减10像素，给滚动条留空间
    end);
    
    -- 更新高度的函数
    local function UpdateContentHeight()
        local textHeight = contentText:GetStringHeight();
        if textHeight > 0 then
            content:SetHeight(textHeight + 40); -- 增加底部边距
        end
    end
    
    scrollFrame:SetScrollChild(content);
    
    -- 延迟更新高度，确保文本已渲染
    C_Timer.After(0.1, UpdateContentHeight);
    C_Timer.After(0.2, UpdateContentHeight); -- 二次更新确保正确
    
    -- 创建返回按钮
    local backButton = CreateFrame('Button', nil, introductionFrame, 'UIPanelButtonTemplate');
    backButton:SetSize(100, 30);
    backButton:SetPoint('BOTTOM', introductionFrame, 'BOTTOM', 0, 10);
    backButton:SetText('返回');
    backButton:SetScript('OnClick', function()
        Info:HideAll();
    end);
    
    self.introductionFrame = introductionFrame;
end


return Info;


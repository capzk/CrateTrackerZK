-- 箱子追踪器主入口文件

-- 模拟魔兽世界API（仅用于语法检查）
if not CreateFrame then
    CreateFrame = function() return { CreateFontString = function() return {} end, SetSize = function() end, SetPoint = function() end, SetScript = function() end, StartMoving = function() end, StopMovingOrSizing = function() end, Hide = function() end, Show = function() end, IsShown = function() return false end, RegisterEvent = function() end } end;
    _G = _G or {};
    print = print or function() end;
    GetScreenWidth = function() return 1920 end;
    GetScreenHeight = function() return 1080 end;
    GameFontNormal = {};
    GameFontHighlight = {};
    GameFontDisable = {};
    GameTooltip = { SetOwner = function() end, SetText = function() end, AddLine = function() end, Show = function() end, Hide = function() end };
end

-- 定义构建环境函数
if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

-- 调试函数（使用Debug模块）
local function DebugPrint(msg, ...)
    if Debug and Debug:IsEnabled() then
        Debug:Print(msg, ...);
    end
end

-- 限制调试信息输出频率（使用Debug模块）
local function DebugPrintLimited(messageKey, msg, ...)
    if Debug and Debug:IsEnabled() then
        Debug:PrintLimited(messageKey, msg, ...);
    end
end

-- 创建命名空间
local CrateTracker = BuildEnv("CrateTracker");

-- 定义插件常量
local ADDON_NAME = "CrateTracker";

-- 初始化数据库
local function InitializeDB()
    -- 初始化UI数据库
    if not CRATETRACKER_UI_DB then
        CRATETRACKER_UI_DB = {
            version = 1,
            position = { point = "CENTER", x = 0, y = 0 },
            minimapButton = { 
                hide = false, 
                position = { 
                    point = "TOPLEFT", 
                    x = 50, 
                    y = -50 
                },
            },
        };
    else
        -- 确保minimapButton配置存在
        if not CRATETRACKER_UI_DB.minimapButton then
            CRATETRACKER_UI_DB.minimapButton = { 
                hide = false, 
                position = { 
                    point = "TOPLEFT", 
                    x = 50, 
                    y = -50 
                },
            };
        else
            -- 确保position字段存在
            if not CRATETRACKER_UI_DB.minimapButton.position then
                CRATETRACKER_UI_DB.minimapButton.position = { 
                    point = "TOPLEFT", 
                    x = 50, 
                    y = -50 
                };
            end
        end
    end
    
    -- 通用数据存储已由Data模块初始化，这里不再需要初始化
end

-- 创建浮动按钮
local function CreateFloatingButton()
    -- 确保数据库结构完整
    if not CRATETRACKER_UI_DB then
        InitializeDB();
    end
    
    -- 检查按钮是否已存在
    if CrateTrackerFloatingButton then
        -- 如果按钮已存在，确保它在正确的位置并显示
        local pos = CRATETRACKER_UI_DB.minimapButton.position;
        
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
            CRATETRACKER_UI_DB.minimapButton.position = { point = point, x = x, y = y };
        end
        
        CrateTrackerFloatingButton:ClearAllPoints();
        CrateTrackerFloatingButton:SetPoint(point, UIParent, point, x, y);
        
        -- 确保按钮显示
        if not (CrateTrackerFrame and CrateTrackerFrame:IsShown()) then
            DebugPrint("显示浮动按钮");
            CrateTrackerFloatingButton:Show();
        else
            DebugPrint("主窗口已显示，隐藏浮动按钮");
            CrateTrackerFloatingButton:Hide();
        end
        
        return CrateTrackerFloatingButton;
    end
    
    DebugPrint("创建浮动按钮");
    
    -- 创建浮动按钮，使用UIMenuButtonStretchTemplate模板实现圆角效果
    local button = CreateFrame("Button", "CrateTrackerFloatingButton", UIParent, "UIMenuButtonStretchTemplate");
    button:SetSize(140, 32); -- 增大按钮尺寸以适应更长的文字
    
    -- 设置按钮层级（确保按钮显示在最前面）
    button:SetFrameStrata("HIGH");
    button:SetFrameLevel(100);
    
    -- 加载保存的位置
    local pos = CRATETRACKER_UI_DB.minimapButton.position;
    
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
        CRATETRACKER_UI_DB.minimapButton.position = { point = point, x = x, y = y };
        DebugPrint("使用默认位置: " .. point .. ", x=" .. x .. ", y=" .. y);
    end
    
    -- 设置按钮到保存的位置
    button:ClearAllPoints();
    button:SetPoint(point, UIParent, point, x, y);
    
    DebugPrint("按钮初始位置: " .. point .. ", x=" .. x .. ", y=" .. y);
    
    -- 设置按钮属性
    button:SetMovable(true);
    button:EnableMouse(true);
    button:RegisterForDrag("LeftButton");
    button:SetText("空投物资追踪器");
    
    -- 设置按钮文本属性
    button:SetNormalFontObject(GameFontNormal);
    button:SetHighlightFontObject(GameFontHighlight);
    button:SetDisabledFontObject(GameFontDisable);
    button.Text:SetTextColor(1, 1, 1); -- 设置文本颜色为白色
    
    -- 设置按钮状态
    button:Enable(); -- 确保按钮是启用状态
    
    -- 根据主窗口状态决定按钮初始显示状态
    if CrateTrackerFrame and CrateTrackerFrame:IsShown() then
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
        local width = self:GetWidth();
        local height = self:GetHeight();
        
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
        if CRATETRACKER_UI_DB then
            local pos = CRATETRACKER_UI_DB.minimapButton.position;
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
        GameTooltip:SetText("空投物资追踪器");
        GameTooltip:AddLine("点击打开/关闭追踪面板");
        GameTooltip:AddLine("拖动可以移动按钮位置");
        GameTooltip:Show();
    end);
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide();
    end);
    
    -- 保存引用
    CrateTracker.floatingButton = button;
    
    -- 默认显示按钮（除非主窗口已显示）
    if CrateTrackerFrame and CrateTrackerFrame:IsShown() then
        DebugPrint("主窗口已显示，隐藏浮动按钮");
        button:Hide();
    else
        DebugPrint("主窗口未显示，显示浮动按钮");
        button:Show();
    end
    
    -- 验证按钮是否真正显示
    if button:IsShown() then
        DebugPrint("浮动按钮创建成功并显示");
    else
        DebugPrint("浮动按钮创建成功但被隐藏");
    end
    
    return button;
end

-- 区域检查函数：判断是否在有效的检测区域（不在副本、战场或室内）
local function CheckValidArea()
    -- 检查是否在室内
    if IsIndoors() then
        return false;
    end
    
    -- 检查是否在副本或战场
    local instanceType = select(4, GetInstanceInfo());
    if instanceType == "party" or instanceType == "raid" or instanceType == "pvp" or instanceType == "arena" or instanceType == "scenario" then
        return false;
    end
    
    return true;
end

-- NPC喊话检测函数
local function CheckNPCSpeech(message, speaker)
    -- 检查是否是路费欧斯的喊话（精确匹配说话者名称）
    if not speaker or speaker ~= "路费欧斯" then
        return false;
    end
    
    -- 记录所有路费欧斯的喊话（用于调试，但只在调试模式开启时输出详细信息）
    -- 注意：这里先记录原始消息，后续会检查是否匹配空投关键词
    
    -- 移除消息中的颜色代码和特殊字符
    local cleanMessage = message;
    if cleanMessage then
        -- 移除颜色代码 |c...|r
        cleanMessage = cleanMessage:gsub("|c[0-9a-fA-F]+", "");
        cleanMessage = cleanMessage:gsub("|r", "");
        -- 去除首尾空白字符
        cleanMessage = cleanMessage:match("^%s*(.-)%s*$");
    end
    
    if not cleanMessage then
        DebugPrint("路费欧斯喊话处理失败：消息为空或无效");
        return false;
    end
    
    -- 检查消息是否完全匹配指定的四句话之一（精确匹配，避免误报）
    local keywords = {
            "附近好像有宝藏，自然也会有宝藏猎手了。小心背后。",
            "附近有满满一箱资源，赶紧找，不然难免大打出手哦！",
            "机会送上门来了！只要你够有勇气，那些宝贝在等着你呢。",
            "区域里出现了珍贵资源！快去抢吧！"
        }
    
    for _, keyword in ipairs(keywords) do
        -- 精确匹配，确保消息完全等于关键词
        if cleanMessage == keyword then
            DebugPrint("【NPC喊话】检测到空投喊话（精确匹配）: " .. cleanMessage);
            return true;
        end
    end
    
    -- 未匹配到空投喊话（不输出调试信息，避免刷屏）
    -- 确保返回false，不触发时间更新
    -- 重要：只有完全匹配四句空投关键词之一才返回true，其他所有喊话都返回false
    return false;
end

-- 获取当前地图ID（使用最新的正式服API）
local function GetCurrentMapId()
    return C_Map.GetBestMapForUnit("player");
end

-- 通过NPC获取位面信息的函数
local function GetLayerFromNPC()
    -- 尝试获取鼠标悬停的NPC或单位
    local unit = "mouseover";
    local guid = UnitGUID(unit);
    
    if not guid then
        -- 如果鼠标没有悬停在单位上，尝试获取目标单位
        unit = "target";
        guid = UnitGUID(unit);
    end
    
    if guid then
        local unitType, _, serverID, _, layerUID = strsplit("-", guid);
        if (unitType == "Creature" or unitType == "Vehicle") and serverID and layerUID then
            return serverID .. "-" .. layerUID;
        end
    end
    return nil;
end

-- 跟踪是否有任何地图获取过位面ID
local anyInstanceIDAcquired = false;

-- 区域变化事件防重复处理标记
local zoneChangePending = false;

-- ==================== 三个独立的核心检测模块 ====================
-- 1. 地图有效性检测（事件驱动，区域变化时检测）
local lastAreaValidState = nil; -- 记录上次的地图有效性状态

-- 检测功能暂停/恢复控制（变量将在后面定义，这里先声明）
local phaseTimer = nil; -- 位面检测定时器（将在后面创建）
local eventFrame = nil; -- 事件框架（将在后面创建）
local phaseLastTime = 0; -- 位面检测计时器累计时间
local PHASE_INTERVAL = 10; -- 位面检测间隔（10秒）

-- 检测功能暂停/恢复控制
local detectionPaused = false; -- 检测功能是否已暂停
local phaseTimerPaused = false; -- 位面检测定时器是否已暂停
local npcSpeechEventRegistered = true; -- NPC喊话事件是否已注册
local phaseTimerResumePending = false; -- 位面检测定时器恢复是否正在进行中（防止重复创建延迟定时器）

-- 前向声明：位面检测函数（将在后面定义）
local UpdatePhaseInfo;

-- 暂停所有检测功能
local function PauseAllDetections()
    if detectionPaused then
        return; -- 已经暂停，避免重复操作
    end
    detectionPaused = true;
    
    -- 暂停位面检测定时器
    if phaseTimer and not phaseTimerPaused then
        phaseTimer:SetScript("OnUpdate", nil);
        phaseTimerPaused = true;
        phaseTimerResumePending = false; -- 清除恢复标记（如果正在恢复，取消恢复）
        DebugPrint("【检测控制】位面检测定时器已暂停");
    end
    
    -- 暂停地图图标检测定时器
    if TimerManager then
        TimerManager:StopMapIconDetection();
        DebugPrint("【检测控制】地图图标检测定时器已暂停");
    end
    
    -- 暂停NPC喊话检测（取消注册事件）
    if eventFrame and npcSpeechEventRegistered then
        eventFrame:UnregisterEvent("CHAT_MSG_MONSTER_SAY");
        npcSpeechEventRegistered = false;
        DebugPrint("【检测控制】NPC喊话检测已暂停");
    end
end

-- 恢复所有检测功能
local function ResumeAllDetections()
    if not detectionPaused then
        return; -- 已经恢复，避免重复操作
    end
    detectionPaused = false;
    
    -- 恢复地图图标检测定时器（立即启动）
    if TimerManager then
        TimerManager:StartMapIconDetection(3);
        DebugPrint("【检测控制】地图图标检测定时器已恢复");
    end
    
    -- 恢复NPC喊话检测（立即启动，重新注册事件）
    if eventFrame and not npcSpeechEventRegistered then
        eventFrame:RegisterEvent("CHAT_MSG_MONSTER_SAY");
        npcSpeechEventRegistered = true;
        DebugPrint("【检测控制】NPC喊话检测已恢复");
    end
    
    -- 恢复位面检测定时器（延迟6秒启动）
    if phaseTimer and phaseTimerPaused and not phaseTimerResumePending then
        phaseTimerResumePending = true; -- 标记为正在恢复，防止重复创建定时器
        DebugPrint("【检测控制】位面检测定时器将在6秒后启动");
        C_Timer.After(6, function()
            phaseTimerResumePending = false; -- 清除标记
            if phaseTimer and phaseTimerPaused then
                phaseTimer:SetScript("OnUpdate", function(self, elapsed)
                    phaseLastTime = phaseLastTime + elapsed;
                    if phaseLastTime >= PHASE_INTERVAL then
                        phaseLastTime = 0;
                        UpdatePhaseInfo();
                    end
                end);
                phaseTimerPaused = false;
                DebugPrint("【检测控制】位面检测定时器已恢复（延迟6秒后启动）");
            end
        end);
    end
end

-- 地图有效性检测函数（作为总开关，供其他模块调用）
function CheckAndUpdateAreaValid()
    -- 检查是否在副本/战场/室内
    local isIndoors = IsIndoors();
    local instanceType = select(4, GetInstanceInfo());
    local isInstance = (instanceType == "party" or instanceType == "raid" or instanceType == "pvp" or instanceType == "arena" or instanceType == "scenario");
    
    -- 如果是在副本/战场/室内，直接返回无效
    if isIndoors or isInstance then
        if lastAreaValidState ~= false then
            lastAreaValidState = false;
            -- 只在调试模式下输出提示信息
            DebugPrint("【地图有效性】区域无效（副本/战场/室内），插件已自动暂停");
            -- 暂停所有检测功能
            PauseAllDetections();
        end
        return false;
    end
    
    -- 检查是否在地图列表中（通过地图ID匹配）
    local currentMapID = GetCurrentMapId();
    if not currentMapID then
        if lastAreaValidState ~= false then
            lastAreaValidState = false;
            DebugPrint("【地图有效性】无法获取地图ID");
            -- 暂停所有检测功能
            PauseAllDetections();
        end
        return false;
    end
    
    local currentMapName = "";
    local parentMapName = "";
    local mapInfo = C_Map.GetMapInfo(currentMapID);
    if mapInfo then
        if mapInfo.name then
            currentMapName = mapInfo.name;
        end
        if mapInfo.parentMapID then
            local parentMapInfo = C_Map.GetMapInfo(mapInfo.parentMapID);
            if parentMapInfo and parentMapInfo.name then
                parentMapName = parentMapInfo.name;
            end
        end
    end
    
    -- 检查是否在主城（地心之战版本主城：多恩诺嘉尔）
    -- 主城是无效区域，不能检测空投
    local capitalCityName = "多恩诺嘉尔";
    local cleanCapitalCityName = string.lower(string.gsub(capitalCityName, "[%p ]", ""));
    local cleanCurrentMapName = string.lower(string.gsub(currentMapName, "[%p ]", ""));
    
    if cleanCurrentMapName == cleanCapitalCityName then
        if lastAreaValidState ~= false then
            lastAreaValidState = false;
            -- 只在调试模式下输出提示信息
            DebugPrint("【地图有效性】区域无效（主城），插件已自动暂停: " .. currentMapName);
            -- 暂停所有检测功能
            PauseAllDetections();
        end
        return false;
    end
    
    -- 检查是否在有效地图列表中
    if Data then
        local maps = Data:GetAllMaps();
        local isValid = false;
        local matchedMapName = nil;
        
        -- 1. 检查当前地图
        for _, mapData in ipairs(maps) do
            local cleanMapDataName = string.lower(string.gsub(mapData.mapName, "[%p ]", ""));
            local cleanCurrentMapName = string.lower(string.gsub(currentMapName, "[%p ]", ""));
            if cleanMapDataName == cleanCurrentMapName then
                isValid = true;
                matchedMapName = currentMapName;
                break;
            end
        end
        
        -- 2. 检查父地图
        if not isValid and parentMapName ~= "" then
            for _, mapData in ipairs(maps) do
                local cleanMapDataName = string.lower(string.gsub(mapData.mapName, "[%p ]", ""));
                local cleanParentMapName = string.lower(string.gsub(parentMapName, "[%p ]", ""));
                if cleanMapDataName == cleanParentMapName then
                    isValid = true;
                    matchedMapName = parentMapName;
                    break;
                end
            end
        end
        
        -- 状态变化提示
        if isValid then
            if lastAreaValidState ~= true then
                lastAreaValidState = true;
                -- 只在调试模式下输出提示信息
                DebugPrint("【地图有效性】区域有效，插件已启用: " .. (matchedMapName or currentMapName));
                -- 恢复所有检测功能
                ResumeAllDetections();
            end
            return true;
        else
            if lastAreaValidState ~= false then
                lastAreaValidState = false;
                -- 只在调试模式下输出提示信息
                DebugPrint("【地图有效性】区域无效（不在有效地图列表中），插件已自动暂停: " .. currentMapName);
                -- 暂停所有检测功能
                PauseAllDetections();
            end
            return false;
        end
    end
    
    return false;
end

-- 2. 位面检测（独立、持续监听）
-- 注意：此函数只在区域有效时被调用（定时器已暂停时不会调用）
-- 前提条件：1. 区域有效 2. 不是子区域 3. 不是主城
UpdatePhaseInfo = function()
    -- 首先检查区域有效性（大前提）
    if detectionPaused then
        DebugPrintLimited("phase_detection_paused", "【位面检测】检测功能已暂停，跳过位面检测");
        return;
    end
    
    if Data then
        -- 获取当前地图信息（使用最新的正式服API）
        local currentMapID = GetCurrentMapId();
        if not currentMapID then
            DebugPrintLimited("no_map_id_phase", "无法获取当前地图ID，跳过位面信息更新");
            return;
        end
        
        local currentMapName = "";
        local parentMapName = "";
        
        -- 使用C_Map.GetMapInfo获取详细地图信息（只获取当前地图和父地图）
        local mapInfo = C_Map.GetMapInfo(currentMapID);
        if mapInfo then
            if mapInfo.name then
                currentMapName = mapInfo.name;
                
                -- 获取父地图信息（如果有）
                if mapInfo.parentMapID then
                    local parentMapInfo = C_Map.GetMapInfo(mapInfo.parentMapID);
                    if parentMapInfo and parentMapInfo.name then
                        parentMapName = parentMapInfo.name;
                    end
                end
            end
        else
            -- 如果无法通过C_Map获取，使用GetInstanceInfo作为备选
            local instanceName = select(1, GetInstanceInfo());
            if instanceName then
                currentMapName = instanceName;
            end
        end
        
        -- 检查是否在主城（主城是无效区域，不检测位面）
        local capitalCityName = "多恩诺嘉尔";
        local cleanCapitalCityName = string.lower(string.gsub(capitalCityName, "[%p ]", ""));
        local cleanCurrentMapName = string.lower(string.gsub(currentMapName, "[%p ]", ""));
        if cleanCurrentMapName == cleanCapitalCityName then
            DebugPrintLimited("capital_city_phase", "【位面检测】当前在主城（无效区域），跳过位面检测: " .. currentMapName);
            return;
        end
        
        -- 合并地图信息输出（只在调试模式下输出，且限制频率）
        if currentMapName ~= "" then
            local mapInfoText = "【地图信息】地图ID=" .. tostring(currentMapID) .. " 地图名称=" .. currentMapName;
            if parentMapName ~= "" then
                mapInfoText = mapInfoText .. " 父地图=" .. parentMapName;
            end
            DebugPrintLimited("map_info_" .. tostring(currentMapID), mapInfoText);
        end
        
        -- 查找对应的地图数据
        local maps = Data:GetAllMaps();
        local targetMapData = nil;
        local matchedMapName = nil;
        local isSubArea = false;  -- 标记是否为子区域（有父地图且父地图在有效列表中）
        
        -- 1. 首先尝试匹配当前地图名称（使用不区分大小写的比较，增加匹配的灵活性）
        for _, mapData in ipairs(maps) do
            -- 移除可能的特殊字符并转换为小写进行比较
            local cleanMapDataName = string.lower(string.gsub(mapData.mapName, "[%p ]", ""));
            local cleanCurrentMapName = string.lower(string.gsub(currentMapName, "[%p ]", ""));
            
            if cleanMapDataName == cleanCurrentMapName then
                targetMapData = mapData;
                matchedMapName = currentMapName;
                -- 检查是否有父地图，且父地图也在有效地图列表中（子区域判断）
                if parentMapName ~= "" then
                    for _, parentMapData in ipairs(maps) do
                        local cleanParentMapDataName = string.lower(string.gsub(parentMapData.mapName, "[%p ]", ""));
                        local cleanParentMapName = string.lower(string.gsub(parentMapName, "[%p ]", ""));
                        if cleanParentMapDataName == cleanParentMapName then
                            -- 当前地图匹配，但父地图也在有效列表中，说明当前是子区域
                            isSubArea = true;
                            DebugPrintLimited("subarea_detected_" .. tostring(currentMapID), "【位面检测】检测到子区域: " .. currentMapName .. " (父地图=" .. parentMapName .. ")，跳过位面检测");
                            break;
                        end
                    end
                end
                if not isSubArea then
                    DebugPrintLimited("map_match_" .. tostring(currentMapID), "【位面检测】地图匹配成功: " .. currentMapName);
                end
                break;
            end
        end
        
        -- 2. 如果当前地图名称匹配失败，尝试使用父地图名称进行匹配
        if not targetMapData and parentMapName ~= "" then
            for _, mapData in ipairs(maps) do
                -- 移除可能的特殊字符并转换为小写进行比较
                local cleanMapDataName = string.lower(string.gsub(mapData.mapName, "[%p ]", ""));
                local cleanParentMapName = string.lower(string.gsub(parentMapName, "[%p ]", ""));
                
                if cleanMapDataName == cleanParentMapName then
                    targetMapData = mapData;
                    matchedMapName = parentMapName;
                    isSubArea = true;  -- 父地图匹配，是子区域
                    DebugPrintLimited("parent_match_" .. tostring(currentMapID), "【位面检测】父地图匹配成功（子区域，跳过位面检测）: " .. parentMapName);
                    break;
                end
            end
        end
        
        -- 位面检测：只有非子区域（当前地图直接匹配且没有父地图在有效列表中）才进行位面检查和更新位面ID数据
        -- 子区域（有父地图且父地图在有效列表中）不检测也不处理任何位面数据
        -- 主城等无效区域：不会匹配到 targetMapData，也不会检测位面
        if targetMapData and not isSubArea then
            -- 获取当前地图的位面信息（根据用户要求，只从NPC获取）
            local instanceID = nil;
            
            -- 只尝试从NPC获取位面信息
            local npcLayerInfo = GetLayerFromNPC();
            if npcLayerInfo then
                instanceID = npcLayerInfo;
                -- 只在位面ID变化时输出详细信息
                if instanceID ~= targetMapData.instance then
                    DebugPrint("【位面检测】从NPC获取到位面ID: " .. targetMapData.mapName .. " = " .. instanceID);
                else
                    DebugPrintLimited("phase_same_" .. targetMapData.id, "【位面检测】位面ID未变化: " .. targetMapData.mapName .. " = " .. instanceID);
                end
            else
                DebugPrintLimited("no_npc_" .. targetMapData.id, "【位面检测】未检测到NPC，无法获取位面ID: " .. targetMapData.mapName);
            end
            
            -- 只有当instanceID与当前值不同时才更新
            if instanceID ~= targetMapData.instance then
                -- 如果获取到了新的位面ID，才更新
                if instanceID then
                    -- 位面发生变化，只更新位面信息，不干扰空投检测
                    -- 空投检测逻辑完全独立，不受位面变化影响
                    
                    -- 先保存旧值，因为 UpdateMap 会立即更新 targetMapData
                    local oldInstance = targetMapData.instance;
                    
                    -- 更新地图的位面信息，保存上一次的位面ID
                    Data:UpdateMap(targetMapData.id, { lastInstance = oldInstance, instance = instanceID });
                    DebugPrint("【位面检测】位面ID已更新: " .. targetMapData.mapName .. " 旧=" .. (oldInstance or "无") .. " 新=" .. instanceID);
                    
                    -- 只有在位面ID发生变化时才显示提示
                    -- 注意：使用 oldInstance 判断，因为 targetMapData.instance 已经被更新为新值
                    if oldInstance then
                        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r 地图[|cffffcc00" .. targetMapData.mapName .. "|r]位面已变更为：|cffffff00" .. instanceID .. "|r");
                    else
                        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r 当前位面ID为：|cffffff00" .. instanceID .. "|r");
                    end
                    
                    -- 更新界面显示
                    if MainPanel and MainPanel.UpdateTable then
                        MainPanel:UpdateTable();
                    end
                elseif not targetMapData.instance then
                    -- 如果没有获取到位面ID且当前也没有位面ID，无需操作
                    DebugPrintLimited("no_phase_" .. targetMapData.id, "【位面检测】无法获取位面ID: " .. targetMapData.mapName);
                else
                    -- 如果没有获取到新的位面ID，但当前已有位面ID，保留原有位面ID
                    -- 同时检查是否需要初始化lastInstance（重新加载插件时，如果lastInstance为nil，应该初始化为当前的instance）
                    if not targetMapData.lastInstance and targetMapData.instance then
                        Data:UpdateMap(targetMapData.id, { lastInstance = targetMapData.instance });
                        DebugPrint("【位面检测】重新加载时初始化lastInstance: " .. targetMapData.mapName .. " = " .. targetMapData.instance);
                    end
                    DebugPrintLimited("keep_phase_" .. targetMapData.id, "【位面检测】保留原有位面ID: " .. targetMapData.mapName .. " = " .. targetMapData.instance);
                end
            elseif instanceID and instanceID == targetMapData.instance then
                -- 位面ID相同，但需要确保lastInstance正确初始化
                -- 如果lastInstance为nil，应该初始化为当前的instance，避免显示红色
                if not targetMapData.lastInstance and targetMapData.instance then
                    Data:UpdateMap(targetMapData.id, { lastInstance = targetMapData.instance });
                    DebugPrint("【位面检测】初始化lastInstance: " .. targetMapData.mapName .. " = " .. targetMapData.instance);
                end
            elseif not instanceID and targetMapData.instance then
                -- 重新加载插件时，如果无法获取位面ID，但已有保存的位面ID
                -- 检查是否需要初始化lastInstance（避免显示红色）
                if not targetMapData.lastInstance and targetMapData.instance then
                    Data:UpdateMap(targetMapData.id, { lastInstance = targetMapData.instance });
                    DebugPrint("【位面检测】重新加载时初始化lastInstance（无法获取当前位面ID）: " .. targetMapData.mapName .. " = " .. targetMapData.instance);
                end
            end
        elseif targetMapData and isSubArea then
            -- 子区域：不检测也不处理任何位面数据
            DebugPrintLimited("subarea_skip_phase_" .. tostring(currentMapID), "【位面检测】当前在子区域，跳过位面检测: " .. currentMapName .. " (父地图=" .. matchedMapName .. ")");
        end
        
        -- 检查是否有任何地图获取过位面ID
        local anyInstance = false;
        for _, mapData in ipairs(maps) do
            if mapData.instance then
                anyInstance = true;
                break;
            end
        end
        
        -- 如果从未获取过任何位面ID，提示玩家使用鼠标指向NPC
        if not anyInstance and not anyInstanceIDAcquired then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r 未获取任何位面ID，请使用鼠标指向任何NPC以获取当前位面ID");
            anyInstanceIDAcquired = true; -- 只提示一次
        end
    end
end

-- 事件处理函数
local function OnEvent(self, event, ...)
    if event == "PLAYER_LOGIN" then
        DebugPrint("【游戏事件】玩家登录");
        -- 显示插件加载的欢迎信息
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r 插件已加载，祝您游戏愉快！");
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r 使用 |cffffcc00/ct help|r 查看帮助信息");
        -- 初始化数据
        -- 初始化各个模块（合并调试信息，减少输出）
        if Data then
            Data:Initialize();
        end
        if Debug then
            Debug:Initialize();
            if Info then
                Info:Initialize();
            end
        end
        if Notification then
            Notification:Initialize();
        end
        if Commands then
            Commands:Initialize();
        end
        DebugPrint("【初始化】数据、调试、通知、命令模块初始化完成");
        -- 初始化TimerManager
        if TimerManager then
            TimerManager:Initialize();
            -- 启动地图图标检测
            TimerManager:StartMapIconDetection(3);
        end
        -- 创建UI
        if MainPanel then
            MainPanel:CreateMainFrame();
        end
        -- 创建浮动按钮
        CreateFloatingButton();
        -- 初始化时检测地图有效性（只在区域变化时检测，初始化时检测一次）
        -- 注意：初始化时不进行位面检测，位面检测由其他逻辑（区域变化、定时器、事件触发）负责
        CheckAndUpdateAreaValid();
        DebugPrint("【初始化】插件初始化完成（TimerManager、UI、地图检测已启动）");
    elseif event == "CHAT_MSG_MONSTER_SAY" then
        -- 空投检测：NPC喊话检测
        -- 注意：如果区域无效，事件已被取消注册，此函数不会被调用
        -- 但为了安全起见，仍然检查检测是否已暂停
        if detectionPaused then
            return;
        end
        
        -- 检查当前地图是否在有效地图列表中
        local currentMapID = GetCurrentMapId();
        if not currentMapID then
            DebugPrintLimited("no_map_id_npc", "【NPC喊话】无法获取当前地图ID，跳过处理");
            return;
        end
        
        local currentMapName = "";
        local parentMapName = "";
        local mapInfo = C_Map.GetMapInfo(currentMapID);
        if mapInfo then
            if mapInfo.name then
                currentMapName = mapInfo.name;
            end
            -- 获取父地图信息（用于子区域匹配）
            if mapInfo.parentMapID then
                local parentMapInfo = C_Map.GetMapInfo(mapInfo.parentMapID);
                if parentMapInfo and parentMapInfo.name then
                    parentMapName = parentMapInfo.name;
                end
            end
        end
        
        if currentMapName and Data then
            local maps = Data:GetAllMaps();
            local isInValidMap = false;
            
            -- 1. 首先尝试匹配当前地图名称
            for _, mapData in ipairs(maps) do
                local cleanMapDataName = string.lower(string.gsub(mapData.mapName, "[%p ]", ""));
                local cleanCurrentMapName = string.lower(string.gsub(currentMapName, "[%p ]", ""));
                if cleanMapDataName == cleanCurrentMapName then
                    isInValidMap = true;
                    DebugPrintLimited("npc_map_match_" .. tostring(currentMapID), "【NPC喊话】地图匹配成功: " .. currentMapName);
                    break;
                end
            end
            
            -- 2. 如果当前地图不匹配，尝试匹配父地图（子区域情况）
            if not isInValidMap and parentMapName ~= "" then
                for _, mapData in ipairs(maps) do
                    local cleanMapDataName = string.lower(string.gsub(mapData.mapName, "[%p ]", ""));
                    local cleanParentMapName = string.lower(string.gsub(parentMapName, "[%p ]", ""));
                    if cleanMapDataName == cleanParentMapName then
                        isInValidMap = true;
                        DebugPrintLimited("npc_parent_match_" .. tostring(currentMapID), "【NPC喊话】父地图匹配成功（子区域）: " .. currentMapName .. " (父地图=" .. parentMapName .. ")");
                        break;
                    end
                end
            end
            
            if not isInValidMap then
                DebugPrintLimited("map_not_in_list_npc", "【NPC喊话】当前地图不在有效列表中，跳过处理: " .. currentMapName);
                return;
            end
        end
        
        local message, speaker = ...;
        -- 先检查是否匹配空投喊话，只有匹配成功才更新时间
        local isAirdropSpeech = CheckNPCSpeech(message, speaker);
        if isAirdropSpeech then
            -- 通过TimerManager启动当前地图计时（内部会检查冷却期）
            if TimerManager then
                TimerManager:StartCurrentMapTimer(TimerManager.detectionSources.NPC_SPEECH);
                DebugPrint("【NPC喊话】检测到空投喊话，已启动计时");
            end
        end
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
        -- 防止ZONE_CHANGED和ZONE_CHANGED_NEW_AREA同时触发时重复处理
        -- 使用延迟处理，确保只处理一次
        if not zoneChangePending then
            zoneChangePending = true;
            -- 延迟0.1秒处理，避免重复触发
            C_Timer.After(0.1, function()
                zoneChangePending = false;
                DebugPrint("【游戏事件】区域变化: " .. event);
                -- 区域变化时，首先检测地图有效性（这是总开关，只在区域变化时检测一次）
                -- 地图有效性检测：检查是否在副本/战场/室内，检查是否在有效地图列表中
                -- 如果区域有效，会自动恢复检测功能；如果区域无效，会自动暂停检测功能
                local wasInvalidBefore = (lastAreaValidState == false);
                CheckAndUpdateAreaValid();
                local justBecameValid = wasInvalidBefore and (lastAreaValidState == true);
                
                -- 区域变化后，如果区域有效，执行一次检测
                if not detectionPaused then
                    -- 区域变化时检测地图图标（空投检测，独立运行，立即启动）
                    if TimerManager then
                        TimerManager:DetectMapIcons();
                    end
                    
                    -- 位面检测：如果刚刚从无效区域变为有效区域，延迟6秒后再检测
                    -- 否则立即检测（区域在有效区域内切换）
                    if justBecameValid then
                        -- 从无效区域变为有效区域，延迟6秒后再检测位面
                        DebugPrint("【检测控制】区域从无效变为有效，位面检测将在6秒后执行");
                        C_Timer.After(6, function()
                            if not detectionPaused then
                                UpdatePhaseInfo();
                            end
                        end);
                    else
                        -- 区域在有效区域内切换，立即检测位面
                        UpdatePhaseInfo();
                    end
                end
            end);
        else
            DebugPrintLimited("zone_change_pending", "【游戏事件】区域变化（已处理，跳过重复）: " .. event);
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        -- 当玩家选择目标时，也尝试更新位面信息（仅在区域有效时执行）
        -- 注意：如果区域无效，检测功能已暂停，不需要更新位面信息
        if not detectionPaused then
            UpdatePhaseInfo();
        end
    end
end

-- 添加鼠标悬停事件监听
if C_TooltipInfo and TooltipDataProcessor then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, tooltipData)
        if tooltip == GameTooltip then
            -- 鼠标悬停在单位上时更新位面信息（仅在区域有效时执行）
            -- 注意：如果区域无效，检测功能已暂停，不需要更新位面信息
            if not detectionPaused then
                UpdatePhaseInfo();
            end
        end
    end)
else
    -- 旧版API支持
    GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip) 
        -- 鼠标悬停在单位上时更新位面信息（仅在区域有效时执行）
        if not detectionPaused then
            UpdatePhaseInfo();
        end
    end);
end

-- 命令行处理函数（使用Commands模块）
local function HandleCommand(msg)
    -- 确保Commands模块已加载
    if not Commands then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[空投物资追踪器]|r 命令模块未加载，请重新加载插件");
        return;
    end
    
    -- 如果未初始化，先初始化
    if not Commands.isInitialized then
        Commands:Initialize();
    end
    
    Commands:HandleCommand(msg);
end

-- 注册命令行（支持 /ct 和 /crate，推荐使用 /ct）
SLASH_CRATETRACKER1 = "/ct"
SLASH_CRATETRACKER2 = "/crate"  -- 保留兼容性
SlashCmdList.CRATETRACKER = HandleCommand;

-- 创建事件框架
eventFrame = CreateFrame("Frame");
eventFrame:SetScript("OnEvent", OnEvent);
eventFrame:RegisterEvent("PLAYER_LOGIN");
eventFrame:RegisterEvent("CHAT_MSG_MONSTER_SAY");
eventFrame:RegisterEvent("ZONE_CHANGED");
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA");
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED");

-- ==================== 两个独立的定时检测框架 ====================
-- 注意：地图有效性检测已改为事件驱动（ZONE_CHANGED/ZONE_CHANGED_NEW_AREA），不再需要定时检测
-- 因为区域变化事件已经能捕获所有区域变化，定时检测是多余的

-- 1. 位面检测定时器（每10秒检测一次，独立运行）
phaseTimer = CreateFrame("Frame");

phaseTimer:SetScript("OnUpdate", function(self, elapsed)
    -- 如果检测功能已暂停，不执行检测
    if detectionPaused or phaseTimerPaused then
        return;
    end
    phaseLastTime = phaseLastTime + elapsed;
    if phaseLastTime >= PHASE_INTERVAL then
        phaseLastTime = 0;
        -- 独立检测位面信息（不依赖其他功能）
        UpdatePhaseInfo();
    end
end);

-- 3. 空投检测已在TimerManager中独立运行（每3秒检测一次地图图标）

-- 初始化插件
InitializeDB();

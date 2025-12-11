--[[
    通知模块 (Notification.lua)
    负责处理所有通知功能，包括玩家通知和团队通知
]]

-- 确保BuildEnv函数存在
if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

-- 定义Notification命名空间
local Notification = BuildEnv('Notification');

-- 模块状态
Notification.isInitialized = false;
Notification.teamNotificationEnabled = true; -- 团队通知开关（默认开启）

-- 初始化通知模块
function Notification:Initialize()
    if self.isInitialized then
        return;
    end
    
    self.isInitialized = true;
    
    -- 从保存的变量中加载团队通知设置
    if CRATETRACKER_UI_DB and CRATETRACKER_UI_DB.teamNotificationEnabled ~= nil then
        self.teamNotificationEnabled = CRATETRACKER_UI_DB.teamNotificationEnabled;
    else
        -- 如果数据库中没有保存的值，使用默认值（开启）并保存
        self.teamNotificationEnabled = true;
        if not CRATETRACKER_UI_DB then
            CRATETRACKER_UI_DB = {};
        end
        CRATETRACKER_UI_DB.teamNotificationEnabled = true;
    end
    
    if Utils and Utils.Debug then
        Utils.Debug("通知模块已初始化");
    end
end

-- 获取团队通知状态
function Notification:IsTeamNotificationEnabled()
    return self.teamNotificationEnabled;
end

-- 设置团队通知状态
function Notification:SetTeamNotificationEnabled(enabled)
    self.teamNotificationEnabled = enabled;
    
    -- 保存到数据库
    if not CRATETRACKER_UI_DB then
        CRATETRACKER_UI_DB = {};
    end
    CRATETRACKER_UI_DB.teamNotificationEnabled = enabled;
    
    local statusText = enabled and "已开启" or "已关闭";
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r 团队通知" .. statusText);
    
    if Utils and Utils.Debug then
        Utils.Debug("通知模块: 团队通知状态已更新", "状态=" .. statusText);
    end
end

-- 发送空投事件通知
-- @param mapName 地图名称
-- @param detectionSource 检测源 ("npc_speech" 或 "map_icon")
function Notification:NotifyAirdropDetected(mapName, detectionSource)
    if not self.isInitialized then
        self:Initialize();
    end
    
    if not mapName then
        return;
    end
    
    local message = string.format("【%s】 发现 战争物资 正在空投！！！", mapName);
    
    -- 1. 通知玩家（始终通知）
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r " .. message);
    
    -- 2. 通知团队（只有在团队中且开启了团队通知才发送，使用团队警告）
    if self.teamNotificationEnabled and self:IsInRaid() then
        -- 使用 RAID_WARNING 发送团队警告消息（系统默认红色/橙色）
        local success, err = pcall(function()
            SendChatMessage(message, "RAID_WARNING");
        end);
        if success then
            if Utils and Utils.Debug then
                Utils.Debug("通知模块: 已发送团队警告通知", "地图名称=" .. mapName, "检测源=" .. (detectionSource or "unknown"), "聊天类型=RAID_WARNING");
            end
        else
            if Utils and Utils.Debug then
                Utils.Debug("通知模块: 发送团队警告消息失败", "错误=" .. tostring(err));
            end
            -- 发送失败，回退到个人通知
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r " .. message);
        end
    elseif self.teamNotificationEnabled and not self:IsInRaid() then
        -- 开启了团队通知但不在团队中（可能在小队中或单人），只通知玩家
        if Utils and Utils.Debug then
            Utils.Debug("通知模块: 不在团队中，跳过团队通知", "地图名称=" .. mapName, "是否在小队中=" .. (IsInGroup() and "是" or "否"));
        end
    end
    
    if Utils and Utils.Debug then
        Utils.Debug("通知模块: 空投事件通知已发送", "地图名称=" .. mapName, "检测源=" .. (detectionSource or "unknown"), "团队通知=" .. (self.teamNotificationEnabled and "开启" or "关闭"));
    end
end

-- 获取团队聊天类型（用于手动通知）
-- @return string|nil 聊天类型（RAID/PARTY/INSTANCE_CHAT）或nil（不在团队中）
function Notification:GetTeamChatType()
    -- 检查是否在副本小队中（需要先检查LE_PARTY_CATEGORY_INSTANCE是否存在）
    if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        -- 在副本小队中
        return "INSTANCE_CHAT";
    elseif IsInRaid() then
        -- 在团队中
        return "RAID";
    elseif IsInGroup() then
        -- 在小队中
        return "PARTY";
    else
        -- 不在团队中
        return nil;
    end
end

-- 检查是否在团队中（不包括小队）
-- @return boolean 是否在团队中
function Notification:IsInRaid()
    return IsInRaid() == true;
end

-- 发送地图刷新时间通知（手动通知：根据空投事件状态发送不同消息）
-- @param mapData 地图数据
function Notification:NotifyMapRefresh(mapData)
    if not self.isInitialized then
        self:Initialize();
    end
    
    if not mapData then
        return;
    end
    
    -- 判断空投是否进行中：只检查地图图标标记（mapIconDetected）
    local isAirdropActive = false;
    if TimerManager and TimerManager.mapIconDetected and TimerManager.mapIconDetected[mapData.id] == true then
        isAirdropActive = true;
    end
    
    if isAirdropActive then
        -- 空投进行中：手动通知
        local message = string.format("【%s】 发现 战争物资 正在空投！！！", mapData.mapName);
        local chatType = self:GetTeamChatType();
        
        if chatType then
            -- 手动通知：在团队中直接发送到团队，不检查团队通知开关
            local success, err = pcall(function()
                SendChatMessage(message, chatType);
            end);
            if not success then
                if Utils and Utils.Debug then
                    Utils.Debug("通知模块: 发送团队消息失败", "错误=" .. tostring(err), "聊天类型=" .. chatType);
                end
                -- 发送失败，回退到个人通知
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r " .. message);
            end
        else
            -- 不在团队中，只发送给自己
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r " .. message);
        end
    else
        -- 空投未进行中：发送剩余刷新时间
        local remaining = Data:CalculateRemainingTime(mapData.nextRefresh);
        local message = "";
        if not remaining then
            message = string.format("【%s】 暂无时间记录！！！", mapData.mapName);
        else
            local remainingText = Data:FormatTime(remaining, true);
            message = string.format("【%s】 距离 战争物资 空投还有：%s！！！", mapData.mapName, remainingText);
        end
        
        -- 手动发送通知：不检查团队通知开关，如果在团队中就直接发送到团队
        local chatType = self:GetTeamChatType();
        
        if chatType then
            -- 在团队中，发送到团队聊天（只发送到团队，不发送给个人）
            local success, err = pcall(function()
                SendChatMessage(message, chatType);
            end);
            if not success then
                if Utils and Utils.Debug then
                    Utils.Debug("通知模块: 发送团队消息失败", "错误=" .. tostring(err), "聊天类型=" .. chatType);
                end
                -- 发送失败，回退到个人通知
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r " .. message);
            end
        else
            -- 不在团队中，只发送给自己
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r " .. message);
        end
    end
    
    if Utils and Utils.Debug then
        Utils.Debug("通知模块: 地图刷新时间通知已发送", "地图名称=" .. mapData.mapName, "空投进行中=" .. (isAirdropActive and "是" or "否"));
    end
end

return Notification;


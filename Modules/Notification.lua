-- Notification.lua - 处理空投检测通知和地图刷新通知

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;
local Notification = BuildEnv('Notification');
local Area = BuildEnv("Area");

Notification.isInitialized = false;
Notification.teamNotificationEnabled = true;
Notification.autoTeamReportEnabled = false;
Notification.autoTeamReportInterval = 60;
-- 首次通知时间记录（用于30秒限制）
Notification.firstNotificationTime = {};
-- 玩家发送通知记录（防止重复发送）
Notification.playerSentNotification = {};
-- 最近喊话时间记录（用于图标检测去重）
Notification.lastShoutTime = Notification.lastShoutTime or {};
Notification.SHOUT_DEDUP_WINDOW = 20;

local function DebugPrint(msg, ...)
    Logger:Debug("Notification", "调试", msg, ...);
end

function Notification:Initialize()
    if self.isInitialized then return end
    self.isInitialized = true;
    
    if CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.teamNotificationEnabled ~= nil then
        self.teamNotificationEnabled = CRATETRACKERZK_UI_DB.teamNotificationEnabled;
    else
        self.teamNotificationEnabled = true;
        if CRATETRACKERZK_UI_DB then
            CRATETRACKERZK_UI_DB.teamNotificationEnabled = true;
        end
    end

    self.autoTeamReportEnabled = false;

    if CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.autoTeamReportInterval ~= nil then
        local value = tonumber(CRATETRACKERZK_UI_DB.autoTeamReportInterval);
        if value and value > 0 then
            self.autoTeamReportInterval = math.floor(value);
        end
    else
        if CRATETRACKERZK_UI_DB then
            CRATETRACKERZK_UI_DB.autoTeamReportInterval = self.autoTeamReportInterval;
        end
    end
    
    DebugPrint("[通知] 通知模块已初始化");
end

function Notification:IsTeamNotificationEnabled()
    return self.teamNotificationEnabled;
end

function Notification:SetTeamNotificationEnabled(enabled)
    self.teamNotificationEnabled = enabled;
    
    if CRATETRACKERZK_UI_DB then
        CRATETRACKERZK_UI_DB.teamNotificationEnabled = enabled;
    end
    
    local statusText = enabled and L["Enabled"] or L["Disabled"];
    Logger:Info("Notification", "状态", statusText);

    if not enabled then
        self.autoTeamReportEnabled = false;
    end
    if CrateTrackerZK then
        if not enabled and CrateTrackerZK.StopAutoTeamReportTicker then
            CrateTrackerZK:StopAutoTeamReportTicker();
        elseif enabled and self:IsAutoTeamReportEnabled() and CrateTrackerZK.RestartAutoTeamReportTicker then
            CrateTrackerZK:RestartAutoTeamReportTicker();
        end
    end
end

function Notification:IsAutoTeamReportEnabled()
    return self.autoTeamReportEnabled == true;
end

function Notification:GetAutoTeamReportInterval()
    return self.autoTeamReportInterval or 60;
end

local function NormalizeInterval(value)
    local numberValue = tonumber(value);
    if not numberValue then
        return nil;
    end
    numberValue = math.floor(numberValue);
    if numberValue < 1 then
        return nil;
    end
    return numberValue;
end

function Notification:SetAutoTeamReportEnabled(enabled)
    if enabled and not self:IsTeamNotificationEnabled() then
        self.autoTeamReportEnabled = false;
        return;
    end
    self.autoTeamReportEnabled = enabled == true;
    if CrateTrackerZK and CrateTrackerZK.RestartAutoTeamReportTicker then
        CrateTrackerZK:RestartAutoTeamReportTicker();
    end
    if self.autoTeamReportEnabled and self:IsTeamNotificationEnabled() then
        self:SendAutoTeamReport();
    end
end

function Notification:SetAutoTeamReportInterval(seconds)
    local value = NormalizeInterval(seconds);
    if not value then
        return nil;
    end
    self.autoTeamReportInterval = value;
    if CRATETRACKERZK_UI_DB then
        CRATETRACKERZK_UI_DB.autoTeamReportInterval = value;
    end
    if CrateTrackerZK and CrateTrackerZK.RestartAutoTeamReportTicker then
        CrateTrackerZK:RestartAutoTeamReportTicker();
    end
    if self:IsAutoTeamReportEnabled() and self:IsTeamNotificationEnabled() then
        self:SendAutoTeamReport();
    end
    return value;
end

-- 更新首次通知时间（团队消息同步）
function Notification:UpdateFirstNotificationTime(mapName, notificationTime)
    if not mapName or not notificationTime then
        return;
    end
    
    if not self.firstNotificationTime[mapName] or notificationTime < self.firstNotificationTime[mapName] then
        self.firstNotificationTime[mapName] = notificationTime;
        Logger:Debug("Notification", "更新", string.format("更新首次通知时间：地图=%s，时间=%s", 
            mapName, UnifiedDataManager:FormatDateTime(notificationTime)));
    end
end

-- 检查30秒限制
function Notification:CanSendNotification(mapName)
    if not mapName then
        return false;
    end
    
    local currentTime = time();
    local firstNotificationTime = self.firstNotificationTime[mapName];
    
    if not firstNotificationTime then
        return true;
    end
    
    local timeSinceFirstNotification = currentTime - firstNotificationTime;
    if timeSinceFirstNotification > 30 then
        Logger:Debug("Notification", "限制", string.format("距离首次通知已超过30秒（%d秒），不允许发送：地图=%s", 
            timeSinceFirstNotification, mapName));
        return false;
    end
    
    return true;
end

function Notification:MarkPlayerSentNotification(mapName)
    if not mapName then
        return;
    end
    
    if not self.playerSentNotification[mapName] then
        self.playerSentNotification[mapName] = true;
        Logger:Debug("Notification", "标记", string.format("标记玩家已发送通知：地图=%s", mapName));
    end
end

function Notification:HasPlayerSentNotification(mapName)
    return self.playerSentNotification[mapName] == true;
end

function Notification:RecordShout(mapName, timestamp)
    if not mapName then return end
    self.lastShoutTime = self.lastShoutTime or {};
    self.lastShoutTime[mapName] = timestamp or time();
    Logger:Debug("Notification", "记录", string.format("记录喊话时间：地图=%s，时间=%s",
        mapName, UnifiedDataManager:FormatDateTime(self.lastShoutTime[mapName])));
end

function Notification:IsRecentShout(mapName, windowSeconds, currentTime)
    if not mapName then return false, nil end
    self.lastShoutTime = self.lastShoutTime or {};
    local lastTime = self.lastShoutTime[mapName];
    if not lastTime then return false, nil end
    windowSeconds = windowSeconds or self.SHOUT_DEDUP_WINDOW or 20;
    currentTime = currentTime or time();
    return (currentTime - lastTime) <= windowSeconds, lastTime;
end

function Notification:NotifyAirdropDetected(mapName, detectionSource)
    if not self.isInitialized then self:Initialize() end
    if not mapName then 
        Logger:Debug("Notification", "通知", "通知失败：地图名称为空");
        return 
    end
    
    local chatType = self:GetTeamChatType();
    local currentTime = time();
    -- 记录喊话时间，用于后续图标检测的去重
    if detectionSource == "npc_shout" then
        self:RecordShout(mapName, currentTime);
    end
    local isRecentShout, lastShoutTime = self:IsRecentShout(mapName, self.SHOUT_DEDUP_WINDOW, currentTime);
    if detectionSource == "map_icon" and isRecentShout then
        self:UpdateFirstNotificationTime(mapName, lastShoutTime or currentTime);
        self:MarkPlayerSentNotification(mapName);
        Logger:Debug("Notification", "去重", string.format("最近%ds内已由喊话触发，跳过图标二次通知：地图=%s，间隔=%ds",
            self.SHOUT_DEDUP_WINDOW, mapName, currentTime - (lastShoutTime or currentTime)));
        return;
    end
    
    if chatType and self.teamNotificationEnabled then
        -- 个人发送限制检查
        if self:HasPlayerSentNotification(mapName) then
            Logger:Debug("Notification", "通知", string.format("玩家已发送过通知，跳过发送：地图=%s，来源=%s", 
                mapName, detectionSource or "未知"));
            local message = string.format(L["AirdropDetected"], mapName);
            Logger:Info("Notification", "通知", message);
            return;
        end
        
        -- 30秒限制检查
        if not self:CanSendNotification(mapName) then
            Logger:Debug("Notification", "通知", string.format("超过30秒限制，不允许发送：地图=%s，来源=%s", 
                mapName, detectionSource or "未知"));
            local message = string.format(L["AirdropDetected"], mapName);
            Logger:Info("Notification", "通知", message);
            return;
        end
        
        -- 记录首次通知时间
        if not self.firstNotificationTime[mapName] then
            self.firstNotificationTime[mapName] = currentTime;
            Logger:Debug("Notification", "通知", string.format("记录首次通知时间：地图=%s，时间=%s", 
                mapName, UnifiedDataManager:FormatDateTime(currentTime)));
        end
        
        self:MarkPlayerSentNotification(mapName);
    end
    
    local message = string.format(L["AirdropDetected"], mapName);
    
    Logger:Debug("Notification", "通知", string.format("发送空投检测通知：地图=%s，来源=%s", mapName, detectionSource or "未知"));
    
    Logger:Debug("Notification", "调试", string.format("团队通知检查：chatType=%s, teamNotificationEnabled=%s, IsInRaid=%s, IsInGroup=%s", 
        tostring(chatType), tostring(self.teamNotificationEnabled), tostring(IsInRaid()), tostring(IsInGroup())));
    
    if chatType and self.teamNotificationEnabled then
        if IsInRaid() then
            local hasPermission = UnitIsGroupLeader("player") or UnitIsGroupAssistant("player");
            local raidChatType = hasPermission and "RAID_WARNING" or "RAID";
            Logger:Debug("Notification", "通知", string.format("发送团队通知：类型=%s，权限=%s", raidChatType, hasPermission and "有" or "无"));
            pcall(function()
                SendChatMessage(message, raidChatType);
            end);
        else
            Logger:Debug("Notification", "通知", string.format("发送小队通知：类型=%s", chatType));
            pcall(function()
                SendChatMessage(message, chatType);
            end);
        end
    else
        Logger:Info("Notification", "通知", message);
        if chatType and not self.teamNotificationEnabled then
            Logger:Debug("Notification", "通知", string.format("团队通知已禁用，仅发送系统消息：地图=%s", mapName));
        end
    end
end

function Notification:GetTeamChatType()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    return nil;
end

local function BuildAutoTeamReportMessage(mapName, remaining)
    local format = (L and L["AutoTeamReportMessage"]) or "Current [%s] War Supply Crate in: %s!!";
    local timeText = (UnifiedDataManager and UnifiedDataManager.FormatTime and UnifiedDataManager:FormatTime(remaining, true)) or "--:--";
    return string.format(format, mapName, timeText);
end

function Notification:GetNearestAirdropInfo()
    if not Data or not Data.GetAllMaps then
        return nil;
    end
    if not UnifiedDataManager or not UnifiedDataManager.GetRemainingTime then
        return nil;
    end

    local hiddenMaps = CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.hiddenMaps or {};
    local bestMap = nil;
    local bestRemaining = nil;

    for _, mapData in ipairs(Data:GetAllMaps() or {}) do
        if mapData and not (hiddenMaps and hiddenMaps[mapData.mapID]) then
            local remaining = UnifiedDataManager:GetRemainingTime(mapData.id);
            if remaining and remaining >= 0 then
                if not bestRemaining or remaining < bestRemaining then
                    bestRemaining = remaining;
                    bestMap = mapData;
                end
            end
        end
    end

    if not bestMap then
        return nil;
    end
    return bestMap, bestRemaining;
end

function Notification:SendAutoTeamReport()
    if not self.isInitialized then self:Initialize() end
    if not self:IsAutoTeamReportEnabled() then
        return false;
    end
    if not self:IsTeamNotificationEnabled() then
        return false;
    end

    if Area and Area.IsActive and not Area:IsActive() then
        return false;
    end

    local mapData, remaining = self:GetNearestAirdropInfo();
    if not mapData or remaining == nil then
        return false;
    end

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(mapData) or nil;
    if not mapName or mapName == "" then
        return false;
    end

    local message = BuildAutoTeamReportMessage(mapName, remaining);
    local chatType = self:GetTeamChatType();
    if chatType then
        if chatType == "RAID" and IsInRaid() then
            local hasPermission = UnitIsGroupLeader("player") or UnitIsGroupAssistant("player");
            local raidChatType = hasPermission and "RAID_WARNING" or "RAID";
            pcall(function()
                SendChatMessage(message, raidChatType);
            end);
        else
            pcall(function()
                SendChatMessage(message, chatType);
            end);
        end
    else
        if Logger and Logger.Info then
            Logger:Info("Notification", "通知", message);
        elseif DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(message);
        end
    end
    return true;
end

function Notification:NotifyMapRefresh(mapData, isAirdropActive)
    if not self.isInitialized then self:Initialize() end
    if not mapData then 
        Logger:Debug("Notification", "通知", "通知地图刷新失败：地图数据为空");
        return 
    end
    
    if isAirdropActive == nil then
        isAirdropActive = false;
        Logger:Debug("Notification", "通知", string.format("未传递空投状态参数，默认发送剩余时间：地图=%s", 
            Data:GetMapDisplayName(mapData)));
    end
    
    Logger:Debug("Notification", "通知", string.format("用户请求通知地图刷新：地图=%s，空投进行中=%s", 
        Data:GetMapDisplayName(mapData), isAirdropActive and "是" or "否"));
    
    local message;
    local systemMessage;
    local displayName = Data:GetMapDisplayName(mapData);
    local remaining = nil;
    
    if isAirdropActive then
        message = string.format(L["AirdropDetectedManual"], displayName);
        systemMessage = message;
    else
        remaining = UnifiedDataManager:GetRemainingTime(mapData.id);
        if not remaining then
            message = string.format(L["NoTimeRecord"], displayName);
            systemMessage = message;
        else
            message = string.format(L["TimeRemaining"], displayName, UnifiedDataManager:FormatTime(remaining, true));
            systemMessage = message;
        end
    end
    
    local chatType = self:GetTeamChatType();
    
    if chatType then
        Logger:Debug("Notification", "通知", string.format("发送小队/团队通知（手动）：类型=%s", chatType));
        local success, err = pcall(function()
            SendChatMessage(message, chatType);
        end);
        if not success then
            Logger:Debug("Notification", "调试", "发送团队消息失败:", err or "未知错误");
        end
    else
        Logger:Info("Notification", "通知", systemMessage);
    end
end


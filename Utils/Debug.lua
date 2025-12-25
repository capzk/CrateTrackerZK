if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local Debug = BuildEnv('Debug');

Debug.isInitialized = false;
Debug.enabled = false;
Debug.lastDebugMessage = {};
Debug.DEBUG_MESSAGE_INTERVAL = 30;
Debug.texts = {
    DebugNoRecord = "无记录",
    DebugTimerStarted = "计时开始：%s，来源=%s，下次=%s",
    DebugDetectionSourceManual = "手动输入",
    DebugDetectionSourceRefresh = "刷新按钮",
    DebugDetectionSourceAPI = "API 接口",
    DebugDetectionSourceMapIcon = "地图图标检测",
    DebugCannotGetMapName2 = "无法获取当前地图名称",
    DebugCMapAPINotAvailable = "C_Map API 不可用",
    DebugCannotGetMapID = "无法获取当前地图 ID",
    DebugCMapGetMapInfoNotAvailable = "C_Map.GetMapInfo 不可用",
    DebugMapListEmpty = "地图列表为空，跳过检测",
    DebugMapMatchSuccess = "匹配到地图：%s",
    DebugParentMapMatchSuccess = "匹配到父地图：%s（父=%s）",
    DebugMapNotInList = "当前地图不在列表中，跳过：%s（父=%s，ID=%s）",
    DebugMapIconNameNotConfigured = "空投箱名称未配置，跳过图标检测",
    DebugIconDetectionStart = "开始检测地图图标：%s，空投名称=%s",
    DebugDetectedMapIconVignette = "检测到地图图标：%s（空投名称=%s）",
    DebugFirstDetectionWait = "首次检测到图标，等待持续确认：%s",
    DebugContinuousDetectionConfirmed = "持续检测确认，更新时间并通知：%s（间隔=%s秒）",
    DebugUpdatedRefreshTime = "刷新时间已更新：%s，下一次=%s",
    DebugUpdateRefreshTimeFailed = "刷新时间更新失败：地图 ID=%s",
    DebugAirdropActive = "空投事件进行中：%s",
    DebugWaitingForConfirmation = "等待持续检测确认：%s（已等待=%s秒）",
    DebugClearedFirstDetectionTime = "清除首次检测时间，未再检测到图标：%s",
    DebugAirdropEnded = "未检测到图标，空投事件结束：%s",
    DebugAreaInvalidInstance = "区域无效（副本/战场/室内），自动暂停",
    DebugAreaCannotGetMapID = "无法获取地图 ID",
    DebugAreaValid = "区域有效，已恢复：%s",
    DebugAreaInvalidNotInList = "区域无效（不在列表中），自动暂停：%s",
    DebugPhaseDetectionPaused = "位面检测已暂停，跳过",
    DebugPhaseNoMapID = "无法获取当前地图 ID，跳过位面更新",
};

function Debug:GetText(key)
    return (self.texts and self.texts[key]) or key;
end

function Debug:Initialize()
    if self.isInitialized then
        return;
    end
    
    self.isInitialized = true;
    
    if CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.debugEnabled ~= nil then
        self.enabled = CRATETRACKERZK_UI_DB.debugEnabled;
    end
    
    if Utils and Utils.Debug then
        Utils.Debug("[Debug] Debug module initialized");
    end
end

function Debug:IsEnabled()
    return self.enabled;
end

function Debug:SetEnabled(enabled)
    self.enabled = enabled;
    
    if not CRATETRACKERZK_UI_DB then
        CRATETRACKERZK_UI_DB = {};
    end
    CRATETRACKERZK_UI_DB.debugEnabled = enabled;
    
    if Utils and Utils.SetDebugEnabled then
        Utils.SetDebugEnabled(enabled);
    end
end

function Debug:PrintLimited(messageKey, msg, ...)
    if not self.enabled then
        return;
    end
    
    local currentTime = time();
    local lastTime = self.lastDebugMessage[messageKey] or 0;
    
    if (currentTime - lastTime) >= self.DEBUG_MESSAGE_INTERVAL then
        self.lastDebugMessage[messageKey] = currentTime;
        self:Print(msg, ...);
    end
end

function Debug:Print(msg, ...)
    if not self.enabled then
        return;
    end
    
    if Utils and Utils.Debug then
        Utils.Debug(msg, ...);
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[CrateTrackerZK]|r " .. tostring(msg));
    end
end

function Debug:ClearMessageCache()
    self.lastDebugMessage = {};
end

return Debug;


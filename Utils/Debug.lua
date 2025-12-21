-- CrateTrackerZK - 调试模块
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


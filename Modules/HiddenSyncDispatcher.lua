-- HiddenSyncDispatcher.lua - 隐藏同步统一分发入口

local HiddenSyncDispatcher = BuildEnv("HiddenSyncDispatcher")

local function ClearArray(buffer)
    if type(buffer) ~= "table" then
        return {}
    end
    for index = #buffer, 1, -1 do
        buffer[index] = nil
    end
    return buffer
end

local function AppendHandler(outHandlers, handler)
    if type(outHandlers) ~= "table" or type(handler) ~= "table" then
        return
    end
    if type(handler.ADDON_PREFIX) ~= "string" or type(handler.HandleAddonEvent) ~= "function" then
        return
    end
    outHandlers[#outHandlers + 1] = handler
end

function HiddenSyncDispatcher:GetHandlers()
    self.handlersBuffer = ClearArray(self.handlersBuffer)
    AppendHandler(self.handlersBuffer, TeamCommListener)
    AppendHandler(self.handlersBuffer, PublicChannelSyncListener)
    return self.handlersBuffer
end

function HiddenSyncDispatcher:DispatchAddonEvent(event, prefix, payload, chatType, sender, ...)
    if type(prefix) ~= "string" or prefix == "" then
        return false
    end

    local handlers = self:GetHandlers()
    for _, handler in ipairs(handlers) do
        if handler.ADDON_PREFIX == prefix then
            if not handler.IsFeatureEnabled or handler:IsFeatureEnabled() == true then
                if handler:HandleAddonEvent(event, prefix, payload, chatType, sender, ...) == true then
                    return true
                end
            end
        end
    end

    return false
end

return HiddenSyncDispatcher

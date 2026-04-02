-- NotificationOutputService.lua - 通知输出适配

local NotificationOutputService = BuildEnv("NotificationOutputService")
local Logger = BuildEnv("Logger")
local TeamCommListener = BuildEnv("TeamCommListener")

local function NormalizeAddonCallResult(...)
    local secondary = select(2, ...)
    if secondary ~= nil then
        return secondary
    end
    return select(1, ...)
end

local function TryPlaySound(path)
    if not path or path == "" or not PlaySoundFile then
        return false
    end
    local ok, result = pcall(PlaySoundFile, path, "Master")
    if ok and result then
        return true
    end
    local ok2, result2 = pcall(PlaySoundFile, path)
    return ok2 and result2 == true
end

function NotificationOutputService:GetTeamChatType()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    return nil
end

function NotificationOutputService:PlayAirdropAlertSound(notification)
    if not notification or not notification.IsSoundAlertEnabled or not notification:IsSoundAlertEnabled() then
        return false
    end
    local played = TryPlaySound(notification.airdropAlertSoundFile)
    if not played then
        Logger:Warn("Notification", "通知", string.format("空投提示音播放失败：%s", tostring(notification.airdropAlertSoundFile)))
    end
    return played
end

function NotificationOutputService:PlayDelayedAlertSound(notification)
    if C_Timer and C_Timer.After then
        C_Timer.After(1, function()
            self:PlayAirdropAlertSound(notification)
        end)
        return
    end
    self:PlayAirdropAlertSound(notification)
end

local function ResolveAddonDistribution(chatType)
    if chatType == "RAID_WARNING" then
        return "RAID"
    end
    if chatType == "RAID" or chatType == "PARTY" or chatType == "INSTANCE_CHAT" then
        return chatType
    end
    return nil
end

local function ResolveAutomaticVisibleChatType()
    if IsInRaid() then
        local hasPermission = UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
        return hasPermission and "RAID_WARNING" or "RAID"
    end
    if IsInGroup() then
        return "PARTY"
    end
    return nil
end

function NotificationOutputService:GetAutomaticVisibleChatType()
    return ResolveAutomaticVisibleChatType()
end

local function ResolveStandardVisibleChatType()
    if IsInRaid() then
        return "RAID"
    end
    if IsInGroup() then
        return "PARTY"
    end
    return nil
end

function NotificationOutputService:GetStandardVisibleChatType()
    return ResolveStandardVisibleChatType()
end

function NotificationOutputService:SendMessage(notification, message, chatType)
    local autoChatType = self:GetAutomaticVisibleChatType()
    if chatType and notification and notification.teamNotificationEnabled and autoChatType then
        local success, err = pcall(function()
            SendChatMessage(message, autoChatType)
        end)
        if not success and Logger and Logger.Warn then
            Logger:Warn(
                "Notification",
                "通知",
                string.format("发送自动团队消息失败：类型=%s，错误=%s", autoChatType, tostring(err))
            )
        end
        return success
    end

    Logger:Info("Notification", "通知", message)
    return false
end

function NotificationOutputService:SendManualMessage(message, chatType)
    local standardChatType = self:GetStandardVisibleChatType()
    if chatType and standardChatType then
        local success, err = pcall(function()
            SendChatMessage(message, standardChatType)
        end)
        return success, err
    end
    return false, nil
end

function NotificationOutputService:SendAirdropSync(syncState, chatType)
    local distribution = ResolveAddonDistribution(chatType)
    if type(syncState) ~= "table" or not distribution then
        return false
    end

    if TeamCommListener and TeamCommListener.RegisterAddonPrefix then
        if TeamCommListener:RegisterAddonPrefix() ~= true then
            return false
        end
    end

    local prefix = TeamCommListener and TeamCommListener.ADDON_PREFIX or nil
    local payload = TeamCommListener and TeamCommListener.BuildAirdropPayload and TeamCommListener:BuildAirdropPayload(syncState) or nil
    if type(prefix) ~= "string" or prefix == "" then
        return false
    end
    if type(payload) ~= "string" or payload == "" then
        return false
    end
    local sendAddonMessage = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
    if type(sendAddonMessage) ~= "function" then
        return false
    end

    local ok, result = pcall(function()
        return NormalizeAddonCallResult(sendAddonMessage(prefix, payload, distribution))
    end)
    local success = ok and (result == true or result == 0)
    if not success and Logger and Logger.Warn then
        Logger:Warn("Notification", "通知", string.format("发送隐藏团队同步失败：prefix=%s，频道=%s", prefix, distribution))
    end
    return success
end

return NotificationOutputService

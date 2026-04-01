-- NotificationOutputService.lua - 通知输出适配

local NotificationOutputService = BuildEnv("NotificationOutputService")
local Logger = BuildEnv("Logger")

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

function NotificationOutputService:SendMessage(notification, message, chatType)
    if chatType and notification and notification.teamNotificationEnabled then
        if IsInRaid() then
            local hasPermission = UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
            local raidChatType = hasPermission and "RAID_WARNING" or "RAID"
            Logger:Debug("Notification", "通知", string.format("发送团队通知：类型=%s，权限=%s", raidChatType, hasPermission and "有" or "无"))
            pcall(function()
                SendChatMessage(message, raidChatType)
            end)
            return true
        end
        Logger:Debug("Notification", "通知", string.format("发送小队通知：类型=%s", chatType))
        pcall(function()
            SendChatMessage(message, chatType)
        end)
        return true
    end

    Logger:Info("Notification", "通知", message)
    return false
end

function NotificationOutputService:SendManualMessage(message, chatType)
    if chatType then
        local success, err = pcall(function()
            SendChatMessage(message, chatType)
        end)
        return success, err
    end
    return false, nil
end

return NotificationOutputService

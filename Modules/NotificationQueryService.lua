-- NotificationQueryService.lua - 通知查询与消息构建

local NotificationQueryService = BuildEnv("NotificationQueryService")
local Data = BuildEnv("Data")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local L = CrateTrackerZK and CrateTrackerZK.L or {}

function NotificationQueryService:BuildAirdropDetectedMessage(mapName)
    local format = (L and L["AirdropDetected"]) or "Airdrop detected on [%s]!"
    return string.format(format, mapName or "")
end

function NotificationQueryService:BuildAutoTeamReportMessage(mapName, remaining)
    local format = (L and L["AutoTeamReportMessage"]) or "Current [%s] War Supply Crate in: %s!!"
    local timeText = (UnifiedDataManager and UnifiedDataManager.FormatTime and UnifiedDataManager:FormatTime(remaining, true)) or "--:--"
    return string.format(format, mapName, timeText)
end

function NotificationQueryService:BuildSharedPhaseSyncAppliedMessage(mapName)
    local format = (L and L["SharedPhaseSyncApplied"]) or "Acquired the latest shared airdrop info for the current phase in [%s]."
    return string.format(format, mapName or "")
end

function NotificationQueryService:BuildTimeRemainingMessage(mapName, remaining)
    local format = (L and L["TimeRemaining"]) or "[%s]War Supplies airdrop in: %s!!!"
    local timeText = (UnifiedDataManager and UnifiedDataManager.FormatTime and UnifiedDataManager:FormatTime(remaining, true)) or "--:--"
    return string.format(format, mapName or "", timeText)
end

function NotificationQueryService:BuildPhaseTeamAlertMessage(mapName, previousPhaseID, currentPhaseID)
    local format = (L and L["PhaseTeamAlertMessage"]) or "Current %s phase changed: %s --> %s"
    local previousText = previousPhaseID ~= nil and tostring(previousPhaseID) or ((L and L["UnknownPhaseValue"]) or "unknown")
    local currentText = currentPhaseID ~= nil and tostring(currentPhaseID) or ((L and L["UnknownPhaseValue"]) or "unknown")
    return string.format(format, mapName or "", previousText, currentText)
end

function NotificationQueryService:BuildTrajectoryPredictionMessage(mapName, x, y)
    local format = (L and L["TrajectoryPredictionMatched"]) or "[%s] Matched airdrop trajectory, predicted drop coordinates: %.1f, %.1f"
    return string.format(format, mapName or "", tonumber(x) or 0, tonumber(y) or 0)
end

function NotificationQueryService:GetNearestAirdropInfo()
    if not Data or not Data.GetAllMaps then
        return nil
    end
    if not UnifiedDataManager or not UnifiedDataManager.GetRemainingTime then
        return nil
    end

    local bestMap = nil
    local bestRemaining = nil
    for _, mapData in ipairs(Data:GetAllMaps() or {}) do
        if mapData and not (Data and Data.IsMapHidden and Data:IsMapHidden(mapData.expansionID, mapData.mapID)) then
            local remaining = UnifiedDataManager:GetRemainingTime(mapData.id)
            if remaining and remaining >= 0 then
                if not bestRemaining or remaining < bestRemaining then
                    bestRemaining = remaining
                    bestMap = mapData
                end
            end
        end
    end

    if not bestMap then
        return nil
    end
    return bestMap, bestRemaining
end

return NotificationQueryService

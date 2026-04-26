-- NotificationQueryService.lua - 通知查询与消息构建

local NotificationQueryService = BuildEnv("NotificationQueryService")
local Data = BuildEnv("Data")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local L = CrateTrackerZK and CrateTrackerZK.L or {}

local function ResolveLocalizedFormat(key, fallback)
    local value = type(L) == "table" and L[key] or nil
    if type(value) ~= "string" or value == "" or value == key then
        return fallback
    end
    return value
end

function NotificationQueryService:BuildAirdropDetectedMessage(mapName)
    local format = ResolveLocalizedFormat("AirdropDetected", "Airdrop detected on [%s]!")
    return string.format(format, mapName or "")
end

function NotificationQueryService:BuildAutoTeamReportMessage(mapName, remaining)
    local format = ResolveLocalizedFormat("AutoTeamReportMessage", "Current [%s] War Supply Crate in: %s!!")
    local timeText = (UnifiedDataManager and UnifiedDataManager.FormatTime and UnifiedDataManager:FormatTime(remaining, true)) or "--:--"
    return string.format(format, mapName, timeText)
end

function NotificationQueryService:BuildSharedPhaseSyncAppliedMessage(mapName)
    local format = ResolveLocalizedFormat("SharedPhaseSyncApplied", "Acquired the latest shared airdrop info for the current phase in [%s].")
    return string.format(format, mapName or "")
end

function NotificationQueryService:BuildTimeRemainingMessage(mapName, remaining)
    local format = ResolveLocalizedFormat("TimeRemaining", "[%s]War Supplies airdrop in: %s!!!")
    local timeText = (UnifiedDataManager and UnifiedDataManager.FormatTime and UnifiedDataManager:FormatTime(remaining, true)) or "--:--"
    return string.format(format, mapName or "", timeText)
end

function NotificationQueryService:BuildPhaseTeamAlertMessage(mapName, previousPhaseID, currentPhaseID)
    local format = ResolveLocalizedFormat("PhaseTeamAlertMessage", "Current %s phase changed: %s --> %s")
    local unknownText = ResolveLocalizedFormat("UnknownPhaseValue", "unknown")
    local previousText = previousPhaseID ~= nil and tostring(previousPhaseID) or unknownText
    local currentText = currentPhaseID ~= nil and tostring(currentPhaseID) or unknownText
    return string.format(format, mapName or "", previousText, currentText)
end

function NotificationQueryService:BuildTrajectoryPredictionMessage(mapName, coordinateText)
    local format = ResolveLocalizedFormat("TrajectoryPredictionMatchedUnified", "[%s]空投位置已确定：%s")
    return string.format(
        format,
        mapName or "",
        tostring(coordinateText or "0.0")
    )
end

function NotificationQueryService:BuildTrajectoryPredictionTeamMessage(mapName, coordinateLink, x, y)
    if type(coordinateLink) == "string" and coordinateLink ~= "" then
        return self:BuildTrajectoryPredictionMessage(mapName, coordinateLink)
    end
    return self:BuildTrajectoryPredictionMessage(mapName, string.format("%s, %s", tostring(x or "0.0"), tostring(y or "0.0")))
end

function NotificationQueryService:BuildTrajectoryPredictionCandidatesMessage(mapName, candidateEntries)
    local header = ResolveLocalizedFormat("TrajectoryPredictionCandidatesAmbiguous", "[%s]当前存在多个可能落点:")
    local message = string.format(header, tostring(mapName or ""))
    local hasCandidate = false
    for _, entry in ipairs(candidateEntries or {}) do
        if type(entry) == "table" then
            local label = tostring(entry.label or "?")
            local link = tostring(entry.coordinateLink or "")
            message = message .. (hasCandidate == true and " " or "") .. string.format("候选%s%s", label, link)
            hasCandidate = true
        end
    end
    return message
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

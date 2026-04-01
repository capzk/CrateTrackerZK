-- NotificationQueryService.lua - 通知查询与消息构建

local NotificationQueryService = BuildEnv("NotificationQueryService")
local Data = BuildEnv("Data")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local L = CrateTrackerZK and CrateTrackerZK.L or {}

function NotificationQueryService:BuildAutoTeamReportMessage(mapName, remaining)
    local format = (L and L["AutoTeamReportMessage"]) or "Current [%s] War Supply Crate in: %s!!"
    local timeText = (UnifiedDataManager and UnifiedDataManager.FormatTime and UnifiedDataManager:FormatTime(remaining, true)) or "--:--"
    return string.format(format, mapName, timeText)
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

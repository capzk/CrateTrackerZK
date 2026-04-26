-- Commands.lua - 设置面板动作处理

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local AddonControlService = BuildEnv("AddonControlService");
local MainPanel = BuildEnv("MainPanel");
local CoreShared = BuildEnv("CrateTrackerZKCoreShared");
local MapTracker = BuildEnv("MapTracker");
local Data = BuildEnv("Data");
local HiddenSyncAuditService = BuildEnv("HiddenSyncAuditService");
local NotificationOutputService = BuildEnv("NotificationOutputService");
local AirdropTrajectoryStore = BuildEnv("AirdropTrajectoryStore");
local AirdropTrajectoryService = BuildEnv("AirdropTrajectoryService");
local AirdropTrajectoryGeometryService = BuildEnv("AirdropTrajectoryGeometryService");
local Commands = BuildEnv('Commands');

Commands.isInitialized = false;

local function RegisterSlashCommands()
    if not SlashCmdList then
        return;
    end
    SLASH_CRATETRACKERZK1 = "/ctk";
    SlashCmdList["CRATETRACKERZK"] = function(msg)
        Commands:HandleSlashCommand(msg);
    end
end

function Commands:Initialize()
    if self.isInitialized then return end
    RegisterSlashCommands();
    self.isInitialized = true;
end

function Commands:HandleClearCommand(arg)
    if AddonControlService and AddonControlService.ClearDataAndReinitialize then
        if not AddonControlService:ClearDataAndReinitialize() then
            Logger:Error("Commands", "错误", "Clear data failed: Data module not loaded");
        end
    else
        Logger:Error("Commands", "错误", "Clear data failed: Data module not loaded");
    end
end

function Commands:HandleAddonToggle(enable)
    if AddonControlService and AddonControlService.ApplyAddonEnabled then
        AddonControlService:ApplyAddonEnabled(enable == true);
    end
end

local function SendLocalDebugMessage(message)
    if type(message) ~= "string" or message == "" then
        return false;
    end
    if NotificationOutputService and NotificationOutputService.SendLocalMessage then
        return NotificationOutputService:SendLocalMessage(message) == true;
    end
    if Logger and Logger.Info then
        Logger:Info("Commands", "命令", message);
        return true;
    end
    return false;
end

local function NormalizeCommandToken(token)
    if type(token) ~= "string" then
        return "";
    end
    return token:lower():gsub("^%s+", ""):gsub("%s+$", "");
end

local function SplitCommandArgs(msg)
    local args = {};
    if type(msg) ~= "string" then
        return args;
    end
    for token in msg:gmatch("%S+") do
        args[#args + 1] = token;
    end
    return args;
end

local function GetMapDisplayNameByMapID(mapID)
    if type(mapID) ~= "number" then
        return tostring(mapID);
    end
    if Data and Data.GetMapByMapID then
        local mapData = Data:GetMapByMapID(mapID);
        if mapData and Data.GetMapDisplayName then
            return Data:GetMapDisplayName(mapData);
        end
    end
    if Data and Data.GetMapDisplayName then
        return Data:GetMapDisplayName({ mapID = mapID });
    end
    return "Map " .. tostring(mapID);
end

local function GetCurrentTrackedMapData()
    local currentMapID = CoreShared and CoreShared.GetCurrentMapID and CoreShared:GetCurrentMapID() or nil;
    if type(currentMapID) ~= "number" then
        return nil;
    end
    if MapTracker and MapTracker.GetTargetMapData then
        return MapTracker:GetTargetMapData(currentMapID);
    end
    return nil;
end

local function FormatCoordinatePercent(value)
    if AirdropTrajectoryGeometryService and AirdropTrajectoryGeometryService.FormatCoordinatePercent then
        return AirdropTrajectoryGeometryService:FormatCoordinatePercent(value);
    end
    return string.format("%.1f", (tonumber(value) or 0) * 100);
end

local function BuildTrajectoryLine(routeIndex, route, includeMapPrefix)
    if type(route) ~= "table" then
        return nil;
    end
    local prefix = "";
    if includeMapPrefix == true then
        prefix = string.format("[%s|%d] ", GetMapDisplayNameByMapID(route.mapID), tonumber(route.mapID) or 0);
    end
    local quality = AirdropTrajectoryStore and AirdropTrajectoryStore.GetRouteQualityLabel
        and AirdropTrajectoryStore:GetRouteQualityLabel(route)
        or "unknown";
    local confidence = AirdropTrajectoryStore and AirdropTrajectoryStore.GetPredictionConfidence
        and AirdropTrajectoryStore:GetPredictionConfidence(route)
        or 0;
    local verificationCount = math.max(0, math.floor(tonumber(route.verificationCount) or 0));
    local verifiedPredictionCount = math.max(0, math.floor(tonumber(route.verifiedPredictionCount) or 0));
    local startX = FormatCoordinatePercent(route.startX);
    local startY = FormatCoordinatePercent(route.startY);
    local endX = FormatCoordinatePercent(route.endX);
    local endY = FormatCoordinatePercent(route.endY);
    return string.format(
        "%s#%d 起点 %s, %s -> 终点 %s, %s | 状态 %s | 可信度 %d | 验证 %d/%d | 样本 %d | 记录 %d | merged %d | family=%s | landing=%s | alert=%s | 更新 %d",
        prefix,
        tonumber(routeIndex) or 0,
        startX,
        startY,
        endX,
        endY,
        tostring(quality),
        confidence,
        verifiedPredictionCount,
        verificationCount,
        math.floor(tonumber(route.sampleCount) or 0),
        math.floor(tonumber(route.observationCount) or 0),
        math.max(1, math.floor(tonumber(route.mergedRouteCount) or 1)),
        tostring(route.routeFamilyKey or "unknown"),
        tostring(route.landingKey or "unknown"),
        tostring(route.alertToken or "unknown"),
        math.floor(tonumber(route.updatedAt) or 0)
    );
end

local function BuildTrajectoryExportLine(route)
    if type(route) ~= "table" then
        return nil;
    end
    local quality = AirdropTrajectoryStore and AirdropTrajectoryStore.GetRouteQualityLabel
        and AirdropTrajectoryStore:GetRouteQualityLabel(route)
        or "unknown";
    local confidence = AirdropTrajectoryStore and AirdropTrajectoryStore.GetPredictionConfidence
        and AirdropTrajectoryStore:GetPredictionConfidence(route)
        or 0;
    local verificationCount = math.max(0, math.floor(tonumber(route.verificationCount) or 0));
    local verifiedPredictionCount = math.max(0, math.floor(tonumber(route.verifiedPredictionCount) or 0));
    local startX = FormatCoordinatePercent(route.startX);
    local startY = FormatCoordinatePercent(route.startY);
    local endX = FormatCoordinatePercent(route.endX);
    local endY = FormatCoordinatePercent(route.endY);
    return string.format(
        "CTK_TRAJECTORY|mapID=%d|route=%s|family=%s|landing=%s|alert=%s|start=%s,%s|end=%s,%s|startConfirmed=%s|endConfirmed=%s|quality=%s|confidence=%d|verified=%d/%d|samples=%d|count=%d|merged=%d|updated=%d",
        tonumber(route.mapID) or 0,
        tostring(route.routeKey or "unknown"),
        tostring(route.routeFamilyKey or "unknown"),
        tostring(route.landingKey or "unknown"),
        tostring(route.alertToken or "unknown"),
        startX,
        startY,
        endX,
        endY,
        tostring(route.startConfirmed == true),
        tostring(route.endConfirmed == true),
        tostring(quality),
        confidence,
        verifiedPredictionCount,
        verificationCount,
        math.floor(tonumber(route.sampleCount) or 0),
        math.floor(tonumber(route.observationCount) or 0),
        math.max(1, math.floor(tonumber(route.mergedRouteCount) or 1)),
        math.floor(tonumber(route.updatedAt) or 0)
    );
end

local function FormatAngleDegrees(angle)
    local value = tonumber(angle)
    if type(value) ~= "number" then
        return "0.0"
    end
    return string.format("%.1f", math.deg(value))
end

local function FormatTrackOffset(value)
    local numberValue = tonumber(value)
    if type(numberValue) ~= "number" then
        return "0.000"
    end
    return string.format("%.3f", numberValue)
end

local function BuildTrackGroupLine(trackIndex, track, includeMapPrefix)
    if type(track) ~= "table" then
        return nil;
    end
    local prefix = "";
    if includeMapPrefix == true then
        prefix = string.format("[%s|%d] ", GetMapDisplayNameByMapID(track.mapID), tonumber(track.mapID) or 0);
    end
    local quality = AirdropTrajectoryStore and AirdropTrajectoryStore.GetRouteQualityLabel
        and AirdropTrajectoryStore:GetRouteQualityLabel(track)
        or "unknown";
    local confidence = AirdropTrajectoryStore and AirdropTrajectoryStore.GetPredictionConfidence
        and AirdropTrajectoryStore:GetPredictionConfidence(track)
        or 0;
    local verificationCount = math.max(0, math.floor(tonumber(track.verificationCount) or 0));
    local verifiedPredictionCount = math.max(0, math.floor(tonumber(track.verifiedPredictionCount) or 0));
    local startX = FormatCoordinatePercent(track.startX);
    local startY = FormatCoordinatePercent(track.startY);
    local endX = FormatCoordinatePercent(track.endX);
    local endY = FormatCoordinatePercent(track.endY);
    return string.format(
        "%s#%d 起点 %s, %s -> 终点 %s, %s | track=%s | angle=%s | offset=%s | 落点 %d | canon %d | 状态 %s | 可信度 %d | 验证 %d/%d | 样本 %d | route=%s | family=%s | alert=%s | 更新 %d",
        prefix,
        tonumber(trackIndex) or 0,
        startX,
        startY,
        endX,
        endY,
        tostring(track.trackKey or "unknown"),
        FormatAngleDegrees(track.angle),
        FormatTrackOffset(track.offset),
        math.max(0, math.floor(tonumber(track.landingClusterCount) or 0)),
        math.max(0, math.floor(tonumber(track.rawRouteCount) or 0)),
        tostring(quality),
        confidence,
        verifiedPredictionCount,
        verificationCount,
        math.floor(tonumber(track.sampleCount) or 0),
        tostring(track.representativeRouteKey or track.routeKey or "unknown"),
        tostring(track.routeFamilyKey or "unknown"),
        tostring(track.alertToken or "unknown"),
        math.floor(tonumber(track.updatedAt) or 0)
    );
end

local function BuildLandingClusterLine(track, landingCluster)
    if type(track) ~= "table" or type(landingCluster) ~= "table" then
        return nil;
    end
    local verificationCount = math.max(0, math.floor(tonumber(landingCluster.verificationCount) or 0));
    local verifiedPredictionCount = math.max(0, math.floor(tonumber(landingCluster.verifiedPredictionCount) or 0));
    local endX = FormatCoordinatePercent(landingCluster.endX);
    local endY = FormatCoordinatePercent(landingCluster.endY);
    return string.format(
        "    落点#%d 终点 %s, %s | projection=%.3f | canon=%d | 验证 %d/%d | 样本 %d | route=%s | family=%s | landing=%s | alert=%s",
        math.max(1, math.floor(tonumber(landingCluster.clusterIndex) or 1)),
        endX,
        endY,
        tonumber(landingCluster.endProjection) or 0,
        math.max(1, math.floor(tonumber(landingCluster.clusterRouteCount) or 1)),
        verifiedPredictionCount,
        verificationCount,
        math.floor(tonumber(landingCluster.sampleCount) or 0),
        tostring(landingCluster.representativeRouteKey or landingCluster.routeKey or "unknown"),
        tostring(landingCluster.routeFamilyKey or "unknown"),
        tostring(landingCluster.landingKey or "unknown"),
        tostring(landingCluster.alertToken or "unknown")
    );
end

local function BuildTrackExportLine(track)
    if type(track) ~= "table" then
        return nil;
    end
    local verificationCount = math.max(0, math.floor(tonumber(track.verificationCount) or 0));
    local verifiedPredictionCount = math.max(0, math.floor(tonumber(track.verifiedPredictionCount) or 0));
    local confidence = AirdropTrajectoryStore and AirdropTrajectoryStore.GetPredictionConfidence
        and AirdropTrajectoryStore:GetPredictionConfidence(track)
        or 0;
    return string.format(
        "CTK_TRACK|mapID=%d|trackKey=%s|start=%s,%s|end=%s,%s|angle=%.6f|offset=%.6f|landings=%d|canonicalRoutes=%d|verified=%d/%d|samples=%d|confidence=%d|updated=%d|route=%s|family=%s|alert=%s",
        tonumber(track.mapID) or 0,
        tostring(track.trackKey or "unknown"),
        FormatCoordinatePercent(track.startX),
        FormatCoordinatePercent(track.startY),
        FormatCoordinatePercent(track.endX),
        FormatCoordinatePercent(track.endY),
        tonumber(track.angle) or 0,
        tonumber(track.offset) or 0,
        math.max(0, math.floor(tonumber(track.landingClusterCount) or 0)),
        math.max(0, math.floor(tonumber(track.rawRouteCount) or 0)),
        verifiedPredictionCount,
        verificationCount,
        math.floor(tonumber(track.sampleCount) or 0),
        confidence,
        math.floor(tonumber(track.updatedAt) or 0),
        tostring(track.representativeRouteKey or track.routeKey or "unknown"),
        tostring(track.routeFamilyKey or "unknown"),
        tostring(track.alertToken or "unknown")
    );
end

local function BuildLandingExportLine(track, landingCluster)
    if type(track) ~= "table" or type(landingCluster) ~= "table" then
        return nil;
    end
    local verificationCount = math.max(0, math.floor(tonumber(landingCluster.verificationCount) or 0));
    local verifiedPredictionCount = math.max(0, math.floor(tonumber(landingCluster.verifiedPredictionCount) or 0));
    return string.format(
        "CTK_LANDING|mapID=%d|trackKey=%s|index=%d|end=%s,%s|projection=%.6f|canonicalRoutes=%d|verified=%d/%d|samples=%d|updated=%d|route=%s|family=%s|landing=%s|alert=%s",
        tonumber(track.mapID) or 0,
        tostring(track.trackKey or "unknown"),
        math.max(1, math.floor(tonumber(landingCluster.clusterIndex) or 1)),
        FormatCoordinatePercent(landingCluster.endX),
        FormatCoordinatePercent(landingCluster.endY),
        tonumber(landingCluster.endProjection) or 0,
        math.max(1, math.floor(tonumber(landingCluster.clusterRouteCount) or 1)),
        verifiedPredictionCount,
        verificationCount,
        math.floor(tonumber(landingCluster.sampleCount) or 0),
        math.floor(tonumber(landingCluster.updatedAt) or 0),
        tostring(landingCluster.representativeRouteKey or landingCluster.routeKey or "unknown"),
        tostring(landingCluster.routeFamilyKey or "unknown"),
        tostring(landingCluster.landingKey or "unknown"),
        tostring(landingCluster.alertToken or "unknown")
    );
end

local function FormatAuditTime(timestamp)
    local value = tonumber(timestamp)
    if type(value) ~= "number" then
        return "--:--:--"
    end
    return date("%H:%M:%S", value)
end

local function EscapeAuditPayload(payload)
    if type(payload) ~= "string" or payload == "" then
        return payload
    end
    return payload
        :gsub("\r", "\\r")
        :gsub("\n", "\\n")
        :gsub("|", "<PIPE>")
end

local function BuildSyncAuditSummary(entries)
    local totalCount = #(entries or {})
    local sendCount = 0
    local recvCount = 0
    local processedCount = 0
    local failedCount = 0

    for _, entry in ipairs(entries or {}) do
        if entry.direction == "send" then
            sendCount = sendCount + 1
        elseif entry.direction == "recv" then
            recvCount = recvCount + 1
        end

        if entry.status == "processed" or entry.status == "sent" then
            processedCount = processedCount + 1
        elseif entry.status == "failed" or entry.status == "blocked" then
            failedCount = failedCount + 1
        end
    end

    return string.format(
        "隐藏同步审计：共 %d 条 | 发送 %d | 接收 %d | 成功 %d | 失败/阻断 %d",
        totalCount,
        sendCount,
        recvCount,
        processedCount,
        failedCount
    )
end

local function BuildSyncAuditLine(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local parts = {
        string.format("[%s]", FormatAuditTime(entry.recordedAt)),
        tostring(entry.protocol or "unknown"),
        tostring(entry.direction or "unknown"),
        tostring(entry.status or "unknown"),
    }

    if type(entry.messageType) == "string" and entry.messageType ~= "" then
        parts[#parts + 1] = "type=" .. entry.messageType
    end
    if type(entry.resultCode) == "string" and entry.resultCode ~= "" then
        parts[#parts + 1] = "result=" .. entry.resultCode
    end
    if type(entry.sender) == "string" and entry.sender ~= "" then
        parts[#parts + 1] = "sender=" .. entry.sender
    end
    if type(entry.distribution) == "string" and entry.distribution ~= "" then
        parts[#parts + 1] = "dist=" .. entry.distribution
    end
    if type(entry.chatType) == "string" and entry.chatType ~= "" then
        parts[#parts + 1] = "chat=" .. entry.chatType
    end
    if type(entry.expansionID) == "string" and entry.expansionID ~= "" then
        parts[#parts + 1] = "exp=" .. entry.expansionID
    end
    if type(entry.mapID) == "number" then
        parts[#parts + 1] = "map=" .. tostring(entry.mapID)
    end
    if type(entry.phaseID) == "string" and entry.phaseID ~= "" then
        parts[#parts + 1] = "phase=" .. entry.phaseID
    end
    if type(entry.requestID) == "string" and entry.requestID ~= "" then
        parts[#parts + 1] = "request=" .. entry.requestID
    end
    if type(entry.routeKey) == "string" and entry.routeKey ~= "" then
        parts[#parts + 1] = "route=" .. entry.routeKey
    end
    if type(entry.routeFamilyKey) == "string" and entry.routeFamilyKey ~= "" then
        parts[#parts + 1] = "family=" .. entry.routeFamilyKey
    end
    if type(entry.landingKey) == "string" and entry.landingKey ~= "" then
        parts[#parts + 1] = "landing=" .. entry.landingKey
    end
    if type(entry.alertToken) == "string" and entry.alertToken ~= "" then
        parts[#parts + 1] = "alert=" .. entry.alertToken
    end
    if type(entry.sampleCount) == "number" then
        parts[#parts + 1] = "samples=" .. tostring(math.floor(entry.sampleCount))
    end
    if type(entry.observationCount) == "number" then
        parts[#parts + 1] = "obs=" .. tostring(math.floor(entry.observationCount))
    end
    if type(entry.verifiedPredictionCount) == "number" or type(entry.verificationCount) == "number" then
        parts[#parts + 1] = string.format(
            "verified=%d/%d",
            math.floor(tonumber(entry.verifiedPredictionCount) or 0),
            math.floor(tonumber(entry.verificationCount) or 0)
        )
    end
    if type(entry.confidenceScore) == "number" then
        parts[#parts + 1] = "confidence=" .. tostring(math.floor(entry.confidenceScore))
    end
    if type(entry.note) == "string" and entry.note ~= "" then
        parts[#parts + 1] = "note=" .. entry.note
    end
    if type(entry.payload) == "string" and entry.payload ~= "" then
        parts[#parts + 1] = "payload=" .. tostring(EscapeAuditPayload(entry.payload) or "")
    end

    return table.concat(parts, " | ")
end

function Commands:PrintTrajectoryHelp()
    SendLocalDebugMessage("轨道命令：/ctk traj debug [all]");
    SendLocalDebugMessage("轨道命令：/ctk traj export [all]");
    SendLocalDebugMessage("轨迹命令：/ctk traj trace on|off|status");
    SendLocalDebugMessage("轨迹命令：/ctk traj trace recent");
    SendLocalDebugMessage("轨迹预测开关：设置 -> 轨迹预测（测试功能）");
end

function Commands:PrintSyncHelp()
    SendLocalDebugMessage("同步命令：/ctk sync audit");
    SendLocalDebugMessage("同步命令：/ctk sync audit all");
end

function Commands:HandleTrajectoryTraceCommand(args)
    local action = NormalizeCommandToken(args[3]);
    if not AirdropTrajectoryService
        or not AirdropTrajectoryService.SetTraceDebugEnabled
        or not AirdropTrajectoryService.IsTraceDebugEnabled then
        SendLocalDebugMessage("轨迹调试链路未初始化。");
        return true;
    end

    if action == "status" or action == "" then
        local enabled = AirdropTrajectoryService:IsTraceDebugEnabled() == true;
        SendLocalDebugMessage(string.format("轨迹点链调试：%s", enabled and "已开启" or "已关闭"));
        return true;
    end

    if action == "recent" or action == "last" then
        local entries = AirdropTrajectoryService.GetRecentTraceEvents
            and AirdropTrajectoryService:GetRecentTraceEvents(3600)
            or {};
        if #entries == 0 then
            SendLocalDebugMessage("最近 1 小时内没有轨迹终点调试记录。");
            return true;
        end

        SendLocalDebugMessage(string.format("轨迹终点调试记录（最近 1 小时）：共 %d 条。", #entries));
        for _, entry in ipairs(entries) do
            local line = self:BuildTrajectoryTraceEventLine(entry);
            if line then
                SendLocalDebugMessage(line);
            end
        end
        return true;
    end

    if action == "on" then
        AirdropTrajectoryService:SetTraceDebugEnabled(true);
        SendLocalDebugMessage("轨迹点链调试已开启：终点确认后将输出本次空投轨迹点链和箱子捕获细节。");
        return true;
    end

    if action == "off" then
        AirdropTrajectoryService:SetTraceDebugEnabled(false);
        SendLocalDebugMessage("轨迹点链调试已关闭。");
        return true;
    end

    SendLocalDebugMessage("轨迹命令：/ctk traj trace on|off|status|recent");
    return true;
end

function Commands:HandleTrajectoryMatchCommand(args)
    SendLocalDebugMessage("轨迹预测开关已移至设置页：设置 -> 轨迹预测（测试功能）。");
    return true;
end

function Commands:BuildTrajectoryTraceEventLine(entry)
    if type(entry) ~= "table" then
        return nil;
    end

    local parts = {
        string.format("[%s]", FormatAuditTime(entry.recordedAt)),
        tostring(entry.eventType or "unknown"),
    };

    if type(entry.mapName) == "string" and entry.mapName ~= "" then
        parts[#parts + 1] = "map=" .. entry.mapName;
    elseif type(entry.mapID) == "number" then
        parts[#parts + 1] = "mapID=" .. tostring(math.floor(entry.mapID));
    end
    if type(entry.vignetteID) == "number" then
        parts[#parts + 1] = "vignetteID=" .. tostring(math.floor(entry.vignetteID));
    end
    if type(entry.vignetteGUID) == "string" and entry.vignetteGUID ~= "" then
        parts[#parts + 1] = "vignetteGUID=" .. entry.vignetteGUID;
    end
    if type(entry.objectGUID) == "string" and entry.objectGUID ~= "" then
        parts[#parts + 1] = "objectGUID=" .. entry.objectGUID;
    end
    if type(entry.sourceObjectGUID) == "string" and entry.sourceObjectGUID ~= "" then
        parts[#parts + 1] = "planeGUID=" .. entry.sourceObjectGUID;
    end
    if type(entry.positionX) == "number" and type(entry.positionY) == "number" then
        parts[#parts + 1] = string.format(
            "pos=%s,%s",
            FormatCoordinatePercent(entry.positionX),
            FormatCoordinatePercent(entry.positionY)
        );
    end
    if type(entry.sampleCount) == "number" then
        parts[#parts + 1] = "samples=" .. tostring(math.floor(entry.sampleCount));
    end
    if type(entry.startConfirmed) == "boolean" or type(entry.endConfirmed) == "boolean" then
        parts[#parts + 1] = string.format(
            "start=%s(%s)",
            tostring(entry.startConfirmed == true),
            tostring(entry.startSource or "nil")
        );
        parts[#parts + 1] = string.format(
            "end=%s(%s)",
            tostring(entry.endConfirmed == true),
            tostring(entry.endSource or "nil")
        );
    end
    if type(entry.routeKey) == "string" and entry.routeKey ~= "" then
        parts[#parts + 1] = "route=" .. entry.routeKey;
    end
    if type(entry.note) == "string" and entry.note ~= "" then
        parts[#parts + 1] = "note=" .. entry.note;
    end

    return table.concat(parts, " | ");
end

function Commands:PrintTrajectoryRoutesForCurrentMap(exportMode)
    local mapData = GetCurrentTrackedMapData();
    if not mapData or type(mapData.mapID) ~= "number" then
        SendLocalDebugMessage("当前不在可追踪地图，无法输出当前地图轨道视图；可使用 /ctk traj debug all 或 /ctk traj export all");
        return true;
    end

    local tracks = AirdropTrajectoryStore and AirdropTrajectoryStore.GetTrackGroups and AirdropTrajectoryStore:GetTrackGroups(mapData.mapID) or {};
    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(mapData) or tostring(mapData.mapID);
    if #tracks == 0 then
        SendLocalDebugMessage(string.format("【%s】当前没有可用的轨道组数据。", mapName));
        return true;
    end

    if exportMode == true then
        SendLocalDebugMessage(string.format("【%s】轨道导出（canonical 派生视图）：共 %d 条。", mapName, #tracks));
        for _, track in ipairs(tracks) do
            local trackExportLine = BuildTrackExportLine(track);
            if trackExportLine then
                SendLocalDebugMessage(trackExportLine);
            end
            for _, landingCluster in ipairs(track.landingClusters or {}) do
                local landingExportLine = BuildLandingExportLine(track, landingCluster);
                if landingExportLine then
                    SendLocalDebugMessage(landingExportLine);
                end
            end
        end
        return true;
    end

    SendLocalDebugMessage(string.format("【%s】轨道调试（canonical 派生视图）：共 %d 条。", mapName, #tracks));
    for index, track in ipairs(tracks) do
        local trackLine = BuildTrackGroupLine(index, track, false);
        if trackLine then
            SendLocalDebugMessage(trackLine);
        end
        for _, landingCluster in ipairs(track.landingClusters or {}) do
            local landingLine = BuildLandingClusterLine(track, landingCluster);
            if landingLine then
                SendLocalDebugMessage(landingLine);
            end
        end
    end
    return true;
end

function Commands:PrintAllTrajectoryRoutes(exportMode)
    local tracks = {};
    local mapIDs = {};
    for mapID in pairs(AirdropTrajectoryStore and AirdropTrajectoryStore.routesByMap or {}) do
        if type(mapID) == "number" then
            mapIDs[#mapIDs + 1] = mapID;
        end
    end
    table.sort(mapIDs);

    for _, mapID in ipairs(mapIDs) do
        local mapTracks = AirdropTrajectoryStore and AirdropTrajectoryStore.GetTrackGroups and AirdropTrajectoryStore:GetTrackGroups(mapID) or {};
        for _, track in ipairs(mapTracks) do
            tracks[#tracks + 1] = track;
        end
    end

    if #tracks == 0 then
        SendLocalDebugMessage("当前没有任何轨道组数据。");
        return true;
    end

    if exportMode == true then
        SendLocalDebugMessage(string.format("轨道导出（全部地图，canonical 派生视图）：共 %d 条。", #tracks));
        for _, track in ipairs(tracks) do
            local trackExportLine = BuildTrackExportLine(track);
            if trackExportLine then
                SendLocalDebugMessage(trackExportLine);
            end
            for _, landingCluster in ipairs(track.landingClusters or {}) do
                local landingExportLine = BuildLandingExportLine(track, landingCluster);
                if landingExportLine then
                    SendLocalDebugMessage(landingExportLine);
                end
            end
        end
        return true;
    end

    SendLocalDebugMessage(string.format("轨道调试（全部地图，canonical 派生视图）：共 %d 条。", #tracks));
    for index, track in ipairs(tracks) do
        local trackLine = BuildTrackGroupLine(index, track, true);
        if trackLine then
            SendLocalDebugMessage(trackLine);
        end
        for _, landingCluster in ipairs(track.landingClusters or {}) do
            local landingLine = BuildLandingClusterLine(track, landingCluster);
            if landingLine then
                SendLocalDebugMessage(landingLine);
            end
        end
    end
    return true;
end

function Commands:HandleTrajectoryCommand(args)
    if not AirdropTrajectoryStore or not AirdropTrajectoryStore.Initialize then
        SendLocalDebugMessage("轨迹数据模块未初始化。");
        return true;
    end
    if not AirdropTrajectoryStore.routesByMap then
        AirdropTrajectoryStore:Initialize();
    end

    local mode = NormalizeCommandToken(args[2]);
    local scope = NormalizeCommandToken(args[3]);
    if mode == "" or mode == "help" then
        self:PrintTrajectoryHelp();
        return true;
    end
    if mode == "trace" then
        return self:HandleTrajectoryTraceCommand(args);
    end
    if mode == "match" then
        return self:HandleTrajectoryMatchCommand(args);
    end
    if mode == "family" then
        SendLocalDebugMessage("family 视图已被 track 视图替代，请使用 /ctk traj debug [all] 或 /ctk traj export [all]。");
        return true;
    end
    if mode ~= "debug" and mode ~= "export" then
        self:PrintTrajectoryHelp();
        return true;
    end

    local exportMode = mode == "export";
    if scope == "all" then
        return self:PrintAllTrajectoryRoutes(exportMode);
    end
    return self:PrintTrajectoryRoutesForCurrentMap(exportMode);
end

function Commands:HandleSyncCommand(args)
    local mode = NormalizeCommandToken(args[2]);
    local scope = NormalizeCommandToken(args[3]);
    if mode == "" or mode == "help" then
        self:PrintSyncHelp();
        return true;
    end
    if mode ~= "audit" then
        self:PrintSyncHelp();
        return true;
    end

    if not HiddenSyncAuditService or not HiddenSyncAuditService.GetRecentEntries then
        SendLocalDebugMessage("隐藏同步审计模块未初始化。");
        return true;
    end

    local entries = nil;
    if scope == "all" then
        entries = HiddenSyncAuditService.entries or {};
    else
        entries = HiddenSyncAuditService:GetRecentEntries(3600);
    end

    if #entries == 0 then
        SendLocalDebugMessage(scope == "all" and "当前没有任何隐藏同步审计记录。" or "最近 1 小时内没有隐藏同步审计记录。");
        return true;
    end

    SendLocalDebugMessage(scope == "all" and "隐藏同步审计（全部保留记录）：" or "隐藏同步审计（最近 1 小时）：");
    SendLocalDebugMessage(BuildSyncAuditSummary(entries));
    for _, entry in ipairs(entries) do
        local line = BuildSyncAuditLine(entry);
        if line then
            SendLocalDebugMessage(line);
        end
    end
    return true;
end

function Commands:HandleSlashCommand(msg)
    local args = SplitCommandArgs(msg);
    local primary = NormalizeCommandToken(args[1]);
    if primary == "traj" or primary == "trajectory" then
        if self:HandleTrajectoryCommand(args) == true then
            return;
        end
    end
    if primary == "sync" then
        if self:HandleSyncCommand(args) == true then
            return;
        end
    end
    if MainPanel and MainPanel.Toggle then
        MainPanel:Toggle();
    end
end

return Commands

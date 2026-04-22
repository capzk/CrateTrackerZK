-- Commands.lua - 设置面板动作处理

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local AddonControlService = BuildEnv("AddonControlService");
local MainPanel = BuildEnv("MainPanel");
local CoreShared = BuildEnv("CrateTrackerZKCoreShared");
local MapTracker = BuildEnv("MapTracker");
local Data = BuildEnv("Data");
local NotificationOutputService = BuildEnv("NotificationOutputService");
local AirdropTrajectoryStore = BuildEnv("AirdropTrajectoryStore");
local AirdropTrajectoryService = BuildEnv("AirdropTrajectoryService");
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
    local startX = math.floor(((tonumber(route.startX) or 0) * 100) + 0.5);
    local startY = math.floor(((tonumber(route.startY) or 0) * 100) + 0.5);
    local endX = math.floor(((tonumber(route.endX) or 0) * 100) + 0.5);
    local endY = math.floor(((tonumber(route.endY) or 0) * 100) + 0.5);
    return string.format(
        "%s#%d 起点 %d, %d -> 终点 %d, %d | 状态 %s | 样本 %d | 记录 %d | 更新 %d",
        prefix,
        tonumber(routeIndex) or 0,
        startX,
        startY,
        endX,
        endY,
        tostring(quality),
        math.floor(tonumber(route.sampleCount) or 0),
        math.floor(tonumber(route.observationCount) or 0),
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
    local startX = math.floor(((tonumber(route.startX) or 0) * 100) + 0.5);
    local startY = math.floor(((tonumber(route.startY) or 0) * 100) + 0.5);
    local endX = math.floor(((tonumber(route.endX) or 0) * 100) + 0.5);
    local endY = math.floor(((tonumber(route.endY) or 0) * 100) + 0.5);
    return string.format(
        "CTK_TRAJECTORY|mapID=%d|start=%d,%d|end=%d,%d|startConfirmed=%s|endConfirmed=%s|quality=%s|samples=%d|count=%d|updated=%d",
        tonumber(route.mapID) or 0,
        startX,
        startY,
        endX,
        endY,
        tostring(route.startConfirmed == true),
        tostring(route.endConfirmed == true),
        tostring(quality),
        math.floor(tonumber(route.sampleCount) or 0),
        math.floor(tonumber(route.observationCount) or 0),
        math.floor(tonumber(route.updatedAt) or 0)
    );
end

function Commands:PrintTrajectoryHelp()
    SendLocalDebugMessage("轨迹命令：/ctk traj debug [all]");
    SendLocalDebugMessage("轨迹命令：/ctk traj export [all]");
    SendLocalDebugMessage("轨迹命令：/ctk traj trace on|off|status");
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

    if action == "on" then
        AirdropTrajectoryService:SetTraceDebugEnabled(true);
        SendLocalDebugMessage("轨迹点链调试已开启：终点确认后将输出本次空投轨迹点链。");
        return true;
    end

    if action == "off" then
        AirdropTrajectoryService:SetTraceDebugEnabled(false);
        SendLocalDebugMessage("轨迹点链调试已关闭。");
        return true;
    end

    SendLocalDebugMessage("轨迹命令：/ctk traj trace on|off|status");
    return true;
end

function Commands:PrintTrajectoryRoutesForCurrentMap(exportMode)
    local mapData = GetCurrentTrackedMapData();
    if not mapData or type(mapData.mapID) ~= "number" then
        SendLocalDebugMessage("当前不在可追踪地图，无法输出当前地图轨迹；可使用 /ctk traj debug all 或 /ctk traj export all");
        return true;
    end

    local routes = AirdropTrajectoryStore and AirdropTrajectoryStore.GetRoutes and AirdropTrajectoryStore:GetRoutes(mapData.mapID) or {};
    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(mapData) or tostring(mapData.mapID);
    if #routes == 0 then
        SendLocalDebugMessage(string.format("【%s】当前没有已存储的空投轨迹数据。", mapName));
        return true;
    end

    if exportMode == true then
        SendLocalDebugMessage(string.format("【%s】轨迹导出：共 %d 条。", mapName, #routes));
        for _, route in ipairs(routes) do
            local exportLine = BuildTrajectoryExportLine(route);
            if exportLine then
                SendLocalDebugMessage(exportLine);
            end
        end
        return true;
    end

    SendLocalDebugMessage(string.format("【%s】轨迹调试：共 %d 条。", mapName, #routes));
    for index, route in ipairs(routes) do
        local line = BuildTrajectoryLine(index, route, false);
        if line then
            SendLocalDebugMessage(line);
        end
    end
    return true;
end

function Commands:PrintAllTrajectoryRoutes(exportMode)
    local routes = {};
    routes = AirdropTrajectoryStore and AirdropTrajectoryStore.AppendRoutesTo and AirdropTrajectoryStore:AppendRoutesTo(routes) or routes;
    if #routes == 0 then
        SendLocalDebugMessage("当前没有任何已存储的空投轨迹数据。");
        return true;
    end

    if exportMode == true then
        SendLocalDebugMessage(string.format("轨迹导出（全部地图）：共 %d 条。", #routes));
        for _, route in ipairs(routes) do
            local exportLine = BuildTrajectoryExportLine(route);
            if exportLine then
                SendLocalDebugMessage(exportLine);
            end
        end
        return true;
    end

    SendLocalDebugMessage(string.format("轨迹调试（全部地图）：共 %d 条。", #routes));
    for index, route in ipairs(routes) do
        local line = BuildTrajectoryLine(index, route, true);
        if line then
            SendLocalDebugMessage(line);
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

function Commands:HandleSlashCommand(msg)
    local args = SplitCommandArgs(msg);
    local primary = NormalizeCommandToken(args[1]);
    if primary == "traj" or primary == "trajectory" then
        if self:HandleTrajectoryCommand(args) == true then
            return;
        end
    end
    if MainPanel and MainPanel.Toggle then
        MainPanel:Toggle();
    end
end

return Commands

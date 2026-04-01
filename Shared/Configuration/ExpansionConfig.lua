-- ExpansionConfig.lua - 资料片版本与地图列表配置

local ExpansionConfig = BuildEnv("ExpansionConfig")

ExpansionConfig.defaultExpansionID = "12.0"
ExpansionConfig.enableSwitch = false

ExpansionConfig.expansionOrder = {
    "11.0",
    "12.0",
}

ExpansionConfig.expansions = {
    ["11.0"] = {
        label = "11.0",
        interval = 1100,
        airdropPlaneVignetteIDs = {
            3689,
        },
        airdropCrates = {
            {
                code = "WarSupplyCrate",
                interval = 1100,
                enabled = true,
            },
        },
        mainCityMapIDs = {
            2339,
        },
        maps = {
            { id = 1101, mapID = 2248, order = 1 },
            { id = 1102, mapID = 2369, order = 2 },
            { id = 1103, mapID = 2371, order = 3 },
            { id = 1104, mapID = 2346, order = 4 },
            { id = 1105, mapID = 2215, order = 5 },
            { id = 1106, mapID = 2214, order = 6 },
            { id = 1107, mapID = 2255, order = 7 },
        },
    },
    ["12.0"] = {
        label = "12.0",
        interval = 1100,
        airdropPlaneVignetteIDs = {
            3689,
        },
        airdropCrates = {
            {
                code = "WarSupplyCrate",
                interval = 1100,
                enabled = true,
            },
        },
        mainCityMapIDs = {
            2393,
        },
        maps = {
            { id = 1201, mapID = 2437, order = 1 },
            { id = 1202, mapID = 2395, order = 2 },
            { id = 1203, mapID = 2405, order = 3 },
            { id = 1204, mapID = 2444, order = 4 },
            { id = 1205, mapID = 2413, order = 5 },
        },
    },
}

local function EnsureUIState()
    if not CRATETRACKERZK_UI_DB or type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {}
    end
    return CRATETRACKERZK_UI_DB
end

local function IsValidExpansionID(expansionID)
    return expansionID and ExpansionConfig.expansions and ExpansionConfig.expansions[expansionID] ~= nil
end

local function CopyMapDefinition(definition)
    if type(definition) ~= "table" then
        return nil
    end
    return {
        id = definition.id,
        mapID = definition.mapID,
        expansionID = definition.expansionID,
        interval = definition.interval,
        enabled = definition.enabled,
        order = definition.order,
        priority = definition.priority,
    }
end

local function IterateExpansionIDs(reverseOrder)
    local result = {}
    local order = ExpansionConfig.expansionOrder or {}
    if reverseOrder then
        for index = #order, 1, -1 do
            local expansionID = order[index]
            if IsValidExpansionID(expansionID) then
                result[#result + 1] = expansionID
            end
        end
    else
        for _, expansionID in ipairs(order) do
            if IsValidExpansionID(expansionID) then
                result[#result + 1] = expansionID
            end
        end
    end
    return result
end

local function GetExpansionMapDefinitions(expansionID)
    local expansion = expansionID and ExpansionConfig.expansions and ExpansionConfig.expansions[expansionID]
    local result = {}
    if not expansion or type(expansion.maps) ~= "table" then
        return result
    end

    for index, mapInfo in ipairs(expansion.maps) do
        if type(mapInfo) == "table" and type(mapInfo.mapID) == "number" and type(mapInfo.id) == "number" then
            local interval = tonumber(mapInfo.interval) or tonumber(expansion.interval) or 1100
            if not interval or interval <= 0 then
                interval = 1100
            end

            result[#result + 1] = {
                id = mapInfo.id,
                mapID = mapInfo.mapID,
                expansionID = expansionID,
                interval = math.floor(interval),
                enabled = mapInfo.enabled ~= false,
                order = tonumber(mapInfo.order) or index,
                priority = tonumber(mapInfo.order) or index,
            }
        end
    end

    table.sort(result, function(a, b)
        if (a.order or 0) == (b.order or 0) then
            return (a.id or 0) < (b.id or 0)
        end
        return (a.order or 0) < (b.order or 0)
    end)

    return result
end

local function BuildTrackedSelectionForExpansion(expansionID)
    local trackedMaps = {}
    if not IsValidExpansionID(expansionID) then
        return trackedMaps
    end

    trackedMaps[expansionID] = {}
    for _, mapInfo in ipairs(GetExpansionMapDefinitions(expansionID)) do
        trackedMaps[expansionID][mapInfo.mapID] = true
    end
    return trackedMaps
end

local function IsValidTrackedMap(expansionID, mapID)
    if not IsValidExpansionID(expansionID) or type(mapID) ~= "number" then
        return false
    end

    for _, mapInfo in ipairs(GetExpansionMapDefinitions(expansionID)) do
        if mapInfo.mapID == mapID then
            return true
        end
    end
    return false
end

local function NormalizeTrackedSelection(trackedMaps)
    if type(trackedMaps) ~= "table" then
        return {}
    end

    local normalized = {}
    for expansionID, maps in pairs(trackedMaps) do
        if IsValidExpansionID(expansionID) and type(maps) == "table" then
            for mapID, selected in pairs(maps) do
                if selected == true and IsValidTrackedMap(expansionID, tonumber(mapID)) then
                    normalized[expansionID] = normalized[expansionID] or {}
                    normalized[expansionID][tonumber(mapID)] = true
                end
            end
        end
    end
    return normalized
end

local function EnsureTrackedMapsSelection()
    local uiDB = EnsureUIState()
    local trackedMaps = uiDB.trackedMaps
    if type(trackedMaps) ~= "table" then
        local legacyExpansionID = uiDB.expansionVersionID
        if IsValidExpansionID(legacyExpansionID) then
            trackedMaps = BuildTrackedSelectionForExpansion(legacyExpansionID)
        else
            trackedMaps = BuildTrackedSelectionForExpansion(ExpansionConfig.defaultExpansionID)
        end
        uiDB.trackedMaps = trackedMaps
    end

    local normalized = NormalizeTrackedSelection(uiDB.trackedMaps)
    uiDB.trackedMaps = normalized
    return uiDB.trackedMaps
end

local function CollectTrackedExpansionIDs()
    local trackedMaps = EnsureTrackedMapsSelection()
    local result = {}
    for _, expansionID in ipairs(IterateExpansionIDs(true)) do
        local expansionSelection = trackedMaps[expansionID]
        if type(expansionSelection) == "table" and next(expansionSelection) ~= nil then
            result[#result + 1] = expansionID
        end
    end
    return result
end

function ExpansionConfig:GetDisplayExpansionOrder()
    return IterateExpansionIDs(true)
end

function ExpansionConfig:GetAvailableExpansions()
    local result = {}
    for _, expansionID in ipairs(self:GetDisplayExpansionOrder()) do
        local config = self.expansions and self.expansions[expansionID]
        if config then
            result[#result + 1] = {
                id = expansionID,
                label = config.label or expansionID,
            }
        end
    end
    return result
end

function ExpansionConfig:GetCurrentExpansionID()
    local db = EnsureUIState()
    local selected = db.expansionVersionID
    if IsValidExpansionID(selected) then
        return selected
    end
    if IsValidExpansionID(self.defaultExpansionID) then
        return self.defaultExpansionID
    end
    local list = IterateExpansionIDs(false)
    return list[1]
end

function ExpansionConfig:GetExpansionMaps(expansionID)
    return GetExpansionMapDefinitions(expansionID)
end

function ExpansionConfig:GetAllMapDefinitions()
    local result = {}
    for _, expansionID in ipairs(self:GetDisplayExpansionOrder()) do
        for _, mapInfo in ipairs(GetExpansionMapDefinitions(expansionID)) do
            result[#result + 1] = CopyMapDefinition(mapInfo)
        end
    end
    return result
end

function ExpansionConfig:GetMapDefinitionByConfigID(configID)
    if type(configID) ~= "number" then
        return nil
    end
    for _, mapInfo in ipairs(self:GetAllMapDefinitions()) do
        if mapInfo.id == configID then
            return mapInfo
        end
    end
    return nil
end

function ExpansionConfig:GetMapDefinitionByMapID(mapID, expansionID)
    if type(mapID) ~= "number" then
        return nil
    end
    if expansionID and IsValidExpansionID(expansionID) then
        for _, mapInfo in ipairs(GetExpansionMapDefinitions(expansionID)) do
            if mapInfo.mapID == mapID then
                return mapInfo
            end
        end
        return nil
    end
    for _, mapInfo in ipairs(self:GetAllMapDefinitions()) do
        if mapInfo.mapID == mapID then
            return mapInfo
        end
    end
    return nil
end

function ExpansionConfig:GetMapExpansionID(mapID, expansionID)
    local mapInfo = self:GetMapDefinitionByMapID(mapID, expansionID)
    return mapInfo and mapInfo.expansionID or nil
end

function ExpansionConfig:GetTrackedMaps()
    return EnsureTrackedMapsSelection()
end

function ExpansionConfig:GetTrackedExpansionIDs()
    return CollectTrackedExpansionIDs()
end

function ExpansionConfig:IsMapTracked(expansionID, mapID)
    local trackedMaps = EnsureTrackedMapsSelection()
    return trackedMaps[expansionID] and trackedMaps[expansionID][mapID] == true or false
end

function ExpansionConfig:SetMapTracked(expansionID, mapID, tracked)
    if not IsValidTrackedMap(expansionID, mapID) then
        return false
    end

    local trackedMaps = EnsureTrackedMapsSelection()
    local expansionSelection = trackedMaps[expansionID]
    local shouldTrack = tracked == true

    if shouldTrack then
        trackedMaps[expansionID] = expansionSelection or {}
        if trackedMaps[expansionID][mapID] == true then
            return false
        end
        trackedMaps[expansionID][mapID] = true
        return true
    end

    if type(expansionSelection) ~= "table" or expansionSelection[mapID] ~= true then
        return false
    end
    expansionSelection[mapID] = nil
    if next(expansionSelection) == nil then
        trackedMaps[expansionID] = nil
    end
    return true
end

function ExpansionConfig:GetTrackedMapConfigs()
    local result = {}
    local trackedMaps = EnsureTrackedMapsSelection()

    for _, expansionID in ipairs(self:GetDisplayExpansionOrder()) do
        local expansionSelection = trackedMaps[expansionID]
        if type(expansionSelection) == "table" then
            for _, mapInfo in ipairs(GetExpansionMapDefinitions(expansionID)) do
                if expansionSelection[mapInfo.mapID] == true and mapInfo.enabled ~= false and not self:IsMainCityMap(mapInfo.mapID) then
                    result[#result + 1] = CopyMapDefinition(mapInfo)
                end
            end
        end
    end

    return result
end

function ExpansionConfig:GetActiveMapConfigs()
    local trackedMaps = self:GetTrackedMapConfigs()
    return trackedMaps, nil
end

function ExpansionConfig:GetTrackedAirdropPlaneVignetteIDs()
    local trackedExpansionIDs = self:GetTrackedExpansionIDs()
    local result = {}
    local seen = {}

    for _, expansionID in ipairs(trackedExpansionIDs) do
        local expansion = self.expansions and self.expansions[expansionID]
        if expansion and type(expansion.airdropPlaneVignetteIDs) == "table" then
            for _, vignetteID in ipairs(expansion.airdropPlaneVignetteIDs) do
                if type(vignetteID) == "number" and not seen[vignetteID] then
                    seen[vignetteID] = true
                    result[#result + 1] = vignetteID
                end
            end
        end
    end

    return result
end

function ExpansionConfig:GetCurrentAirdropPlaneVignetteIDs()
    return self:GetTrackedAirdropPlaneVignetteIDs()
end

function ExpansionConfig:IsAirdropPlaneVignetteID(vignetteID)
    if type(vignetteID) ~= "number" then
        return false
    end
    for _, id in ipairs(self:GetTrackedAirdropPlaneVignetteIDs()) do
        if id == vignetteID then
            return true
        end
    end
    return false
end

function ExpansionConfig:GetTrackedAirdropCrates()
    local trackedExpansionIDs = self:GetTrackedExpansionIDs()
    local result = {}
    local seen = {}

    for _, expansionID in ipairs(trackedExpansionIDs) do
        local expansion = self.expansions and self.expansions[expansionID]
        local defaultInterval = (expansion and expansion.interval) or 1100
        for _, crate in ipairs(expansion and expansion.airdropCrates or {}) do
            if type(crate) == "table" and type(crate.code) == "string" and crate.code ~= "" then
                local interval = tonumber(crate.interval) or defaultInterval
                if not interval or interval <= 0 then
                    interval = defaultInterval
                end

                local uniqueKey = crate.code .. ":" .. tostring(math.floor(interval))
                if not seen[uniqueKey] then
                    seen[uniqueKey] = true
                    result[#result + 1] = {
                        code = crate.code,
                        interval = math.floor(interval),
                        enabled = crate.enabled ~= false,
                    }
                end
            end
        end
    end

    return result
end

function ExpansionConfig:GetCurrentAirdropCrates()
    return self:GetTrackedAirdropCrates()
end

function ExpansionConfig:GetCurrentDefaultInterval()
    local crates = self:GetTrackedAirdropCrates()
    for _, crate in ipairs(crates) do
        if crate.enabled and crate.interval and crate.interval > 0 then
            return crate.interval
        end
    end

    local defaultExpansion = self.expansions and self.expansions[self.defaultExpansionID]
    if defaultExpansion and defaultExpansion.interval and defaultExpansion.interval > 0 then
        return defaultExpansion.interval
    end
    return 1100
end

function ExpansionConfig:IsMainCityMap(mapID)
    if type(mapID) ~= "number" then
        return false
    end

    for _, expansionID in ipairs(IterateExpansionIDs(false)) do
        local expansion = self.expansions and self.expansions[expansionID]
        for _, cityMapID in ipairs(expansion and expansion.mainCityMapIDs or {}) do
            if cityMapID == mapID then
                return true
            end
        end
    end
    return false
end

return ExpansionConfig

-- ExpansionConfig.lua - 资料片版本与地图列表配置

local ExpansionConfig = BuildEnv("ExpansionConfig")

ExpansionConfig.defaultExpansionID = "11.0"
ExpansionConfig.enableSwitch = true

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
        mapIDs = {
            2248,
            2369,
            2371,
            2346,
            2215,
            2214,
            2255,
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
        mapIDs = {
            2424,
            2541,
            2413,
            2437,
            2405,
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

function ExpansionConfig:IsSwitchEnabled()
    return self.enableSwitch == true
end

function ExpansionConfig:GetAvailableExpansions()
    local result = {}
    local order = self.expansionOrder or {}
    for _, expansionID in ipairs(order) do
        local config = self.expansions and self.expansions[expansionID]
        if config then
            table.insert(result, {
                id = expansionID,
                label = expansionID,
            })
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
    local list = self:GetAvailableExpansions()
    return list[1] and list[1].id or nil
end

function ExpansionConfig:GetCurrentExpansionLabel()
    local expansionID = self:GetCurrentExpansionID()
    local config = expansionID and self.expansions and self.expansions[expansionID]
    return config and config.label or expansionID or "N/A"
end

function ExpansionConfig:SetCurrentExpansionID(expansionID)
    if not IsValidExpansionID(expansionID) then
        return false
    end
    local db = EnsureUIState()
    db.expansionVersionID = expansionID
    return true
end

function ExpansionConfig:GetNextExpansionID(currentID)
    local list = self:GetAvailableExpansions()
    if #list == 0 then
        return nil
    end
    local currentIndex = 1
    for i, info in ipairs(list) do
        if info.id == currentID then
            currentIndex = i
            break
        end
    end
    local nextIndex = currentIndex + 1
    if nextIndex > #list then
        nextIndex = 1
    end
    return list[nextIndex].id
end

function ExpansionConfig:GetActiveMapConfigs()
    local expansionID = self:GetCurrentExpansionID()
    local expansion = expansionID and self.expansions and self.expansions[expansionID]
    if not expansion then
        return {}, expansionID
    end

    local interval = self:GetCurrentDefaultInterval()
    local maps = {}
    for index, mapID in ipairs(expansion.mapIDs or {}) do
        if type(mapID) == "number" and not self:IsMainCityMap(mapID) then
            table.insert(maps, {
                mapID = mapID,
                interval = interval,
                enabled = true,
                priority = index,
            })
        end
    end

    return maps, expansionID
end

function ExpansionConfig:GetCurrentAirdropPlaneVignetteIDs()
    local expansionID = self:GetCurrentExpansionID()
    local expansion = expansionID and self.expansions and self.expansions[expansionID]
    local result = {}
    if not expansion or not expansion.airdropPlaneVignetteIDs then
        return result
    end
    for _, vignetteID in ipairs(expansion.airdropPlaneVignetteIDs) do
        if type(vignetteID) == "number" then
            table.insert(result, vignetteID)
        end
    end
    return result
end

function ExpansionConfig:IsAirdropPlaneVignetteID(vignetteID)
    if type(vignetteID) ~= "number" then
        return false
    end
    local ids = self:GetCurrentAirdropPlaneVignetteIDs()
    for _, id in ipairs(ids) do
        if id == vignetteID then
            return true
        end
    end
    return false
end

function ExpansionConfig:GetCurrentAirdropCrates()
    local expansionID = self:GetCurrentExpansionID()
    local expansion = expansionID and self.expansions and self.expansions[expansionID]
    local result = {}
    local defaultInterval = (expansion and expansion.interval) or 1100
    if not expansion or not expansion.airdropCrates then
        return result
    end

    for _, crate in ipairs(expansion.airdropCrates) do
        if type(crate) == "table" and type(crate.code) == "string" and crate.code ~= "" then
            local interval = tonumber(crate.interval) or defaultInterval
            if not interval or interval <= 0 then
                interval = defaultInterval
            end
            table.insert(result, {
                code = crate.code,
                interval = math.floor(interval),
                enabled = crate.enabled ~= false,
            })
        end
    end

    return result
end

function ExpansionConfig:GetCurrentDefaultInterval()
    local crates = self:GetCurrentAirdropCrates()
    for _, crate in ipairs(crates) do
        if crate.enabled and crate.interval and crate.interval > 0 then
            return crate.interval
        end
    end

    local expansionID = self:GetCurrentExpansionID()
    local expansion = expansionID and self.expansions and self.expansions[expansionID]
    if expansion and expansion.interval and expansion.interval > 0 then
        return expansion.interval
    end
    return 1100
end

function ExpansionConfig:GetCurrentMainCityMapIDs()
    local expansionID = self:GetCurrentExpansionID()
    local expansion = expansionID and self.expansions and self.expansions[expansionID]
    local result = {}
    if not expansion or not expansion.mainCityMapIDs then
        return result
    end
    for _, mapID in ipairs(expansion.mainCityMapIDs) do
        if type(mapID) == "number" then
            table.insert(result, mapID)
        end
    end
    return result
end

function ExpansionConfig:IsMainCityMap(mapID)
    if type(mapID) ~= "number" then
        return false
    end
    local cityIDs = self:GetCurrentMainCityMapIDs()
    for _, cityMapID in ipairs(cityIDs) do
        if cityMapID == mapID then
            return true
        end
    end
    return false
end

return ExpansionConfig

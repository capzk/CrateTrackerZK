-- PhaseProbeService.lua - 位面探针单位过滤与解析

local PhaseProbeService = BuildEnv("PhaseProbeService")

local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitIsPlayer = UnitIsPlayer
local UnitPlayerControlled = UnitPlayerControlled
local UnitIsOtherPlayersPet = UnitIsOtherPlayersPet
local UnitIsOtherPlayersBattlePet = UnitIsOtherPlayersBattlePet
local UnitIsBattlePet = UnitIsBattlePet
local UnitIsWildBattlePet = UnitIsWildBattlePet
local UnitInVehicle = UnitInVehicle
local UnitUsingVehicle = UnitUsingVehicle
local UnitCreatureID = UnitCreatureID
local UnitCreatureType = UnitCreatureType
local UnitIsTrivial = UnitIsTrivial
local UnitLevel = UnitLevel
local C_GUIDUtil_GetCreatureID = C_GUIDUtil and C_GUIDUtil.GetCreatureID or nil

-- 玩家坐骑随行 NPC（商人/拍卖师/幻化师/车夫等）黑名单
-- 与独立插件 PhaseDetector 保持一致，避免把坐骑附带 NPC 当作有效位面探针。
local EXCLUDED_PLAYER_MOUNT_NPC_IDS = {
    [32638] = true,   -- Hakmud of Argus
    [32639] = true,   -- Gnimo
    [32641] = true,   -- Drix Blackwrench
    [32642] = true,   -- Mojodishu
    [62821] = true,   -- Mystic Birdhat
    [62822] = true,   -- Cousin Slowhands
    [64515] = true,   -- Mystic Birdhat (variant)
    [64516] = true,   -- Cousin Slowhands (variant)
    [89713] = true,   -- Koak Hoburn
    [89715] = true,   -- Franklin Martin
    [128288] = true,  -- Hakmud of Argus (Argus variant)
    [142666] = true,  -- Collector Unta
    [142668] = true,  -- Merchant Maku
}

local LOW_LEVEL_PROBE_MAX_LEVEL = 5
local CRITTER_CREATURE_TYPES = {
    ["Critter"] = true,
    ["小动物"] = true,
    ["小動物"] = true,
}

local function IsCritterCreatureType(creatureType)
    if type(creatureType) ~= "string" or creatureType == "" then
        return false
    end
    return CRITTER_CREATURE_TYPES[creatureType] == true
end

local function SafeSplitGuid(guid)
    if not guid or type(guid) ~= "string" then
        return nil
    end
    local ok, unitType, _, serverID, _, zoneUID = pcall(strsplit, "-", guid)
    if not ok then
        return nil
    end
    return unitType, serverID, zoneUID
end

function PhaseProbeService:IsIgnoredUnit(unit)
    if not unit or not UnitExists or not UnitExists(unit) then
        return true
    end

    if UnitIsPlayer and UnitIsPlayer(unit) then
        return true
    end

    if UnitPlayerControlled and UnitPlayerControlled(unit) then
        return true
    end

    if UnitIsOtherPlayersPet and UnitIsOtherPlayersPet(unit) then
        return true
    end

    if UnitIsOtherPlayersBattlePet and UnitIsOtherPlayersBattlePet(unit) then
        return true
    end

    if UnitIsBattlePet and UnitIsBattlePet(unit) then
        return true
    end

    if UnitIsWildBattlePet and UnitIsWildBattlePet(unit) then
        return true
    end

    -- 玩家坐骑上的商人/拍卖师等通常作为“在载具中的单位”暴露出来。
    if UnitInVehicle and UnitInVehicle(unit) then
        return true
    end

    if UnitUsingVehicle and UnitUsingVehicle(unit) then
        return true
    end

    local creatureType = UnitCreatureType and UnitCreatureType(unit) or nil
    if IsCritterCreatureType(creatureType) then
        return true
    end

    if UnitIsTrivial and UnitIsTrivial(unit) then
        return true
    end

    local unitLevel = UnitLevel and tonumber(UnitLevel(unit)) or nil
    if type(unitLevel) == "number" and unitLevel > 0 and unitLevel <= LOW_LEVEL_PROBE_MAX_LEVEL then
        return true
    end

    return false
end

function PhaseProbeService:GetCreatureIDFromUnit(unit, guid)
    if UnitCreatureID then
        local creatureID = UnitCreatureID(unit)
        if creatureID then
            return tonumber(creatureID)
        end
    end

    if C_GUIDUtil_GetCreatureID then
        local creatureID = C_GUIDUtil_GetCreatureID(guid)
        if creatureID then
            return tonumber(creatureID)
        end
    end

    local _, _, _, _, _, npcID = strsplit("-", guid)
    if npcID then
        return tonumber(npcID)
    end

    return nil
end

function PhaseProbeService:GetPhaseFromUnit(unit)
    if self:IsIgnoredUnit(unit) then
        return nil
    end

    local guid = UnitGUID and UnitGUID(unit)
    if not guid then
        return nil
    end

    local unitType, serverID, zoneUID = SafeSplitGuid(guid)
    if not unitType then
        return nil
    end

    local numericNpcID = self:GetCreatureIDFromUnit(unit, guid)
    if numericNpcID and EXCLUDED_PLAYER_MOUNT_NPC_IDS[numericNpcID] then
        return nil
    end

    if (unitType == "Creature" or unitType == "Vehicle") and serverID and zoneUID then
        return serverID .. "-" .. zoneUID
    end

    return nil
end

function PhaseProbeService:GetPreferredPhase(primaryUnit, fallbackUnit)
    local phaseID = self:GetPhaseFromUnit(primaryUnit)
    if phaseID then
        return phaseID
    end

    return self:GetPhaseFromUnit(fallbackUnit)
end

function PhaseProbeService:HasValidProbeUnit(primaryUnit, fallbackUnit)
    return self:GetPreferredPhase(primaryUnit, fallbackUnit) ~= nil
end

return PhaseProbeService

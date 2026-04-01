-- TeamCommMapCache.lua - 团队消息地图名缓存与身份缓存

local TeamCommMapCache = BuildEnv("TeamCommMapCache")
local Data = BuildEnv("Data")

function TeamCommMapCache:Build(listener)
    listener.mapNameToID = {}
    listener.mapNameCacheSignature = nil
    listener.mapNameCacheMapsRef = nil
    listener.mapNameCacheCount = nil
    listener.mapNameCacheExpansionID = nil

    if not Data or not Data.GetAllMaps then
        return
    end
    local maps = Data:GetAllMaps()
    if not maps or #maps == 0 then
        return
    end

    local signatureParts = { tostring(#maps) }
    for _, mapData in ipairs(maps) do
        if mapData then
            table.insert(signatureParts, table.concat({
                tostring(mapData.expansionID or "default"),
                tostring(mapData.id),
                tostring(mapData.mapID)
            }, ":"))
        end
    end

    listener.mapNameCacheSignature = table.concat(signatureParts, "|")
    listener.mapNameCacheMapsRef = maps
    listener.mapNameCacheCount = #maps

    for _, mapData in ipairs(maps) do
        if mapData then
            local displayName = Data:GetMapDisplayName(mapData)
            if type(displayName) == "string" and displayName ~= "" then
                listener.mapNameToID[displayName] = mapData.id
            end
        end
    end

    local LocaleManager = BuildEnv("LocaleManager")
    if LocaleManager and LocaleManager.GetLocaleRegistry then
        local localeRegistry = LocaleManager.GetLocaleRegistry()
        if localeRegistry then
            for _, mapData in ipairs(maps) do
                if mapData and mapData.mapID then
                    for _, localeData in pairs(localeRegistry) do
                        local localizedName = localeData and localeData.MapNames and localeData.MapNames[mapData.mapID]
                        if type(localizedName) == "string" and localizedName ~= "" and not listener.mapNameToID[localizedName] then
                            listener.mapNameToID[localizedName] = mapData.id
                        end
                    end
                end
            end
        end
    end
end

function TeamCommMapCache:Ensure(listener)
    if not Data or not Data.GetAllMaps then
        return
    end
    local maps = Data:GetAllMaps()
    if not maps then
        return
    end
    local signatureParts = { tostring(#maps) }
    for _, mapData in ipairs(maps) do
        if mapData then
            table.insert(signatureParts, table.concat({
                tostring(mapData.expansionID or "default"),
                tostring(mapData.id),
                tostring(mapData.mapID)
            }, ":"))
        end
    end
    local currentSignature = table.concat(signatureParts, "|")
    if listener.mapNameCacheMapsRef ~= maps
        or listener.mapNameCacheCount ~= #maps
        or listener.mapNameCacheSignature ~= currentSignature
        or not listener.mapNameToID then
        self:Build(listener)
    end
end

function TeamCommMapCache:GetMapIdByName(listener, mapName)
    local name = type(mapName) == "string" and mapName:match("^%s*(.-)%s*$") or nil
    if not name or name == "" then
        return nil
    end
    self:Ensure(listener)
    return listener.mapNameToID and listener.mapNameToID[name] or nil
end

function TeamCommMapCache:EnsurePlayerIdentity(listener)
    if listener.playerName and listener.fullPlayerName then
        return
    end
    local playerName = UnitName("player")
    local realmName = GetRealmName()
    listener.playerName = playerName
    if playerName and realmName and realmName ~= "" then
        listener.fullPlayerName = playerName .. "-" .. realmName
    else
        listener.fullPlayerName = playerName
    end
end

return TeamCommMapCache

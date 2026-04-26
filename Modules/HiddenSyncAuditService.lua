-- HiddenSyncAuditService.lua - 隐藏同步与共享协议运行时审计

local HiddenSyncAuditService = BuildEnv("HiddenSyncAuditService")

HiddenSyncAuditService.MAX_AGE_SECONDS = 3600
HiddenSyncAuditService.MAX_ENTRIES = 400
HiddenSyncAuditService.entries = HiddenSyncAuditService.entries or {}

local function NormalizeText(value)
    if value == nil then
        return nil
    end
    local text = tostring(value)
    if text == "" then
        return nil
    end
    return text
end

local function PruneExpiredEntries(self, currentTime)
    self.entries = type(self.entries) == "table" and self.entries or {}
    local now = tonumber(currentTime) or Utils:GetCurrentTimestamp()
    local maxAge = tonumber(self.MAX_AGE_SECONDS) or 3600

    local writeIndex = 1
    for index = 1, #self.entries do
        local entry = self.entries[index]
        local recordedAt = type(entry) == "table" and tonumber(entry.recordedAt) or nil
        if type(recordedAt) == "number" and (now - recordedAt) <= maxAge then
            self.entries[writeIndex] = entry
            writeIndex = writeIndex + 1
        end
    end

    for index = writeIndex, #self.entries do
        self.entries[index] = nil
    end
    return self.entries
end

function HiddenSyncAuditService:Reset()
    self.entries = {}
    return true
end

function HiddenSyncAuditService:Record(event)
    if type(event) ~= "table" then
        return false
    end

    self.entries = type(self.entries) == "table" and self.entries or {}
    PruneExpiredEntries(self)

    local entry = {
        recordedAt = tonumber(event.recordedAt) or Utils:GetCurrentTimestamp(),
        protocol = NormalizeText(event.protocol) or "unknown",
        direction = NormalizeText(event.direction) or "unknown",
        status = NormalizeText(event.status) or "unknown",
        resultCode = NormalizeText(event.resultCode),
        prefix = NormalizeText(event.prefix),
        messageType = NormalizeText(event.messageType),
        distribution = NormalizeText(event.distribution),
        chatType = NormalizeText(event.chatType),
        sender = NormalizeText(event.sender),
        requestID = NormalizeText(event.requestID),
        expansionID = NormalizeText(event.expansionID),
        mapID = tonumber(event.mapID),
        phaseID = NormalizeText(event.phaseID),
        routeKey = NormalizeText(event.routeKey),
        routeFamilyKey = NormalizeText(event.routeFamilyKey),
        landingKey = NormalizeText(event.landingKey),
        alertToken = NormalizeText(event.alertToken),
        objectGUID = NormalizeText(event.objectGUID),
        sampleCount = tonumber(event.sampleCount),
        observationCount = tonumber(event.observationCount),
        verificationCount = tonumber(event.verificationCount),
        verifiedPredictionCount = tonumber(event.verifiedPredictionCount),
        confidenceScore = tonumber(event.confidenceScore),
        payload = NormalizeText(event.payload),
        note = NormalizeText(event.note),
    }

    self.entries[#self.entries + 1] = entry

    local maxEntries = tonumber(self.MAX_ENTRIES) or 400
    while #self.entries > maxEntries do
        table.remove(self.entries, 1)
    end
    return true
end

function HiddenSyncAuditService:GetRecentEntries(maxAgeSeconds)
    PruneExpiredEntries(self)

    local entries = {}
    local now = Utils:GetCurrentTimestamp()
    local maxAge = tonumber(maxAgeSeconds) or tonumber(self.MAX_AGE_SECONDS) or 3600
    for _, entry in ipairs(self.entries or {}) do
        if type(entry) == "table"
            and type(entry.recordedAt) == "number"
            and (now - entry.recordedAt) <= maxAge then
            entries[#entries + 1] = entry
        end
    end
    return entries
end

return HiddenSyncAuditService

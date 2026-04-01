-- AppSettingsStore.lua - UI 配置读写访问

local AppSettingsStore = BuildEnv("AppSettingsStore")
local AppContext = BuildEnv("AppContext")

local function EnsureUIState()
    if AppContext and AppContext.EnsureUIState then
        return AppContext:EnsureUIState()
    end
    if type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {}
    end
    return CRATETRACKERZK_UI_DB
end

function AppSettingsStore:GetUIState()
    return EnsureUIState()
end

function AppSettingsStore:GetBoolean(key, defaultValue)
    local uiState = EnsureUIState()
    local value = uiState[key]
    if value == nil then
        return defaultValue == true
    end
    return value == true
end

function AppSettingsStore:SetBoolean(key, value)
    local uiState = EnsureUIState()
    uiState[key] = value == true
    return uiState[key]
end

function AppSettingsStore:GetNumber(key, defaultValue)
    local uiState = EnsureUIState()
    local value = tonumber(uiState[key])
    if not value then
        return defaultValue
    end
    return value
end

function AppSettingsStore:SetNumber(key, value)
    local uiState = EnsureUIState()
    local numberValue = tonumber(value)
    if not numberValue then
        uiState[key] = nil
        return nil
    end
    uiState[key] = numberValue
    return numberValue
end

return AppSettingsStore

-- AppContext.lua - 应用级共享上下文访问

local AppContext = BuildEnv("AppContext")
local ExpansionConfig = BuildEnv("ExpansionConfig")

function AppContext:EnsureUIState()
    if type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {}
    end
    return CRATETRACKERZK_UI_DB
end

function AppContext:EnsurePersistentState()
    if type(CRATETRACKERZK_DB) ~= "table" then
        CRATETRACKERZK_DB = {}
    end
    return CRATETRACKERZK_DB
end

function AppContext:GetCurrentExpansionID()
    if ExpansionConfig and ExpansionConfig.GetCurrentExpansionID then
        local expansionID = ExpansionConfig:GetCurrentExpansionID()
        if expansionID then
            return expansionID
        end
    end
    return "default"
end

return AppContext

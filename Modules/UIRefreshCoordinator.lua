-- UIRefreshCoordinator.lua - 统一 UI 刷新协调点

local UIRefreshCoordinator = BuildEnv("UIRefreshCoordinator")
local MainPanel = BuildEnv("MainPanel")

function UIRefreshCoordinator:RefreshMainTable(force)
    if MainPanel and MainPanel.UpdateTable then
        MainPanel:UpdateTable(force == true)
        return true
    end
    return false
end

function UIRefreshCoordinator:RefreshMainTableIfVisible(force)
    if MainPanel and MainPanel.IsMainFrameVisible and not MainPanel:IsMainFrameVisible() then
        return false
    end
    return self:RefreshMainTable(force)
end

function UIRefreshCoordinator:RequestLayoutUpdate()
    if MainPanel and MainPanel.RequestLayoutUpdate then
        MainPanel:RequestLayoutUpdate()
        return true
    end
    return false
end

return UIRefreshCoordinator

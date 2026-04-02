-- UIRefreshCoordinator.lua - 统一 UI 刷新协调点

local UIRefreshCoordinator = BuildEnv("UIRefreshCoordinator")
local MainPanel = BuildEnv("MainPanel")

UIRefreshCoordinator.SYNC_REFRESH_DELAY = 0.08
UIRefreshCoordinator.syncRefreshPending = UIRefreshCoordinator.syncRefreshPending or false
UIRefreshCoordinator.refreshTimer = UIRefreshCoordinator.refreshTimer or nil
UIRefreshCoordinator.pendingForceRefresh = UIRefreshCoordinator.pendingForceRefresh or false

function UIRefreshCoordinator:CancelPendingRefreshes()
    if self.refreshTimer and self.refreshTimer.Cancel then
        self.refreshTimer:Cancel()
    end
    self.refreshTimer = nil
    self.syncRefreshPending = false
    self.pendingForceRefresh = false
    return true
end

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

local function FlushPendingMainTableRefresh(self)
    local force = self.pendingForceRefresh == true
    self.pendingForceRefresh = false
    self.syncRefreshPending = false
    self.refreshTimer = nil
    self:RefreshMainTableIfVisible(force)
end

function UIRefreshCoordinator:RequestMainTableRefresh(force, delay)
    if MainPanel and MainPanel.IsMainFrameVisible and not MainPanel:IsMainFrameVisible() then
        return false
    end

    if force == true then
        self.pendingForceRefresh = true
    end

    delay = tonumber(delay)
    if delay == nil then
        delay = self.SYNC_REFRESH_DELAY or 0.08
    end
    if delay <= 0 then
        if self.refreshTimer and self.refreshTimer.Cancel then
            self.refreshTimer:Cancel()
        end
        self.refreshTimer = nil
        self.syncRefreshPending = false
        FlushPendingMainTableRefresh(self)
        return true
    end

    if self.syncRefreshPending then
        return true
    end

    self.syncRefreshPending = true

    if C_Timer and C_Timer.NewTimer then
        self.refreshTimer = C_Timer.NewTimer(delay, function()
            FlushPendingMainTableRefresh(self)
        end)
        return true
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(delay, function()
            FlushPendingMainTableRefresh(self)
        end)
        return true
    end

    FlushPendingMainTableRefresh(self)
    return true
end

function UIRefreshCoordinator:RequestRowRefresh(rowId, options)
    if MainPanel and MainPanel.IsMainFrameVisible and not MainPanel:IsMainFrameVisible() then
        return false
    end

    local refreshed = false
    if rowId ~= nil and MainPanel and MainPanel.RefreshRowData then
        refreshed = MainPanel:RefreshRowData(rowId) == true
    end

    local delay = options and options.delay or self.SYNC_REFRESH_DELAY or 0.08
    if not refreshed or ((options and options.affectsSort == true) and MainPanel and MainPanel.IsSortActive and MainPanel:IsSortActive()) then
        self:RequestMainTableRefresh(options and options.force == true, delay)
    end

    return refreshed
end

function UIRefreshCoordinator:RequestSyncRefresh(rowId)
    return self:RequestRowRefresh(rowId, {
        affectsSort = true,
        delay = self.SYNC_REFRESH_DELAY or 0.08,
    })
end

function UIRefreshCoordinator:RequestLayoutUpdate()
    if MainPanel and MainPanel.RequestLayoutUpdate then
        MainPanel:RequestLayoutUpdate()
        return true
    end
    return false
end

return UIRefreshCoordinator

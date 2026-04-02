-- MainPanelController.lua - 主面板生命周期与布局调度控制器

local MainPanelController = BuildEnv("MainPanelController")
local CountdownSystem = BuildEnv("CountdownSystem")

function MainPanelController:BindFrameLifecycle(panel, frame)
    if not panel or not frame or frame.__ctkMainPanelLifecycleBound then
        return
    end

    if frame.HookScript then
        frame:HookScript("OnShow", function()
            panel:StartUpdateTimer()
            panel:UpdateTable(true)
        end)
        frame:HookScript("OnHide", function()
            panel:StopUpdateTimer()
        end)
    end

    frame.__ctkMainPanelLifecycleBound = true
end

function MainPanelController:RequestLayoutUpdate(panel)
    if not panel or not panel.mainFrame then
        return
    end
    if not panel:IsMainFrameVisible() then
        return
    end

    local now = GetTime and GetTime() or 0
    local interval = panel.LAYOUT_UPDATE_INTERVAL or 0.016
    if panel.mainFrame and panel.mainFrame.isSizing then
        interval = math.max(interval, 0.033)
    end

    local elapsed = now - (panel.lastLayoutUpdateAt or 0)
    if elapsed >= interval then
        panel.lastLayoutUpdateAt = now
        panel:UpdateLayoutOnly()
        return
    end

    if panel.layoutUpdatePending then
        return
    end

    panel.layoutUpdatePending = true
    local delay = interval - elapsed
    if delay < 0.005 then
        delay = 0.005
    end

    panel.layoutUpdateTimer = C_Timer.NewTimer(delay, function()
        panel.layoutUpdateTimer = nil
        panel.layoutUpdatePending = false
        if not panel.mainFrame or not panel:IsMainFrameVisible() then
            return
        end
        panel.lastLayoutUpdateAt = GetTime and GetTime() or 0
        panel:UpdateLayoutOnly()
    end)
end

function MainPanelController:StartUpdateTimer(panel)
    if not panel or not panel:IsMainFrameVisible() then
        if panel then
            panel:StopUpdateTimer()
        end
        return
    end
    if panel.updateTimerActive then
        return
    end
    if CountdownSystem and CountdownSystem.Start then
        CountdownSystem:Start()
        panel.updateTimerActive = true
    end
end

function MainPanelController:StopUpdateTimer(panel)
    if not panel then
        return
    end
    if panel.layoutUpdateTimer then
        panel.layoutUpdateTimer:Cancel()
        panel.layoutUpdateTimer = nil
    end
    panel.layoutUpdatePending = false
    if CountdownSystem and CountdownSystem.Stop then
        CountdownSystem:Stop()
    end
    panel.updateTimerActive = false
    if panel.ReleaseHiddenState then
        panel:ReleaseHiddenState()
    end
end

return MainPanelController

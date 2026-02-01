-- MiniModeManager.lua - 极简/标准模式切换管理

local MiniModeManager = BuildEnv("MiniModeManager")
local MiniFrame = BuildEnv("MiniFrame")
local MainPanel = BuildEnv("MainPanel")

local function IsStandardShown()
    return CrateTrackerZKFrame and CrateTrackerZKFrame:IsShown()
end

local function IsMiniShown()
    return MiniFrame and MiniFrame.IsShown and MiniFrame:IsShown()
end

function MiniModeManager:GetCurrentMode()
    if IsMiniShown() then
        return "mini"
    end
    if IsStandardShown() then
        return "standard"
    end
    return "hidden"
end

function MiniModeManager:ShowStandard()
    if MiniFrame and MiniFrame.Hide then
        MiniFrame:Hide()
    end
    if MainPanel and MainPanel.CreateMainFrame then
        MainPanel:CreateMainFrame()
    end
    if CrateTrackerZKFrame then
        CrateTrackerZKFrame:Show()
        if MainPanel and MainPanel.UpdateTable then
            MainPanel:UpdateTable(true)
        end
    end
end

function MiniModeManager:ShowMini()
    if CrateTrackerZKFrame then
        CrateTrackerZKFrame:Hide()
    end
    if MiniFrame and MiniFrame.Show then
        MiniFrame:Show()
    end
end

function MiniModeManager:HideAll()
    if CrateTrackerZKFrame then
        CrateTrackerZKFrame:Hide()
    end
    if MiniFrame and MiniFrame.Hide then
        MiniFrame:Hide()
    end
end

function MiniModeManager:UpdateButton(mode)
    local button = BuildEnv("MiniModeButton")
    if button and button.SetMode then
        button:SetMode(mode or self:GetCurrentMode())
    end
end

function MiniModeManager:CycleMode()
    if IsMiniShown() then
        self:HideAll()
        self:UpdateButton("hidden")
        return "hidden"
    end
    if IsStandardShown() then
        self:ShowMini()
        self:UpdateButton("mini")
        return "mini"
    end

    self:ShowStandard()
    self:UpdateButton("standard")
    return "standard"
end

return MiniModeManager

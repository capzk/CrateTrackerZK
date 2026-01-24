-- MinimapButton.lua - 小地图按钮

local MinimapButton = BuildEnv("MinimapButton")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local UIConfig = BuildEnv("UIConfig")
local MainPanel = BuildEnv("MainPanel")
local SettingsPanel = BuildEnv("CrateTrackerZKSettingsPanel")
local L = CrateTrackerZK.L

local minimapButton = nil
local isDragging = false
local dragStartX, dragStartY = 0, 0
local dragStartAngle = nil

local function EnsureUIState()
    if not CRATETRACKERZK_UI_DB or type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {}
    end
end

local function GetIconPath()
    EnsureUIState()
    return CRATETRACKERZK_UI_DB.minimapButtonIcon
        or UIConfig.values.minimapButtonIcon
        or "Interface\\Icons\\INV_Misc_Gear_01"
end

function MinimapButton:CreateButton()
    if minimapButton then
        CrateTrackerZKFloatingButton = minimapButton
        return minimapButton
    end

    EnsureUIState()

    minimapButton = CreateFrame("Button", "CrateTrackerZKFloatingButton", Minimap)
    minimapButton:SetSize(33, 33)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)
    minimapButton:SetMovable(true)
    minimapButton:EnableMouse(true)
    minimapButton:RegisterForClicks("AnyUp")
    minimapButton:RegisterForDrag("LeftButton")

    local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(21, 21)
    icon:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 7, -6)
    icon:SetTexture(GetIconPath())

    C_Timer.After(0.1, function()
        if not icon:GetTexture() or icon:GetTexture() == "" then
            icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
        end
    end)

    local border = minimapButton:CreateTexture(nil, "OVERLAY")
    border:SetSize(56, 56)
    border:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local highlight = minimapButton:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(33, 33)
    highlight:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")

    minimapButton:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            if MainPanel and MainPanel.Toggle then
                MainPanel:Toggle()
            end
        elseif button == "RightButton" then
            if SettingsPanel and SettingsPanel.Toggle then
                SettingsPanel:Toggle()
            elseif SettingsPanel and SettingsPanel.Show then
                SettingsPanel:Show()
            end
        end
    end)

    minimapButton:SetScript("OnDragStart", function(self)
        isDragging = true
        self:LockHighlight()
        EnsureUIState()
        dragStartAngle = CRATETRACKERZK_UI_DB.minimapButtonPosition or UIConfig.values.minimapButtonPosition or 45
        local px, py = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        dragStartX, dragStartY = px / scale, py / scale
        self:SetScript("OnUpdate", function()
            if not isDragging then return end
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            px, py = px / scale, py / scale
            local angle = math.atan2(py - my, px - mx)
            local degrees = math.deg(angle)
            CRATETRACKERZK_UI_DB.minimapButtonPosition = degrees
            MinimapButton:UpdatePosition()
        end)
    end)

    minimapButton:SetScript("OnDragStop", function(self)
        isDragging = false
        self:UnlockHighlight()
        self:SetScript("OnUpdate", nil)
        local px, py = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        local dx = px / scale - dragStartX
        local dy = py / scale - dragStartY
        local distance = math.sqrt(dx * dx + dy * dy)
        -- 小范围拖动视为点击，避免误拖导致点击失效
        if distance <= 6 then
            EnsureUIState()
            CRATETRACKERZK_UI_DB.minimapButtonPosition = dragStartAngle
            MinimapButton:UpdatePosition()
            if MainPanel and MainPanel.Toggle then
                MainPanel:Toggle()
            end
        end
    end)

    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("CrateTrackerZK", 1, 1, 1)
        local line1 = L and L["FloatingButtonTooltipLine1"] or "Click to open/close tracking panel"
        local line2 = L and L["FloatingButtonTooltipLine2"] or "Drag to move button position"
        local line3 = L and L["FloatingButtonTooltipLine3"] or "Right-click to open settings"
        GameTooltip:AddLine(line1, 0.8, 0.8, 0.8)
        GameTooltip:AddLine(line2, 0.8, 0.8, 0.8)
        if line3 and line3 ~= "" then
            GameTooltip:AddLine(line3, 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
    end)

    minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self:UpdatePosition()

    local shouldHide = CRATETRACKERZK_UI_DB.minimapButtonHide
    if shouldHide == nil then
        shouldHide = UIConfig.values.minimapButtonHide
    end
    if shouldHide then
        minimapButton:Hide()
    else
        minimapButton:Show()
    end

    return minimapButton
end

function MinimapButton:UpdatePosition()
    if not minimapButton then return end
    EnsureUIState()
    local position = CRATETRACKERZK_UI_DB.minimapButtonPosition or UIConfig.values.minimapButtonPosition or 45
    local angle = math.rad(position)
    local distance = 100
    local x = distance * math.cos(angle)
    local y = distance * math.sin(angle)
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function MinimapButton:Show()
    if minimapButton then
        minimapButton:Show()
        EnsureUIState()
        CRATETRACKERZK_UI_DB.minimapButtonHide = false
    end
end

function MinimapButton:Hide()
    if minimapButton then
        minimapButton:Hide()
        EnsureUIState()
        CRATETRACKERZK_UI_DB.minimapButtonHide = true
    end
end

function MinimapButton:UpdateIcon(iconPath)
    if not minimapButton then return end
    local icon = nil
    for i = 1, minimapButton:GetNumRegions() do
        local region = select(i, minimapButton:GetRegions())
        if region and region:GetObjectType() == "Texture" and region:GetDrawLayer() == "BACKGROUND" then
            icon = region
            break
        end
    end
    if not icon then return end

    EnsureUIState()
    CRATETRACKERZK_UI_DB.minimapButtonIcon = iconPath
    icon:SetTexture(iconPath)

    C_Timer.After(0.1, function()
        if not icon:GetTexture() or icon:GetTexture() == "" then
            icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
        end
    end)
end

function MinimapButton:Toggle()
    if not minimapButton then return end
    if minimapButton:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function MinimapButton:Initialize()
    self:CreateButton()
end

function CrateTrackerZK:CreateFloatingButton()
    return MinimapButton:CreateButton()
end

return MinimapButton

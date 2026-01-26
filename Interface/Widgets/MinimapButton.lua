-- MinimapButton.lua - 小地图按钮

local MinimapButton = BuildEnv("MinimapButton")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local UIConfig = BuildEnv("UIConfig")
local MainPanel = BuildEnv("MainPanel")
local SettingsPanel = BuildEnv("CrateTrackerZKSettingsPanel")
local L = CrateTrackerZK.L

local minimapButton = nil
local ldbObject = nil
local dbIcon = nil
local isDragging = false
local dragStartX, dragStartY = 0, 0
local dragStartAngle = nil

local function EnsureUIState()
    if not CRATETRACKERZK_UI_DB or type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {}
    end
end

local function GetIconPath()
    return UIConfig.minimapButtonIcon or "Interface\\Icons\\INV_Misc_Gear_01"
end

local function EnsureMinimapDB()
    EnsureUIState()
    CRATETRACKERZK_UI_DB.minimapButtonPosition = nil
    CRATETRACKERZK_UI_DB.minimapButtonHide = nil
    CRATETRACKERZK_UI_DB.minimapButtonIcon = nil
    CRATETRACKERZK_UI_DB.minimap = CRATETRACKERZK_UI_DB.minimap or {}
    local db = CRATETRACKERZK_UI_DB.minimap
    if db.minimapPos == nil then
        db.minimapPos = UIConfig.minimapButtonPosition or 45
    end
    if db.hide == nil then
        db.hide = UIConfig.minimapButtonHide
    end
    return db
end

local function GetLibraries()
    if not LibStub then
        return nil, nil
    end
    return LibStub("LibDataBroker-1.1", true), LibStub("LibDBIcon-1.0", true)
end

local function HandleClick(button)
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
end

local function ApplyTooltip(tooltip)
    if not tooltip then
        return
    end
    tooltip:AddLine("CrateTrackerZK", 1, 1, 1)
    local line1 = L and L["FloatingButtonTooltipLine1"] or "Click to open/close tracking panel"
    local line2 = L and L["FloatingButtonTooltipLine2"] or "Drag to move button position"
    local line3 = L and L["FloatingButtonTooltipLine3"] or "Right-click to open settings"
    tooltip:AddLine(line1, 0.8, 0.8, 0.8)
    tooltip:AddLine(line2, 0.8, 0.8, 0.8)
    if line3 and line3 ~= "" then
        tooltip:AddLine(line3, 0.8, 0.8, 0.8)
    end
end

local function AttachButtonScripts(button)
    if not button then
        return
    end
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")

    button:SetScript("OnClick", function(_, btn)
        HandleClick(btn)
    end)

    button:SetScript("OnDragStart", function(self)
        isDragging = true
        self:LockHighlight()
        local db = EnsureMinimapDB()
        dragStartAngle = db.minimapPos or UIConfig.minimapButtonPosition or 45
        local px, py = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        dragStartX, dragStartY = px / scale, py / scale
        self:SetScript("OnUpdate", function()
            if not isDragging then return end
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local cursorScale = UIParent:GetEffectiveScale()
            cx, cy = cx / cursorScale, cy / cursorScale
            local angle = math.atan2(cy - my, cx - mx)
            local degrees = math.deg(angle)
            db.minimapPos = degrees
            MinimapButton:UpdatePosition()
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        isDragging = false
        self:UnlockHighlight()
        self:SetScript("OnUpdate", nil)
        local px, py = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        local dx = px / scale - dragStartX
        local dy = py / scale - dragStartY
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance <= 6 then
            local db = EnsureMinimapDB()
            db.minimapPos = dragStartAngle
            MinimapButton:UpdatePosition()
            HandleClick("LeftButton")
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        ApplyTooltip(GameTooltip)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function MinimapButton:CreateButton()
    if minimapButton then
        CrateTrackerZKFloatingButton = minimapButton
        return minimapButton
    end

    EnsureUIState()
    local ldb, iconLib = GetLibraries()
    local db = EnsureMinimapDB()
    if ldb and iconLib then
        dbIcon = iconLib
        if not ldbObject then
            ldbObject = ldb:NewDataObject("CrateTrackerZK", {
                type = "launcher",
                text = "CrateTrackerZK",
                icon = GetIconPath(),
                OnClick = function(_, button)
                    HandleClick(button)
                end,
                OnTooltipShow = function(tooltip)
                    ApplyTooltip(tooltip)
                end,
            })
        else
            ldbObject.icon = GetIconPath()
        end

        iconLib:Register("CrateTrackerZK", ldbObject, db)
        minimapButton = iconLib:GetMinimapButton("CrateTrackerZK")
        if minimapButton then
            CrateTrackerZKFloatingButton = minimapButton
            AttachButtonScripts(minimapButton)
            if minimapButton.icon then
                minimapButton.icon:SetTexture(GetIconPath())
            end

            self:UpdatePosition()
            if db.hide then
                iconLib:Hide("CrateTrackerZK")
            else
                iconLib:Show("CrateTrackerZK")
            end
            return minimapButton
        end
    end

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

    AttachButtonScripts(minimapButton)

    self:UpdatePosition()

    local db = EnsureMinimapDB()
    if db.hide then
        minimapButton:Hide()
    else
        minimapButton:Show()
    end

    return minimapButton
end

function MinimapButton:UpdatePosition()
    if not minimapButton then return end
    local db = EnsureMinimapDB()
    local position = db.minimapPos or UIConfig.minimapButtonPosition or 45
    local angle = math.rad(position)
    local distance = 100
    local x = distance * math.cos(angle)
    local y = distance * math.sin(angle)
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function MinimapButton:Show()
    if minimapButton then
        local db = EnsureMinimapDB()
        db.hide = false
        if dbIcon then
            dbIcon:Show("CrateTrackerZK")
        else
            minimapButton:Show()
        end
    end
end

function MinimapButton:Hide()
    if minimapButton then
        local db = EnsureMinimapDB()
        db.hide = true
        if dbIcon then
            dbIcon:Hide("CrateTrackerZK")
        else
            minimapButton:Hide()
        end
    end
end

function MinimapButton:UpdateIcon(iconPath)
    if not minimapButton then return end
    local icon = minimapButton.icon
    if not icon then
        for i = 1, minimapButton:GetNumRegions() do
            local region = select(i, minimapButton:GetRegions())
            if region and region:GetObjectType() == "Texture" and region:GetDrawLayer() == "BACKGROUND" then
                icon = region
                break
            end
        end
    end
    if not icon then return end

    EnsureUIState()
    if ldbObject then
        ldbObject.icon = iconPath
    end
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

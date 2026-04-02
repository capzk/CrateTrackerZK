-- MainFrame.lua - 主框架

local MainFrame = BuildEnv("MainFrame")
local MainFrameChrome = BuildEnv("MainFrameChrome")
local MainFrameMetrics = BuildEnv("MainFrameMetrics")
local MainFrameResizeController = BuildEnv("MainFrameResizeController")
local MainFrameState = BuildEnv("MainFrameState")
local UIConfig = BuildEnv("ThemeConfig")
local SettingsPanel = BuildEnv("CrateTrackerZKSettingsPanel")
local Data = BuildEnv("Data")

local FRAME_CFG = MainFrameMetrics.FRAME_CFG
local WIDTH_PROFILE_VERSION = MainFrameMetrics.WIDTH_PROFILE_VERSION
local UI_STATE_MIGRATION_VERSION = MainFrameMetrics.UI_STATE_MIGRATION_VERSION
local RESIZE_LAYOUT_NOTIFY_INTERVAL = MainFrameMetrics.RESIZE_LAYOUT_NOTIFY_INTERVAL
local RESIZE_LAYOUT_PIXEL_STEP = MainFrameMetrics.RESIZE_LAYOUT_PIXEL_STEP

local function EnsureUIState()
    if MainFrameState and MainFrameState.EnsureUIState then
        return MainFrameState:EnsureUIState(FRAME_CFG, WIDTH_PROFILE_VERSION, UI_STATE_MIGRATION_VERSION)
    end
    if not CRATETRACKERZK_UI_DB or type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {}
    end
    return CRATETRACKERZK_UI_DB
end

local function NotifyLayoutChanged(frame)
    if frame and frame.OnLayoutChanged then
        frame:OnLayoutChanged()
    end
end

local function NotifyLayoutChangedIfNeeded(frame, force)
    if not frame then
        return
    end
    local width = math.floor((frame:GetWidth() or 0) + 0.5)
    local height = math.floor((frame:GetHeight() or 0) + 0.5)

    local deltaW = math.abs((frame.lastLayoutWidth or width) - width)
    local deltaH = math.abs((frame.lastLayoutHeight or height) - height)
    local minPixelStep = frame.isSizing and RESIZE_LAYOUT_PIXEL_STEP or 1
    if not force and deltaW < minPixelStep and deltaH < minPixelStep then
        return
    end

    local now = GetTime and GetTime() or 0
    if not force and frame.isSizing and frame.lastLayoutNotifyAt and (now - frame.lastLayoutNotifyAt) < RESIZE_LAYOUT_NOTIFY_INTERVAL then
        return
    end
    frame.lastLayoutWidth = width
    frame.lastLayoutHeight = height
    frame.lastLayoutNotifyAt = now
    NotifyLayoutChanged(frame)
end

local function Clamp(value, minValue, maxValue) return MainFrameMetrics:Clamp(value, minValue, maxValue) end
local function GetChromeMetrics(scale) return MainFrameMetrics:GetChromeMetrics(scale) end
local function GetAdaptiveHeightBounds() return MainFrameMetrics:GetAdaptiveHeightBounds() end
local function GetAdaptiveDefaultHeight() return MainFrameMetrics:GetAdaptiveDefaultHeight() end
local function GetAdaptiveHeightForWidth(width) return MainFrameMetrics:GetAdaptiveHeightForWidth(width) end
local function ApplyFontScale(fontString, scale, minSize, maxSize) return MainFrameMetrics:ApplyFontScale(fontString, scale, minSize, maxSize) end
local function GetFrameScale(frame) return MainFrameMetrics:GetFrameScale(frame) end
local function GetEffectiveMinWidth(frame) return MainFrameMetrics:GetEffectiveMinWidth(frame) end
local function GetEffectiveMaxWidth(frame, minWidth) return MainFrameMetrics:GetEffectiveMaxWidth(frame, minWidth) end
local function GetEffectiveMinHeight(frame) return MainFrameMetrics:GetEffectiveMinHeight(frame) end
local function GetEffectiveMaxHeight(frame, minHeight) return MainFrameMetrics:GetEffectiveMaxHeight(frame, minHeight) end
local function IsAtMinimumWidth(frame) return MainFrameMetrics:IsAtMinimumWidth(frame) end

function MainFrame:ApplyScaledChrome(frame, scale)
    if MainFrameChrome and MainFrameChrome.ApplyScaledChrome then
        return MainFrameChrome:ApplyScaledChrome(frame, scale)
    end
end

function MainFrame:NormalizeSize(frame)
    if not frame then
        return
    end
    local currentWidth = frame:GetWidth() or FRAME_CFG.width
    local minHeight = GetEffectiveMinHeight(frame)
    local maxHeight = GetEffectiveMaxHeight(frame, minHeight)
    local currentHeight = frame:GetHeight() or maxHeight
    local targetHeight = currentHeight

    if not frame.isSizing and frame.__ctkHeightControlledByUser ~= true then
        targetHeight = maxHeight
    else
        targetHeight = Clamp(currentHeight, minHeight, maxHeight)
    end

    if math.abs(currentHeight - targetHeight) > 0.5 then
        frame.isNormalizingSize = true
        frame:SetHeight(targetHeight)
        frame.isNormalizingSize = nil
    end
    self:ApplyScaledChrome(frame, GetFrameScale(frame))
end

function MainFrame:ApplyAdaptiveResizeBounds(frame)
    if not frame then
        return
    end
    local minWidth = GetEffectiveMinWidth(frame)
    local maxWidth = GetEffectiveMaxWidth(frame, minWidth)
    local minHeight = GetEffectiveMinHeight(frame)
    local maxHeight = GetEffectiveMaxHeight(frame, minHeight)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
    else
        if frame.SetMinResize then
            frame:SetMinResize(minWidth, minHeight)
        end
        if frame.SetMaxResize then
            frame:SetMaxResize(maxWidth, maxHeight)
        end
    end
    local currentWidth = frame:GetWidth() or FRAME_CFG.width
    local currentHeight = frame:GetHeight() or maxHeight
    if currentWidth + 0.5 < minWidth then
        frame:SetWidth(minWidth)
        if self and self.PersistFrameSize then
            self:PersistFrameSize(frame)
        end
    elseif currentWidth - 0.5 > maxWidth then
        frame:SetWidth(maxWidth)
        if self and self.PersistFrameSize then
            self:PersistFrameSize(frame)
        end
    end
    if currentHeight + 0.5 < minHeight then
        frame:SetHeight(minHeight)
        if self and self.PersistFrameSize then
            self:PersistFrameSize(frame)
        end
    elseif currentHeight - 0.5 > maxHeight then
        frame:SetHeight(maxHeight)
        if self and self.PersistFrameSize then
            self:PersistFrameSize(frame)
        end
    end
end

function MainFrame:ApplyAdaptiveHeight(frame)
    if not frame then
        return
    end
    self:ApplyAdaptiveResizeBounds(frame)
    self:NormalizeSize(frame)
    NotifyLayoutChangedIfNeeded(frame)
end

function MainFrame:Create()
    local frame = CreateFrame("Frame", "CrateTrackerZKFrame", UIParent)
    frame.__ctkWidthControlledByUser = false
    frame.__ctkHeightControlledByUser = false
    frame:SetSize(FRAME_CFG.width, GetAdaptiveDefaultHeight())
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("LOW")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetResizable(true)
    self:ApplyAdaptiveResizeBounds(frame)

    self:ApplySavedSize(frame)

    self:CreateBackground(frame)
    self:CreateTitleBar(frame)
    self:CreateTableContainer(frame)
    self:CreateResizeHandle(frame)
    self:ApplyScaledChrome(frame, GetFrameScale(frame))
    self:ApplyThemeColors(frame)

    frame:SetScript("OnSizeChanged", function()
        if not frame.isNormalizingSize then
            self:NormalizeSize(frame)
        end
        -- 拖拽中也立即参与布局同步，避免边框先变、内容晚一拍导致溢出
        NotifyLayoutChangedIfNeeded(frame)
    end)

    return frame
end

function MainFrame:PersistFrameSize(frame)
    if not frame then
        return
    end
    if MainFrameState and MainFrameState.SaveFrameSize then
        MainFrameState:SaveFrameSize(frame, FRAME_CFG, WIDTH_PROFILE_VERSION, UI_STATE_MIGRATION_VERSION)
    end
end

function MainFrame:ApplySavedSize(frame)
    if MainFrameState and MainFrameState.ApplySavedSize then
        return MainFrameState:ApplySavedSize(
            frame,
            FRAME_CFG,
            WIDTH_PROFILE_VERSION,
            UI_STATE_MIGRATION_VERSION,
            GetEffectiveMinWidth,
            GetEffectiveMaxWidth,
            GetEffectiveMinHeight,
            GetEffectiveMaxHeight,
            function()
                self:NormalizeSize(frame)
            end
        )
    end
end

function MainFrame:CreateBackground(frame)
    if MainFrameChrome and MainFrameChrome.CreateBackground then
        return MainFrameChrome:CreateBackground(frame, function(targetFrame)
            self:CreateDragArea(targetFrame)
        end)
    end
end

function MainFrame:CreateDragArea(frame)
    if MainFrameChrome and MainFrameChrome.CreateDragArea then
        return MainFrameChrome:CreateDragArea(frame, function(targetFrame)
            if MainFrameState and MainFrameState.SaveFramePosition then
                MainFrameState:SaveFramePosition(targetFrame, FRAME_CFG, WIDTH_PROFILE_VERSION, UI_STATE_MIGRATION_VERSION)
            end
        end)
    end
end

function MainFrame:CreateTitleBar(frame)
    if MainFrameChrome and MainFrameChrome.CreateTitleBar then
        return MainFrameChrome:CreateTitleBar(frame, function(targetFrame)
            self:CreateSettingsButton(targetFrame)
        end, function(targetFrame)
            self:CreateCloseButton(targetFrame)
        end)
    end
end

function MainFrame:CreateSettingsButton(frame)
    if MainFrameChrome and MainFrameChrome.CreateSettingsButton then
        return MainFrameChrome:CreateSettingsButton(frame)
    end
end

function MainFrame:CreateCloseButton(frame)
    if MainFrameChrome and MainFrameChrome.CreateCloseButton then
        return MainFrameChrome:CreateCloseButton(frame)
    end
end

function MainFrame:CreateResizeHandle(frame)
    if MainFrameResizeController and MainFrameResizeController.CreateResizeHandle then
        return MainFrameResizeController:CreateResizeHandle(frame, {
            frameCfg = FRAME_CFG,
            resizeLayoutNotifyInterval = RESIZE_LAYOUT_NOTIFY_INTERVAL,
            resizeReleaseGuardInterval = math.max(RESIZE_LAYOUT_NOTIFY_INTERVAL or 0.016, 0.05),
            getEffectiveMinHeight = GetEffectiveMinHeight,
            getEffectiveMaxHeight = GetEffectiveMaxHeight,
            normalizeSize = function(targetFrame)
                self:NormalizeSize(targetFrame)
            end,
            persistFrameSize = function(targetFrame)
                self:PersistFrameSize(targetFrame)
            end,
            notifyLayoutChangedIfNeeded = function(targetFrame, force)
                NotifyLayoutChangedIfNeeded(targetFrame, force)
            end,
        })
    end
end

return MainFrame

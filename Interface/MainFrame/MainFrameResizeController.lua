-- MainFrameResizeController.lua - 主框架缩放手柄与尺寸交互

local MainFrameResizeController = BuildEnv("MainFrameResizeController")
local MainFrameMetrics = BuildEnv("MainFrameMetrics")

local function Clamp(value, minValue, maxValue)
    if MainFrameMetrics and MainFrameMetrics.Clamp then
        return MainFrameMetrics:Clamp(value, minValue, maxValue)
    end
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

function MainFrameResizeController:CreateResizeHandle(frame, options)
    options = options or {}

    local resizeHandle = CreateFrame("Button", nil, frame)
    resizeHandle:SetSize(16, 16)
    resizeHandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    resizeHandle:SetFrameLevel(frame:GetFrameLevel() + 20)
    resizeHandle:EnableMouse(true)
    if resizeHandle.SetHitRectInsets then
        resizeHandle:SetHitRectInsets(-4, -4, -4, -4)
    end
    resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    local function NotifyLayoutChanged(force)
        if options.notifyLayoutChangedIfNeeded then
            options.notifyLayoutChangedIfNeeded(frame, force)
        end
    end

    local function SetResizeHandleVisible(visible)
        if frame.resizeHandleVisible == visible then
            return
        end
        frame.resizeHandleVisible = visible
        if visible then
            resizeHandle:EnableMouse(true)
            if resizeHandle.SetAlpha then
                resizeHandle:SetAlpha(1)
            end
            resizeHandle:Show()
        else
            resizeHandle:EnableMouse(false)
            if resizeHandle.SetAlpha then
                resizeHandle:SetAlpha(0)
                resizeHandle:Show()
            else
                resizeHandle:Hide()
            end
        end
    end

    local function IsCursorInsideFrame()
        if not frame or not frame:IsShown() then
            return false
        end
        local left, right = frame:GetLeft(), frame:GetRight()
        local top, bottom = frame:GetTop(), frame:GetBottom()
        if not left or not right or not top or not bottom then
            return false
        end
        local x, y = GetCursorPosition()
        local scale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        if scale and scale > 0 then
            x = x / scale
            y = y / scale
        end
        return x >= left and x <= right and y >= bottom and y <= top
    end

    local function ShouldShowResizeHandle()
        if not frame or not frame:IsShown() then
            return false
        end
        if frame.isSizing then
            return true
        end
        return IsCursorInsideFrame()
    end

    local function CancelHideTimer()
        if frame.resizeHideTimer then
            frame.resizeHideTimer:Cancel()
            frame.resizeHideTimer = nil
        end
    end

    local HIDE_DELAY_SECONDS = 2.0

    local function ScheduleHideIfNeeded()
        CancelHideTimer()
        frame.resizeHideTimer = C_Timer.NewTimer(HIDE_DELAY_SECONDS, function()
            frame.resizeHideTimer = nil
            if not frame or not frame:IsShown() or frame.isSizing or IsCursorInsideFrame() then
                return
            end
            SetResizeHandleVisible(false)
        end)
    end

    local StopSizing

    local function StartLayoutRefreshTicker()
        if frame.layoutRefreshTicker then
            return
        end
        frame.layoutRefreshTicker = C_Timer.NewTicker(options.resizeLayoutNotifyInterval or 0.016, function()
            if not frame or not frame:IsShown() or not frame.isSizing then
                return
            end
            if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
                if StopSizing then
                    StopSizing()
                end
                return
            end
            NotifyLayoutChanged(false)
        end)
    end

    local function StopLayoutRefreshTicker()
        if frame.layoutRefreshTicker then
            frame.layoutRefreshTicker:Cancel()
            frame.layoutRefreshTicker = nil
        end
    end

    StopSizing = function()
        if not frame.isSizing then
            return
        end
        frame.isSizing = false
        frame.__ctkSizingStartWidth = nil
        frame.__ctkSizingStartHeight = nil
        frame.__ctkAutoHeightSyncValue = nil
        local finalWidth = frame:GetWidth() or options.frameCfg.width
        local finalHeight = frame:GetHeight() or options.frameCfg.height
        local maxWidth = tonumber(frame.__ctkContentMaxWidth) or options.frameCfg.width
        local minHeight = options.getEffectiveMinHeight(frame)
        local maxHeight = options.getEffectiveMaxHeight(frame, minHeight)
        local releaseSnapWidth = tonumber(frame.__ctkReleaseSnapWidth) or nil
        local releaseSnapHeight = tonumber(frame.__ctkReleaseSnapHeight) or nil
        if releaseSnapWidth then
            local minWidth = tonumber(frame.__ctkContentMinWidth) or options.frameCfg.minWidth
            local clampedSnapWidth = Clamp(math.floor(releaseSnapWidth + 0.5), minWidth, maxWidth)
            frame:SetWidth(clampedSnapWidth)
            finalWidth = clampedSnapWidth
        end
        if releaseSnapHeight then
            local clampedSnapHeight = Clamp(math.floor(releaseSnapHeight + 0.5), minHeight, maxHeight)
            frame:SetHeight(clampedSnapHeight)
            finalHeight = clampedSnapHeight
        end
        frame.__ctkReleaseSnapWidth = nil
        frame.__ctkReleaseSnapHeight = nil
        maxWidth = Clamp(math.floor(maxWidth + 0.5), options.frameCfg.minWidth, options.frameCfg.maxWidth)
        frame.__ctkWidthControlledByUser = (finalWidth + 0.5) < maxWidth
        frame.__ctkHeightControlledByUser = (finalHeight + 0.5) < maxHeight
        frame:StopMovingOrSizing()
        StopLayoutRefreshTicker()
        if options.normalizeSize then
            options.normalizeSize(frame)
        end
        if options.persistFrameSize then
            options.persistFrameSize(frame)
        end
        NotifyLayoutChanged(true)
        CancelHideTimer()
        if ShouldShowResizeHandle() then
            SetResizeHandleVisible(true)
        else
            ScheduleHideIfNeeded()
        end
    end

    resizeHandle:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then
            return
        end
        frame.isSizing = true
        frame.__ctkSizingStartWidth = frame:GetWidth() or options.frameCfg.width
        frame.__ctkSizingStartHeight = frame:GetHeight() or options.frameCfg.height
        frame.__ctkAutoHeightSyncValue = nil
        SetResizeHandleVisible(true)
        StartLayoutRefreshTicker()
        frame:StartSizing("BOTTOMRIGHT")
        NotifyLayoutChanged(true)
    end)

    resizeHandle:SetScript("OnMouseUp", function()
        StopSizing()
    end)

    frame:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            StopSizing()
        end
    end)

    frame:SetScript("OnEnter", function()
        CancelHideTimer()
        SetResizeHandleVisible(true)
    end)

    frame:SetScript("OnLeave", function()
        if frame.isSizing then
            return
        end
        ScheduleHideIfNeeded()
    end)

    frame:SetScript("OnShow", function()
        CancelHideTimer()
        SetResizeHandleVisible(ShouldShowResizeHandle())
    end)

    frame:SetScript("OnHide", function()
        StopLayoutRefreshTicker()
        CancelHideTimer()
        frame.isSizing = false
        frame.__ctkReleaseSnapWidth = nil
        frame.__ctkReleaseSnapHeight = nil
        SetResizeHandleVisible(false)
    end)

    frame.mainFrameResizeHandle = resizeHandle
    frame.resizeHandleVisible = nil
    SetResizeHandleVisible(false)
end

return MainFrameResizeController

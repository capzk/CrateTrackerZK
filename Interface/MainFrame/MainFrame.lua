-- MainFrame.lua - 主框架

local MainFrame = BuildEnv("MainFrame")
local UIConfig = BuildEnv("ThemeConfig")
local SettingsPanel = BuildEnv("CrateTrackerZKSettingsPanel")
local Data = BuildEnv("Data")

local FRAME_CFG = {
    width = 600,
    height = 335,
    minScale = 0.6,
    maxScale = 1.0,
    minWidth = 100,
    minHeight = 80,
    maxWidth = 600,
    maxHeight = 419,
}
local WIDTH_PROFILE_VERSION = 4
local UI_STATE_MIGRATION_VERSION = 1

local RESIZE_LAYOUT_NOTIFY_INTERVAL = 0.016
local RESIZE_LAYOUT_PIXEL_STEP = 1
local COMPACT_FIXED_ROW_HEIGHT = 34
local COMPACT_BASE_ROW_GAP = 2
local HEADER_COLLAPSE_TRANSITION_WIDTH = 60
local FIXED_TITLE_HEIGHT = 22
local FIXED_CONTENT_EDGE_GAP = 12

local function GetFixedTableInsets()
    local tableInset = FIXED_CONTENT_EDGE_GAP
    local tableTopInset = FIXED_TITLE_HEIGHT + FIXED_CONTENT_EDGE_GAP
    return tableInset, tableTopInset
end

local function IsFiniteNumber(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function MigrateUIState(db)
    if not db or type(db) ~= "table" then
        return
    end

    local migratedVersion = tonumber(db.uiStateMigrationVersion) or 0
    if migratedVersion >= UI_STATE_MIGRATION_VERSION then
        return
    end

    local size = db.mainFrameSize
    if size ~= nil and type(size) ~= "table" then
        db.mainFrameSize = nil
    elseif type(size) == "table" then
        local savedWidth = tonumber(size.width)
        local savedHeight = tonumber(size.height)
        local savedProfileVersion = tonumber(size.widthProfileVersion) or 0

        local invalidWidth = not IsFiniteNumber(savedWidth)
        local invalidHeight = not IsFiniteNumber(savedHeight)
        local invalidProfile = savedProfileVersion ~= WIDTH_PROFILE_VERSION

        if invalidWidth or invalidHeight or invalidProfile then
            -- 历史尺寸配置（含旧版 profile）统一丢弃，避免继续污染新布局逻辑
            db.mainFrameSize = nil
        else
            size.width = math.max(FRAME_CFG.minWidth, math.min(FRAME_CFG.maxWidth, savedWidth))
            size.height = math.max(FRAME_CFG.minHeight, math.min(FRAME_CFG.maxHeight, savedHeight))
            size.userControlledWidth = size.userControlledWidth == true
            size.userControlledHeight = size.userControlledHeight == true
            size.widthProfileVersion = WIDTH_PROFILE_VERSION
        end
    end

    local position = db.position
    if position ~= nil and type(position) ~= "table" then
        db.position = nil
    elseif type(position) == "table" then
        local point = type(position.point) == "string" and position.point or "CENTER"
        local x = tonumber(position.x) or 0
        local y = tonumber(position.y) or 0
        if not IsFiniteNumber(x) then x = 0 end
        if not IsFiniteNumber(y) then y = 0 end
        db.position = { point = point, x = x, y = y }
    end

    db.uiStateMigrationVersion = UI_STATE_MIGRATION_VERSION
end

local function EnsureUIState()
    if not CRATETRACKERZK_UI_DB or type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {}
    end
    MigrateUIState(CRATETRACKERZK_UI_DB)
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

local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function GetConfiguredMapCount()
    if Data and Data.GetAllMaps then
        local maps = Data:GetAllMaps()
        if maps and #maps > 0 then
            return #maps
        end
    end
    if Data and Data.MAP_CONFIG and Data.MAP_CONFIG.current_maps then
        local count = #Data.MAP_CONFIG.current_maps
        if count > 0 then
            return count
        end
    end
    return 7
end

local function GetCompactVisibleMapCount()
    if Data and Data.GetAllMaps then
        local maps = Data:GetAllMaps()
        if maps and #maps > 0 then
            local hiddenMaps = (Data.GetHiddenMaps and Data:GetHiddenMaps()) or {}
            local visibleCount = 0
            for _, mapData in ipairs(maps) do
                if mapData and mapData.mapID and not hiddenMaps[mapData.mapID] then
                    visibleCount = visibleCount + 1
                end
            end
            if visibleCount > 0 then
                return visibleCount
            end
        end
    end
    return math.max(1, GetConfiguredMapCount())
end

local function GetAdaptiveBaseHeight()
    local baseMapCount = 7
    local perMapHeight = 39
    local mapCount = GetConfiguredMapCount()
    return FRAME_CFG.height + (mapCount - baseMapCount) * perMapHeight
end

local function GetAdaptiveHeightBounds()
    local baseHeight = GetAdaptiveBaseHeight()
    local minHeight = FRAME_CFG.minHeight
    local maxHeight = math.floor(baseHeight * FRAME_CFG.maxScale + 0.5)
    if minHeight > maxHeight then
        minHeight, maxHeight = maxHeight, minHeight
    end
    return minHeight, maxHeight
end

local function GetAdaptiveDefaultHeight()
    local baseHeight = GetAdaptiveBaseHeight()
    local minHeight, maxHeight = GetAdaptiveHeightBounds()
    return Clamp(math.floor(baseHeight + 0.5), minHeight, maxHeight)
end

local function GetHeaderTransitionExtraHeight(width)
    local safeWidth = width or FRAME_CFG.width
    if safeWidth >= FRAME_CFG.width then
        return COMPACT_FIXED_ROW_HEIGHT + COMPACT_BASE_ROW_GAP
    end
    local collapseRange = HEADER_COLLAPSE_TRANSITION_WIDTH
    if collapseRange <= 0 then
        return 0
    end
    local t = Clamp((FRAME_CFG.width - safeWidth) / collapseRange, 0, 1)
    local eased = t * t * (3 - 2 * t)
    local ratio = 1 - eased
    local headerHeight = COMPACT_FIXED_ROW_HEIGHT * ratio
    local headerGap = COMPACT_BASE_ROW_GAP * ratio
    if headerHeight < 0.5 then
        headerHeight = 0
    end
    if headerGap < 0.5 then
        headerGap = 0
    end
    return headerHeight + headerGap
end

local function GetCompactFixedHeight(width)
    local rowCount = GetCompactVisibleMapCount()
    local fixedRowHeight = COMPACT_FIXED_ROW_HEIGHT
    local rowGap = COMPACT_BASE_ROW_GAP

    local tableInset, tableTopInset = GetFixedTableInsets()

    local rowsHeight = rowCount * fixedRowHeight + math.max(0, rowCount - 1) * rowGap
    local headerExtra = GetHeaderTransitionExtraHeight(width)
    return rowsHeight + headerExtra + tableTopInset + tableInset
end

local function GetAdaptiveHeightForWidth(width)
    local baseHeight = GetAdaptiveBaseHeight()
    local minHeight, maxHeight = GetAdaptiveHeightBounds()
    local safeWidth = width or FRAME_CFG.width
    local scale = Clamp(safeWidth / FRAME_CFG.width, FRAME_CFG.minScale, FRAME_CFG.maxScale)

    local targetHeight = nil
    if safeWidth < FRAME_CFG.width then
        -- 缩小态高度按固定行高反推，并计入表头压缩过渡高度，避免底部行被临时裁掉
        targetHeight = math.floor(GetCompactFixedHeight(safeWidth) + 0.5)
    else
        targetHeight = math.floor(baseHeight * scale + 0.5)
    end
    return Clamp(targetHeight, minHeight, maxHeight), scale
end

local function ApplyFontScale(fontString, scale, minSize, maxSize)
    if not fontString or not fontString.GetFont then
        return
    end
    if not fontString.__ctkBaseFont then
        local font, size, flags = fontString:GetFont()
        if not font then
            local defaultFont, defaultSize, defaultFlags = GameFontNormal:GetFont()
            font, size, flags = defaultFont, defaultSize, defaultFlags
        end
        fontString.__ctkBaseFont = {
            font = font,
            size = size or 12,
            flags = flags,
        }
    end
    local base = fontString.__ctkBaseFont
    local scaled = math.floor(base.size * (scale or 1) + 0.5)
    scaled = Clamp(scaled, minSize or 8, maxSize or 18)
    fontString:SetFont(base.font, scaled, base.flags)
end

local function GetFrameScale(frame)
    local width = frame and frame:GetWidth() or FRAME_CFG.width
    return Clamp(width / FRAME_CFG.width, FRAME_CFG.minScale, FRAME_CFG.maxScale)
end

local function GetEffectiveMinWidth(frame)
    local contentMin = frame and tonumber(frame.__ctkContentMinWidth) or nil
    if contentMin then
        return Clamp(math.floor(contentMin + 0.5), FRAME_CFG.minWidth, FRAME_CFG.maxWidth)
    end
    return FRAME_CFG.minWidth
end

local function GetEffectiveMaxWidth(frame, minWidth)
    local resolvedMinWidth = minWidth or GetEffectiveMinWidth(frame)
    local contentMax = frame and tonumber(frame.__ctkContentMaxWidth) or nil
    if contentMax then
        local clamped = Clamp(math.floor(contentMax + 0.5), FRAME_CFG.minWidth, FRAME_CFG.maxWidth)
        return math.max(resolvedMinWidth, clamped)
    end
    return FRAME_CFG.maxWidth
end

local function GetEffectiveMinHeight(frame)
    local _, adaptiveMax = GetAdaptiveHeightBounds()
    local contentMin = frame and tonumber(frame.__ctkContentMinHeight) or nil
    if contentMin then
        return Clamp(math.floor(contentMin + 0.5), FRAME_CFG.minHeight, adaptiveMax)
    end
    return FRAME_CFG.minHeight
end

local function GetEffectiveMaxHeight(frame, minHeight)
    local _, adaptiveMax = GetAdaptiveHeightBounds()
    local resolvedMinHeight = minHeight or GetEffectiveMinHeight(frame)
    local contentMax = frame and tonumber(frame.__ctkContentMaxHeight) or nil
    if contentMax then
        local clamped = Clamp(math.floor(contentMax + 0.5), FRAME_CFG.minHeight, adaptiveMax)
        return math.max(resolvedMinHeight, clamped)
    end
    return math.max(resolvedMinHeight, adaptiveMax)
end

local function IsAtMinimumWidth(frame)
    if not frame or not frame.GetWidth then
        return false
    end
    local width = frame:GetWidth() or FRAME_CFG.width
    local minWidth = GetEffectiveMinWidth(frame)
    return width <= (minWidth + 1)
end

function MainFrame:ApplyScaledChrome(frame, scale)
    if not frame then
        return
    end
    local scaled = scale or GetFrameScale(frame)
    local fixedTitleHeight = FIXED_TITLE_HEIGHT
    local fixedTitleButtonSize = 16
    local fixedTitleInsetY = -3
    local fixedSettingsInsetX = -35
    local fixedCloseInsetX = -12
    local fixedDotSize = 2
    local fixedDotOffset = 3
    local fixedCloseLineWidth = 8
    local fixedCloseLineHeight = 1
    local handleSize = math.max(12, math.floor(16 * scaled + 0.5))
    local handleInset = math.max(1, math.floor(2 * scaled + 0.5))
    local titleHeight = fixedTitleHeight
    local sideWidth = math.max(14, math.floor(20 * scaled + 0.5))
    local bottomHeight = math.max(20, math.floor(30 * scaled + 0.5))
    local tableInset, tableTopInset = GetFixedTableInsets()

    if frame.titleDragArea then
        frame.titleDragArea:SetHeight(titleHeight)
    end
    if frame.bottomDragArea then
        frame.bottomDragArea:SetHeight(bottomHeight)
        frame.bottomDragArea:ClearAllPoints()
        frame.bottomDragArea:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
        frame.bottomDragArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(handleSize + handleInset + 4), 1)
    end
    if frame.leftDragArea then
        frame.leftDragArea:SetWidth(sideWidth)
        frame.leftDragArea:ClearAllPoints()
        frame.leftDragArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -(titleHeight + 1))
        frame.leftDragArea:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, bottomHeight + 1)
    end
    if frame.rightDragArea then
        frame.rightDragArea:SetWidth(sideWidth)
        frame.rightDragArea:ClearAllPoints()
        frame.rightDragArea:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -(titleHeight + 1))
        frame.rightDragArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, bottomHeight + 1)
    end

    if frame.titleBg then
        frame.titleBg:SetHeight(titleHeight)
    end
    if frame.titleText then
        -- 标题字体保持固定，不随窗口缩放
        ApplyFontScale(frame.titleText, 1, 8, 16)
        if IsAtMinimumWidth(frame) or frame.__ctkMapColumnCompressed == true then
            frame.titleText:Hide()
        else
            frame.titleText:Show()
        end
    end

    if frame.settingsButton then
        frame.settingsButton:SetSize(fixedTitleButtonSize, fixedTitleButtonSize)
        frame.settingsButton:ClearAllPoints()
        frame.settingsButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", fixedSettingsInsetX, fixedTitleInsetY)
        if frame.settingsDot1 then
            frame.settingsDot1:SetSize(fixedDotSize, fixedDotSize)
            frame.settingsDot1:ClearAllPoints()
            frame.settingsDot1:SetPoint("CENTER", frame.settingsButton, "CENTER", -fixedDotOffset, 0)
        end
        if frame.settingsDot2 then
            frame.settingsDot2:SetSize(fixedDotSize, fixedDotSize)
            frame.settingsDot2:ClearAllPoints()
            frame.settingsDot2:SetPoint("CENTER", frame.settingsButton, "CENTER", 0, 0)
        end
        if frame.settingsDot3 then
            frame.settingsDot3:SetSize(fixedDotSize, fixedDotSize)
            frame.settingsDot3:ClearAllPoints()
            frame.settingsDot3:SetPoint("CENTER", frame.settingsButton, "CENTER", fixedDotOffset, 0)
        end
    end

    if frame.closeButton then
        frame.closeButton:SetSize(fixedTitleButtonSize, fixedTitleButtonSize)
        frame.closeButton:ClearAllPoints()
        frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", fixedCloseInsetX, fixedTitleInsetY)
    end
    if frame.closeLine then
        frame.closeLine:SetSize(fixedCloseLineWidth, fixedCloseLineHeight)
    end

    if frame.tableContainer then
        frame.tableContainer:ClearAllPoints()
        frame.tableContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", tableInset, -tableTopInset)
        frame.tableContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -tableInset, tableInset)
    end

    if frame.mainFrameResizeHandle then
        frame.mainFrameResizeHandle:SetSize(handleSize, handleSize)
        frame.mainFrameResizeHandle:ClearAllPoints()
        frame.mainFrameResizeHandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -handleInset, handleInset)
    end
end

function MainFrame:NormalizeSize(frame)
    if not frame then
        return
    end
    local currentWidth = frame:GetWidth() or FRAME_CFG.width
    local _, scale = GetAdaptiveHeightForWidth(currentWidth)
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
    self:ApplyScaledChrome(frame, scale)
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
    frame:SetFrameStrata("HIGH")
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

local function SaveFramePosition(frame)
    EnsureUIState()
    local point, _, _, x, y = frame:GetPoint()
    CRATETRACKERZK_UI_DB.position = { point = point, x = x, y = y }
end

local function SaveFrameSize(frame)
    EnsureUIState()
    CRATETRACKERZK_UI_DB.mainFrameSize = {
        width = frame:GetWidth(),
        height = frame:GetHeight(),
        userControlledWidth = frame and frame.__ctkWidthControlledByUser == true,
        userControlledHeight = frame and frame.__ctkHeightControlledByUser == true,
        widthProfileVersion = WIDTH_PROFILE_VERSION,
    }
end

function MainFrame:PersistFrameSize(frame)
    if not frame then
        return
    end
    SaveFrameSize(frame)
end

function MainFrame:ApplySavedSize(frame)
    EnsureUIState()
    local size = CRATETRACKERZK_UI_DB.mainFrameSize
    local minWidth = GetEffectiveMinWidth(frame)
    local maxWidth = GetEffectiveMaxWidth(frame, minWidth)
    local minHeight = GetEffectiveMinHeight(frame)
    local maxHeight = GetEffectiveMaxHeight(frame, minHeight)
    local savedWidth = size and tonumber(size.width) or nil
    local savedHeight = size and tonumber(size.height) or nil
    local profileVersion = size and tonumber(size.widthProfileVersion) or 0
    local hasUserControlledWidth = profileVersion == WIDTH_PROFILE_VERSION and size and size.userControlledWidth == true and savedWidth and (savedWidth + 0.5) < maxWidth
    local hasUserControlledHeight = profileVersion == WIDTH_PROFILE_VERSION and size and size.userControlledHeight == true and savedHeight and (savedHeight + 0.5) < maxHeight

    if not hasUserControlledWidth and not hasUserControlledHeight then
        frame.__ctkWidthControlledByUser = false
        frame.__ctkHeightControlledByUser = false
        frame:SetSize(FRAME_CFG.width, maxHeight)
        self:NormalizeSize(frame)
        return
    end

    local width = savedWidth or FRAME_CFG.width
    local height = savedHeight or maxHeight
    frame.__ctkWidthControlledByUser = hasUserControlledWidth == true
    frame.__ctkHeightControlledByUser = hasUserControlledHeight == true
    if not hasUserControlledWidth then
        width = FRAME_CFG.width
    end
    if not hasUserControlledHeight then
        height = maxHeight
    end
    width = math.max(minWidth, math.min(maxWidth, width))
    height = math.max(minHeight, math.min(maxHeight, height))
    frame:SetSize(width, height)
    self:NormalizeSize(frame)
end

function MainFrame:CreateBackground(frame)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    local bgColor = UIConfig.GetColor("mainFrameBackground")
    bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
    frame.mainBg = bg

    self:CreateDragArea(frame)
end

function MainFrame:CreateDragArea(frame)
    local titleDragArea = CreateFrame("Frame", nil, frame)
    titleDragArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    titleDragArea:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    titleDragArea:SetHeight(22)
    titleDragArea:SetFrameLevel(2)
    titleDragArea:EnableMouse(true)
    titleDragArea:RegisterForDrag("LeftButton")

    local bottomDragArea = CreateFrame("Frame", nil, frame)
    bottomDragArea:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    bottomDragArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 1)
    bottomDragArea:SetHeight(30)
    bottomDragArea:SetFrameLevel(2)
    bottomDragArea:EnableMouse(true)
    bottomDragArea:RegisterForDrag("LeftButton")

    local leftDragArea = CreateFrame("Frame", nil, frame)
    leftDragArea:SetWidth(20)
    leftDragArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -23)
    leftDragArea:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 31)
    leftDragArea:SetFrameLevel(2)
    leftDragArea:EnableMouse(true)
    leftDragArea:RegisterForDrag("LeftButton")

    local rightDragArea = CreateFrame("Frame", nil, frame)
    rightDragArea:SetWidth(20)
    rightDragArea:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -23)
    rightDragArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 31)
    rightDragArea:SetFrameLevel(2)
    rightDragArea:EnableMouse(true)
    rightDragArea:RegisterForDrag("LeftButton")

    for _, dragArea in ipairs({titleDragArea, bottomDragArea, leftDragArea, rightDragArea}) do
        dragArea:SetScript("OnDragStart", function() frame:StartMoving() end)
        dragArea:SetScript("OnDragStop", function()
            frame:StopMovingOrSizing()
            SaveFramePosition(frame)
        end)
    end

    frame.titleDragArea = titleDragArea
    frame.bottomDragArea = bottomDragArea
    frame.leftDragArea = leftDragArea
    frame.rightDragArea = rightDragArea
end

function MainFrame:CreateTitleBar(frame)
    local titleBg = frame:CreateTexture(nil, "ARTWORK")
    titleBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    titleBg:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    titleBg:SetHeight(22)
    local titleBarColor = UIConfig.GetColor("titleBarBackground")
    titleBg:SetColorTexture(titleBarColor[1], titleBarColor[2], titleBarColor[3], titleBarColor[4])

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("CENTER", titleBg, "CENTER", 0, 0)
    title:SetText("CrateTrackerZK")
    local titleColor = UIConfig.GetTextColor("normal")
    title:SetTextColor(titleColor[1], titleColor[2], titleColor[3], titleColor[4])
    title:SetJustifyH("CENTER")
    title:SetJustifyV("MIDDLE")
    title:SetShadowOffset(0, 0)

    frame.titleBg = titleBg
    frame.titleText = title

    self:CreateSettingsButton(frame)
    self:CreateCloseButton(frame)
end

function MainFrame:CreateSettingsButton(frame)
    local settingsButton = CreateFrame("Button", nil, frame)
    settingsButton:SetSize(16, 16)
    settingsButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -35, -3)
    settingsButton:SetFrameLevel(frame:GetFrameLevel() + 20)

    local settingsBg = settingsButton:CreateTexture(nil, "BACKGROUND")
    settingsBg:SetAllPoints(settingsButton)
    local buttonColor = UIConfig.GetColor("titleBarButton")
    settingsBg:SetColorTexture(buttonColor[1], buttonColor[2], buttonColor[3], buttonColor[4])

    local dot1 = settingsButton:CreateTexture(nil, "OVERLAY")
    dot1:SetSize(2, 2)
    dot1:SetPoint("CENTER", settingsButton, "CENTER", -3, 0)
    local textColor = UIConfig.GetTextColor("normal")
    dot1:SetColorTexture(textColor[1], textColor[2], textColor[3], textColor[4])

    local dot2 = settingsButton:CreateTexture(nil, "OVERLAY")
    dot2:SetSize(2, 2)
    dot2:SetPoint("CENTER", settingsButton, "CENTER", 0, 0)
    dot2:SetColorTexture(textColor[1], textColor[2], textColor[3], textColor[4])

    local dot3 = settingsButton:CreateTexture(nil, "OVERLAY")
    dot3:SetSize(2, 2)
    dot3:SetPoint("CENTER", settingsButton, "CENTER", 3, 0)
    dot3:SetColorTexture(textColor[1], textColor[2], textColor[3], textColor[4])

    settingsButton:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel.Show then
            SettingsPanel:Show()
        end
    end)

    settingsButton:SetScript("OnEnter", function()
        local hoverColor = UIConfig.GetColor("titleBarButtonHover")
        settingsBg:SetColorTexture(hoverColor[1], hoverColor[2], hoverColor[3], hoverColor[4])
    end)
    settingsButton:SetScript("OnLeave", function()
        local normalColor = UIConfig.GetColor("titleBarButton")
        settingsBg:SetColorTexture(normalColor[1], normalColor[2], normalColor[3], normalColor[4])
    end)

    frame.settingsButton = settingsButton
    frame.settingsButtonBg = settingsBg
    frame.settingsDot1 = dot1
    frame.settingsDot2 = dot2
    frame.settingsDot3 = dot3
end

function MainFrame:CreateCloseButton(frame)
    local closeButton = CreateFrame("Button", nil, frame)
    closeButton:SetSize(16, 16)
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -3)
    closeButton:SetFrameLevel(frame:GetFrameLevel() + 20)

    local closeBg = closeButton:CreateTexture(nil, "BACKGROUND")
    closeBg:SetAllPoints(closeButton)
    local buttonColor = UIConfig.GetColor("titleBarButton")
    closeBg:SetColorTexture(buttonColor[1], buttonColor[2], buttonColor[3], buttonColor[4])

    local line = closeButton:CreateTexture(nil, "OVERLAY")
    line:SetSize(8, 1)
    line:SetPoint("CENTER", closeButton, "CENTER", 0, 0)
    local textColor = UIConfig.GetTextColor("normal")
    line:SetColorTexture(textColor[1], textColor[2], textColor[3], textColor[4])

    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    closeButton:SetScript("OnEnter", function()
        local hoverColor = UIConfig.GetColor("titleBarButtonHover")
        closeBg:SetColorTexture(hoverColor[1], hoverColor[2], hoverColor[3], hoverColor[4])
    end)
    closeButton:SetScript("OnLeave", function()
        local normalColor = UIConfig.GetColor("titleBarButton")
        closeBg:SetColorTexture(normalColor[1], normalColor[2], normalColor[3], normalColor[4])
    end)

    frame.closeButton = closeButton
    frame.closeButtonBg = closeBg
    frame.closeLine = line
end

function MainFrame:CreateResizeHandle(frame)
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

    local function SetResizeHandleVisible(visible)
        if not resizeHandle then
            return
        end
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
            if not frame or not frame:IsShown() then
                return
            end
            if frame.isSizing then
                return
            end
            if IsCursorInsideFrame() then
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
        frame.layoutRefreshTicker = C_Timer.NewTicker(RESIZE_LAYOUT_NOTIFY_INTERVAL, function()
            if not frame or not frame:IsShown() or not frame.isSizing then
                return
            end
            if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
                if StopSizing then
                    StopSizing()
                end
                return
            end
            NotifyLayoutChangedIfNeeded(frame)
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
        local finalWidth = frame:GetWidth() or FRAME_CFG.width
        local finalHeight = frame:GetHeight() or FRAME_CFG.height
        local maxWidth = tonumber(frame.__ctkContentMaxWidth) or FRAME_CFG.width
        local minHeight = GetEffectiveMinHeight(frame)
        local maxHeight = GetEffectiveMaxHeight(frame, minHeight)
        maxWidth = Clamp(math.floor(maxWidth + 0.5), FRAME_CFG.minWidth, FRAME_CFG.maxWidth)
        frame.__ctkWidthControlledByUser = (finalWidth + 0.5) < maxWidth
        frame.__ctkHeightControlledByUser = (finalHeight + 0.5) < maxHeight
        frame:StopMovingOrSizing()
        StopLayoutRefreshTicker()
        self:NormalizeSize(frame)
        self:PersistFrameSize(frame)
        NotifyLayoutChangedIfNeeded(frame, true)
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
        SetResizeHandleVisible(true)
        StartLayoutRefreshTicker()
        frame:StartSizing("BOTTOMRIGHT")
        NotifyLayoutChangedIfNeeded(frame, true)
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
        SetResizeHandleVisible(false)
    end)

    frame.mainFrameResizeHandle = resizeHandle
    frame.resizeHandleVisible = nil
    SetResizeHandleVisible(false)
end

return MainFrame

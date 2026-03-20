-- MainFrameState.lua - 主框架状态迁移与持久化

local MainFrameState = BuildEnv("MainFrameState")

local function IsFiniteNumber(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function MainFrameState:MigrateUIState(frameCfg, widthProfileVersion, uiStateMigrationVersion)
    if type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {}
    end

    local db = CRATETRACKERZK_UI_DB
    local migratedVersion = tonumber(db.uiStateMigrationVersion) or 0
    if migratedVersion >= uiStateMigrationVersion then
        return db
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
        local invalidProfile = savedProfileVersion ~= widthProfileVersion

        if invalidWidth or invalidHeight or invalidProfile then
            db.mainFrameSize = nil
        else
            size.width = math.max(frameCfg.minWidth, math.min(frameCfg.maxWidth, savedWidth))
            size.height = math.max(frameCfg.minHeight, math.min(frameCfg.maxHeight, savedHeight))
            size.userControlledWidth = size.userControlledWidth == true
            size.userControlledHeight = size.userControlledHeight == true
            size.widthProfileVersion = widthProfileVersion
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

    db.uiStateMigrationVersion = uiStateMigrationVersion
    return db
end

function MainFrameState:EnsureUIState(frameCfg, widthProfileVersion, uiStateMigrationVersion)
    return self:MigrateUIState(frameCfg, widthProfileVersion, uiStateMigrationVersion)
end

function MainFrameState:SaveFramePosition(frame, frameCfg, widthProfileVersion, uiStateMigrationVersion)
    local db = self:EnsureUIState(frameCfg, widthProfileVersion, uiStateMigrationVersion)
    local point, _, _, x, y = frame:GetPoint()
    db.position = { point = point, x = x, y = y }
end

function MainFrameState:SaveFrameSize(frame, frameCfg, widthProfileVersion, uiStateMigrationVersion)
    local db = self:EnsureUIState(frameCfg, widthProfileVersion, uiStateMigrationVersion)
    db.mainFrameSize = {
        width = frame:GetWidth(),
        height = frame:GetHeight(),
        userControlledWidth = frame and frame.__ctkWidthControlledByUser == true,
        userControlledHeight = frame and frame.__ctkHeightControlledByUser == true,
        widthProfileVersion = widthProfileVersion,
    }
end

function MainFrameState:ApplySavedSize(frame, frameCfg, widthProfileVersion, uiStateMigrationVersion, getMinWidth, getMaxWidth, getMinHeight, getMaxHeight, normalizeCallback)
    local db = self:EnsureUIState(frameCfg, widthProfileVersion, uiStateMigrationVersion)
    local size = db.mainFrameSize
    local minWidth = getMinWidth(frame)
    local maxWidth = getMaxWidth(frame, minWidth)
    local minHeight = getMinHeight(frame)
    local maxHeight = getMaxHeight(frame, minHeight)
    local savedWidth = size and tonumber(size.width) or nil
    local savedHeight = size and tonumber(size.height) or nil
    local profileVersion = size and tonumber(size.widthProfileVersion) or 0
    local hasUserControlledWidth = profileVersion == widthProfileVersion and size and size.userControlledWidth == true and savedWidth and (savedWidth + 0.5) < maxWidth
    local hasUserControlledHeight = profileVersion == widthProfileVersion and size and size.userControlledHeight == true and savedHeight and (savedHeight + 0.5) < maxHeight

    if not hasUserControlledWidth and not hasUserControlledHeight then
        frame.__ctkWidthControlledByUser = false
        frame.__ctkHeightControlledByUser = false
        frame:SetSize(frameCfg.width, maxHeight)
        if normalizeCallback then
            normalizeCallback()
        end
        return
    end

    local width = savedWidth or frameCfg.width
    local height = savedHeight or maxHeight
    frame.__ctkWidthControlledByUser = hasUserControlledWidth == true
    frame.__ctkHeightControlledByUser = hasUserControlledHeight == true
    if not hasUserControlledWidth then
        width = frameCfg.width
    end
    if not hasUserControlledHeight then
        height = maxHeight
    end
    width = math.max(minWidth, math.min(maxWidth, width))
    height = math.max(minHeight, math.min(maxHeight, height))
    frame:SetSize(width, height)
    if normalizeCallback then
        normalizeCallback()
    end
end

return MainFrameState

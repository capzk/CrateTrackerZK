-- RowStateSystem.lua - 行状态与右键菜单

local RowStateSystem = BuildEnv("RowStateSystem")
local MainPanel = BuildEnv("MainPanel")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local L = CrateTrackerZK.L

local rowStates = {}
local rowFrames = {}
local rowButtons = {}
local ROW_STATE = {
    NORMAL = "normal",
    RIGHT_CLICKED = "right_clicked",
    DELETED = "deleted",
}

RowStateSystem.mainFrame = nil

function RowStateSystem:InitializeRowState(rowId, isDeleted)
    rowStates[rowId] = {
        deleted = isDeleted == true,
        rightClicked = false,
        state = isDeleted and ROW_STATE.DELETED or ROW_STATE.NORMAL,
    }
end

function RowStateSystem:SyncRowState(rowId, isDeleted)
    if not rowStates[rowId] then
        self:InitializeRowState(rowId, isDeleted)
        return
    end
    local state = rowStates[rowId]
    state.deleted = isDeleted == true
    state.rightClicked = false
    state.state = state.deleted and ROW_STATE.DELETED or ROW_STATE.NORMAL
end

function RowStateSystem:GetRowState(rowId)
    if not rowStates[rowId] then
        self:InitializeRowState(rowId, false)
    end
    return rowStates[rowId]
end

function RowStateSystem:IsRowDeleted(rowId)
    local state = self:GetRowState(rowId)
    return state.deleted
end

function RowStateSystem:RegisterRowFrame(rowId, frame)
    rowFrames[rowId] = frame
end

function RowStateSystem:RegisterRowButtons(rowId, refreshBtn, notifyBtn)
    rowButtons[rowId] = {
        refresh = refreshBtn,
        notify = notifyBtn,
    }
end

function RowStateSystem:GetRowButtons(rowId)
    return rowButtons[rowId]
end

function RowStateSystem:OnRowRightClick(rowId)
    local state = self:GetRowState(rowId)
    if state.deleted then
        self:ShowRestoreButton(rowId)
    else
        self:ShowDeleteButton(rowId)
    end
    state.rightClicked = true
    state.state = ROW_STATE.RIGHT_CLICKED
    self:CreateCancelListener()
end

function RowStateSystem:ShowDeleteButton(rowId)
    local buttons = self:GetRowButtons(rowId)
    if not buttons then return end

    if buttons.refresh then buttons.refresh:Hide() end
    if buttons.notify then buttons.notify:Hide() end

    if not buttons.delete then
        local frame = rowFrames[rowId]
        if frame then
            buttons.delete = self:CreateDeleteButton(frame, rowId)
        end
    end

    if buttons.delete then
        buttons.delete:Show()
    end
end

function RowStateSystem:ShowRestoreButton(rowId)
    local buttons = self:GetRowButtons(rowId)
    if not buttons then return end

    if buttons.refresh then buttons.refresh:Hide() end
    if buttons.notify then buttons.notify:Hide() end

    if not buttons.restore then
        local frame = rowFrames[rowId]
        if frame then
            buttons.restore = self:CreateRestoreButton(frame, rowId)
        end
    end

    if buttons.restore then
        buttons.restore:Show()
    end
end

function RowStateSystem:RestoreNormalButtons(rowId)
    local buttons = self:GetRowButtons(rowId)
    if not buttons then return end

    if buttons.delete then buttons.delete:Hide() end
    if buttons.restore then buttons.restore:Hide() end

    if buttons.refresh then buttons.refresh:Show() end
    if buttons.notify then buttons.notify:Show() end

    local state = self:GetRowState(rowId)
    state.rightClicked = false
    state.state = state.deleted and ROW_STATE.DELETED or ROW_STATE.NORMAL
end

function RowStateSystem:CreateDeleteButton(parentFrame, rowId)
    local deleteBtn = CreateFrame("Button", nil, parentFrame)
    deleteBtn:SetSize(80, 20)
    local operationColumnStart = 120 + 100 + 120 + 100
    local operationColumnWidth = 120
    local columnCenter = operationColumnStart + operationColumnWidth / 2
    deleteBtn:SetPoint("CENTER", parentFrame, "LEFT", columnCenter, 0)
    deleteBtn:SetFrameLevel(parentFrame:GetFrameLevel() + 5)

    local bg = deleteBtn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(deleteBtn)
    bg:SetColorTexture(0.8, 0.2, 0.2, 0.8)

    local text = deleteBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER", deleteBtn, "CENTER", 0, 0)
    text:SetText(L["Delete"] or "删除")
    text:SetTextColor(1, 1, 1, 1)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetShadowOffset(0, 0)

    deleteBtn:SetScript("OnClick", function()
        self:DeleteRow(rowId)
    end)

    deleteBtn:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" then
            self:OnGlobalLeftClick()
        end
    end)

    deleteBtn:SetScript("OnEnter", function()
        bg:SetColorTexture(1, 0.3, 0.3, 0.9)
    end)
    deleteBtn:SetScript("OnLeave", function()
        bg:SetColorTexture(0.8, 0.2, 0.2, 0.8)
    end)

    deleteBtn:Hide()
    return deleteBtn
end

function RowStateSystem:CreateRestoreButton(parentFrame, rowId)
    local restoreBtn = CreateFrame("Button", nil, parentFrame)
    restoreBtn:SetSize(80, 20)
    local operationColumnStart = 120 + 100 + 120 + 100
    local operationColumnWidth = 120
    local columnCenter = operationColumnStart + operationColumnWidth / 2
    restoreBtn:SetPoint("CENTER", parentFrame, "LEFT", columnCenter, 0)
    restoreBtn:SetFrameLevel(parentFrame:GetFrameLevel() + 5)

    local bg = restoreBtn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(restoreBtn)
    bg:SetColorTexture(0.2, 0.8, 0.2, 0.8)

    local text = restoreBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER", restoreBtn, "CENTER", 0, 0)
    text:SetText(L["Restore"] or "恢复")
    text:SetTextColor(1, 1, 1, 1)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetShadowOffset(0, 0)

    restoreBtn:SetScript("OnClick", function()
        self:RestoreRow(rowId)
    end)

    restoreBtn:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" then
            self:OnGlobalLeftClick()
        end
    end)

    restoreBtn:SetScript("OnEnter", function()
        bg:SetColorTexture(0.3, 1, 0.3, 0.9)
    end)
    restoreBtn:SetScript("OnLeave", function()
        bg:SetColorTexture(0.2, 0.8, 0.2, 0.8)
    end)

    restoreBtn:Hide()
    return restoreBtn
end

function RowStateSystem:DeleteRow(rowId)
    self:OnGlobalLeftClick()
    if MainPanel and MainPanel.HideMap then
        MainPanel:HideMap(rowId)
    end
end

function RowStateSystem:RestoreRow(rowId)
    self:OnGlobalLeftClick()
    if MainPanel and MainPanel.RestoreMap then
        MainPanel:RestoreMap(rowId)
    end
end

function RowStateSystem:OnGlobalLeftClick()
    local cancelCount = 0
    for rowId, state in pairs(rowStates) do
        if state.rightClicked then
            self:RestoreNormalButtons(rowId)
            cancelCount = cancelCount + 1
        end
    end
    if cancelCount > 0 then
        self:RemoveCancelListener()
    end
end

function RowStateSystem:AddClickListenerToTableArea(frame)
    self.mainFrame = frame
end

function RowStateSystem:CreateCancelListener()
    if not self.mainFrame then return end
    self:RemoveCancelListener()

    local tableClickListener = CreateFrame("Frame", nil, self.mainFrame)
    tableClickListener:SetPoint("TOPLEFT", self.mainFrame, "TOPLEFT", 20, -23)
    tableClickListener:SetPoint("BOTTOMRIGHT", self.mainFrame, "TOPLEFT", 580, -270)
    tableClickListener:SetFrameLevel(1)
    tableClickListener:EnableMouse(true)
    tableClickListener:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" or button == "RightButton" then
            self:OnGlobalLeftClick()
        end
    end)

    self.mainFrame.rowStateTableClickListener = tableClickListener
end

function RowStateSystem:RemoveCancelListener()
    if self.mainFrame and self.mainFrame.rowStateTableClickListener then
        self.mainFrame.rowStateTableClickListener:Hide()
        self.mainFrame.rowStateTableClickListener:SetParent(nil)
        self.mainFrame.rowStateTableClickListener = nil
    end
end

function RowStateSystem:ClearRowRefs()
    rowFrames = {}
    rowButtons = {}
end

return RowStateSystem

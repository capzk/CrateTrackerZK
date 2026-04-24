local SettingsPanelControlFactory = BuildEnv("CrateTrackerZKSettingsPanelFactory")
local SettingsPanelLayout = BuildEnv("CrateTrackerZKSettingsPanelLayout")

local function ShowTooltip(owner, titleText, bodyText)
    if not GameTooltip or not owner then
        return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:SetText(titleText or "", 1, 1, 1, 1, true)
    if type(bodyText) == "string" and bodyText ~= "" then
        GameTooltip:AddLine(bodyText, 1, 1, 1, true)
    end
    GameTooltip:Show()
end

local function HideTooltip()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

function SettingsPanelControlFactory:CreateDivider(parent, anchor, offsetY)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY or -8)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -24, offsetY or -8)
    divider:SetHeight(1)
    divider:SetColorTexture(1, 1, 1, 0.12)
    return divider
end

function SettingsPanelControlFactory:CreatePageFrame(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    page:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    page.topAnchor = CreateFrame("Frame", nil, page)
    page.topAnchor:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    page.topAnchor:SetSize(1, 1)
    page:Hide()
    return page
end

function SettingsPanelControlFactory:AttachTooltip(frame, titleText, bodyText)
    if not frame or type(bodyText) ~= "string" or bodyText == "" then
        return frame
    end

    frame:SetScript("OnEnter", function(self)
        ShowTooltip(self, titleText, bodyText)
    end)
    frame:SetScript("OnLeave", function()
        HideTooltip()
    end)

    return frame
end

function SettingsPanelControlFactory:CreateCheckbox(parent, anchor, labelText, onClick, tooltipText)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)

    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", check, "RIGHT", 4, 1)
    label:SetJustifyH("LEFT")
    label:SetText(labelText or "")
    check.label = label

    local labelWidth = 0
    if label.GetStringWidth then
        labelWidth = math.ceil(label:GetStringWidth() or 0)
    end
    if check.SetHitRectInsets then
        check:SetHitRectInsets(0, -(labelWidth + 12), 0, 0)
    end

    check:SetScript("OnClick", function(self)
        if onClick then
            onClick(self:GetChecked() == true)
        end
    end)

    self:AttachTooltip(check, labelText, tooltipText)

    return check
end

function SettingsPanelControlFactory:CreateActionButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 120, 24)
    button:SetText(text or "")
    button:SetScript("OnClick", function()
        if onClick then
            onClick()
        end
    end)
    return button
end

function SettingsPanelControlFactory:UpdateButtonText(button, text, minWidth)
    if not button then
        return
    end
    button:SetText(text or "")
    local width = minWidth or 120
    if button.GetFontString and button:GetFontString() and button:GetFontString().GetStringWidth then
        width = math.max(width, math.ceil(button:GetFontString():GetStringWidth() + 24))
    end
    button:SetWidth(width)
end

function SettingsPanelControlFactory:CreateInlineButtonRow(parent, anchor, labelText, buttonText, buttonWidth, onClick)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)
    label:SetJustifyH("LEFT")
    label:SetText(labelText or "")

    local button = self:CreateActionButton(parent, buttonText, buttonWidth, onClick)
    button:SetPoint("LEFT", label, "RIGHT", 16, 0)

    return {
        label = label,
        button = button,
    }
end

function SettingsPanelControlFactory:CreateSectionLabel(parent, anchor, text)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -18)
    label:SetJustifyH("LEFT")
    label:SetText(text or "")
    return label
end

function SettingsPanelControlFactory:CreateIntervalRow(parent, anchor, labelText, onApply)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 26, -14)
    label:SetJustifyH("LEFT")
    label:SetText(labelText or "")

    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editBox:SetSize(64, 24)
    editBox:SetPoint("LEFT", label, "RIGHT", 12, 0)
    editBox:SetAutoFocus(false)
    editBox:SetNumeric(true)
    editBox:SetMaxLetters(4)

    editBox:SetScript("OnEnterPressed", function(self)
        if onApply then
            onApply(self)
        end
        self:ClearFocus()
    end)

    editBox:SetScript("OnEditFocusLost", function(self)
        if onApply then
            onApply(self)
        end
    end)

    return label, editBox
end

function SettingsPanelControlFactory:CreateScrollableContent(parent, text)
    if SettingsPanelLayout and SettingsPanelLayout.CreateScrollableText then
        return SettingsPanelLayout:CreateScrollableText(parent, text or "", true)
    end

    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    label:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("TOP")
    label:SetText(text or "")
    return label
end

return SettingsPanelControlFactory

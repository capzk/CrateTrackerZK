-- SettingsPanelLayout.lua - 设置面板布局与控件构建

local SettingsPanelLayout = BuildEnv("CrateTrackerZKSettingsPanelLayout")
local ThemeConfig = BuildEnv("ThemeConfig")

function SettingsPanelLayout:GetTheme()
    return {
        background = ThemeConfig.GetSettingsColor("background"),
        titleBar = ThemeConfig.GetSettingsColor("titleBar"),
        panel = ThemeConfig.GetSettingsColor("panel"),
        navBg = ThemeConfig.GetSettingsColor("navBg"),
        navItem = ThemeConfig.GetSettingsColor("navItem"),
        navItemActive = ThemeConfig.GetSettingsColor("navItemActive"),
        navIndicator = ThemeConfig.GetSettingsColor("navIndicator"),
        button = ThemeConfig.GetSettingsColor("button"),
        buttonHover = ThemeConfig.GetSettingsColor("buttonHover"),
        text = ThemeConfig.GetSettingsColor("text"),
    }
end

function SettingsPanelLayout:CreateNoShadowText(parent, template, text)
    local theme = self:GetTheme()
    local fontString = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    fontString:SetText(text or "")
    fontString:SetTextColor(theme.text[1], theme.text[2], theme.text[3], theme.text[4])
    fontString:SetShadowOffset(0, 0)
    return fontString
end

function SettingsPanelLayout:CreateScrollableText(parent, text, enableWrap)
    local theme = self:GetTheme()
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -28, 0)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(parent:GetWidth() or 520, parent:GetHeight() or 300)
    scroll:SetScrollChild(content)

    local editBox = CreateFrame("EditBox", nil, content)
    editBox:SetPoint("TOPLEFT", content, "TOPLEFT", 6, -6)
    editBox:SetPoint("TOPRIGHT", content, "TOPRIGHT", -6, -6)
    editBox:SetFontObject("GameFontNormal")
    editBox:SetTextColor(theme.text[1], theme.text[2], theme.text[3], theme.text[4])
    editBox:SetShadowOffset(0, 0)
    editBox:SetMultiLine(true)
    if enableWrap then
        if editBox.SetWordWrap then
            editBox:SetWordWrap(true)
        end
        if editBox.SetNonSpaceWrap then
            editBox:SetNonSpaceWrap(true)
        end
    else
        if editBox.SetWordWrap then
            editBox:SetWordWrap(false)
        end
        if editBox.SetNonSpaceWrap then
            editBox:SetNonSpaceWrap(false)
        end
    end
    editBox:SetAutoFocus(false)
    editBox:EnableMouse(true)
    editBox:SetScript("OnEscapePressed", function() editBox:ClearFocus() end)
    editBox:SetScript("OnEditFocusLost", function() editBox:HighlightText(0, 0) end)
    editBox:SetScript("OnTextChanged", function(self)
        if self.ignoreTextChanged then return end
        self.ignoreTextChanged = true
        self:SetText(self.originalText or "")
        self.ignoreTextChanged = false
    end)

    editBox.originalText = text or ""
    editBox.ignoreTextChanged = true
    editBox:SetText(text or "")
    editBox.ignoreTextChanged = false

    local function UpdateLayout()
        local viewW = scroll:GetWidth()
        if viewW and viewW > 0 then
            content:SetWidth(viewW)
            editBox:SetWidth(viewW - 12)
        end
        local h = (editBox.GetStringHeight and editBox:GetStringHeight() or editBox:GetHeight()) + 20
        local viewH = scroll:GetHeight()
        local child = scroll:GetScrollChild()
        if child then child:SetHeight(math.max(h, viewH)) end
        local sb = scroll.ScrollBar
        if sb then
            if h > viewH + 1 then sb:Show() else sb:Hide() scroll:SetVerticalScroll(0) end
        end
    end

    scroll:SetScript("OnSizeChanged", UpdateLayout)
    C_Timer.After(0.05, UpdateLayout)

    return editBox
end

function SettingsPanelLayout:CreateSettingButton(parent, text)
    local theme = self:GetTheme()
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(90, 22)

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(button)
    bg:SetColorTexture(theme.button[1], theme.button[2], theme.button[3], theme.button[4])
    button.bg = bg

    local label = self:CreateNoShadowText(button, "GameFontNormal", text or "")
    label:SetPoint("CENTER", button, "CENTER", 0, 0)

    button:SetScript("OnEnter", function()
        bg:SetColorTexture(theme.buttonHover[1], theme.buttonHover[2], theme.buttonHover[3], theme.buttonHover[4])
    end)
    button:SetScript("OnLeave", function()
        bg:SetColorTexture(theme.button[1], theme.button[2], theme.button[3], theme.button[4])
    end)

    return button, label
end

return SettingsPanelLayout

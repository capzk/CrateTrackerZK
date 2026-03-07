-- TableUIActions.lua - 表格操作按钮职责拆分

local TableUI = BuildEnv("TableUI");
local UIConfig = BuildEnv("ThemeConfig");
local CrateTrackerZK = BuildEnv("CrateTrackerZK");
local MainPanel = BuildEnv("MainPanel");
local L = CrateTrackerZK.L;

local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue;
    end
    if value > maxValue then
        return maxValue;
    end
    return value;
end

local function IsAddonEnabled()
    if not CRATETRACKERZK_UI_DB or CRATETRACKERZK_UI_DB.addonEnabled == nil then
        return true;
    end
    return CRATETRACKERZK_UI_DB.addonEnabled == true;
end

local function GetConfig()
    return UIConfig;
end

function TableUI:CreateActionButtons(rowFrame, rowInfo, colWidths, rowBg, scale)
    local rowId = rowInfo.rowId;
    local operationColumnStart = colWidths[1] + colWidths[2] + colWidths[3] + colWidths[4];
    local columnCenter = operationColumnStart + colWidths[5] / 2;
    rowFrame.operationColumnCenter = columnCenter;
    local notifyText = L["Notify"] or "通知";

    local notifyBtn = rowFrame.notifyBtn;
    if not notifyBtn then
        notifyBtn = self:CreateActionButton(rowFrame, rowBg, notifyText, columnCenter, nil, rowInfo.isHidden, scale);
        rowFrame.notifyBtn = notifyBtn;
    end

    if notifyBtn:GetParent() ~= rowFrame then
        notifyBtn:SetParent(rowFrame);
    end

    notifyBtn:ClearAllPoints();
    notifyBtn:SetPoint("CENTER", rowBg, "LEFT", columnCenter, 0);
    notifyBtn:Show();

    local cfg = GetConfig();
    local normalColor = cfg.GetTextColor("normal");
    local normalTextColor = rowInfo.isHidden and {0.5, 0.5, 0.5, 0.8} or normalColor;

    notifyBtn.__ctkRowId = rowId;
    notifyBtn.__ctkIsHidden = rowInfo.isHidden == true;
    notifyBtn.__ctkNormalTextColor = normalTextColor;

    local height = Clamp(math.floor(20 * (scale or 1) + 0.5), 18, 24);
    local minWidth = math.floor(30 * (scale or 1) + 0.5);
    local padding = math.floor(10 * (scale or 1) + 0.5);

    if notifyBtn.label then
        notifyBtn.label:SetText(notifyText);
        if notifyBtn.label.GetFont and notifyBtn.label.SetFont and notifyBtn.label.GetObjectType then
            -- 与原实现一致：沿用 TableUI 中的缩放工具字段
            if notifyBtn.label.__ctkBaseFont then
                local base = notifyBtn.label.__ctkBaseFont;
                local scaled = math.floor(base.size * (scale or 1) + 0.5);
                if scaled < 8 then
                    scaled = 8;
                elseif scaled > 18 then
                    scaled = 18;
                end
                notifyBtn.label:SetFont(base.font, scaled, base.flags);
            end
        end
        local textWidth = notifyBtn.label:GetStringWidth() or 0;
        notifyBtn:SetSize(math.max(minWidth, textWidth + padding), height);
        notifyBtn.label:SetTextColor(normalTextColor[1], normalTextColor[2], normalTextColor[3], normalTextColor[4]);
    else
        notifyBtn:SetSize(minWidth, height);
    end

    return notifyBtn;
end

function TableUI:CreateActionButton(parent, parentBg, text, x, clickHandler, isHidden, scale)
    local cfg = GetConfig();
    local btn = CreateFrame("Button", nil, parent);
    local height = Clamp(math.floor(20 * (scale or 1) + 0.5), 18, 24);
    btn:SetSize(30, height);
    btn:SetPoint("CENTER", parentBg, "LEFT", x, 0);
    btn:SetFrameLevel(parent:GetFrameLevel() + 1);

    local normalColor = cfg.GetTextColor("normal");
    local hoverTextColor = {1, 0.6, 0.1, 1};

    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal");
    btnText:SetPoint("CENTER", btn, "CENTER", 0, 0);
    btnText:SetText(text);
    btnText:SetJustifyH("CENTER");
    btnText:SetJustifyV("MIDDLE");
    btnText:SetShadowOffset(0, 0);
    if btnText.GetFont and btnText.SetFont then
        local font, size, flags = btnText:GetFont();
        if not font then
            local defaultFont, defaultSize, defaultFlags = GameFontNormal:GetFont();
            font, size, flags = defaultFont, defaultSize, defaultFlags;
        end
        btnText.__ctkBaseFont = {
            font = font,
            size = size or 12,
            flags = flags,
        };
        local scaled = math.floor((size or 12) * (scale or 1) + 0.5);
        if scaled < 8 then
            scaled = 8;
        elseif scaled > 18 then
            scaled = 18;
        end
        btnText:SetFont(font, scaled, flags);
    end
    btn.label = btnText;

    local textWidth = btnText:GetStringWidth() or 0;
    local minWidth = math.floor(30 * (scale or 1) + 0.5);
    local padding = math.floor(10 * (scale or 1) + 0.5);
    local targetWidth = math.max(minWidth, textWidth + padding);
    btn:SetSize(targetWidth, height);

    local normalTextColor = isHidden and {0.5, 0.5, 0.5, 0.8} or normalColor;
    btn.__ctkIsHidden = isHidden == true;
    btn.__ctkNormalTextColor = normalTextColor;
    btn.__ctkRowId = nil;
    btn.__ctkClickHandler = clickHandler;
    btnText:SetTextColor(normalTextColor[1], normalTextColor[2], normalTextColor[3], normalTextColor[4]);

    btn:SetScript("OnClick", function(self)
        if not IsAddonEnabled() then
            return;
        end
        if self.__ctkIsHidden then
            return;
        end
        if self.__ctkClickHandler then
            self.__ctkClickHandler();
            return;
        end
        if self.__ctkRowId and MainPanel and MainPanel.NotifyMapById then
            MainPanel:NotifyMapById(self.__ctkRowId);
        end
    end);

    btn:SetScript("OnEnter", function(self)
        if self.__ctkIsHidden then return end;
        btnText:SetTextColor(hoverTextColor[1], hoverTextColor[2], hoverTextColor[3], hoverTextColor[4]);
    end);
    btn:SetScript("OnLeave", function(self)
        local color = self.__ctkNormalTextColor or normalTextColor;
        btnText:SetTextColor(color[1], color[2], color[3], color[4]);
    end);

    return btn;
end

return TableUI;

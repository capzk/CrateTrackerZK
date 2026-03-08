-- MainFrameTheme.lua - MainFrame 主题与容器职责拆分

local MainFrame = BuildEnv("MainFrame");
local UIConfig = BuildEnv("ThemeConfig");

local FIXED_TITLE_HEIGHT = 22;
local FIXED_CONTENT_EDGE_GAP = 12;

function MainFrame:ApplyThemeColors(frame)
    if not frame then
        return;
    end

    local mainBgColor = UIConfig.GetColor("mainFrameBackground");
    if frame.mainBg then
        frame.mainBg:SetColorTexture(mainBgColor[1], mainBgColor[2], mainBgColor[3], mainBgColor[4]);
    end

    local titleBarColor = UIConfig.GetColor("titleBarBackground");
    if frame.titleBg then
        frame.titleBg:SetColorTexture(titleBarColor[1], titleBarColor[2], titleBarColor[3], titleBarColor[4]);
    end

    local titleColor = UIConfig.GetTextColor("normal");
    if frame.titleText then
        frame.titleText:SetTextColor(titleColor[1], titleColor[2], titleColor[3], titleColor[4]);
    end

    local buttonColor = UIConfig.GetColor("titleBarButton");
    if frame.settingsButtonBg then
        frame.settingsButtonBg:SetColorTexture(buttonColor[1], buttonColor[2], buttonColor[3], buttonColor[4]);
    end
    if frame.closeButtonBg then
        frame.closeButtonBg:SetColorTexture(buttonColor[1], buttonColor[2], buttonColor[3], buttonColor[4]);
    end

    local normalTextColor = UIConfig.GetTextColor("normal");
    if frame.settingsDot1 then
        frame.settingsDot1:SetColorTexture(normalTextColor[1], normalTextColor[2], normalTextColor[3], normalTextColor[4]);
    end
    if frame.settingsDot2 then
        frame.settingsDot2:SetColorTexture(normalTextColor[1], normalTextColor[2], normalTextColor[3], normalTextColor[4]);
    end
    if frame.settingsDot3 then
        frame.settingsDot3:SetColorTexture(normalTextColor[1], normalTextColor[2], normalTextColor[3], normalTextColor[4]);
    end
    if frame.closeLine then
        frame.closeLine:SetColorTexture(normalTextColor[1], normalTextColor[2], normalTextColor[3], normalTextColor[4]);
    end
end

function MainFrame:CreateTableContainer(frame)
    local tableContainer = CreateFrame("Frame", nil, frame);
    tableContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", FIXED_CONTENT_EDGE_GAP, -(FIXED_TITLE_HEIGHT + FIXED_CONTENT_EDGE_GAP));
    tableContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -FIXED_CONTENT_EDGE_GAP, FIXED_CONTENT_EDGE_GAP);
    tableContainer:SetFrameLevel(frame:GetFrameLevel() + 5);
    if tableContainer.SetClipsChildren then
        tableContainer:SetClipsChildren(true);
    end
    frame.tableContainer = tableContainer;
end

return MainFrame;

-- CrateTrackerZK - Korean Localization
-- Translator: 007bb
local LocaleManager = BuildEnv("LocaleManager");
if not LocaleManager or not LocaleManager.RegisterLocale then
    if LocaleManager then
        LocaleManager.failedLocales = LocaleManager.failedLocales or {};
        table.insert(LocaleManager.failedLocales, {
            locale = "koKR",
            reason = "RegisterLocale function not available"
        });
    end
    return;
end

local localeData = {};

-- General

-- Floating Button
localeData["FloatingButtonTooltipLine3"] = "우클릭으로 설정 열기";

localeData["MiniModeTooltipLine1"] = "우클릭으로 알리기";

-- Notifications (Airdrop)
localeData["Enabled"] = "그룹 알림 활성화";
localeData["Disabled"] = "그룹 알림 비활성화";
localeData["AirdropDetected"] = "[%s] 전쟁 보급품 공중 투하 감지!!!";  -- Auto detection message (with "Detected" keyword)
localeData["AirdropDetectedManual"] = "[%s] 전쟁 보급품 공중 투하!!!";  -- Manual notification message (without "Detected" keyword)
localeData["NoTimeRecord"] = "[%s] 기록된 시간 없음!!!";
localeData["TimeRemaining"] = "[%s] 전쟁 보급품 공중 투하: %s!!!";
localeData["AutoTeamReportMessage"] = "현재 [%s] 전쟁 보급품 보유량: %s!!";

-- Phase Detection Alerts
localeData["PhaseDetectedFirstTime"] = "[%s] 현재 위상 ID: |cffffff00%s|r";
localeData["InstanceChangedTo"] = "[%s] 현재 위상 ID 변경됨: |cffffff00%s|r";

-- UI
localeData["MapName"] = "지역 이름";
localeData["PhaseID"] = "현재 위상";
localeData["LastRefresh"] = "마지막 갱신";
localeData["NextRefresh"] = "다음 갱신";
localeData["Operation"] = "작동";
localeData["Notify"] = "경보";
localeData["Delete"] = "삭제";
localeData["Restore"] = "복구";
localeData["NotAcquired"] = "---:---";
localeData["NoRecord"] = "--:--";
localeData["MinuteSecond"] = "%d분 %02d초";
-- Menu Items
localeData["MenuHelp"] = "도움말";
localeData["MenuAbout"] = "소개";

-- Settings Panel
localeData["SettingsPanelTitle"] = "CrateTrackerZK - 설정";
localeData["SettingsTabSettings"] = "설정";
localeData["SettingsSectionControl"] = "애드온 제어";
localeData["SettingsSectionData"] = "데이터 관리";
localeData["SettingsSectionUI"] = "UI 설정";
localeData["SettingsMiniModeCollapsedRows"] = "축소한 후 유지되는 행 수";
localeData["SettingsAddonToggle"] = "애드온 전환";
localeData["SettingsTeamNotify"] = "그룹 알림";
localeData["SettingsAutoReport"] = "자동 알림";
localeData["SettingsAutoReportInterval"] = "알림 간격 (초)";
localeData["SettingsClearAllData"] = "모든 데이터 삭제";
localeData["SettingsClearButton"] = "삭제";
localeData["SettingsClearDesc"] = "• 모든 보급품 시간 및 위상 기록 삭제";
localeData["SettingsUIConfigDesc"] = "• UI 스타일은 UiConfig.lua에서 조정할 수 있습니다.";
localeData["SettingsReloadDesc"] = "• 변경 후 /reload 실행";
localeData["SettingsToggleOn"] = "활성화";
localeData["SettingsToggleOff"] = "비활성화";
localeData["SettingsClearConfirmText"] = "모든 데이터를 삭제하고 초기화하시겠습니까? 이 작업은 되돌릴 수 없습니다.";
localeData["SettingsClearConfirmYes"] = "확인";
localeData["SettingsClearConfirmNo"] = "취소";

-- Airdrop NPC shouts (optional for shout detection and efficiency; can be omitted or left as default)
localeData.AirdropShouts = {
    "Ruffious says: Opportunity's knocking! If you've got the mettle, there are valuables waiting to be won.",
    "Ruffious says: I see some valuable resources in the area! Get ready to grab them!",
    "Ruffious says: There's a cache of resources nearby. Find it before you have to fight over it!",
    "Ruffious says: Looks like there's treasure nearby. And that means treasure hunters. Watch your back.",
};

-- Register this locale
LocaleManager.RegisterLocale("koKR", localeData);

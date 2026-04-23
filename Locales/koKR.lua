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

-- Floating Button
localeData["FloatingButtonTooltipLine3"] = "우클릭으로 설정 열기";

-- Notifications (Airdrop)
localeData["Enabled"] = "그룹 알림 활성화";
localeData["Disabled"] = "그룹 알림 비활성화";
localeData["AirdropDetected"] = "[%s]전쟁 보급품 공중 투하 감지!!!";  -- Unified airdrop message
localeData["NoTimeRecord"] = "[%s]기록된 시간 없음!!!";
localeData["TimeRemaining"] = "[%s]전쟁 보급품 공중 투하: %s!!!";
localeData["AutoTeamReportMessage"] = "현재[%s]전쟁 보급품 보유량: %s!!";
localeData["SharedPhaseSyncApplied"] = "[%s] 현재 위상의 최신 공중 보급 공유 정보를 가져왔습니다.";
localeData["PhaseTeamAlertMessage"] = "%s 현재 위상 변경: %s ➡ %s";
localeData["TrajectoryPredictionMatched"] = "[%s] 공중 보급 경로를 일치시켰습니다. 예상 낙하지점 좌표: %d, %d";
localeData["TrajectoryPredictionWaypointSet"] = "[%s] 예상 낙하지점을 내 지도에 표시했습니다: %d, %d";
localeData["UnknownPhaseValue"] = "알 수 없음";

-- Phase Detection Alerts
localeData["PhaseDetectedFirstTime"] = "[%s] 현재 위상 ID: |cffffff00%s|r";
localeData["InstanceChangedTo"] = "[%s] 현재 위상 ID 변경됨: |cffffff00%s|r";

-- UI
localeData["MapName"] = "지역 이름";
localeData["PhaseID"] = "현재 위상";
localeData["LastRefresh"] = "마지막 갱신";
localeData["NextRefresh"] = "다음 갱신";
localeData["NotAcquired"] = "---:---";
localeData["NoRecord"] = "--:--";
localeData["MinuteSecond"] = "%d분 %02d초";
-- Menu Items
localeData["MenuHelp"] = "도움말";
localeData["MenuAbout"] = "소개";

-- Settings Panel
localeData["SettingsSectionExpansion"] = "버전 설정";
localeData["SettingsSectionControl"] = "애드온 제어";
localeData["SettingsSectionData"] = "데이터 관리";
localeData["SettingsSectionUI"] = "UI 설정";
localeData["SettingsMainPage"] = "기본 설정";
localeData["SettingsMessages"] = "메시지 설정";
localeData["SettingsMapSelection"] = "지도 선택";
localeData["SettingsThemeSwitch"] = "테마";
localeData["SettingsAddonToggle"] = "애드온 전환";
localeData["SettingsLeaderMode"] = "공대장 모드";
localeData["SettingsLeaderModeTooltip"] = "활성화하면 공격대의 표시형 공중 보급 알림과 자동 방송이 우선 공격대 경보로 전송되며, 권한이 없으면 일반 공격대 채팅으로 자동 전환됩니다.";
localeData["SettingsTeamNotify"] = "그룹 알림";
localeData["SettingsPhaseTeamAlert"] = "위상 변경 팀 알림";
localeData["SettingsPhaseTeamAlertTooltip"] = "활성화하면 위상 변경 메시지가 파티 또는 공격대 채팅으로 전송됩니다.";
localeData["SettingsSoundAlert"] = "사운드 리마인더";
localeData["SettingsAutoReport"] = "자동 알림";
localeData["SettingsAutoReportInterval"] = "알림 간격 (초)";
localeData["SettingsTrajectoryPredictionTest"] = "궤적 예측 (테스트 기능)";
localeData["SettingsClearButton"] = "로컬 데이터 삭제";
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

localeData["SettingsHelpText"] = [[
사용 안내

1. 메인 UI의 카운트다운은 마우스 클릭으로 메시지를 보낼 수 있습니다:
   왼쪽 클릭: "[지도] War Supplies airdrop in: 시간" 메시지 전송
   오른쪽 클릭: "Current [지도] War Supplies airdrop in: 시간" 메시지 전송

2. 메시지 설정 페이지 옵션 설명:
   메시지 설정: 수동 및 자동 메시지 전송 동작을 제어합니다
   공대장 모드: 활성화하면 공격대의 표시형 공중 보급 알림과 자동 방송이 우선 공격대 경보로 전송되며, 권한이 없으면 일반 공격대 채팅으로 전환됩니다
   그룹 알림: 활성화하면 메시지가 파티 또는 공격대 채팅으로 전송됩니다
   사운드 알림: 활성화하면 공중 보급이 감지될 때 소리가 재생됩니다
   자동 알림: 활성화하면 설정한 간격으로 가장 가까운 공중 보급 카운트다운을 자동 전송합니다
   알림 간격 (초): 자동 메시지 전송 간격을 설정합니다
]];

-- Register this locale
LocaleManager.RegisterLocale("koKR", localeData);

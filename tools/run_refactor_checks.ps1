param(
    [string]$Root = "."
)

$ErrorActionPreference = "Stop"

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Get-FileText {
    param([string]$Path)
    return (Get-Content -Path $Path -Raw)
}

$rootPath = (Resolve-Path $Root).Path
Write-Output "CHECK_ROOT=$rootPath"

# 1) 语法检查
$luaFiles = Get-ChildItem -Path $rootPath -Recurse -File -Filter *.lua
foreach ($f in $luaFiles) {
    & luac -p $f.FullName
}
Write-Output "LUA_SYNTAX=PASS"

# 2) 关键阈值不变量
$timerText = Get-FileText (Join-Path $rootPath "Modules/Timer.lua")
Assert-True ($timerText -match "CONFIRM_TIME\s*=\s*2") "Timer CONFIRM_TIME changed"
Assert-True ($timerText -match "MIN_STABLE_TIME\s*=\s*5") "Timer MIN_STABLE_TIME changed"

$notificationText = Get-FileText (Join-Path $rootPath "Modules/Notification.lua")
Assert-True ($notificationText -match "SHOUT_DEDUP_WINDOW\s*=\s*20") "Notification SHOUT_DEDUP_WINDOW changed"

$udmText = Get-FileText (Join-Path $rootPath "Modules/UnifiedDataManager.lua")
Assert-True ($udmText -match "TEMPORARY_TIME_ADOPTION_WINDOW\s*=\s*120") "UDM TEMPORARY_TIME_ADOPTION_WINDOW changed"
Write-Output "KEY_CONSTANTS=PASS"

# 3) 关键架构不变量（事件入口已收口到 EventRouter）
$eventRouterText = Get-FileText (Join-Path $rootPath "Core/EventRouter.lua")
Assert-True ($eventRouterText -match 'function EventRouter:RegisterEventFrame\(\)') "EventRouter RegisterEventFrame missing"
Assert-True ($eventRouterText -match 'eventFrame:RegisterEvent\("PLAYER_LOGIN"\)') "EventRouter PLAYER_LOGIN event missing"
Assert-True ($eventRouterText -match 'eventFrame:RegisterEvent\("CHAT_MSG_MONSTER_PARTY"\)') "EventRouter CHAT_MSG_MONSTER_PARTY event missing"
Assert-True ($eventRouterText -match 'eventFrame:SetScript\("OnEvent"') "EventRouter OnEvent binding missing"
Write-Output "CORE_EVENT_HUB=PASS"

# 4) 遗留分支清理检查（Commands 不再依赖旧聊天事件帧）
$commandsText = Get-FileText (Join-Path $rootPath "Modules/Commands.lua")
Assert-True (-not ($commandsText -match "TeamCommListener\.chatFrame")) "Legacy TeamCommListener.chatFrame branch still exists"
Assert-True (-not ($commandsText -match "ShoutDetector\.eventFrame")) "Legacy ShoutDetector.eventFrame branch still exists"
Write-Output "LEGACY_BRANCH_CLEANUP=PASS"

Write-Output "ALL_STATIC_CHECKS_OK"

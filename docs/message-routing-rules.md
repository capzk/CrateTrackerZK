# Message Routing Rules

This file records the current routing rules for player-visible messages.

## Business Messages

| Message type | Send local when | Send team when | Stay silent when | Main entry |
| --- | --- | --- | --- | --- |
| Airdrop auto detection | Not in party/raid, or `teamNotificationEnabled` is off, or no valid visible team channel | `teamNotificationEnabled` is on and a valid party/raid/instance channel is available | Dedup window blocks it, player already sent it, or sync/shout suppression blocks it | `NotificationDispatchService:NotifyAirdropDetected` |
| Local phase detection prompt | Always local when a new phase is detected or a phase change is observed | Never | No tracked map, no detected/cached phase, or hidden-map gating stops phase detection | `Phase:UpdatePhaseInfo` via `Logger:Info` |
| Trajectory prediction matched | Team routing is not available for trajectory alerts | `teamNotificationEnabled` is on, trajectory prediction is on, trajectory team alert is on, and team shared channel is available | Prediction is disabled, duplicate candidate state blocks it, or local/team paths both fail | `AirdropTrajectoryService:NotifyPrediction` |
| Trajectory prediction candidates | Team routing is not available for trajectory alerts | `teamNotificationEnabled` is on, trajectory prediction is on, trajectory team alert is on, and team shared channel is available | Prediction is disabled, candidate already announced, or coordination rejects it | `AirdropTrajectoryService:NotifyPredictionCandidates` |
| Shared phase sync applied | No eligible phase-followup team route is available | `teamNotificationEnabled` is on, `phaseTeamAlertEnabled` is on, and a valid visible team channel is available | The same shared record was already notified inside the coordinated phase flow | `NotificationTeamMessageService:NotifySharedPhaseSyncApplied` |
| Phase change team alert | Never | `teamNotificationEnabled` is on, `phaseTeamAlertEnabled` is on, hidden sync is available, and the local sender wins coordination | Coordination rank loses, sender limit is reached, or baseline phase is invalid | `PhaseTeamAlertCoordinator:EvaluateVisibleSend` |
| Phase follow-up: shared sync applied | Never | Same as phase change alert, after phase alert has already been sent | Phase flow not active or shared record unavailable | `NotificationTeamMessageService:SendSharedPhaseSyncAppliedTeamMessage` |
| Phase follow-up: time remaining | Never | Same as phase change alert, after shared sync follow-up succeeds | Remaining time unavailable or phase flow not active | `NotificationTeamMessageService:SendTimeRemainingTeamMessage` |
| Auto team report ticker | Never | `autoTeamReportEnabled` is on, `teamNotificationEnabled` is on, and a valid visible team channel is available | Not in tracked area, no nearest map found, or no channel available | `NotificationDispatchService:SendAutoTeamReport` |
| Manual row notify / manual remaining query | Not in party/raid, or `teamNotificationEnabled` is off, or no valid visible team channel | `teamNotificationEnabled` is on and a valid visible team channel is available | Input map is invalid | `NotificationDispatchService:NotifyMapRefresh` |

## Local-Only Messages

| Message type | Rule | Main entry |
| --- | --- | --- |
| Slash command output | Always local only | `Commands.lua` |
| Trajectory trace/debug output | Always local only; gated by trace debug setting where applicable | `AirdropTrajectorySamplingService.lua` |
| Logger fallback messages | Local log only; never promoted to team chat | `NotificationOutputService.lua` |

## Current Intent

1. Gameplay notifications should prefer team-visible output when the relevant feature toggle is enabled and a valid team route exists.
2. The same gameplay notification should not also emit a duplicate local visible message when the team-visible message has already been chosen.
3. Debug and slash-command output should remain local only.

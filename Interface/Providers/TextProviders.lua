-- TextProviders.lua - 帮助/关于文案提供者

local HelpTextProvider = BuildEnv("HelpTextProvider")
local AboutTextProvider = BuildEnv("AboutTextProvider")

function HelpTextProvider:GetHelpText()
    return [[

插件更新地址：
https://www.curseforge.com/wow/addons/cratetrackerzk

-插件UI的颜色和透明度现在可以通过编辑\CrateTrackerZK\UiConfig.lua 来设置
-修改后需要执行 /reload 生效，后续更新会把此功能增加到设置页面，敬请期待！

== 基本功能 ==
- 自动检测记录空投刷新时间
- 团队成员自动共享空投刷新时间，提高蹲守效率
- 实时显示位面ID信息
- 空投时间排序功能
- 团队通知
- 数据持久化存储

== 可用命令 ==
/ctk clear              清除所有数据并重新初始化插件
/ctk team off           关闭团队通知
/ctk team on            开启团队通知

== 界面操作 ==
- 右键点击地图行可以隐藏/恢复地图
- 点击"刷新"按钮手动设置空投刷新时间
- 点击"通知"按钮发送团队通知

== 位面检测 ==
插件会自动检测当前位面ID，并与历史位面数据进行比对：
- 绿色：位面ID匹配，时间可靠
- 红色：位面ID不匹配，时间可能会不准
- 白色：未获取到当前位面信息

== 数据管理 ==
- 所有数据自动保存到角色配置文件
- 数据在账号内共享（不同角色共享）
- 可通过重置命令清空所有数据

== 团队功能 ==
- 团队通知：向团队成员发送空投提醒
- 团队时间共享：自动共享团队成员的刷新时间（默认开启）
- 需要团队成员都开启团队通知能才能生效

== 问题反馈 ==
如遇到问题，请访问：
https://github.com/capzk/CrateTrackerZK/issues


======================================================


Addon update URL:
https://www.curseforge.com/wow/addons/cratetrackerzk

- UI colors and opacity can now be adjusted by editing \CrateTrackerZK\UiConfig.lua
- After changes, run /reload to apply. UI settings will be added to the Settings page in a future update.

== Core Features ==
- Automatically detect and record airdrop refresh times
- Automatically share airdrop refresh times within the team to improve camping efficiency
- Show phase ID in real time
- Sort airdrop times
- Team notifications
- Persistent data storage

== Commands ==
/ctk clear               Clear all data and reinitialize the addon
/ctk team off            Disable team notifications
/ctk team on             Enable team notifications

== UI Operations ==
- Right-click a map row to hide/restore the map
- Right-click to remove and restore maps
- Click "Refresh" to manually set the airdrop refresh time
- Click "Notify" to send a team notification

== Phase Detection ==
The addon automatically detects the current phase ID and compares it with historical data:
- Green: phase ID matches, time is reliable
- Red: phase ID mismatch, time may be inaccurate
- White: current phase info not available

== Data Management ==
- All data is saved automatically to the character profile
- Data is shared across the account (shared by different characters)
- Use the reset command to clear all data

== Team Features ==
- Team notification: send airdrop alerts to team members
- Team time sharing: automatically share team members' refresh times (enabled by default)
- Requires team members to enable team notifications for it to take effect

== Feedback ==
If you encounter any issue, please visit:
https://github.com/capzk/CrateTrackerZK/issues]]
end

function AboutTextProvider:GetAboutText()
    return [[CrateTrackerZK

Version: v1.2.1

Maintainer:
capzk

Source Code:
https://github.com/capzk/CrateTrackerZK

]]
end

return {
    HelpTextProvider = HelpTextProvider,
    AboutTextProvider = AboutTextProvider,
}

-- Help.lua - 帮助页面内容配置

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local Help = BuildEnv("Help");

-- 帮助页面内容配置
function Help:GetHelpText()
    return [[CrateTrackerZK 使用帮助

==如果更新后遇到异常，请把此插件目录完全删除后全新安装==
==空投开始后会进行5秒确认，防止误报==
==团队通知默认做了限制，空投开始后的短时间内才会自动发送空投通知，超过时间不会再发送团队消息==
== 基本功能 ==

- 自动检测空投箱子刷新时间
- 实时显示位面ID信息
- 支持团队通知功能
- 数据持久化存储

== 可用命令 ==

/ctk help                显示帮助信息
/ctk clear               清除所有数据并重新初始化插件
/ctk team on | off         开启/关闭团队通知


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
- 支持多角色独立数据存储
- 可通过重置命令清空所有数据

== 团队功能 ==

- 团队通知：向团队成员发送空投提醒
- 团队时间共享：自动共享团队成员的刷新时间（默认开启）
- 需要团队成员都开启团队通知能才能生效

== 问题反馈 ==

如遇到问题，请访问：
https://github.com/capzk/CrateTrackerZK/issues

--------------------

CrateTrackerZK Help

==If you encounter issues after updating, please delete this addon folder completely and reinstall==
==Team notifications are limited: they only auto-send for a short time after the drop starts==
== Core Features ==

- Automatically detect airdrop refresh times
- Show phase ID in real time
- Support team notifications
- Persist data

== Commands ==

/ctk help                Show help
/ctk clear               Clear all data and reinitialize the addon
/ctk team on | off         Enable/disable team notification


== UI Operations ==

- Right-click a map row to hide/restore the map
- Click "Refresh" to manually set the airdrop refresh time
- Click "Notify" to send a team notification

== Phase Detection ==

The addon automatically detects the current phase ID and compares it with historical data:
- Green: phase ID matches, time is reliable
- Red: phase ID mismatch, time may be inaccurate
- White: phase info not available

== Data Management ==

- All data is automatically saved to the character profile
- Separate data per character
- Use the reset command to clear all data

== Team Features ==

- Team notification: send airdrop alerts to team members
- Team time sharing: automatically share team members' refresh times (enabled by default)
- Requires team members to enable team notification for sharing to work

== Feedback ==

If you encounter any issue, please visit:
https://github.com/capzk/CrateTrackerZK/issues]];
end

return Help;

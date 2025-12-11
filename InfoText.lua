-- 空投物资追踪器 - 信息文本模块
-- 此文件包含公告和插件简介的文本内容，方便修改

-- 确保BuildEnv函数存在
if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

-- 定义InfoText命名空间
local InfoText = BuildEnv('InfoText');

-- 公告文本
InfoText.Announcement = [[空投物资追踪器 v1.0.6

最新公告：

capzk@itcat.dev

插件更新：https://addons.itcat.dev/

如有问题或建议，欢迎反馈！]];

-- 插件简介文本
InfoText.Introduction = [[空投物资追踪器 v1.0.6

自动检测当前地图空投物资刷新情况，同时支持手动设置刷新时间。
自动保存数据，关闭插件时数据不会丢失。
退出游戏数据不丢失。
• /ct help - 显示帮助信息
• /ct clear - 清除所有时间和位面数据
• /ct team on|off - 开启/关闭团队通知
• /ct team status - 查看团队通知状态

作者：capzk

感谢使用！]];

return InfoText;


-- About.lua - 关于页面内容配置

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local About = BuildEnv("About");

-- 获取关于页面文本
function About:GetAboutText()
    return [[CrateTrackerZK

Version: v1.1.8
Build: 2026-01-22

Maintainer:
capzk

Source Code:
https://github.com/capzk/CrateTrackerZK

]];
end

return About;

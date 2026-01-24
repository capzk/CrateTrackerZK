-- AboutTextProvider.lua - 关于文案提供者

local AboutTextProvider = BuildEnv("AboutTextProvider")

function AboutTextProvider:GetAboutText()
    return [[CrateTrackerZK

Version: v1.1.8
Build: 2026-01-22

Maintainer:
capzk

Source Code:
https://github.com/capzk/CrateTrackerZK

]]
end

return AboutTextProvider

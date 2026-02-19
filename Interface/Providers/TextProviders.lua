-- TextProviders.lua - 帮助/关于文案提供者

local HelpTextProvider = BuildEnv("HelpTextProvider")
local AboutTextProvider = BuildEnv("AboutTextProvider")

function HelpTextProvider:GetHelpText()
    return [[

插件更新地址：
https://www.curseforge.com/wow/addons/cratetrackerzk

-插件UI的颜色和透明度暂时可以通过编辑\CrateTrackerZK\UiConfig.lua来设置；

== 问题反馈 ==
如遇到问题，可在此留言反馈：
https://www.curseforge.com/wow/addons/cratetrackerzk/comments


Addon update URL:
https://www.curseforge.com/wow/addons/cratetrackerzk

- UI color and opacity can be configured for now by editing \CrateTrackerZK\UiConfig.lua


== Feedback ==
If you encounter any issue, please leave feedback here:
https://www.curseforge.com/wow/addons/cratetrackerzk/comments]]
end

function AboutTextProvider:GetAboutText()
    return [[

Maintainer:
capzk

Source Code:
https://github.com/capzk/CrateTrackerZK

Addon Release Page:
https://www.curseforge.com/wow/addons/cratetrackerzk

]]
end

return {
    HelpTextProvider = HelpTextProvider,
    AboutTextProvider = AboutTextProvider,
}

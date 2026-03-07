-- Utils.lua - 占位模块（手动时间输入功能已移除，保留命名空间以兼容旧引用）

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local Utils = BuildEnv('Utils')

return Utils;

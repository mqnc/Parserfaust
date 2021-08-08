local T = require "typekey"

local DispatcherMeta = {
    __call = function(self, arg, ...)
        if type(arg) ~= "table" then
            local argType
            return self[T .. type(arg)](arg, ...)
        else
            return self[arg[T]](arg, ...)
        end
    end
}

return function()
    local Dispatcher = {}
    setmetatable(Dispatcher, DispatcherMeta)
    return Dispatcher
end

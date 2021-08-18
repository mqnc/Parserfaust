local mt = {}

mt.__index = mt
local IS_TAG = {}
mt[IS_TAG] = true

function mt:derive(label)

    local derived = {
        parent = self
    }
    if self ~= nil then
        derived.label = self.label .. "." .. label
    else
        derived.label = label
    end

    setmetatable(derived, mt)
    return derived
end

function mt:includes(other)
    if type(other) ~= "table" or not other[IS_TAG] then
        return false
    end
    local gen = other
    repeat
        if gen == self then
            return true
        end
        gen = gen.parent
    until gen == nil
    return false
end

local tag = mt.derive(nil, "__root", nil)
tag.create = mt.derive

return tag

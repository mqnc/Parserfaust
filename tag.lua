local mt = {}

mt.__index = mt
local IS_TAG = {}
mt[IS_TAG] = true

function mt:derive(label, newMembers)

    local derived = {
        parent = self
    }
    if self ~= nil then
        derived.label = self.label .. "." .. label
    else
        derived.label = label
    end
    derived.members = {}

    if self ~= nil and self.members ~= nil then
        for _, m in ipairs(self.members) do
            table.insert(derived.members, m)
            derived.members[m] = true
        end
    end

    if newMembers then
        for _, m in ipairs(newMembers) do
            table.insert(derived.members, m)
            derived.members[m] = true
        end
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

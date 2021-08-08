local mt = {}

mt.__index = mt
local IS_TAG = {}
mt[IS_TAG] = true

function mt:derive(name, additionalMembers)

    local derived = {
        parent = self
    }
    if self ~= nil then
        derived.name = self.name .. "." .. name
    else
        derived.name = name
    end
    derived.members = {}

    if self ~= nil and self.members ~= nil then
        for _, m in ipairs(self.members) do
            table.insert(derived.members, m)
            derived.members[m] = true
        end
    end

    if additionalMembers then
        for _, m in ipairs(additionalMembers) do
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

--[[
function mt:resolve(candidates)
    local gen = self
    repeat
        if candidates[gen] ~= nil then
            return candidates[gen]
        end
        gen = gen.parent
    until gen == nil
    return nil
end
]]

local tag = mt.derive(nil, "*", nil)

return tag

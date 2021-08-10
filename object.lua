local tag = require "tag"

local object = {}

object.RANDOM_ORDER = nil
object.CHRONOLOGICAL_ORDER = 1
object.ALPHABETICAL_ORDER = 2

local objectMt = {

    __index = function(t, k)
        return t.__consts[k]
    end,

    __newindex = function(t, k, v)
        if t.__consts[k] ~= nil then
            error("attempt to overwrite constant member " .. k, 2)
        else
            rawset(t, k, v)
            if order == object.CHRONOLOGICAL_ORDER then
                table.insert(t.__order, k)
            end
        end
    end,

    __pairs = function(t)
        if t.__ordering == object.ALPHABETICAL_ORDER --
        or t.__ordering == object.CHRONOLOGICAL_ORDER then

            local keys
            if t.__ordering == object.ALPHABETICAL_ORDER then
                keys = {}
                for k, _ in pairs(t.__consts) do
                    table.insert(keys, k)
                end
                local k, _ = next(obj, k)
				-- pairs() would call this function recursively
                for k in next, t do
                    table.insert(keys, k)
                end
                table.sort(keys)
            else
                keys = t.__order
            end

            local function iter(t, k)
                local newKey
                if k == nil then
                    newKey = keys[1]
                else
                    for i, key in ipairs(keys) do
                        if key == k then
                            newKey = keys[i + 1]
                            break
                        end
                    end
                end
                if newKey then
                    return newKey, t[newKey]
                end
            end
            return iter, t, nil

        else -- random order

            local function iter(t, k)
                local v
                -- iterate through const table
                if k == nil or t.__consts[k] ~= nil then
                    k, v = next(t.__consts, k)
                    if k ~= nil then
                        return k, v
                    end
                end

                -- iterate through normal table
                return next(t, k)
            end
            return iter, t, nil
        end
    end
}

function object.Object(typeTag, consts, ordering)
    if consts == nil then
        consts = {}
    end

    local obj = {}

    obj.__type = typeTag
    obj.__consts = consts
    obj.__ordering = ordering

    if ordering == object.CHRONOLOGICAL_ORDER then
        obj.__order = {}
        if consts then
            for k, _ in pairs(consts) do
                table.insert(obj.__order, k)
            end
            table.sort(obj.__order)
        end
    end

    setmetatable(obj, objectMt)

    return obj
end

object.nativeTypeTag = tag:create("nativeTypeMarker")
object["nil"] = object.nativeTypeTag:derive("nil")
object.boolean = object.nativeTypeTag:derive("boolean")
object.number = object.nativeTypeTag:derive("number")
object.string = object.nativeTypeTag:derive("string")
object["function"] = object.nativeTypeTag:derive("function")
object.userdata = object.nativeTypeTag:derive("userdata")
object["thread"] = object.nativeTypeTag:derive("thread")
object.table = object.nativeTypeTag:derive("table")

function object.getType(obj)
    if type(obj) == "table" and obj.__type ~= nil then
        return obj.__type
    else
        return object[type(obj)]
    end
end

local dispatcherMt = {
    __call = function(functor, arg, ...)

        local nativeTag = object[type(arg)]

        if nativeTag ~= object.table and functor[nativeTag] ~= nil then
            -- anything that is not a table
            return functor[nativeTag](arg, ...)

        elseif nativeTag == object.table then
            if arg.__type ~= nil then
                -- table has a type field
                local typeTag = arg.__type
                while functor[typeTag] == nil and typeTag ~= nil do
                    typeTag = typeTag.parent
                end
                if functor[typeTag] ~= nil then
                    return functor[typeTag](arg, ...)
                else
                    error("no overload defined for type tag " .. arg.__type.label, 2)
                end
            else
                -- just a regular table
                if functor[object.table] ~= nil then
                    return functor[object.table](arg, ...)
                end
            end

        else
            error("no overload defined for native type " .. type(arg), 2)

        end
    end
}
function object.Dispatcher()
    local Dispatcher = {}
    setmetatable(Dispatcher, dispatcherMt)
    return Dispatcher
end

return object


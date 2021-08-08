local tag = require "tag"

object = {}

local TYPE = tag:derive("typeKey")
local CALL = tag:derive("callKey")
local ORDERING = tag:derive("orderingKey")
local ORDER = tag:derive("orderKey")
local CONSTS = tag:derive("constsKey")

object.RANDOM_ORDER = nil
object.CHRONOLOGICAL_ORDER = tag:derive("chronoMarker")
object.ALPHABETICAL_ORDER = tag:derive("alphaMarker")

local objectMt = {

    __call = function(t, ...)
        return t[CALL](...)
    end,

    __index = function(t, k)
        return t[CONSTS][k]
    end,

    __newindex = function(t, k, v)
        if t[CONSTS][k] ~= nil then
            error("attempt to overwrite constant member " .. k, 2)
        else
            rawset(t, k, v)
            if order == object.CHRONOLOGICAL_ORDER then
                table.insert(t[ORDER], k)
            end
        end
    end,

    __pairs = function(t)
        if t[ORDERING] == object.ALPHABETICAL_ORDER --
        or t[ORDERING] == object.CHRONOLOGICAL_ORDER then

            local keys
            if t[ORDERING] == object.ALPHABETICAL_ORDER then
                keys = {}
                for k, _ in pairs(t[CONSTS]) do
                    if not tag:includes(k) then
                        table.insert(keys, k)
                    end
                end
                local k, v
                while true do
                    k, v = next(obj, k)
                    if k ~= nil then
                        table.insert(keys, k)
                    else
                        break
                    end
                end
                table.sort(keys)
            else
                keys = t[ORDER]
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
                if k == nil or t[CONST][k] ~= nil then
                    repeat
                        k, v = next(t[CONST], k)
                    until not tag:includes(k) or k == nil
                    if k ~= nil then
                        return k, v
                    end
                end

                -- iterate through normal table
                repeat
                    k, v = next(t, k)
                until not tag:includes(k) or k == nil
                return k, v
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

    obj[TYPE] = typeTag
    obj[CONSTS] = consts
    obj[ORDERING] = ordering
    obj[CALL] = function()
        error("call is not defined for this object", 2)
    end

    if ordering == object.CHRONOLOGICAL_ORDER then
        obj[ORDER] = {}
        if consts then
            for k, _ in pairs(consts) do
                table.insert(obj[ORDER], k)
            end
            table.sort(obj[ORDER])
        end
    end

    setmetatable(obj, objectMt)

    return obj
end

function object.setCall(obj, fn)
    obj[CALL] = fn
end

function object.getCall(obj)
    return obj[CALL]
end

function object.getType(obj)
    if type(obj) == "table" then
        return obj[TYPE]
    else
        return nil
    end
end

object.nativeTypeTag = tag:derive("nativeTypeMarker")
object["nil"] = object.nativeTypeTag:derive("nil")
object.boolean = object.nativeTypeTag:derive("boolean")
object.number = object.nativeTypeTag:derive("number")
object.string = object.nativeTypeTag:derive("string")
object["function"] = object.nativeTypeTag:derive("function")
object.userdata = object.nativeTypeTag:derive("userdata")
object["thread"] = object.nativeTypeTag:derive("thread")
object.table = object.nativeTypeTag:derive("table")

local dispatcherMt = {
    __call = function(functor, arg, ...)

        local nativeTag = object[type(arg)]

        if nativeTag ~= object.table and functor[nativeTag] ~= nil then
            -- anything that is not a table
            return functor[nativeTag](arg, ...)

        elseif nativeTag == object.table then
            if arg[TYPE] ~= nil then
                -- table has a type field
                local typeTag = arg[TYPE]
                while functor[typeTag] == nil and typeTag ~= nil do
                    typeTag = typeTag.parent
                end
                if functor[typeTag] ~= nil then
                    return functor[typeTag](arg, ...)
                else
                    error("no overload defined for type tag " .. arg[TYPE].name, 2)
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


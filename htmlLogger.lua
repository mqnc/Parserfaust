local opf = require "operatorFactory"
local strfy = require "PegStringify"
local utils = require "utils"

local escapeJs = "[\b\f\n\r\t\v\0\'\"\\]"
local escapeJsMap = {
    ["\b"] = "\\b",
    ["\f"] = "\\f",
    ["\n"] = "\\n",
    ["\r"] = "\\r",
    ["\t"] = "\\t",
    ["\v"] = "\\v",
    ["\0"] = "\\0",
    ["\'"] = "\\\'",
    ["\""] = "\\\"",
    ["\\"] = "\\\\"
}

local escapeHtml = "[\n%&%<%>%\"%\']"
local escapeHtmlMap = {
    ["\n"] = "<br>\n",
    ["&"] = "&amp;",
    ["<"] = "&lt;",
    [">"] = "&gt;",
    ['"'] = "&quot;",
    ["'"] = "&apos;"
}

log = {
    append = print
}
log.append = function()
end

function sleep(n)
    -- os.execute("sleep " .. tonumber(n))
end

return function(operatorFactory, stringifier)
    local id = 0

    local strfMt = {}

    local opfMt = {
        __index = function(t, k)

            if operatorFactory.Op:includes(k) then
                return function(...)

                    local op = operatorFactory[k](...)

                    local opProxy = {}

                    opProxy.id = id
                    id = id + 1

                    opProxy.parse = function(src, pos)
                        log.append("[", opProxy.id, ",", pos, "],")
                        sleep(0.01)
                        local match = op.parse(src, pos)
                        log.append("[", opProxy.id, ",", pos, ",", match, "],")
                        return match
                    end

                    opProxy.defRule = function(name, def)
                        log.append("<", name, ">")
                        op.defRule(name, def)
                    end

                    utils.proxyfy(op, opProxy)

                    return opProxy

                end
            else
                return operatorFactory[k]
            end

        end,

        __newindex = function(t, k, v)
            operatorFactory[k] = v
        end
    }

    local opFactoryProxy = {}
    setmetatable(opFactoryProxy, opfMt)

    return opFactoryProxy
end
--[[
return function()

    local id = 0
    local log = {}

    local grammar = Grammar.create()

    local stringify = Stringifier()

    for typeTag, original in pairs(stringify) do
        if typeTag ~= Grammar.type and typeTag ~= object.string then
            stringify[typeTag] = function(op)
                return "\01" .. op.id .. "\02" .. original(op) .. "\03"
            end
        end
    end

    local mt = {}

    local function deco(op)
        local T = getType(op)
        if op.id ~= nil then
            return
        end
        id = id + 1
        op.id = id
        op.icon = icon[T]

        local oldParse = op.parse
        local newParse = function(src, pos)
            table.insert(log, "[" .. op.id .. "," .. pos .. "]")
            if T == operators.ReferenceType then
                table.insert(log, --
                "['" .. op.target .. "'," .. pos .. "]")
            end
            local len, tree = oldParse(src, pos)
            if T == operators.ReferenceType then
                table.insert(log, --
                "['" .. op.target .. "'," .. pos .. "," .. len .. "]")
            end
            table.insert(log, "[" .. op.id .. "," .. pos .. "," .. len .. "]")
            return len, tree
        end
        op.parse = newParse
    end

    mt.__index = function(t, rule)
        return grammar[rule]
    end

    mt.__newindex = function(t, k, v)
        if type(k) == "string" --
        and operators.OpType:includes(object.getType(v)) then
            Grammar.decorate(v, deco)
            table.insert(log, '{"' .. k .. '":"' .. --
            stringify(v) --
            :gsub(escapeHtml, escapeHtmlMap) --
            :gsub(escapeJs, escapeJsMap) .. '"}')
        end
        rawset(t, k, v)
    end

    mt.__tostring = function()
        return "let program=[" .. table.concat(log, ",\n") .. "]"
    end

    local opProxy = {}
    setmetatable(opProxy, mt)

    return opProxy
end
]]

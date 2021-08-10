utils = require "utils"

ss = utils.stringStream()

ss.append("abc", "def")

print(ss.concat(function(x)
    return "(" .. x .. ")"
end, ","))

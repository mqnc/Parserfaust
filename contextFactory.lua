local tag = require "tag"
local Object = (require "object").Object

local ctxf = {}

ctxf.ctxTag = tag:create("Context")

function ctxf.makeContext()
	local self = Object(ctxf.ctxTag)
	self.activeGrammar = nil
	self.ignoreVals = false
	self.furthestPos = 0
	return self
end

return ctxf

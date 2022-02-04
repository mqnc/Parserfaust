local inspect = (require "inspect").inspect

return function(operatorFactory)

	local opf = operatorFactory

	local Ref = opf[opf.Reference]
	local Grm = opf[opf.Grammar]
	local Lit = opf[opf.Literal]
	local Rng = opf[opf.Range]
	local Any = opf[opf.Any]
	local Seq = opf[opf.Sequence]
	local Cho = opf[opf.Choice]
	local Rep = opf[opf.Repetition]
	local And = opf[opf.LookAhead]
	local Act = opf[opf.Action]

	local pegGrammar = Grm("Grammar")
	local builtGrammar = Grm("Start")

	-- zero or more
	local Zom = function(op)
		return Rep(op, 0, math.huge)
	end

	-- one or more
	local Oom = function(op)
		return Rep(op, 1, math.huge)
	end

	-- optional
	local Opt = function(op)
		return Rep(op, 0, 1)
	end

	-- negative look ahead
	local Not = function(op)
		return And(op, false)
	end

	-- forwarding choice, ignoring index
	local fCho = function(...)
		return Act(Cho(...), function(args)
			local index, value = next(args.vals)
			return index
		end)
	end

	-- just forward matched string
	local Match = function(op)
		return Act(op, function(args)
			return args.src:sub(args.pos, args.pos + args.len - 1)
		end)
	end

	-- pick an item from a sequence
	local Pick = function(index, seq)
		return Act(seq, function(args)
			return args.vals[index]
		end)
	end

	local DEBUG = function(op)
		return Act(op, function(args)
			print(inspect(args))
			return args.vals
		end)
	end

	-- grammar construction helper
	local g = {
		__index = function(t, k)
			return Ref(k, pegGrammar)
		end,
		__newindex = function(t, k, v)
			pegGrammar.rules[k] = v
		end
	}
	setmetatable(g, g)

	-- # Hierarchical syntax

	-- Grammar <- Spacing Definition+ EndOfFile
	g.Grammar = Act(Seq(g.Spacing, Oom(g.Definition),
			g.EndOfFile), --
	function(args)
		return builtGrammar
	end)

	-- Definition <- Identifier LEFTARROW Expression
	g.Definition = Act(Seq(g.Identifier, g.LEFTARROW,
			g.Expression), --
	function(args)
		local id = args.vals[1]
		local op = args.vals[3]
		assert(opf.Op:includes(op))
		builtGrammar.rules[id] = op
	end)

	-- Expression <- Sequence (SLASH Sequence)*
	g.Expression = Act(Seq(g.Sequence, Zom(
			Pick(2, Seq(g.SLASH, g.Sequence)))), --
	function(args)
		return Cho(args.vals)
	end)

	-- Sequence <- Prefix*
	g.Sequence = Act(Zom(g.Prefix), --
	function(args)
		return Seq(args.vals)
	end)

	-- Prefix <- (AND / NOT)? Suffix
	g.Prefix = Act(Seq(Opt(Cho(g.AND, g.NOT)), g.Suffix), --
	function(args)
		local pref = args.vals[1]
		local suff = args.vals[2]
		if #pref == 1 then
			local choice, _ = next(pref[1])
			if choice == 1 then
				return And(suff)
			elseif choice == 2 then
				return Not(suff)
			end
		else
			return suff
		end
	end)

	-- Suffix <- Primary (QUESTION / STAR / PLUS)?
	g.Suffix = Act(Seq(g.Primary,
			Opt(Cho(g.QUESTION, g.STAR, g.PLUS))), --
	function(args)
		local prim = args.vals[1]
		local suff = args.vals[2]
		if #suff == 1 then
			local choice, _ = next(suff[1])
			if choice == 1 then
				return Opt(prim)
			elseif choice == 2 then
				return Zom(prim)
			elseif choice == 3 then
				return Oom(prim)
			end
		else
			return prim
		end
	end)

	-- Primary <- Identifier !LEFTARROW
	--          / OPEN Expression CLOSE
	--          / Literal / Class / DOT
	g.Primary = Act(Cho( --
	Pick(1, Seq(g.Identifier, Not(g.LEFTARROW))), --
	Pick(2, Seq(g.OPEN, g.Expression, g.CLOSE)), --
	g.Literal, g.Class, g.DOT), --
	function(args)
		local choice, val = next(args.vals)
		if choice == 1 then
			return Ref(val, builtGrammar)
		elseif choice == 5 then
			return Any()
		else
			return val
		end
	end)

	-- # Lexical syntax

	-- Identifier <- IdentStart IdentCont* Spacing
	g.Identifier = Pick(1, Seq(
			Match(Seq(g.IdentStart, Zom(g.IdentCont))), g.Spacing))

	-- IdentStart <- [a-zA-Z_]
	g.IdentStart = Cho(Rng("a", "z"), Rng("A", "Z"), Rng("_"))

	-- IdentCont <- IdentStart / [0-9]
	g.IdentCont = Cho(g.IdentStart, Rng("0", "9"))

	-- Literal <- ['] (!['] Char)* ['] Spacing
	--          / ["] (!["] Char)* ["] Spacing
	g.Literal = Act(fCho( --
	Pick(2,
			Seq(Rng("'"), Match(Zom(Seq(Not(Rng("'")), g.Char))),
					Rng("'"), g.Spacing)), --
	Pick(2,
			Seq(Rng('"'), Match(Zom(Seq(Not(Rng('"')), g.Char))),
					Rng('"'), g.Spacing)) --
	), function(args)
		return Lit(args.vals)
	end)

	-- Class <- '[' (!']' Range)* ']' Spacing
	g.Class = Act(Seq(Lit("["), --
	Zom(Pick(2, Seq(Not(Lit("]")), g.Range))), --
	Lit("]"), g.Spacing), --
	function(args)
		local ranges = args.vals[2]
		return Cho(ranges)
	end)

	-- Range <- Char '-' Char / Char
	g.Range =
			Act(Cho(Seq(g.Char, Lit("-"), g.Char), g.Char), --
			function(args)
				local choice, val = next(args.vals)
				if choice == 1 then
					return Rng(val[1], val[3])
				else
					return Rng(val)
				end
			end)

	-- Char <- '\\' [nrt'"\[\]\\]
	--       / '\\' [0-3][0-7][0-7]
	--       / '\\' [0-7][0-7]?
	--       / !'\\' .
	-- # (original paper says [0-2][0-7][0-7] but I think it's a typo)
	g.Char = fCho(g.Escape, g.Octal, g.SimpleChar)
	g.Escape = Act(Seq(Lit("\\"), Cho( --
	Rng("n"), Rng("r"), Rng("t"), Rng("'"), --
	Rng('"'), Rng("["), Rng("]"), Rng("\\"))), --
	function(args)
		local c = args.src:sub(args.pos + 1, args.pos + 1)
		local map = {n = "\n", r = "\r", t = "\t"}
		if map[c] then
			return map[c]
		else
			return c
		end
	end)
	g.Octal = Act(Cho(Seq(Lit("\\"), Rng("0", "3"),
			Rng("0", "7"), Rng("0", "7")), --
	Seq(Lit("\\"), Rng("0", "7"), Opt(Rng("0", "7"))) --
	), --
	function(args)
		return string.char(tonumber(args.src:sub(args.pos + 1,
				args.pos + args.len - 1), 8))
	end)
	g.SimpleChar = Match(Seq(Not(Lit("\\")), Any()))

	-- LEFTARROW <- '<-' Spacing
	g.LEFTARROW = Seq(Lit("<-"), g.Spacing)

	-- SLASH <- '/' Spacing
	g.SLASH = Seq(Lit("/"), g.Spacing)

	-- AND <- '&' Spacing
	g.AND = Seq(Lit("&"), g.Spacing)

	-- NOT <- '!' Spacing
	g.NOT = Seq(Lit("!"), g.Spacing)

	-- QUESTION <- '?' Spacing
	g.QUESTION = Seq(Lit("?"), g.Spacing)

	-- STAR <- '*' Spacing
	g.STAR = Seq(Lit("*"), g.Spacing)

	-- PLUS <- '+' Spacing
	g.PLUS = Seq(Lit("+"), g.Spacing)

	-- OPEN <- '(' Spacing
	g.OPEN = Seq(Lit("("), g.Spacing)

	-- CLOSE <- ')' Spacing
	g.CLOSE = Seq(Lit(")"), g.Spacing)

	-- DOT <- '.' Spacing
	g.DOT = Seq(Lit("."), g.Spacing)

	-- Spacing <- (Space / Comment)*
	g.Spacing = Zom(Cho(g.Space, g.Comment))

	-- Comment <- '#' (!EndOfLine .)* EndOfLine
	g.Comment = Seq(Lit("#"),
			Zom(Seq(Not(g.EndOfLine), Any())), g.EndOfLine)

	-- Space <- ' ' / '\t' / EndOfLine
	g.Space = Cho(Lit(" "), Lit("\t"), g.EndOfLine)

	-- EndOfLine <- '\r\n' / '\n' / '\r'
	g.EndOfLine = Cho(Lit("\r\n"), Lit("\n"), Lit("\r"))

	-- EndOfFile <- !.
	g.EndOfFile = Not(Any())

	return pegGrammar
end

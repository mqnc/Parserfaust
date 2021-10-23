local inspect = (require "inspect").inspect

return function(operatorFactory)

	local opf = operatorFactory

	local Grm = opf[opf.Grammar]
	local Lit = opf[opf.Literal]
	local Rng = opf[opf.Range]
	local Any = opf[opf.Any]
	local Seq = opf[opf.Sequence]
	local Cho = opf[opf.Choice]
	local Rep = opf[opf.Repetition]
	local And = opf[opf.LookAhead]
	local Act = opf[opf.Action]

	local grammar = Grm("Grammar")

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

	-- often used semantic actions
	local Ignore = function()
	end

	local Forward = function(src, pos, len, tree)
		return tree
	end

	local g = opf.makeGrammarHelper(grammar)

	-- # Hierarchical syntax

	-- Grammar <- Spacing Definition+ EndOfFile
	g.Grammar = Seq(g.Spacing, Oom(g.Definition), g.EndOfFile)

	-- Definition <- Identifier LEFTARROW Expression
	g.Definition = Seq(g.Identifier, g.LEFTARROW, g.Expression)

	-- Expression <- Sequence (SLASH Sequence)*
	g.Expression = Seq(g.Sequence, Zom(Seq(g.SLASH, g.Sequence)))

	-- Sequence <- Prefix*
	g.Sequence = Zom(g.Prefix)

	-- Prefix <- (AND / NOT)? Suffix
	g.Prefix = Seq(Opt(Cho(g.AND, g.NOT)), g.Suffix)

	-- Suffix <- Primary (QUESTION / STAR / PLUS)?
	g.Suffix = Seq(g.Primary, Opt(Cho(g.QUESTION, g.STAR, g.PLUS)))

	-- Primary <- Identifier !LEFTARROW
	--          / OPEN Expression CLOSE
	--          / Literal / Class / DOT
	g.Primary = Cho(Seq(g.Identifier, Not(g.LEFTARROW)), --
	Seq(g.OPEN, g.Expression, g.CLOSE), --
	g.Literal, g.Class, g.DOT)

	-- # Lexical syntax

	-- Identifier <- IdentStart IdentCont* Spacing
	g.Identifier = Act(Seq(g.IdentStart, Zom(g.IdentCont), g.Spacing), --
	function(src, pos, len, tree)
		return {
			id = src:sub(pos, pos + tree[2].len)
		}
	end)

	-- IdentStart <- [a-zA-Z_]
	g.IdentStart = Cho(Rng("a", "z"), Rng("A", "Z"), Rng("_"))

	-- IdentCont <- IdentStart / [0-9]
	g.IdentCont = Cho(g.IdentStart, Rng("0", "9"))

	-- Literal <- ['] (!['] Char)* ['] Spacing
	--          / ["] (!["] Char)* ["] Spacing
	g.Literal = Act(Cho( --
	Seq(Rng("'"), Zom(Seq(Not(Rng("'")), g.Char)), Rng("'"), g.Spacing), --
	Seq(Rng('"'), Zom(Seq(Not(Rng('"')), g.Char)), Rng('"'), g.Spacing) --
	), --
	function(src, pos, len, tree)
		return {}
	end)

	-- Class <- '[' (!']' Range)* ']' Spacing
	g.Class = Seq(Lit("["), Zom(Seq(Not(Lit("]")), g.Range)), Lit("]"), g.Spacing)

	-- Range <- Char '-' Char / Char
	g.Range = Cho(Seq(g.Char, Lit("-"), g.Char), g.Char)

	-- Char <- '\\' [nrt'"\[\]\\]
	--       / '\\' [0-3][0-7][0-7]
	--       / '\\' [0-7][0-7]?
	--       / !'\\' .
	-- # (original paper says [0-2][0-7][0-7] but I think it's a typo)
	g.Char = Act(Cho(g.Escape, g.Octal, g.SimpleChar), --
	function(src, pos, len, tree)
		print(tree.tree[4])
		return tree
	end)
	g.Escape = Act(Seq(Lit("\\"), Cho( --
	Rng("n"), Rng("r"), Rng("t"), Rng("'"), --
	Rng('"'), Rng("["), Rng("]"), Rng("\\"))), --
	function(src, pos, len, tree)
		local map = {
			n = "\n",
			r = "\r",
			t = "\t",
			["'"] = "'",
			['"'] = '"',
			["["] = "[",
			["]"] = "]",
			["\\"] = "\\"
		}
		return map[src:sub(pos + 1, pos + 1)]
	end)
	g.Octal = Act(Cho( --
	Seq(Lit("\\"), Rng("0", "3"), Rng("0", "7"), Rng("0", "7")), --
	Seq(Lit("\\"), Rng("0", "7"), Opt(Rng("0", "7"))) --
	), --
	function(src, pos, len, tree)
		return string.char(tonumber(src:sub(pos + 1, pos + len - 1), 8))
	end)
	g.SimpleChar = Act(Seq(Not(Lit("\\")), Any()), --
	function(src, pos, len, tree)
		return src:sub(pos, pos)
	end)

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
	g.Comment = Seq(Lit("#"), Zom(Seq(Not(g.EndOfLine), Any())), g.EndOfLine)

	-- Space <- ' ' / '\t' / EndOfLine
	g.Space = Cho(Lit(" "), Lit("\t"), g.EndOfLine)

	-- EndOfLine <- '\r\n' / '\n' / '\r'
	g.EndOfLine = Cho(Lit("\r\n"), Lit("\n"), Lit("\r"))

	-- EndOfFile <- !.
	g.EndOfFile = Not(Any())

	return grammar
end

local inspect = (require "inspect").inspect

return function(operatorFactory)

	local opf = operatorFactory

	local Grm = opf[opf.Grammar]
	local Ref = opf[opf.Reference]
	local Lit = opf[opf.Literal]
	local Rng = opf[opf.Range]
	local Any = opf[opf.Any]
	local Seq = opf[opf.Sequence]
	local Cho = opf[opf.Choice]
	local Rep = opf[opf.Repetition]
	local And = opf[opf.LookAhead]
	local Act = opf[opf.Action]

	local grammar = Grm("Grammar")

	-- curry grammar into references
	local R = function(name)
		return Ref(grammar, name)
	end

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

	local g = grammar.rules

	-- # Hierarchical syntax

	-- Grammar <- Spacing Definition+ EndOfFile
	g.Grammar = Seq(R("Spacing"), Oom(R("Definition")), R("EndOfFile"))

	-- Definition <- Identifier LEFTARROW Expression
	g.Definition = Seq(R("Identifier"), R("LEFTARROW"), R("Expression"))

	-- Expression <- Sequence (SLASH Sequence)*
	g.Expression = Seq(R("Sequence"), Zom(Seq(R("SLASH"), R("Sequence"))))

	-- Sequence <- Prefix*
	g.Sequence = Zom(R("Prefix"))

	-- Prefix <- (AND / NOT)? Suffix
	g.Prefix = Seq(Opt(Cho(R("AND"), R("NOT"))), R("Suffix"))

	-- Suffix <- Primary (QUESTION / STAR / PLUS)?
	g.Suffix = Seq(R("Primary"), Opt(Cho(R("QUESTION"), R("STAR"), R("PLUS"))))

	-- Primary <- Identifier !LEFTARROW
	--          / OPEN Expression CLOSE
	--          / Literal / Class / DOT
	g.Primary = Cho(Seq(R("Identifier"), Not(R("LEFTARROW"))), --
	Seq(R("OPEN"), R("Expression"), R("CLOSE")), --
	R("Literal"), R("Class"), R("DOT"))

	-- # Lexical syntax

	-- Identifier <- IdentStart IdentCont* Spacing
	g.Identifier = Act(Seq(R("IdentStart"), Zom(R("IdentCont")), R("Spacing")), --
	function(src, pos, len, tree)
		return {
			id = src:sub(pos, pos + tree[2].len)
		}
	end)

	-- IdentStart <- [a-zA-Z_]
	g.IdentStart = Cho(Rng("a", "z"), Rng("A", "Z"), Rng("_"))

	-- IdentCont <- IdentStart / [0-9]
	g.IdentCont = Cho(R("IdentStart"), Rng("0", "9"))

	-- Literal <- ['] (!['] Char)* ['] Spacing
	--          / ["] (!["] Char)* ["] Spacing
	g.Literal = Act(Cho( --
	Seq(Rng("'"), Zom(Seq(Not(Rng("'")), R("Char"))), Rng("'"), R("Spacing")), --
	Seq(Rng('"'), Zom(Seq(Not(Rng('"')), R("Char"))), Rng('"'), R("Spacing")) --
	), --
	function(src, pos, len, tree)
		return {}
	end)

	-- Class <- '[' (!']' Range)* ']' Spacing
	g.Class = Seq(Lit("["), Zom(Seq(Not(Lit("]")), R("Range"))), Lit("]"), R("Spacing"))

	-- Range <- Char '-' Char / Char
	g.Range = Cho(Seq(R("Char"), Lit("-"), R("Char")), R("Char"))

	-- Char <- '\\' [nrt'"\[\]\\]
	--       / '\\' [0-3][0-7][0-7]
	--       / '\\' [0-7][0-7]?
	--       / !'\\' .
	-- # (original paper says [0-2][0-7][0-7] but I think it's a typo)
	g.Char = Act(Cho(R("Escape"), R("Octal"), R("SimpleChar")), --
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
	g.LEFTARROW = Seq(Lit("<-"), R("Spacing"))

	-- SLASH <- '/' Spacing
	g.SLASH = Seq(Lit("/"), R("Spacing"))

	-- AND <- '&' Spacing
	g.AND = Seq(Lit("&"), R("Spacing"))

	-- NOT <- '!' Spacing
	g.NOT = Seq(Lit("!"), R("Spacing"))

	-- QUESTION <- '?' Spacing
	g.QUESTION = Seq(Lit("?"), R("Spacing"))

	-- STAR <- '*' Spacing
	g.STAR = Seq(Lit("*"), R("Spacing"))

	-- PLUS <- '+' Spacing
	g.PLUS = Seq(Lit("+"), R("Spacing"))

	-- OPEN <- '(' Spacing
	g.OPEN = Seq(Lit("("), R("Spacing"))

	-- CLOSE <- ')' Spacing
	g.CLOSE = Seq(Lit(")"), R("Spacing"))

	-- DOT <- '.' Spacing
	g.DOT = Seq(Lit("."), R("Spacing"))

	-- Spacing <- (Space / Comment)*
	g.Spacing = Zom(Cho(R("Space"), R("Comment")))

	-- Comment <- '#' (!EndOfLine .)* EndOfLine
	g.Comment = Seq(Lit("#"), Zom(Seq(Not(R("EndOfLine")), Any())), R("EndOfLine"))

	-- Space <- ' ' / '\t' / EndOfLine
	g.Space = Cho(Lit(" "), Lit("\t"), R("EndOfLine"))

	-- EndOfLine <- '\r\n' / '\n' / '\r'
	g.EndOfLine = Cho(Lit("\r\n"), Lit("\n"), Lit("\r"))

	-- EndOfFile <- !.
	g.EndOfFile = Not(Any())

	return grammar
end

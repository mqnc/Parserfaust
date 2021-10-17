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

    -- action for ignoring arguments
    local Ignore = function()
    end

    local g = grammar.rules

    -- # Hierarchical syntax

    -- Grammar <- Spacing Definition+ EndOfFile
    g.Grammar = Act(Seq(R("Spacing"), Oom(R("Definition")), R("EndOfFile")))

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
    g.Identifier = Act(Seq(R("IdentStart"), Zom(R("IdentCont")), R("Spacing")), Ignore)
    --[[function(src, pos, len, tree)
        return {
            -- pos + tree[1].len (=1) + tree[2].len -1
            id = src:sub(pos, pos + tree[2].len)
        }
    end)]]

    -- IdentStart <- [a-zA-Z_]
    g.IdentStart = Act(Cho(Rng("a", "z"), Rng("A", "Z"), Rng("_")), Ignore)

    -- IdentCont <- IdentStart / [0-9]
    g.IdentCont = Act(Cho(R("IdentStart"), Rng("0", "9")), Ignore)

    -- Literal <- ['] (!['] Char)* ['] Spacing
    --          / ["] (!["] Char)* ["] Spacing
    g.Literal = Act(Cho(Seq(Rng("'"), Zom(Seq(Not(Rng("'")), R("Char"))), Rng("'"), R("Spacing")), --
    Seq(Rng('"'), Zom(Seq(Not(Rng('"')), R("Char"))), Rng('"'), R("Spacing"))), --
    function(src, pos, len, tree)
        -- print(src:sub(pos, pos + len))
        -- print(explore(tree, {depth=1}))
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
    g.Char = Cho(Seq(Lit("\\\\"), Cho(Rng("n"), Rng("r"), Rng("t"), Rng("'"), Rng('"'), Rng("["), Rng("]"))), --
    Seq(Lit("\\\\"), Rng("0", "3"), Rng("0", "7"), Rng("0", "7")), --
    Seq(Lit("\\\\"), Rng("0", "7"), Opt(Rng("0", "7"))), --
    Seq(Not(Lit("\\\\")), Any()))

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

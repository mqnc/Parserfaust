require "object"
local Object = object.Object
local INFO = object.infoKey

return function(grammar, operators)

    local Lit = operators.Literal
    local Rng = operators.Range
    local Any = operators.Any
    local Seq = operators.Sequence
    local Cho = operators.Choice
    local Rep = operators.Repetition
    local And = operators.LookAhead
    local Act = operators.Action
    local Ref = operators.Reference

    -- set grammar environment for references
    local R = function(name)
        return Ref(name, grammar)
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
    debug.getinfo(Ignore).name = "Ignore"

    -- # Hierarchical syntax

    -- Grammar <- Spacing Definition+ EndOfFile
    grammar.Grammar = Act(Seq(R("Spacing"), Oom(R("Definition")), R("EndOfFile")))

    -- Definition <- Identifier LEFTARROW Expression
    grammar.Definition = Seq(R("Identifier"), R("LEFTARROW"), R("Expression"))

    -- Expression <- Sequence (SLASH Sequence)*
    grammar.Expression = Seq(R("Sequence"), Zom(Seq(R("SLASH"), R("Sequence"))))

    -- Sequence <- Prefix*
    grammar.Sequence = Zom(R("Prefix"))

    -- Prefix <- (AND / NOT)? Suffix
    grammar.Prefix = Seq(Opt(Cho(R("AND"), R("NOT"))), R("Suffix"))

    -- Suffix <- Primary (QUESTION / STAR / PLUS)?
    grammar.Suffix = Seq(R("Primary"), Opt(Cho(R("QUESTION"), R("STAR"), R("PLUS"))))

    -- Primary <- Identifier !LEFTARROW
    --          / OPEN Expression CLOSE
    --          / Literal / Class / DOT
    grammar.Primary = Cho(Seq(R("Identifier"), Not(R("LEFTARROW"))), --
    Seq(R("OPEN"), R("Expression"), R("CLOSE")), --
    R("Literal"), R("Class"), R("DOT"))

    -- # Lexical syntax

    -- Identifier <- IdentStart IdentCont* Spacing
    grammar.Identifier = Act(Seq(R("IdentStart"), Zom(R("IdentCont")), R("Spacing")), --
    function(src, pos, len, tree)
        return {
            -- pos + tree[1].len (=1) + tree[2].len -1
            id = src:sub(pos, pos + tree[2].len)
        }
    end)

    -- IdentStart <- [a-zA-Z_]
    grammar.IdentStart = Act(Cho(Rng("a", "z"), Rng("A", "Z"), Rng("_")), Ignore)

    -- IdentCont <- IdentStart / [0-9]
    grammar.IdentCont = Act(Cho(R("IdentStart"), Rng("0", "9")), Ignore)

    -- Literal <- ['] (!['] Char)* ['] Spacing
    --          / ["] (!["] Char)* ["] Spacing
    grammar.Literal = Act(Cho(Seq(Lit("'"), Zom(Seq(Not(Lit("'")), R("Char"))), Lit(""), R("Spacing")), --
    Seq(Lit('"'), Zom(Seq(Not(Lit('"')), R("Char"))), Lit('"'), R("Spacing"))), --
    function(src, pos, len, tree)
        -- print(src:sub(pos, pos + len))
        -- print(explore(tree, {depth=1}))
        return {}
    end)

    -- Class <- '[' (!']' Range)* ']' Spacing
    grammar.Class = Seq(Lit("["), Zom(Seq(Not(Lit("]")), R("Range"))), Lit("]"), R("Spacing"))

    -- Range <- Char '-' Char / Char
    grammar.Range = Cho(Seq(R("Char"), Lit("-"), R("Char")), R("Char"))

    -- Char <- '\\' [nrt'"\[\]\\]
    --       / '\\' [0-3][0-7][0-7]
    --       / '\\' [0-7][0-7]?
    --       / !'\\' .
    -- # (original paper says [0-2][0-7][0-7] but I think it's a typo)
    grammar.Char = Cho(Seq(Lit("\\\\"), Cho(Rng("n"), Rng("r"), Rng("t"), Rng("'"), Rng('"'), Rng("["), Lit("]"))), --
    Seq(Lit("\\\\"), Rng("0", "3"), Rng("0", "7"), Rng("0", "7")), --
    Seq(Lit("\\\\"), Rng("0", "7"), Opt(Rng("0", "7"))), --
    Seq(Not(Lit("\\\\")), Any()))

    -- LEFTARROW <- '<-' Spacing
    grammar.LEFTARROW = Seq(Lit("<-"), R("Spacing"))

    -- SLASH <- '/' Spacing
    grammar.SLASH = Seq(Lit("/"), R("Spacing"))

    -- AND <- '&' Spacing
    grammar.AND = Seq(Lit("&"), R("Spacing"))

    -- NOT <- '!' Spacing
    grammar.NOT = Seq(Lit("!"), R("Spacing"))

    -- QUESTION <- '?' Spacing
    grammar.QUESTION = Seq(Lit("?"), R("Spacing"))

    -- STAR <- '*' Spacing
    grammar.STAR = Seq(Lit("*"), R("Spacing"))

    -- PLUS <- '+' Spacing
    grammar.PLUS = Seq(Lit("+"), R("Spacing"))

    -- OPEN <- '(' Spacing
    grammar.OPEN = Seq(Lit("("), R("Spacing"))

    -- CLOSE <- ')' Spacing
    grammar.CLOSE = Seq(Lit(")"), R("Spacing"))

    -- DOT <- '.' Spacing
    grammar.DOT = Seq(Lit("."), R("Spacing"))

    -- Spacing <- (Space / Comment)*
    grammar.Spacing = Zom(Cho(R("Space"), R("Comment")))

    -- Comment <- '#' (!EndOfLine .)* EndOfLine
    grammar.Comment = Seq(Lit("#"), Zom(Seq(Not(R("EndOfLine")), Any())), R("EndOfLine"))

    -- Space <- ' ' / '\t' / EndOfLine
    grammar.Space = Cho(Lit(" "), Lit("\t"), R("EndOfLine"))

    -- EndOfLine <- '\r\n' / '\n' / '\r'
    grammar.EndOfLine = Cho(Lit("\r\n"), Lit("\n"), Lit("\r"))

    -- EndOfFile <- !.
    grammar.EndOfFile = Not(Any())

end

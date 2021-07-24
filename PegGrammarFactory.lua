ops = require "PegOperators"

return function(operatorDecorator)

    if operatorDecorator == nil then
        operatorDecorator = function(op)
            return op
        end
    end

    local rules = {}

    local Lit = operatorDecorator(ops.Literal)
    local Rng = operatorDecorator(ops.Range)
    local Any = operatorDecorator(ops.Any)
    local Seq = operatorDecorator(ops.Sequence)
    local Cho = operatorDecorator(ops.OrderedChoice)
    local Rep = operatorDecorator(ops.Repetition)
    local And = operatorDecorator(ops.LookAhead)
    local Rule = operatorDecorator(ops.Rule)
    local Ref = operatorDecorator(ops.Reference)

    -- set rules environment for references
    local R = function(name)
        return Ref(name, rules)
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
    rules.Grammar = Seq(R("Spacing"), Oom(R("Definition")), R("EndOfFile"))

    -- Definition <- Identifier LEFTARROW Expression
    rules.Definition = Seq(R("Identifier"), R("LEFTARROW"), R("Expression"))

    -- Expression <- Sequence (SLASH Sequence)*
    rules.Expression = Seq(R("Sequence"), Zom(Seq(R("SLASH"), R("Sequence"))))

    -- Sequence <- Prefix*
    rules.Sequence = Zom(R("Prefix"))

    -- Prefix <- (AND / NOT)? Suffix
    rules.Prefix = Seq(Opt(Cho(R("AND"), R("NOT"))), R("Suffix"))

    -- Suffix <- Primary (QUESTION / STAR / PLUS)?
    rules.Suffix = Seq(R("Primary"), Opt(Cho(R("QUESTION"), R("STAR"), R("PLUS"))))

    -- Primary <- Identifier !LEFTARROW
    --          / OPEN Expression CLOSE
    --          / Literal / Class / DOT
    rules.Primary = Cho(Seq(R("Identifier"), Not(R("LEFTARROW"))), --
    Seq(R("OPEN"), R("Expression"), R("CLOSE")), --
    R("Literal"), R("Class"), R("DOT"))

    -- # Lexical syntax

    -- Identifier <- IdentStart IdentCont* Spacing
    rules.Identifier = Rule(Seq(R("IdentStart"), Zom(R("IdentCont")), R("Spacing")), --
    function(src, pos, len, tree)
        return {
            -- pos + tree[1].len (=1) + tree[2].len -1
            id = src:sub(pos, pos + tree[2].len)
        }
    end)

    -- IdentStart <- [a-zA-Z_]
    rules.IdentStart = Rule(Cho(Rng("a", "z"), Rng("A", "Z"), Rng("_")), Ignore)

    -- IdentCont <- IdentStart / [0-9]
    rules.IdentCont = Rule(Cho(R("IdentStart"), Rng("0", "9")), Ignore)

    -- Literal <- ['] (!['] Char)* ['] Spacing
    --          / ["] (!["] Char)* ["] Spacing
    rules.Literal = Rule(Cho(Seq(Lit("'"), Zom(Seq(Not(Lit("'")), R("Char"))), Lit(""), R("Spacing")), --
    Seq(Lit('"'), Zom(Seq(Not(Lit('"')), R("Char"))), Lit('"'), R("Spacing"))), --
    function(src, pos, len, tree)
        print(src:sub(pos, pos + len))
        -- print(inspect(tree, {depth=1}))
        return {}
    end)

    -- Class <- '[' (!']' Range)* ']' Spacing
    rules.Class = Seq(Lit("["), Zom(Seq(Not(Lit("]")), R("Range"))), Lit("]"), R("Spacing"))

    -- Range <- Char '-' Char / Char
    rules.Range = Cho(Seq(R("Char"), Lit("-"), R("Char")), R("Char"))

    -- Char <- '\\' [nrt'"\[\]\\]
    --       / '\\' [0-2][0-7][0-7]
    --       / '\\' [0-7][0-7]?
    --       / !'\\' .
    rules.Char = Cho(Seq(Lit("\\\\"), Cho(Rng("n"), Rng("r"), Rng("t"), Rng("'"), Rng('"'), Rng("["), Lit("]"))), --
    Seq(Lit("\\\\"), Rng("0", "2"), Rng("0", "7"), Rng("0", "7")), --
    Seq(Lit("\\\\"), Rng("0", "7"), Opt(Rng("0", "7"))), --
    Seq(Not(Lit("\\\\")), Any()))

    -- LEFTARROW <- '<-' Spacing
    rules.LEFTARROW = Seq(Lit("<-"), R("Spacing"))

    -- SLASH <- '/' Spacing
    rules.SLASH = Seq(Lit("/"), R("Spacing"))

    -- AND <- '&' Spacing
    rules.AND = Seq(Lit("&"), R("Spacing"))

    -- NOT <- '!' Spacing
    rules.NOT = Seq(Lit("!"), R("Spacing"))

    -- QUESTION <- '?' Spacing
    rules.QUESTION = Seq(Lit("?"), R("Spacing"))

    -- STAR <- '*' Spacing
    rules.STAR = Seq(Lit("*"), R("Spacing"))

    -- PLUS <- '+' Spacing
    rules.PLUS = Seq(Lit("+"), R("Spacing"))

    -- OPEN <- '(' Spacing
    rules.OPEN = Seq(Lit("("), R("Spacing"))

    -- CLOSE <- ')' Spacing
    rules.CLOSE = Seq(Lit(")"), R("Spacing"))

    -- DOT <- '.' Spacing
    rules.DOT = Seq(Lit("."), R("Spacing"))

    -- Spacing <- (Space / Comment)*
    rules.Spacing = Zom(Cho(R("Space"), R("Comment")))

    -- Comment <- '#' (!EndOfLine .)* EndOfLine
    rules.Comment = Seq(Lit("#"), Zom(Seq(Not(R("EndOfLine")), Any())), R("EndOfLine"))

    -- Space <- ' ' / '\t' / EndOfLine
    rules.Space = Cho(Lit(" "), Lit("\t"), R("EndOfLine"))

    -- EndOfLine <- '\r\n' / '\n' / '\r'
    rules.EndOfLine = Cho(Lit("\r\n"), Lit("\n"), Lit("\r"))

    -- EndOfFile <- !.
    rules.EndOfFile = Not(Any())

    return rules
end

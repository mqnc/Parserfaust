peg = require "PegOperators"

return function(operatorDecorator)

    if operatorDecorator == nil then
        operatorDecorator = function(op)
            return op
        end
    end

    local rules = {}

    local Lit = operatorDecorator(peg.Literal)
    local Rng = operatorDecorator(peg.Range)
    local Any = operatorDecorator(peg.Any)
    local Seq = operatorDecorator(peg.Sequence)
    local Cho = operatorDecorator(peg.OrderedChoice)
    local Rep = operatorDecorator(peg.Repetition)
    local And = operatorDecorator(peg.LookAhead)
    local Ptr = operatorDecorator(peg.Pointer)

    -- pointer in rules environment
    local P = function(name)
        return Ptr(name, rules)
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

    -- # Hierarchical syntax

    -- Grammar <- Spacing Definition+ EndOfFile
    rules.Grammar = Seq(P("Spacing"), Oom(P("Definition")), P("EndOfFile"))

    -- Definition <- Identifier LEFTARROW Expression
    rules.Definition = Seq(P("Identifier"), P("LEFTARROW"), P("Expression"))

    -- Expression <- Sequence (SLASH Sequence)*
    rules.Expression = Seq(P("Sequence"), Zom(Seq(P("SLASH"), P("Sequence"))))

    -- Sequence <- Prefix*
    rules.Sequence = Zom(P("Prefix"))

    -- Prefix <- (AND / NOT)? Suffix
    rules.Prefix = Seq(Opt(Cho(P("AND"), P("NOT"))), P("Suffix"))

    -- Suffix <- Primary (QUESTION / STAR / PLUS)?
    rules.Suffix = Seq(P("Primary"), Opt(Cho(P("QUESTION"), P("STAR"), P("PLUS"))))

    -- Primary <- Identifier !LEFTARROW
    --          / OPEN Expression CLOSE
    --          / Literal / Class / DOT
    rules.Primary = Cho(Seq(P("Identifier"), Not(P("LEFTARROW"))), --
    Seq(P("OPEN"), P("Expression"), P("CLOSE")), --
    P("Literal"), P("Class"), P("DOT"))

    -- # Lexical syntax

    -- Identifier <- IdentStart IdentCont* Spacing
    rules.Identifier = Seq(P("IdentStart"), Zom(P("IdentCont")), P("Spacing"))

    -- IdentStart <- [a-zA-Z_]
    rules.IdentStart = Cho(Rng("a", "z"), Rng("A", "Z"), Lit("_"))

    -- IdentCont <- IdentStart / [0-9]
    rules.IdentCont = Cho(P("IdentStart"), Rng("0", "9"))

    -- Literal <- ['] (!['] Char)* ['] Spacing
    --          / ["] (!["] Char)* ["] Spacing
    rules.Literal = Cho(Seq(Lit("'"), Zom(Seq(Not(Lit("'")), P("Char"))), Lit(""), P("Spacing")), --
    Seq(Lit('"'), Zom(Seq(Not(Lit('"')), P("Char"))), Lit('"'), P("Spacing")))

    -- Class <- '[' (!']' Range)* ']' Spacing
    rules.Class = Seq(Lit("["), Zom(Seq(Not(Lit("]")), P("Range"))), Lit("]"), P("Spacing"))

    -- Range <- Char '-' Char / Char
    rules.Range = Cho(Seq(P("Char"), Lit("-"), P("Char")), P("Char"))

    -- Char <- '\\' [nrt'"\[\]\\]
    --       / '\\' [0-2][0-7][0-7]
    --       / '\\' [0-7][0-7]?
    --       / !'\\' .
    rules.Char = Cho(Seq(Lit("\\\\"), Cho(Lit("n"), Lit("r"), Lit("t"), Lit("'"), Lit('"'), Lit("["), Lit("]"))), --
    Seq(Lit("\\\\"), Rng("0", "2"), Rng("0", "7"), Rng("0", "7")), --
    Seq(Lit("\\\\"), Rng("0", "7"), Opt(Rng("0", "7"))), --
    Seq(Not(Lit("\\\\")), Any()))

    -- LEFTARROW <- '<-' Spacing
    rules.LEFTARROW = Seq(Lit("<-"), P("Spacing"))

    -- SLASH <- '/' Spacing
    rules.SLASH = Seq(Lit("/"), P("Spacing"))

    -- AND <- '&' Spacing
    rules.AND = Seq(Lit("&"), P("Spacing"))

    -- NOT <- '!' Spacing
    rules.NOT = Seq(Lit("!"), P("Spacing"))

    -- QUESTION <- '?' Spacing
    rules.QUESTION = Seq(Lit("?"), P("Spacing"))

    -- STAR <- '*' Spacing
    rules.STAR = Seq(Lit("*"), P("Spacing"))

    -- PLUS <- '+' Spacing
    rules.PLUS = Seq(Lit("+"), P("Spacing"))

    -- OPEN <- '(' Spacing
    rules.OPEN = Seq(Lit("("), P("Spacing"))

    -- CLOSE <- ')' Spacing
    rules.CLOSE = Seq(Lit(")"), P("Spacing"))

    -- DOT <- '.' Spacing
    rules.DOT = Seq(Lit("."), P("Spacing"))

    -- Spacing <- (Space / Comment)*
    rules.Spacing = Zom(Cho(P("Space"), P("Comment")))

    -- Comment <- '#' (!EndOfLine .)* EndOfLine
    rules.Comment = Seq(Lit("#"), Zom(Seq(Not(P("EndOfLine")), Any())), P("EndOfLine"))

    -- Space <- ' ' / '\t' / EndOfLine
    rules.Space = Cho(Lit(" "), Lit("\t"), P("EndOfLine"))

    -- EndOfLine <- '\r\n' / '\n' / '\r'
    rules.EndOfLine = Cho(Lit("\r\n"), Lit("\n"), Lit("\r"))

    -- EndOfFile <- !.
    rules.EndOfFile = Not(Any())

    return rules
end

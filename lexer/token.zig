pub const TokenKind = enum {
    // Keywords
    If,
    Else,
    While,
    Int,
    Float,
    Bool,
    Char,
    Return,
    Void,
    True,
    False,

    // Identifiers
    Identifier,

    // Delimiters
    LeftParen,
    RightParen,
    LeftBracket,
    RightBracket,
    LeftCurly,
    RightCurly,

    // Assignment
    Eq,
    PlusEq,
    MinusEq,
    MultiplyEq,
    DivEq,

    // Arithmetic
    Plus,
    Minus,
    Multiply,
    Div,
    Modulo,
    Inc,
    Dec,

    // Comparison
    IsEq,
    NotEq,
    Greater,
    Less,
    GEq,
    LEq,

    // Logical
    LogicalAnd,
    LogicalOr,
    LogicalNot,

    // Bitwise
    BitwiseAnd,
    BitwiseOr,
    BitwiseNot,
    BitwiseXor,
    LeftShift,
    RightShift,

    // Punctuation
    Comma,
    SemiColon,
    Dot,
    Colon,
    Arrow,
    Question,
    Hash,
    Tilde,

    // Literals
    Integer,
    FloatLiteral,
    Character,
    String,

    // Special
    Error,
    Eof,
};

pub const Token = struct {
    kind: TokenKind,
    lexeme: []const u8,
    line: u32,
    column: u32,
};

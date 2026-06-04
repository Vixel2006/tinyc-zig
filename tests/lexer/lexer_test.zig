const std = @import("std");
const testing = std.testing;
const Lexer = @import("lexer").Lexer;
const TokenKind = @import("lexer").TokenKind;
const Token = @import("lexer").Token;

fn tokenize(source: []const u8) TokenIterator {
    return .{ .lexer = Lexer.init(source) };
}

const TokenIterator = struct {
    lexer: Lexer,

    fn next(self: *TokenIterator) TokenKind {
        return self.lexer.next().kind;
    }

    fn nextWith(self: *TokenIterator) Token {
        return self.lexer.next();
    }
};

fn expectToken(tok: Token, kind: TokenKind, lexeme: []const u8, line: u32, column: u32) !void {
    try testing.expectEqual(kind, tok.kind);
    try testing.expectEqualStrings(lexeme, tok.lexeme);
    try testing.expectEqual(line, tok.line);
    try testing.expectEqual(column, tok.column);
}

fn expectTokens(source: []const u8, expected: []const Token) !void {
    var it = tokenize(source);
    for (expected) |exp| {
        const tok = it.nextWith();
        try testing.expectEqual(exp.kind, tok.kind);
        try testing.expectEqualStrings(exp.lexeme, tok.lexeme);
        try testing.expectEqual(exp.line, tok.line);
        try testing.expectEqual(exp.column, tok.column);
    }
    try testing.expectEqual(.Eof, it.nextWith().kind);
}

test "empty input" {
    var it = tokenize("");
    try testing.expectEqual(.Eof, it.next());
}

test "whitespace-only input" {
    var it = tokenize("   \t\n\r  \n");
    try testing.expectEqual(.Eof, it.next());
}

test "keywords" {
    const inputs = [_]TokenKind{
        .If, .Else, .While, .Int, .Float,
        .Bool, .Char, .Return, .Void, .True, .False,
    };
    const names = [_][]const u8{
        "if", "else", "while", "int", "float",
        "bool", "char", "return", "void", "true", "false",
    };
    for (inputs, names) |kind, name| {
        var it = tokenize(name);
        try testing.expectEqual(kind, it.next());
        try testing.expectEqual(.Eof, it.next());
    }
}

test "identifier" {
    var it = tokenize("foo bar _baz qux123 _");
    try testing.expectEqual(.Identifier, it.next());
    try testing.expectEqual(.Identifier, it.next());
    try testing.expectEqual(.Identifier, it.next());
    try testing.expectEqual(.Identifier, it.next());
    try testing.expectEqual(.Identifier, it.next());
    try testing.expectEqual(.Eof, it.next());
}

test "identifier lexeme" {
    var it = tokenize("myVar");
    const tok = it.nextWith();
    try testing.expectEqual(.Identifier, tok.kind);
    try testing.expectEqualStrings("myVar", tok.lexeme);
}

test "decimal integer" {
    try expectTokens("123", &.{
        .{ .kind = .Integer, .lexeme = "123", .line = 1, .column = 1 },
    });
}

test "hex integer" {
    try expectTokens("0xFF 0x1a2b", &.{
        .{ .kind = .Integer, .lexeme = "0xFF", .line = 1, .column = 1 },
        .{ .kind = .Integer, .lexeme = "0x1a2b", .line = 1, .column = 6 },
    });
}

test "binary integer" {
    try expectTokens("0b1010 0B01", &.{
        .{ .kind = .Integer, .lexeme = "0b1010", .line = 1, .column = 1 },
        .{ .kind = .Integer, .lexeme = "0B01", .line = 1, .column = 8 },
    });
}

test "octal integer" {
    try expectTokens("0o777 0O123", &.{
        .{ .kind = .Integer, .lexeme = "0o777", .line = 1, .column = 1 },
        .{ .kind = .Integer, .lexeme = "0O123", .line = 1, .column = 7 },
    });
}

test "invalid hex literal" {
    var it = tokenize("0x");
    const tok = it.nextWith();
    try testing.expectEqual(.Error, tok.kind);
}

test "invalid binary literal" {
    var it = tokenize("0b");
    const tok = it.nextWith();
    try testing.expectEqual(.Error, tok.kind);
}

test "invalid octal literal" {
    var it = tokenize("0o");
    const tok = it.nextWith();
    try testing.expectEqual(.Error, tok.kind);
}

test "float simple" {
    try expectTokens("3.14", &.{
        .{ .kind = .FloatLiteral, .lexeme = "3.14", .line = 1, .column = 1 },
    });
}

test "float with exponent" {
    try expectTokens("1.5e10 2.0E-3 1e2", &.{
        .{ .kind = .FloatLiteral, .lexeme = "1.5e10", .line = 1, .column = 1 },
        .{ .kind = .FloatLiteral, .lexeme = "2.0E-3", .line = 1, .column = 8 },
        .{ .kind = .FloatLiteral, .lexeme = "1e2", .line = 1, .column = 15 },
    });
}

test "zero followed by dot is float" {
    try expectTokens("0.5", &.{
        .{ .kind = .FloatLiteral, .lexeme = "0.5", .line = 1, .column = 1 },
    });
}

test "single-char delimiters" {
    try expectTokens("( ) [ ] { } , ; : .", &.{
        .{ .kind = .LeftParen, .lexeme = "(", .line = 1, .column = 1 },
        .{ .kind = .RightParen, .lexeme = ")", .line = 1, .column = 3 },
        .{ .kind = .LeftBracket, .lexeme = "[", .line = 1, .column = 5 },
        .{ .kind = .RightBracket, .lexeme = "]", .line = 1, .column = 7 },
        .{ .kind = .LeftCurly, .lexeme = "{", .line = 1, .column = 9 },
        .{ .kind = .RightCurly, .lexeme = "}", .line = 1, .column = 11 },
        .{ .kind = .Comma, .lexeme = ",", .line = 1, .column = 13 },
        .{ .kind = .SemiColon, .lexeme = ";", .line = 1, .column = 15 },
        .{ .kind = .Colon, .lexeme = ":", .line = 1, .column = 17 },
        .{ .kind = .Dot, .lexeme = ".", .line = 1, .column = 19 },
    });
}

test "single-char operators" {
    try expectTokens("+ - * / % ^ ~ ?", &.{
        .{ .kind = .Plus, .lexeme = "+", .line = 1, .column = 1 },
        .{ .kind = .Minus, .lexeme = "-", .line = 1, .column = 3 },
        .{ .kind = .Multiply, .lexeme = "*", .line = 1, .column = 5 },
        .{ .kind = .Div, .lexeme = "/", .line = 1, .column = 7 },
        .{ .kind = .Modulo, .lexeme = "%", .line = 1, .column = 9 },
        .{ .kind = .BitwiseXor, .lexeme = "^", .line = 1, .column = 11 },
        .{ .kind = .Tilde, .lexeme = "~", .line = 1, .column = 13 },
        .{ .kind = .Question, .lexeme = "?", .line = 1, .column = 15 },
    });
}

test "comparison operators" {
    try expectTokens("== != < > <= >=", &.{
        .{ .kind = .IsEq, .lexeme = "==", .line = 1, .column = 1 },
        .{ .kind = .NotEq, .lexeme = "!=", .line = 1, .column = 4 },
        .{ .kind = .Less, .lexeme = "<", .line = 1, .column = 7 },
        .{ .kind = .Greater, .lexeme = ">", .line = 1, .column = 9 },
        .{ .kind = .LEq, .lexeme = "<=", .line = 1, .column = 11 },
        .{ .kind = .GEq, .lexeme = ">=", .line = 1, .column = 14 },
    });
}

test "logical operators" {
    try expectTokens("&& || !", &.{
        .{ .kind = .LogicalAnd, .lexeme = "&&", .line = 1, .column = 1 },
        .{ .kind = .LogicalOr, .lexeme = "||", .line = 1, .column = 4 },
        .{ .kind = .LogicalNot, .lexeme = "!", .line = 1, .column = 7 },
    });
}

test "bitwise operators" {
    try expectTokens("& | << >>", &.{
        .{ .kind = .BitwiseAnd, .lexeme = "&", .line = 1, .column = 1 },
        .{ .kind = .BitwiseOr, .lexeme = "|", .line = 1, .column = 3 },
        .{ .kind = .LeftShift, .lexeme = "<<", .line = 1, .column = 5 },
        .{ .kind = .RightShift, .lexeme = ">>", .line = 1, .column = 8 },
    });
}

test "assignment operators" {
    try expectTokens("= += -= *= /=", &.{
        .{ .kind = .Eq, .lexeme = "=", .line = 1, .column = 1 },
        .{ .kind = .PlusEq, .lexeme = "+=", .line = 1, .column = 3 },
        .{ .kind = .MinusEq, .lexeme = "-=", .line = 1, .column = 6 },
        .{ .kind = .MultiplyEq, .lexeme = "*=", .line = 1, .column = 9 },
        .{ .kind = .DivEq, .lexeme = "/=", .line = 1, .column = 12 },
    });
}

test "inc dec arrow" {
    try expectTokens("++ -- ->", &.{
        .{ .kind = .Inc, .lexeme = "++", .line = 1, .column = 1 },
        .{ .kind = .Dec, .lexeme = "--", .line = 1, .column = 4 },
        .{ .kind = .Arrow, .lexeme = "->", .line = 1, .column = 7 },
    });
}

test "string literal" {
    try expectTokens("\"hello\"", &.{
        .{ .kind = .String, .lexeme = "\"hello\"", .line = 1, .column = 1 },
    });
}

test "string with escape" {
    try expectTokens("\"a\\\"b\\\\n\"", &.{
        .{ .kind = .String, .lexeme = "\"a\\\"b\\\\n\"", .line = 1, .column = 1 },
    });
}

test "unterminated string" {
    var it = tokenize("\"hello");
    const tok = it.nextWith();
    try testing.expectEqual(.Error, tok.kind);
}

test "unterminated string at newline" {
    var it = tokenize("\"hello\n");
    const tok = it.nextWith();
    try testing.expectEqual(.Error, tok.kind);
}

test "char literal" {
    try expectTokens("'a' '\\n' '\\\\'", &.{
        .{ .kind = .Character, .lexeme = "'a'", .line = 1, .column = 1 },
        .{ .kind = .Character, .lexeme = "'\\n'", .line = 1, .column = 5 },
        .{ .kind = .Character, .lexeme = "'\\\\'", .line = 1, .column = 10 },
    });
}

test "unterminated char" {
    var it = tokenize("'a");
    const tok = it.nextWith();
    try testing.expectEqual(.Error, tok.kind);
}

test "empty char literal" {
    var it = tokenize("''");
    const tok = it.nextWith();
    try testing.expectEqual(.Error, tok.kind);
}

test "line comment" {
    var it = tokenize("// comment\na");
    try testing.expectEqual(.Identifier, it.next());
    try testing.expectEqual(.Eof, it.next());
}

test "block comment" {
    var it = tokenize("/* comment */ a");
    try testing.expectEqual(.Identifier, it.next());
    try testing.expectEqual(.Eof, it.next());
}

test "multiline block comment" {
    var it = tokenize("/* line1\n   line2 */ b");
    try testing.expectEqual(.Identifier, it.next());
    try testing.expectEqual(.Eof, it.next());
}

test "unterminated block comment" {
    var it = tokenize("/* oops");
    const tok = it.nextWith();
    try testing.expectEqual(.Error, tok.kind);
}

test "unexpected character" {
    var it = tokenize("@");
    const tok = it.nextWith();
    try testing.expectEqual(.Error, tok.kind);
}

test "line and column tracking" {
    try expectTokens("a\nb\nc", &.{
        .{ .kind = .Identifier, .lexeme = "a", .line = 1, .column = 1 },
        .{ .kind = .Identifier, .lexeme = "b", .line = 2, .column = 1 },
        .{ .kind = .Identifier, .lexeme = "c", .line = 3, .column = 1 },
    });
}

test "column advances correctly" {
    try expectTokens("  abc 123", &.{
        .{ .kind = .Identifier, .lexeme = "abc", .line = 1, .column = 3 },
        .{ .kind = .Integer, .lexeme = "123", .line = 1, .column = 7 },
    });
}

test "identifier after keyword" {
    var it = tokenize("intMain");
    try testing.expectEqual(.Identifier, it.next());
}

test "keyword followed by non-identifier char" {
    var it = tokenize("int;");
    try testing.expectEqual(.Int, it.next());
    try testing.expectEqual(.SemiColon, it.next());
}

test "hash and tilde tokens" {
    try expectTokens("# ~", &.{
        .{ .kind = .Hash, .lexeme = "#", .line = 1, .column = 1 },
        .{ .kind = .Tilde, .lexeme = "~", .line = 1, .column = 3 },
    });
}

test "tokenize realistic snippet" {
    try expectTokens(
        \\int main() {
        \\    return 42;
        \\}
    , &.{
        .{ .kind = .Int, .lexeme = "int", .line = 1, .column = 1 },
        .{ .kind = .Identifier, .lexeme = "main", .line = 1, .column = 5 },
        .{ .kind = .LeftParen, .lexeme = "(", .line = 1, .column = 9 },
        .{ .kind = .RightParen, .lexeme = ")", .line = 1, .column = 10 },
        .{ .kind = .LeftCurly, .lexeme = "{", .line = 1, .column = 12 },
        .{ .kind = .Return, .lexeme = "return", .line = 2, .column = 5 },
        .{ .kind = .Integer, .lexeme = "42", .line = 2, .column = 12 },
        .{ .kind = .SemiColon, .lexeme = ";", .line = 2, .column = 14 },
        .{ .kind = .RightCurly, .lexeme = "}", .line = 3, .column = 1 },
    });
}

test "tokenize with comment skipping" {
    try expectTokens(
        \\// header comment
        \\int x = 1; // inline
        \\/* block */
        \\y = 2.0;
    , &.{
        .{ .kind = .Int, .lexeme = "int", .line = 2, .column = 1 },
        .{ .kind = .Identifier, .lexeme = "x", .line = 2, .column = 5 },
        .{ .kind = .Eq, .lexeme = "=", .line = 2, .column = 7 },
        .{ .kind = .Integer, .lexeme = "1", .line = 2, .column = 9 },
        .{ .kind = .SemiColon, .lexeme = ";", .line = 2, .column = 10 },
        .{ .kind = .Identifier, .lexeme = "y", .line = 4, .column = 1 },
        .{ .kind = .Eq, .lexeme = "=", .line = 4, .column = 3 },
        .{ .kind = .FloatLiteral, .lexeme = "2.0", .line = 4, .column = 5 },
        .{ .kind = .SemiColon, .lexeme = ";", .line = 4, .column = 8 },
    });
}

test "consecutive multi-char operators" {
    try expectTokens("==!=<=>=&&||<<>>", &.{
        .{ .kind = .IsEq, .lexeme = "==", .line = 1, .column = 1 },
        .{ .kind = .NotEq, .lexeme = "!=", .line = 1, .column = 3 },
        .{ .kind = .LEq, .lexeme = "<=", .line = 1, .column = 5 },
        .{ .kind = .GEq, .lexeme = ">=", .line = 1, .column = 7 },
        .{ .kind = .LogicalAnd, .lexeme = "&&", .line = 1, .column = 9 },
        .{ .kind = .LogicalOr, .lexeme = "||", .line = 1, .column = 11 },
        .{ .kind = .LeftShift, .lexeme = "<<", .line = 1, .column = 13 },
        .{ .kind = .RightShift, .lexeme = ">>", .line = 1, .column = 15 },
    });
}

test "zero is integer" {
    try expectTokens("0", &.{
        .{ .kind = .Integer, .lexeme = "0", .line = 1, .column = 1 },
    });
}

test "dot alone is Dot token" {
    try expectTokens(".", &.{
        .{ .kind = .Dot, .lexeme = ".", .line = 1, .column = 1 },
    });
}

test "error message for unterminated string" {
    var it = tokenize("\"hello");
    _ = it.nextWith();
    try testing.expectEqualStrings("unterminated string literal", it.lexer.err_msg.?);
}

test "error message for unexpected char" {
    var it = tokenize("@");
    _ = it.nextWith();
    try testing.expectEqualStrings("unexpected character", it.lexer.err_msg.?);
}

test "error message for unterminated block comment" {
    var it = tokenize("/* hello");
    _ = it.nextWith();
    try testing.expectEqualStrings("unterminated block comment", it.lexer.err_msg.?);
}

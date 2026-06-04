const std = @import("std");
pub const TokenKind = @import("token.zig").TokenKind;
pub const Token = @import("token.zig").Token;

pub const Lexer = struct {
    source: []const u8,
    pos: usize,
    line: u32,
    column: u32,
    err_msg: ?[]const u8,
    tok_start: usize,
    tok_line: u32,
    tok_col: u32,

    pub fn init(source: []const u8) Lexer {
        return .{
            .source = source,
            .pos = 0,
            .line = 1,
            .column = 1,
            .err_msg = null,
            .tok_start = 0,
            .tok_line = 0,
            .tok_col = 0,
        };
    }

    pub fn next(self: *Lexer) Token {
        self.skipWhitespace();
        self.err_msg = null;

        if (self.pos >= self.source.len) {
            return .{
                .kind = .Eof,
                .lexeme = "",
                .line = self.line,
                .column = self.column,
            };
        }

        self.tok_start = self.pos;
        self.tok_line = self.line;
        self.tok_col = self.column;
        const c = self.advance();

        return switch (c) {
            'a'...'z', 'A'...'Z', '_' => self.readIdentifier(),
            '0'...'9' => self.readNumber(),
            '"' => self.readString(),
            '\'' => self.readChar(),
            '/' => self.readSlash(),
            '+' => self.readPlus(),
            '-' => self.readMinus(),
            '*' => self.readMaybeEq(.Multiply, .MultiplyEq),
            '%' => self.singleToken(.Modulo),
            '&' => self.readMaybeDouble(.BitwiseAnd, .LogicalAnd),
            '|' => self.readMaybeDouble(.BitwiseOr, .LogicalOr),
            '^' => self.singleToken(.BitwiseXor),
            '~' => self.singleToken(.Tilde),
            '!' => self.readMaybeEq(.LogicalNot, .NotEq),
            '=' => self.readMaybeEq(.Eq, .IsEq),
            '<' => self.readLess(),
            '>' => self.readGreater(),
            '?' => self.singleToken(.Question),
            '#' => self.singleToken(.Hash),
            '.' => self.singleToken(.Dot),
            ',' => self.singleToken(.Comma),
            ';' => self.singleToken(.SemiColon),
            ':' => self.singleToken(.Colon),
            '(' => self.singleToken(.LeftParen),
            ')' => self.singleToken(.RightParen),
            '{' => self.singleToken(.LeftCurly),
            '}' => self.singleToken(.RightCurly),
            '[' => self.singleToken(.LeftBracket),
            ']' => self.singleToken(.RightBracket),
            else => self.errorToken("unexpected character"),
        };
    }

    fn advance(self: *Lexer) u8 {
        const c = self.source[self.pos];
        self.pos += 1;
        if (c == '\n') {
            self.line += 1;
            self.column = 1;
        } else {
            self.column += 1;
        }
        return c;
    }

    fn peek(self: *const Lexer) ?u8 {
        if (self.pos >= self.source.len) return null;
        return self.source[self.pos];
    }

    fn skipWhitespace(self: *Lexer) void {
        while (self.peek()) |c| {
            switch (c) {
                ' ', '\t', '\r', '\n' => _ = self.advance(),
                else => break,
            }
        }
    }

    fn currentLexeme(self: *Lexer) []const u8 {
        return self.source[self.tok_start..self.pos];
    }

    fn singleToken(self: *Lexer, kind: TokenKind) Token {
        return .{
            .kind = kind,
            .lexeme = self.currentLexeme(),
            .line = self.tok_line,
            .column = self.tok_col,
        };
    }

    fn errorToken(self: *Lexer, msg: []const u8) Token {
        self.err_msg = msg;
        return .{
            .kind = .Error,
            .lexeme = self.currentLexeme(),
            .line = self.tok_line,
            .column = self.tok_col,
        };
    }

    fn readIdentifier(self: *Lexer) Token {
        while (self.peek()) |c| {
            switch (c) {
                'a'...'z', 'A'...'Z', '0'...'9', '_' => _ = self.advance(),
                else => break,
            }
        }
        const lexeme = self.currentLexeme();
        const kind = classifyKeyword(lexeme) orelse .Identifier;
        return self.singleToken(kind);
    }

    fn readNumber(self: *Lexer) Token {
        if (self.source[self.tok_start] == '0') {
            if (self.peek()) |c2| {
                switch (c2) {
                    'x', 'X' => {
                        _ = self.advance();
                        return self.readHex();
                    },
                    'b', 'B' => {
                        _ = self.advance();
                        return self.readBinary();
                    },
                    'o', 'O' => {
                        _ = self.advance();
                        return self.readOctal();
                    },
                    else => {},
                }
            }
        }

        while (self.peek()) |c| {
            switch (c) {
                '0'...'9' => _ = self.advance(),
                else => break,
            }
        }

        if (self.peek()) |c2| {
            if (c2 == '.') {
                _ = self.advance();
                return self.readFloatFrac();
            }
            if (c2 == 'e' or c2 == 'E') {
                _ = self.advance();
                return self.readFloatExp();
            }
        }

        return self.singleToken(.Integer);
    }

    fn readHex(self: *Lexer) Token {
        while (self.peek()) |c| {
            switch (c) {
                '0'...'9', 'a'...'f', 'A'...'F' => _ = self.advance(),
                else => break,
            }
        }
        if (self.pos == self.tok_start + 2) {
            return self.errorToken("invalid hex literal");
        }
        return self.singleToken(.Integer);
    }

    fn readBinary(self: *Lexer) Token {
        while (self.peek()) |c| {
            switch (c) {
                '0', '1' => _ = self.advance(),
                else => break,
            }
        }
        if (self.pos == self.tok_start + 2) {
            return self.errorToken("invalid binary literal");
        }
        return self.singleToken(.Integer);
    }

    fn readOctal(self: *Lexer) Token {
        while (self.peek()) |c| {
            switch (c) {
                '0'...'7' => _ = self.advance(),
                else => break,
            }
        }
        if (self.pos == self.tok_start + 2) {
            return self.errorToken("invalid octal literal");
        }
        return self.singleToken(.Integer);
    }

    fn readFloatFrac(self: *Lexer) Token {
        while (self.peek()) |c| {
            switch (c) {
                '0'...'9' => _ = self.advance(),
                else => break,
            }
        }
        if (self.peek()) |c2| {
            if (c2 == 'e' or c2 == 'E') {
                _ = self.advance();
                return self.readFloatExp();
            }
        }
        return self.singleToken(.FloatLiteral);
    }

    fn readFloatExp(self: *Lexer) Token {
        if (self.peek()) |c2| {
            if (c2 == '+' or c2 == '-') {
                _ = self.advance();
            }
        }
        while (self.peek()) |c| {
            switch (c) {
                '0'...'9' => _ = self.advance(),
                else => break,
            }
        }
        return self.singleToken(.FloatLiteral);
    }

    fn readString(self: *Lexer) Token {
        while (self.peek()) |c| {
            switch (c) {
                '"' => {
                    _ = self.advance();
                    return self.singleToken(.String);
                },
                '\\' => {
                    _ = self.advance();
                    if (self.peek()) |_| _ = self.advance();
                },
                '\n' => return self.errorToken("unterminated string literal"),
                else => _ = self.advance(),
            }
        }
        return self.errorToken("unterminated string literal");
    }

    fn readChar(self: *Lexer) Token {
        if (self.peek()) |c2| {
            _ = self.advance();
            if (c2 == '\\') {
                if (self.peek()) |_| _ = self.advance();
            }
            if (self.peek()) |c| {
                if (c == '\'') {
                    _ = self.advance();
                    return self.singleToken(.Character);
                }
            }
            return self.errorToken("unterminated char literal");
        }
        return self.errorToken("unterminated char literal");
    }

    fn readSlash(self: *Lexer) Token {
        if (self.peek()) |c2| {
            switch (c2) {
                '/' => {
                    _ = self.advance();
                    while (self.peek()) |c| {
                        if (c == '\n') break;
                        _ = self.advance();
                    }
                    return self.next();
                },
                '*' => {
                    _ = self.advance();
                    return self.readBlockComment();
                },
                '=' => {
                    _ = self.advance();
                    return self.singleToken(.DivEq);
                },
                else => {},
            }
        }
        return self.singleToken(.Div);
    }

    fn readBlockComment(self: *Lexer) Token {
        while (self.peek()) |c| {
            if (c == '*') {
                _ = self.advance();
                if (self.peek()) |c2| {
                    if (c2 == '/') {
                        _ = self.advance();
                        return self.next();
                    }
                }
            } else {
                _ = self.advance();
            }
        }
        return self.errorToken("unterminated block comment");
    }

    fn readPlus(self: *Lexer) Token {
        if (self.peek()) |c2| {
            switch (c2) {
                '+' => {
                    _ = self.advance();
                    return self.singleToken(.Inc);
                },
                '=' => {
                    _ = self.advance();
                    return self.singleToken(.PlusEq);
                },
                else => {},
            }
        }
        return self.singleToken(.Plus);
    }

    fn readMinus(self: *Lexer) Token {
        if (self.peek()) |c2| {
            switch (c2) {
                '-' => {
                    _ = self.advance();
                    return self.singleToken(.Dec);
                },
                '=' => {
                    _ = self.advance();
                    return self.singleToken(.MinusEq);
                },
                '>' => {
                    _ = self.advance();
                    return self.singleToken(.Arrow);
                },
                else => {},
            }
        }
        return self.singleToken(.Minus);
    }

    fn readMaybeEq(self: *Lexer, single: TokenKind, eq: TokenKind) Token {
        if (self.peek()) |c2| {
            if (c2 == '=') {
                _ = self.advance();
                return self.singleToken(eq);
            }
        }
        return self.singleToken(single);
    }

    fn readMaybeDouble(self: *Lexer, single: TokenKind, double: TokenKind) Token {
        if (self.peek()) |c2| {
            if (c2 == self.source[self.tok_start]) {
                _ = self.advance();
                return self.singleToken(double);
            }
        }
        return self.singleToken(single);
    }

    fn readLess(self: *Lexer) Token {
        if (self.peek()) |c2| {
            switch (c2) {
                '=' => {
                    _ = self.advance();
                    return self.singleToken(.LEq);
                },
                '<' => {
                    _ = self.advance();
                    return self.singleToken(.LeftShift);
                },
                else => {},
            }
        }
        return self.singleToken(.Less);
    }

    fn readGreater(self: *Lexer) Token {
        if (self.peek()) |c2| {
            switch (c2) {
                '=' => {
                    _ = self.advance();
                    return self.singleToken(.GEq);
                },
                '>' => {
                    _ = self.advance();
                    return self.singleToken(.RightShift);
                },
                else => {},
            }
        }
        return self.singleToken(.Greater);
    }
};

fn classifyKeyword(lexeme: []const u8) ?TokenKind {
    const kw = std.StaticStringMap(TokenKind).initComptime(.{
        .{ "if", .If },
        .{ "else", .Else },
        .{ "while", .While },
        .{ "int", .Int },
        .{ "float", .Float },
        .{ "bool", .Bool },
        .{ "char", .Char },
        .{ "return", .Return },
        .{ "void", .Void },
        .{ "true", .True },
        .{ "false", .False },
    });
    return kw.get(lexeme);
}

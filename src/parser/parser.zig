const std = @import("std");
const Token = @import("../lexer/token.zig").Token;
const TokenKind = @import("../lexer/token.zig").TokenKind;

pub const Parser = struct {
    allocator: std.mem.Allocator,
    tokens: []const Token,
    pos: usize,

    pub fn init(allocator: std.mem.Allocator, tokens: []const Token) Parser {
        return .{
            .allocator = allocator,
            .tokens = tokens,
            .pos = 0,
        };
    }

    pub fn current(self: *const Parser) Token {
        if (self.pos >= self.tokens.len) return .{ .kind = .Eof, .lexeme = "", .line = 0, .column = 0 };
        return self.tokens[self.pos];
    }

    pub fn advance(self: *Parser) Token {
        const tok = self.current();
        self.pos += 1;
        return tok;
    }

    pub fn expect(self: *Parser, kind: TokenKind) anyerror!Token {
        const tok = self.current();
        if (tok.kind != kind) return error.UnexpectedToken;
        return self.advance();
    }
};

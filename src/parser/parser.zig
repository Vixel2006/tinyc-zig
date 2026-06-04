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

    fn current(self: *const Parser) Token {
        if (self.pos >= self.tokens.len) return .{ .kind = .Eof, .lexeme = "", .line = 0, .column = 0 };
        return self.tokens[self.pos];
    }

    fn advance(self: *Parser) Token {
        const tok = self.current();
        self.pos += 1;
        return tok;
    }

    fn expect(self: *Parser, kind: TokenKind) !Token {
        const tok = self.current();
        if (tok.kind != kind) return error.UnexpectedToken;
        return self.advance();
    }
};

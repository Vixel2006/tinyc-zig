const std = @import("std");
const Token = @import("lexer/token.zig").Token;

pub const errors = error{
    LexerError,
    ParserError,
};

pub fn print_syntax_err(curr: Token, msg: []const u8) void {
    std.debug.print("Syntax error at line {}, col {}: {s}", .{ curr.line, curr.column, msg });
}

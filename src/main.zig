const std = @import("std");
const Lexer = @import("tinyc").Lexer;
const TokenKind = @import("tinyc").TokenKind;

pub fn main() !void {
    const source =
        \\int main() {
        \\    // greet
        \\    return 42;
        \\}
    ;

    var lexer = Lexer.init(source);

    while (true) {
        const tok = lexer.next();
        if (tok.kind == .Eof) break;
        std.debug.print("{s} \"{s}\" {d}:{d}\n", .{
            @tagName(tok.kind),
            tok.lexeme,
            tok.line,
            tok.column,
        });
        if (tok.kind == .Error) {
            if (lexer.err_msg) |msg| {
                std.debug.print("  error: {s}\n", .{msg});
            }
        }
    }
}

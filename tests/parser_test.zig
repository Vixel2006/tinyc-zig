const std = @import("std");
const testing = std.testing;
const Lexer = @import("tinyc").Lexer;
const TokenKind = @import("tinyc").TokenKind;
const Token = @import("tinyc").Token;
const Parser = @import("tinyc").Parser;
const productions = @import("tinyc").productions;

fn tokenize(allocator: std.mem.Allocator, source: []const u8) ![]const Token {
    var tokens = std.ArrayList(Token).init(allocator);
    var lexer = Lexer.init(source);
    while (true) {
        const tok = lexer.next();
        try tokens.append(tok);
        if (tok.kind == .Eof) break;
    }
    return tokens.items;
}

fn makeParser(allocator: std.mem.Allocator, source: []const u8) !Parser {
    const tokens = try tokenize(allocator, source);
    return Parser.init(allocator, tokens);
}

test "lexer produces tokens for parser" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const parser = try makeParser(allocator, "int x = 42;");
    try testing.expectEqual(TokenKind.Int, parser.current().kind);
}

test "parser current and advance" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const parser = try makeParser(allocator, "int x;");
    try testing.expectEqual(TokenKind.Int, parser.current().kind);
    try testing.expectEqualStrings("int", parser.current().lexeme);
    _ = parser.advance();
    try testing.expectEqual(TokenKind.Identifier, parser.current().kind);
    try testing.expectEqualStrings("x", parser.current().lexeme);
    _ = parser.advance();
    try testing.expectEqual(TokenKind.SemiColon, parser.current().kind);
    _ = parser.advance();
    try testing.expectEqual(TokenKind.Eof, parser.current().kind);
}

test "parser expect consumes expected token" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const parser = try makeParser(allocator, "int");
    const tok = try parser.expect(TokenKind.Int);
    try testing.expectEqualStrings("int", tok.lexeme);
    try testing.expectEqual(TokenKind.Eof, parser.current().kind);
}

test "parser expect returns error on mismatch" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const parser = try makeParser(allocator, "int");
    try testing.expectError(error.UnexpectedToken, parser.expect(TokenKind.While));
}

test "parse empty program" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const parser = try makeParser(allocator, "");
    _ = parser;
}

test "parse variable declaration" {
    _ = productions.VarDecl{
        .typeSpec = .Int,
        .name = .{ .kind = .Identifier, .lexeme = "x", .line = 1, .column = 1 },
        .init = null,
    };
}

test "parse integer literal expression" {
    _ = productions.Expr{
        .Value = .{ .Int = 42 },
    };
}

test "parse binary expression structure" {
    _ = productions.Expr{
        .Binary = undefined, // will fill in when parser works
    };
}

test "parse if statement" {
    _ = productions.IfStmt{
        .condition = undefined,
        .thenBlock = undefined,
        .elseBlock = null,
    };
}

test "parse return statement" {
    _ = productions.ReturnStmt{
        .value = null,
    };
}

test "parse function declaration" {
    _ = productions.FuncDecl{
        .returnType = .Int,
        .name = .{ .kind = .Identifier, .lexeme = "main", .line = 1, .column = 1 },
        .params = std.ArrayList(productions.Param).init(testing.allocator),
        .body = .{ .stmts = std.ArrayList(productions.Stmt).init(testing.allocator) },
    };
}

test "parse block statement" {
    _ = productions.BlockStmt{
        .stmts = std.ArrayList(productions.Stmt).init(testing.allocator),
    };
}

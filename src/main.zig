const std = @import("std");
const Lexer = @import("tinyc").Lexer;
const Token = @import("tinyc").Token;
const Parser = @import("tinyc").Parser;
const productions = @import("tinyc").productions;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const source =
        \\int main() {
        \\    int x = 0;
        \\    if (x == -1) {
        \\        x = 1;
        \\    }
        \\    // greet
        \\    return x;
        \\}
    ;

    var token_count: usize = 0;
    {
        var counter = Lexer.init(source);
        while (true) {
            const tok = counter.next();
            token_count += 1;
            if (tok.kind == .Eof) break;
        }
    }

    var tokens = try allocator.alloc(Token, token_count);
    {
        var collector = Lexer.init(source);
        var i: usize = 0;
        while (true) {
            const tok = collector.next();
            tokens[i] = tok;
            i += 1;
            if (tok.kind == .Eof) break;
            if (tok.kind == .Error) {
                std.debug.print("Lexer error: {s}\n", .{if (collector.err_msg) |m| m else "unknown"});
                return;
            }
        }
    }

    var parser = Parser.init(allocator, tokens);
    const program = productions.Program.parse(&parser) catch {
        std.debug.print("Parse error\n", .{});
        return;
    };

    dumpProgram(program, 0);
}

fn dumpIndent(indent: usize) void {
    var i: usize = 0;
    while (i < indent) : (i += 1) {
        std.debug.print("  ", .{});
    }
}

fn dumpProgram(prog: productions.Program, indent: usize) void {
    dumpIndent(indent);
    std.debug.print("Program\n", .{});
    for (prog.declarations.items) |decl| {
        dumpDecl(decl, indent + 1);
    }
}

fn dumpDecl(decl: productions.Decl, indent: usize) void {
    switch (decl) {
        .Func => |f| {
            dumpIndent(indent);
            std.debug.print("FuncDecl\n", .{});
            dumpIndent(indent + 1);
            std.debug.print("returnType: {s}\n", .{@tagName(f.returnType)});
            dumpIndent(indent + 1);
            std.debug.print("name: {s}\n", .{f.name.lexeme});
            dumpIndent(indent + 1);
            std.debug.print("params:\n", .{});
            for (f.params.items) |param| {
                dumpParam(param, indent + 2);
            }
            dumpIndent(indent + 1);
            std.debug.print("body:\n", .{});
            dumpBlockStmt(f.body, indent + 2);
        },
        .Var => |v| {
            dumpIndent(indent);
            std.debug.print("VarDecl\n", .{});
            dumpIndent(indent + 1);
            std.debug.print("type: {s}\n", .{@tagName(v.typeSpec)});
            dumpIndent(indent + 1);
            std.debug.print("name: {s}\n", .{v.name.lexeme});
            if (v.init) |init| {
                dumpIndent(indent + 1);
                std.debug.print("init:\n", .{});
                dumpExpr(init.*, indent + 2);
            }
        },
    }
}

fn dumpParam(param: productions.Param, indent: usize) void {
    dumpIndent(indent);
    std.debug.print("Param\n", .{});
    dumpIndent(indent + 1);
    std.debug.print("type: {s}\n", .{@tagName(param.typeSpec)});
    dumpIndent(indent + 1);
    std.debug.print("name: {s}\n", .{param.name.lexeme});
}

fn dumpBlockStmt(block: productions.BlockStmt, indent: usize) void {
    dumpIndent(indent);
    std.debug.print("BlockStmt\n", .{});
    for (block.stmts.items) |stmt| {
        dumpStmt(stmt, indent + 1);
    }
}

fn dumpStmt(stmt: productions.Stmt, indent: usize) void {
    switch (stmt) {
        .Decl => |d| dumpDecl(d, indent),
        .Assign => |a| {
            dumpIndent(indent);
            std.debug.print("AssignStmt\n", .{});
            dumpIndent(indent + 1);
            std.debug.print("target: {s}\n", .{a.target.lexeme});
            dumpIndent(indent + 1);
            std.debug.print("value:\n", .{});
            dumpExpr(a.value.*, indent + 2);
        },
        .If => |i| {
            dumpIndent(indent);
            std.debug.print("IfStmt\n", .{});
            dumpIndent(indent + 1);
            std.debug.print("condition:\n", .{});
            dumpExpr(i.condition.*, indent + 2);
            dumpIndent(indent + 1);
            std.debug.print("then:\n", .{});
            dumpStmt(i.thenBlock, indent + 2);
            if (i.elseBlock) |else_blk| {
                dumpIndent(indent + 1);
                std.debug.print("else:\n", .{});
                dumpStmt(else_blk.*, indent + 2);
            }
        },
        .While => |w| {
            dumpIndent(indent);
            std.debug.print("WhileStmt\n", .{});
            dumpIndent(indent + 1);
            std.debug.print("condition:\n", .{});
            dumpExpr(w.condition.*, indent + 2);
            dumpIndent(indent + 1);
            std.debug.print("body:\n", .{});
            dumpStmt(w.body.*, indent + 2);
        },
        .Return => |r| {
            dumpIndent(indent);
            std.debug.print("ReturnStmt\n", .{});
            if (r.value) |val| {
                dumpIndent(indent + 1);
                std.debug.print("value:\n", .{});
                dumpExpr(val.*, indent + 2);
            }
        },
        .Expr => |e| {
            dumpIndent(indent);
            std.debug.print("ExprStmt\n", .{});
            dumpExpr(e.*, indent + 1);
        },
        .Block => |b| {
            dumpBlockStmt(b.*, indent);
        },
    }
}

fn dumpExpr(expr: productions.Expr, indent: usize) void {
    switch (expr) {
        .Value => |v| {
            dumpIndent(indent);
            switch (v) {
                .Int => |i| std.debug.print("Value {d}\n", .{i}),
                .Float => |f| std.debug.print("Value {d}\n", .{f}),
                .Bool => |b| std.debug.print("Value {}\n", .{b}),
                .Char => |c| std.debug.print("Value '{c}'\n", .{c}),
                .String => |s| std.debug.print("Value \"{s}\"\n", .{s}),
            }
        },
        .Identifier => |id| {
            dumpIndent(indent);
            std.debug.print("Identifier \"{s}\"\n", .{id.lexeme});
        },
        .Binary => |b| {
            dumpIndent(indent);
            std.debug.print("BinaryExpr ({s})\n", .{@tagName(b.op)});
            dumpExpr(b.left.*, indent + 1);
            dumpExpr(b.right.*, indent + 1);
        },
        .Unary => |u| {
            dumpIndent(indent);
            std.debug.print("UnaryExpr ({s})\n", .{@tagName(u.op)});
            dumpExpr(u.operand.*, indent + 1);
        },
        .Paren => |p| {
            dumpIndent(indent);
            std.debug.print("ParenExpr\n", .{});
            dumpExpr(p.*, indent + 1);
        },
        .Call => |c| {
            dumpIndent(indent);
            std.debug.print("CallExpr \"{s}\"\n", .{c.callee.lexeme});
            for (c.args.items) |arg| {
                dumpExpr(arg, indent + 1);
            }
        },
        .Assign => |a| {
            dumpIndent(indent);
            std.debug.print("AssignExpr\n", .{});
            dumpIndent(indent + 1);
            std.debug.print("target: {s}\n", .{a.target.lexeme});
            dumpIndent(indent + 1);
            std.debug.print("value:\n", .{});
            dumpExpr(a.value.*, indent + 2);
        },
    }
}

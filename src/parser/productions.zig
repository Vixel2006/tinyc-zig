const std = @import("std");
const Token = @import("../lexer/token.zig").Token;
const TokenKind = @import("../lexer/token.zig").TokenKind;
const Parser = @import("parser.zig").Parser;
const utils = @import("../utils.zig");

pub const TypeSpec = enum(u8) {
    Int,
    Float,
    Bool,
    Char,
    Void,
};

pub const Literal = union(enum) {
    Int: i32,
    Float: f64,
    Bool: bool,
    Char: u8,
    String: []const u8,
};

pub const BinaryOp = enum(u8) {
    Add,
    Sub,
    Mul,
    Div,
    Equal,
    NotEqual,
    Greater,
    Less,
    GreaterEqual,
    LessEqual,
    LogicalAnd,
    LogicalOr,
    BitAnd,
    BitOr,
    BitXor,
    LeftShift,
    RightShift,
};

pub const UnaryOp = enum(u8) {
    Negate,
    Not,
    BitNot,
};

pub const BinaryExpr = struct {
    op: BinaryOp,
    left: *Expr,
    right: *Expr,

    pub fn parse(parser: *Parser, left: *Expr) !BinaryExpr {
        const tok = parser.current();
        const op: BinaryOp = switch (tok.kind) {
            .Plus => .Add,
            .Minus => .Sub,
            .Multiply => .Mul,
            .Div => .Div,
            .IsEq => .Equal,
            .NotEq => .NotEqual,
            .Greater => .Greater,
            .Less => .Less,
            .GEq => .GreaterEqual,
            .LEq => .LessEqual,
            .LogicalAnd => .LogicalAnd,
            .LogicalOr => .LogicalOr,
            .BitwiseAnd => .BitAnd,
            .BitwiseOr => .BitOr,
            .BitwiseXor => .BitXor,
            .LeftShift => .LeftShift,
            .RightShift => .RightShift,
            else => {
                utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: expected binary operator");
                return utils.errors.ParserError;
            },
        };
        _ = parser.advance();

        const right = try Expr.parse(parser);

        return BinaryExpr{ .op = op, .left = left, .right = right };
    }
};

pub const UnaryExpr = struct {
    op: UnaryOp,
    operand: *Expr,

    pub fn parse(parser: *Parser) !UnaryExpr {
        const tok = parser.current();
        const op: UnaryOp = switch (tok.kind) {
            .Minus => .Negate,
            .LogicalNot => .Not,
            .BitwiseNot => .BitNot,
            else => {
                utils.print_syntax_err(tok, "syntax error at line {} col {}: expected unary operator");
                return utils.errors.ParserError;
            },
        };
        _ = parser.advance();

        const operand = try Expr.parse(parser);

        return UnaryExpr{ .op = op, .operand = operand };
    }
};

pub const CallExpr = struct {
    callee: Token,
    args: std.ArrayList(Expr),

    pub fn parse(parser: *Parser, callee: Token) !CallExpr {
        _ = parser.expect(TokenKind.LeftParen) catch |err| switch (err) {
            error.UnexpectedToken => {
                utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: expected ( after function call");
                return utils.errors.ParserError;
            },
            else => {
                std.debug.print("error parsing call expression: {}", .{err});
                return utils.errors.ParserError;
            },
        };

        var args: std.ArrayList(Expr) = .empty;
        if (parser.current().kind != TokenKind.RightParen) {
            while (true) {
                const arg = try Expr.parse(parser);
                try args.append(parser.allocator, arg);
                if (parser.current().kind == TokenKind.Comma) {
                    _ = parser.advance();
                } else {
                    break;
                }
            }
        }

        _ = parser.expect(TokenKind.RightParen) catch |err| switch (err) {
            error.UnexpectedToken => {
                utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: expected ) after function arguments");
                return utils.errors.ParserError;
            },
            else => {
                std.debug.print("error parsing call expression: {}", .{err});
                return utils.errors.ParserError;
            },
        };

        return CallExpr{ .callee = callee, .args = args };
    }
};

pub const AssignExpr = struct {
    target: Token,
    value: *Expr,

    pub fn parse(parser: *Parser, target: Token) !AssignExpr {
        _ = parser.advance();

        const expr = try parser.allocator.create(Expr);
        expr.* = try Expr.parse(parser);

        return AssignExpr{ .target = target, .value = expr };
    }
};

pub const Expr = union(enum) {
    Value: Literal,
    Identifier: Token,
    Binary: *BinaryExpr,
    Unary: *UnaryExpr,
    Paren: *Expr,
    Call: *CallExpr,
    Assign: *AssignExpr,

    pub fn parse(parser: *Parser) !Expr {
        return parseExpr(parser, 0);
    }
};

fn precedence(kind: TokenKind) ?u8 {
    return switch (kind) {
        .Eq => 1,
        .LogicalOr => 2,
        .LogicalAnd => 3,
        .BitwiseOr => 4,
        .BitwiseXor => 5,
        .BitwiseAnd => 6,
        .IsEq, .NotEq => 7,
        .Greater, .Less, .GEq, .LEq => 8,
        .LeftShift, .RightShift => 9,
        .Plus, .Minus => 10,
        .Multiply, .Div => 11,
        .LeftParen => 13,
        else => null,
    };
}

fn tokenToBinaryOp(kind: TokenKind) BinaryOp {
    return switch (kind) {
        .Plus => .Add,
        .Minus => .Sub,
        .Multiply => .Mul,
        .Div => .Div,
        .IsEq => .Equal,
        .NotEq => .NotEqual,
        .Greater => .Greater,
        .Less => .Less,
        .GEq => .GreaterEqual,
        .LEq => .LessEqual,
        .LogicalAnd => .LogicalAnd,
        .LogicalOr => .LogicalOr,
        .BitwiseAnd => .BitAnd,
        .BitwiseOr => .BitOr,
        .BitwiseXor => .BitXor,
        .LeftShift => .LeftShift,
        .RightShift => .RightShift,
        else => unreachable,
    };
}

fn parseExpr(parser: *Parser, minPrec: u8) anyerror!Expr {
    var left = try parsePrefix(parser);

    while (true) {
        const prec = precedence(parser.current().kind) orelse break;
        if (prec <= minPrec) break;

        const tok = parser.advance();
        switch (tok.kind) {
            .LeftParen => {
                var args: std.ArrayList(Expr) = .empty;
                if (parser.current().kind != .RightParen) {
                    while (true) {
                        const arg = try parseExpr(parser, 0);
                        try args.append(parser.allocator, arg);
                        if (parser.current().kind == .Comma) {
                            _ = parser.advance();
                        } else {
                            break;
                        }
                    }
                }

                _ = parser.expect(.RightParen) catch |err| switch (err) {
                    error.UnexpectedToken => {
                        utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: expected ) after arguments");
                        return utils.errors.ParserError;
                    },
                    else => {
                        std.debug.print("error parsing call expression: {}", .{err});
                        return utils.errors.ParserError;
                    },
                };

                const callee = switch (left) {
                    .Identifier => |t| t,
                    else => {
                        utils.print_syntax_err(tok, "syntax error: expected identifier before (");
                        return utils.errors.ParserError;
                    },
                };
                const call = try parser.allocator.create(CallExpr);
                call.* = CallExpr{ .callee = callee, .args = args };
                left = Expr{ .Call = call };
            },
            .Eq => {
                const target = switch (left) {
                    .Identifier => |t| t,
                    else => {
                        utils.print_syntax_err(tok, "syntax error: expected identifier before =");
                        return utils.errors.ParserError;
                    },
                };
                const value = try parser.allocator.create(Expr);
                value.* = try parseExpr(parser, prec - 1);
                const assign = try parser.allocator.create(AssignExpr);
                assign.* = AssignExpr{ .target = target, .value = value };
                left = Expr{ .Assign = assign };
            },
            else => {
                const op = tokenToBinaryOp(tok.kind);
                const leftPtr = try parser.allocator.create(Expr);
                leftPtr.* = left;
                const right = try parser.allocator.create(Expr);
                right.* = try parseExpr(parser, prec);
                const bin = try parser.allocator.create(BinaryExpr);
                bin.* = BinaryExpr{ .op = op, .left = leftPtr, .right = right };
                left = Expr{ .Binary = bin };
            },
        }
    }

    return left;
}

fn parsePrefix(parser: *Parser) anyerror!Expr {
    const tok = parser.current();
    switch (tok.kind) {
        .Integer => {
            _ = parser.advance();
            const val = std.fmt.parseInt(i32, tok.lexeme, 0) catch {
                utils.print_syntax_err(tok, "syntax error at line {} col {}: invalid integer literal");
                return utils.errors.ParserError;
            };
            return Expr{ .Value = .{ .Int = val } };
        },
        .FloatLiteral => {
            _ = parser.advance();
            const val = std.fmt.parseFloat(f64, tok.lexeme) catch {
                utils.print_syntax_err(tok, "syntax error at line {} col {}: invalid float literal");
                return utils.errors.ParserError;
            };
            return Expr{ .Value = .{ .Float = val } };
        },
        .True => {
            _ = parser.advance();
            return Expr{ .Value = .{ .Bool = true } };
        },
        .False => {
            _ = parser.advance();
            return Expr{ .Value = .{ .Bool = false } };
        },
        .Character => {
            _ = parser.advance();
            const val: u8 = if (tok.lexeme.len == 3 and tok.lexeme[0] == '\'')
                tok.lexeme[1]
            else if (tok.lexeme.len == 4 and tok.lexeme[0] == '\'' and tok.lexeme[1] == '\\')
                switch (tok.lexeme[2]) {
                    'n' => '\n',
                    't' => '\t',
                    '0' => 0,
                    '\\' => '\\',
                    '\'' => '\'',
                    else => {
                        utils.print_syntax_err(tok, "syntax error at line {} col {}: invalid escape sequence");
                        return utils.errors.ParserError;
                    },
                }
            else {
                utils.print_syntax_err(tok, "syntax error at line {} col {}: invalid character literal");
                return utils.errors.ParserError;
            };
            return Expr{ .Value = .{ .Char = val } };
        },
        .String => {
            _ = parser.advance();
            const val = tok.lexeme[1 .. tok.lexeme.len - 1];
            return Expr{ .Value = .{ .String = val } };
        },
        .Identifier => {
            _ = parser.advance();
            return Expr{ .Identifier = tok };
        },
        .LeftParen => {
            _ = parser.advance();
            const inner = try parseExpr(parser, 0);
            _ = parser.expect(.RightParen) catch |err| switch (err) {
                error.UnexpectedToken => {
                    utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: expected ) after expression");
                    return utils.errors.ParserError;
                },
                else => {
                    std.debug.print("error parsing parenthesized expression: {}", .{err});
                    return utils.errors.ParserError;
                },
            };
            const ptr = try parser.allocator.create(Expr);
            ptr.* = inner;
            return Expr{ .Paren = ptr };
        },
        .Minus, .LogicalNot, .BitwiseNot => {
            const op: UnaryOp = switch (tok.kind) {
                .Minus => .Negate,
                .LogicalNot => .Not,
                .BitwiseNot => .BitNot,
                else => unreachable,
            };
            _ = parser.advance();
            const operand = try parser.allocator.create(Expr);
            operand.* = try parseExpr(parser, 12);
            const unary = try parser.allocator.create(UnaryExpr);
            unary.* = UnaryExpr{ .op = op, .operand = operand };
            return Expr{ .Unary = unary };
        },
        else => {
            utils.print_syntax_err(tok, "syntax error at line {} col {}: expected expression");
            return utils.errors.ParserError;
        },
    }
}

pub const Param = struct {
    typeSpec: TypeSpec,
    name: Token,

    pub fn parse(parser: *Parser) !Param {
        const tok = parser.current();
        const typeSpec: TypeSpec = switch (tok.kind) {
            .Int => .Int,
            .Float => .Float,
            .Bool => .Bool,
            .Char => .Char,
            .Void => .Void,
            else => {
                utils.print_syntax_err(tok, "syntax error at line {} col {}: expected type specifier in parameter");
                return utils.errors.ParserError;
            },
        };
        _ = parser.advance();

        const name = parser.expect(TokenKind.Identifier) catch |err| switch (err) {
            error.UnexpectedToken => {
                utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: expected parameter name");
                return utils.errors.ParserError;
            },
            else => {
                std.debug.print("error parsing parameter: {}", .{err});
                return utils.errors.ParserError;
            },
        };

        return Param{ .typeSpec = typeSpec, .name = name };
    }
};

pub const VarDecl = struct {
    typeSpec: TypeSpec,
    name: Token,
    init: ?*Expr,

    pub fn parse(parser: *Parser, typeSpec: TypeSpec, name: Token) !VarDecl {
        var init: ?*Expr = null;
        if (parser.current().kind == TokenKind.Eq) {
            _ = parser.advance();
            const expr = try parser.allocator.create(Expr);
            expr.* = try Expr.parse(parser);
            init = expr;
        }

        _ = parser.expect(TokenKind.SemiColon) catch |err| switch (err) {
            error.UnexpectedToken => {
                utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: expected ; after variable declaration");
                return utils.errors.ParserError;
            },
            else => {
                std.debug.print("error parsing variable declaration: {}", .{err});
                return utils.errors.ParserError;
            },
        };

        return VarDecl{ .typeSpec = typeSpec, .name = name, .init = init };
    }
};

pub const FuncDecl = struct {
    returnType: TypeSpec,
    name: Token,
    params: std.ArrayList(Param),
    body: BlockStmt,

    pub fn parse(parser: *Parser, returnType: TypeSpec, name: Token) !FuncDecl {
        _ = parser.expect(TokenKind.LeftParen) catch |err| switch (err) {
            error.UnexpectedToken => {
                utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: expected ( after function name");
                return utils.errors.ParserError;
            },
            else => {
                std.debug.print("error parsing function declaration: {}", .{err});
                return utils.errors.ParserError;
            },
        };

        var params: std.ArrayList(Param) = .empty;
        if (parser.current().kind != TokenKind.RightParen) {
            while (true) {
                const param = try Param.parse(parser);
                try params.append(parser.allocator, param);
                if (parser.current().kind == TokenKind.Comma) {
                    _ = parser.advance();
                } else {
                    break;
                }
            }
        }

        _ = parser.expect(TokenKind.RightParen) catch |err| switch (err) {
            error.UnexpectedToken => {
                utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: expected ) after parameters");
                return utils.errors.ParserError;
            },
            else => {
                std.debug.print("error parsing function declaration: {}", .{err});
                return utils.errors.ParserError;
            },
        };

        const body = try BlockStmt.parse(parser);

        return FuncDecl{ .returnType = returnType, .name = name, .params = params, .body = body };
    }
};

pub const Decl = union(enum) {
    Var: VarDecl,
    Func: FuncDecl,

    pub fn parse(parser: *Parser) !Decl {
        const tok = parser.current();
        const typeSpec: TypeSpec = switch (tok.kind) {
            .Int => .Int,
            .Float => .Float,
            .Bool => .Bool,
            .Char => .Char,
            .Void => .Void,
            else => {
                utils.print_syntax_err(tok, "syntax error at line {} col {}: expected type specifier");
                return utils.errors.ParserError;
            },
        };
        _ = parser.advance();

        const name = parser.expect(TokenKind.Identifier) catch |err| switch (err) {
            error.UnexpectedToken => {
                utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: expected identifier");
                return utils.errors.ParserError;
            },
            else => {
                std.debug.print("error parsing declaration: {}", .{err});
                return utils.errors.ParserError;
            },
        };

        switch (parser.current().kind) {
            TokenKind.LeftParen => {
                return Decl{ .Func = try FuncDecl.parse(parser, typeSpec, name) };
            },
            TokenKind.Eq, TokenKind.SemiColon => {
                return Decl{ .Var = try VarDecl.parse(parser, typeSpec, name) };
            },
            else => {
                utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: expected (, =, or ; after identifier in declaration");
                return utils.errors.ParserError;
            },
        }
    }
};

pub const IfStmt = struct {
    condition: *Expr,
    thenBlock: Stmt,
    elseBlock: ?*Stmt,

    pub fn parse(parser: *Parser) anyerror!IfStmt {
        _ = parser.expect(TokenKind.LeftParen) catch |err| switch (err) {
            error.UnexpectedToken => {
                utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: expected ( after if keyword");
                return utils.errors.ParserError;
            },
            else => {
                std.debug.print("error parsing if statement: {}", .{err});
                return utils.errors.ParserError;
            },
        };

        const condition = try parser.allocator.create(Expr);
        condition.* = try Expr.parse(parser);

        _ = parser.expect(TokenKind.RightParen) catch |err| switch (err) {
            error.UnexpectedToken => {
                utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: a '(' without closing ')'");
                return utils.errors.ParserError;
            },
            else => {
                std.debug.print("error parsing if statement: {}", .{err});
                return utils.errors.ParserError;
            },
        };

        const thenBlock = try Stmt.parse(parser);

        var elseBlock: ?*Stmt = null;
        if (parser.current().kind == TokenKind.Else) {
            _ = parser.advance();
            const stmt = try parser.allocator.create(Stmt);
            stmt.* = try Stmt.parse(parser);
            elseBlock = stmt;
        }

        return IfStmt{ .condition = condition, .thenBlock = thenBlock, .elseBlock = elseBlock };
    }
};

pub const WhileStmt = struct {
    condition: *Expr,
    body: *Stmt,

    pub fn parse(parser: *Parser) anyerror!WhileStmt {
        _ = parser.expect(TokenKind.LeftParen) catch |err| switch (err) {
            error.UnexpectedToken => {
                utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: expected ( after while keyword but got {}");
                return utils.errors.ParserError;
            },
            else => {
                std.debug.print("error parsing while statement: {}", .{err});
                return utils.errors.ParserError;
            },
        };

        const expr = try parser.allocator.create(Expr);
        expr.* = try Expr.parse(parser);

        _ = parser.expect(TokenKind.RightParen) catch |err| switch (err) {
            error.UnexpectedToken => {
                utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: a '(' without closing ')'");
                return utils.errors.ParserError;
            },

            else => {
                std.debug.print("error parsing while statement: {}", .{err});
                return utils.errors.ParserError;
            },
        };

        const body = try parser.allocator.create(Stmt);
        body.* = try Stmt.parse(parser);

        return WhileStmt{ .condition = expr, .body = body };
    }
};

pub const ReturnStmt = struct {
    value: ?*Expr,

    pub fn parse(parser: *Parser) !ReturnStmt {
        var value: ?*Expr = null;
        if (parser.current().kind != TokenKind.SemiColon) {
            const expr = try parser.allocator.create(Expr);
            expr.* = try Expr.parse(parser);
            value = expr;
        }

        _ = parser.expect(TokenKind.SemiColon) catch |err| switch (err) {
            error.UnexpectedToken => {
                utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: expected ; after return statement");
                return utils.errors.ParserError;
            },
            else => {
                std.debug.print("error parsing return statement: {}", .{err});
                return utils.errors.ParserError;
            },
        };

        return ReturnStmt{ .value = value };
    }
};

pub const BlockStmt = struct {
    stmts: std.ArrayList(Stmt),

    pub fn parse(parser: *Parser) anyerror!BlockStmt {
        _ = parser.expect(TokenKind.LeftCurly) catch |err| switch (err) {
            error.UnexpectedToken => {
                utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: expected {");
                return utils.errors.ParserError;
            },
            else => {
                std.debug.print("error parsing block statement: {}", .{err});
                return utils.errors.ParserError;
            },
        };

        var stmts: std.ArrayList(Stmt) = .empty;
        while (parser.current().kind != TokenKind.RightCurly) {
            const stmt = try Stmt.parse(parser);
            try stmts.append(parser.allocator, stmt);
        }

        _ = parser.expect(TokenKind.RightCurly) catch |err| switch (err) {
            error.UnexpectedToken => {
                utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: expected }");
                return utils.errors.ParserError;
            },
            else => {
                std.debug.print("error parsing block statement: {}", .{err});
                return utils.errors.ParserError;
            },
        };

        return BlockStmt{ .stmts = stmts };
    }
};

pub const Stmt = union(enum) {
    Decl: Decl,
    Assign: *AssignExpr,
    If: *IfStmt,
    While: *WhileStmt,
    Return: *ReturnStmt,
    Expr: *Expr,
    Block: *BlockStmt,

    pub fn parse(parser: *Parser) anyerror!Stmt {
        const tok = parser.current();
        switch (tok.kind) {
            .If => {
                _ = parser.advance();
                const if_stmt = try parser.allocator.create(IfStmt);
                if_stmt.* = try IfStmt.parse(parser);
                return Stmt{ .If = if_stmt };
            },
            .While => {
                _ = parser.advance();
                const while_stmt = try parser.allocator.create(WhileStmt);
                while_stmt.* = try WhileStmt.parse(parser);
                return Stmt{ .While = while_stmt };
            },
            .Return => {
                _ = parser.advance();
                const return_stmt = try parser.allocator.create(ReturnStmt);
                return_stmt.* = try ReturnStmt.parse(parser);
                return Stmt{ .Return = return_stmt };
            },
            .LeftCurly => {
                const block = try parser.allocator.create(BlockStmt);
                block.* = try BlockStmt.parse(parser);
                return Stmt{ .Block = block };
            },
            .Int, .Float, .Bool, .Char, .Void => {
                const decl = try Decl.parse(parser);
                return Stmt{ .Decl = decl };
            },
            .SemiColon => {
                _ = parser.advance();
                const expr = try parser.allocator.create(Expr);
                expr.* = Expr{ .Value = .{ .Int = 0 } };
                return Stmt{ .Expr = expr };
            },
            .Identifier => {
                const expr = try parser.allocator.create(Expr);
                expr.* = try Expr.parse(parser);
                _ = parser.expect(TokenKind.SemiColon) catch |err| switch (err) {
                    error.UnexpectedToken => {
                        utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: expected ;");
                        return utils.errors.ParserError;
                    },
                    else => {
                        std.debug.print("error parsing statement: {}", .{err});
                        return utils.errors.ParserError;
                    },
                };
                switch (expr.*) {
                    .Assign => |a| return Stmt{ .Assign = a },
                    else => return Stmt{ .Expr = expr },
                }
            },
            else => {
                const expr = try parser.allocator.create(Expr);
                expr.* = try Expr.parse(parser);
                _ = parser.expect(TokenKind.SemiColon) catch |err| switch (err) {
                    error.UnexpectedToken => {
                        utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: expected ;");
                        return utils.errors.ParserError;
                    },
                    else => {
                        std.debug.print("error parsing statement: {}", .{err});
                        return utils.errors.ParserError;
                    },
                };
                return Stmt{ .Expr = expr };
            },
        }
    }
};

pub const Program = struct {
    declarations: std.ArrayList(Decl),

    pub fn parse(parser: *Parser) !Program {
        var declarations: std.ArrayList(Decl) = .empty;
        while (parser.current().kind != TokenKind.Eof) {
            const decl = try Decl.parse(parser);
            try declarations.append(parser.allocator, decl);
        }
        return Program{ .declarations = declarations };
    }
};

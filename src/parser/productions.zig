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
        parser.expect(TokenKind.LeftParen) catch |err| switch (err) {
            error.UnexpectedToken => {
                utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: expected ( after function call");
                return utils.errors.ParserError;
            },
            else => {
                std.debug.print("error parsing call expression: {}", .{err});
                return utils.errors.ParserError;
            },
        };

        var args = std.ArrayList(Expr).init(parser.allocator);
        if (parser.current().kind != TokenKind.RightParen) {
            while (true) {
                const arg = try Expr.parse(parser);
                try args.append(arg);
                if (parser.current().kind == TokenKind.Comma) {
                    _ = parser.advance();
                } else {
                    break;
                }
            }
        }

        parser.expect(TokenKind.RightParen) catch |err| switch (err) {
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
        _ = parser;
        _ = target;
        @compileError("TODO");
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
        _ = parser;
        @compileError("TODO");
    }
};

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

    pub fn parse(parser: *Parser) !VarDecl {
        const tok = parser.current();
        const typeSpec: TypeSpec = switch (tok.kind) {
            .Int => .Int,
            .Float => .Float,
            .Bool => .Bool,
            .Char => .Char,
            else => {
                utils.print_syntax_err(tok, "syntax error at line {} col {}: expected type specifier in variable declaration");
                return utils.errors.ParserError;
            },
        };
        _ = parser.advance();

        const name = parser.expect(TokenKind.Identifier) catch |err| switch (err) {
            error.UnexpectedToken => {
                utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: expected variable name");
                return utils.errors.ParserError;
            },
            else => {
                std.debug.print("error parsing variable declaration: {}", .{err});
                return utils.errors.ParserError;
            },
        };

        var init: ?Expr = null;
        if (parser.current().kind == TokenKind.Eq) {
            _ = parser.advance();
            init = try Expr.parse(parser);
        }

        parser.expect(TokenKind.SemiColon) catch |err| switch (err) {
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

    pub fn parse(parser: *Parser) !FuncDecl {
        const tok = parser.current();
        const returnType: TypeSpec = switch (tok.kind) {
            .Int => .Int,
            .Float => .Float,
            .Bool => .Bool,
            .Char => .Char,
            .Void => .Void,
            else => {
                utils.print_syntax_err(tok, "syntax error at line {} col {}: expected return type");
                return utils.errors.ParserError;
            },
        };
        _ = parser.advance();

        const name = parser.expect(TokenKind.Identifier) catch |err| switch (err) {
            error.UnexpectedToken => {
                utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: expected function name");
                return utils.errors.ParserError;
            },
            else => {
                std.debug.print("error parsing function declaration: {}", .{err});
                return utils.errors.ParserError;
            },
        };

        parser.expect(TokenKind.LeftParen) catch |err| switch (err) {
            error.UnexpectedToken => {
                utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: expected ( after function name");
                return utils.errors.ParserError;
            },
            else => {
                std.debug.print("error parsing function declaration: {}", .{err});
                return utils.errors.ParserError;
            },
        };

        var params = std.ArrayList(Param).init(parser.allocator);
        if (parser.current().kind != TokenKind.RightParen) {
            while (true) {
                const param = try Param.parse(parser);
                try params.append(param);
                if (parser.current().kind == TokenKind.Comma) {
                    _ = parser.advance();
                } else {
                    break;
                }
            }
        }

        parser.expect(TokenKind.RightParen) catch |err| switch (err) {
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
        _ = parser;
        @compileError("TODO");
    }
};

pub const IfStmt = struct {
    condition: *Expr,
    thenBlock: Stmt,
    elseBlock: ?*Stmt,

    pub fn parse(parser: *Parser) !IfStmt {
        parser.expect(TokenKind.LeftParen) catch |err| switch (err) {
            error.UnexpectedToken => {
                utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: expected ( after if keyword");
                return utils.errors.ParserError;
            },
            else => {
                std.debug.print("error parsing if statement: {}", .{err});
                return utils.errors.ParserError;
            },
        };

        const condition = try Expr.parse(parser);

        parser.expect(TokenKind.RightParen) catch |err| switch (err) {
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

        var elseBlock: ?Stmt = null;
        if (parser.current().kind == TokenKind.Else) {
            _ = parser.advance();
            elseBlock = try Stmt.parse(parser);
        }

        return IfStmt{ .condition = condition, .thenBlock = thenBlock, .elseBlock = elseBlock };
    }
};

pub const WhileStmt = struct {
    condition: *Expr,
    body: *Stmt,

    pub fn parse(parser: *Parser) !WhileStmt {
        parser.expect(TokenKind.LeftParen) catch |err| switch (err) {
            error.UnexpectedToken => {
                utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: expected ( after while keyword but got {}");
                return utils.errors.ParserError;
            },
            else => {
                std.debug.print("error parsing while statement: {}", .{err});
                return utils.errors.ParserError;
            },
        };

        const expr = try Expr.parse(parser);

        parser.expect(TokenKind.RightParen) catch |err| switch (err) {
            error.UnexpectedToken => {
                utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: a '(' without closing ')'");
                return utils.errors.ParserError;
            },

            else => {
                std.debug.print("error parsing while statement: {}", .{err});
                return utils.errors.ParserError;
            },
        };

        const body = try Stmt.parse(parser);

        return WhileStmt{ .condition = expr, .body = body };
    }
};

pub const ReturnStmt = struct {
    value: ?*Expr,

    pub fn parse(parser: *Parser) !ReturnStmt {
        var value: ?Expr = null;
        if (parser.current().kind != TokenKind.SemiColon) {
            value = try Expr.parse(parser);
        }

        parser.expect(TokenKind.SemiColon) catch |err| switch (err) {
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

    pub fn parse(parser: *Parser) !BlockStmt {
        parser.expect(TokenKind.LeftCurly) catch |err| switch (err) {
            error.UnexpectedToken => {
                utils.print_syntax_err(parser.current(), "syntax error at line {} col {}: expected {");
                return utils.errors.ParserError;
            },
            else => {
                std.debug.print("error parsing block statement: {}", .{err});
                return utils.errors.ParserError;
            },
        };

        var stmts = std.ArrayList(Stmt).init(parser.allocator);
        while (parser.current().kind != TokenKind.RightCurly) {
            const stmt = try Stmt.parse(parser);
            try stmts.append(stmt);
        }

        parser.expect(TokenKind.RightCurly) catch |err| switch (err) {
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

    pub fn parse(parser: *Parser) !Stmt {
        _ = parser;
        @compileError("TODO");
    }
};

pub const Program = struct {
    declarations: std.ArrayList(Decl),

    pub fn parse(parser: *Parser) !Program {
        _ = parser;
        @compileError("TODO");
    }
};

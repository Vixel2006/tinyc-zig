const std = @import("std");
const Token = @import("../lexer/token.zig").Token;
const Parser = @import("parser.zig").Parser;

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
        _ = parser;
        _ = left;
        @compileError("TODO");
    }
};

pub const UnaryExpr = struct {
    op: UnaryOp,
    operand: *Expr,

    pub fn parse(parser: *Parser) !UnaryExpr {
        _ = parser;
        @compileError("TODO");
    }
};

pub const CallExpr = struct {
    callee: Token,
    args: std.ArrayList(Expr),

    pub fn parse(parser: *Parser, callee: Token) !CallExpr {
        _ = parser;
        _ = callee;
        @compileError("TODO");
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
        _ = parser;
        @compileError("TODO");
    }
};

pub const VarDecl = struct {
    typeSpec: TypeSpec,
    name: Token,
    init: ?*Expr,

    pub fn parse(parser: *Parser) !VarDecl {
        _ = parser;
        @compileError("TODO");
    }
};

pub const FuncDecl = struct {
    returnType: TypeSpec,
    name: Token,
    params: std.ArrayList(Param),
    body: BlockStmt,

    pub fn parse(parser: *Parser) !FuncDecl {
        _ = parser;
        @compileError("TODO");
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
        _ = parser;
        @compileError("TODO");
    }
};

pub const WhileStmt = struct {
    condition: *Expr,
    body: *Stmt,

    pub fn parse(parser: *Parser) !WhileStmt {
        _ = parser;
        @compileError("TODO");
    }
};

pub const ReturnStmt = struct {
    value: ?*Expr,

    pub fn parse(parser: *Parser) !ReturnStmt {
        _ = parser;
        @compileError("TODO");
    }
};

pub const BlockStmt = struct {
    stmts: std.ArrayList(Stmt),

    pub fn parse(parser: *Parser) !BlockStmt {
        _ = parser;
        @compileError("TODO");
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

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tinyc_mod = b.addModule("tinyc", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "tinyc",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "tinyc", .module = tinyc_mod },
            },
        }),
    });
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const test_step = b.step("test", "Run all tests");

    const tinyc_tests = b.addTest(.{ .root_module = tinyc_mod });
    const run_tinyc_tests = b.addRunArtifact(tinyc_tests);
    test_step.dependOn(&run_tinyc_tests.step);

    const lexer_test = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/lexer_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "tinyc", .module = tinyc_mod },
            },
        }),
    });
    const run_lexer_test = b.addRunArtifact(lexer_test);
    test_step.dependOn(&run_lexer_test.step);
}

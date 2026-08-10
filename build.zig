const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const ingest_module = b.createModule(.{ .root_source_file = b.path("ingest/ingest.zig") });
    const comparable_module = b.createModule(.{ .root_source_file = b.path("comparable/comparable.zig") });
    comparable_module.addImport("ingest", ingest_module);
    const provider_module = b.createModule(.{ .root_source_file = b.path("provider/provider.zig") });
    provider_module.addImport("ingest", ingest_module);
    const geometry_module = b.createModule(.{ .root_source_file = b.path("geometry/geometry.zig") });
    const tiles_module = b.createModule(.{ .root_source_file = b.path("tiles/tiles.zig") });
    tiles_module.addImport("geometry", geometry_module);
    const operations_module = b.createModule(.{ .root_source_file = b.path("operations/operations.zig") });
    const model_module = b.createModule(.{ .root_source_file = b.path("model/model.zig") });
    model_module.addImport("ingest", ingest_module);

    const exe = b.addExecutable(.{
        .name = "property-tax-explorer",
        .root_module = b.createModule(.{
            .root_source_file = b.path("app/app.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("ingest", ingest_module);
    exe.root_module.addImport("comparable", comparable_module);
    exe.root_module.addImport("provider", provider_module);
    exe.root_module.addImport("geometry", geometry_module);
    exe.root_module.addImport("tiles", tiles_module);
    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    run.step.dependOn(b.getInstallStep());
    if (b.args) |args| run.addArgs(args);
    const run_step = b.step("run", "Run the property-tax explorer");
    run_step.dependOn(&run.step);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/ingest_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    tests.root_module.addImport("ingest", ingest_module);
    tests.root_module.addImport("comparable", comparable_module);
    tests.root_module.addImport("geometry", geometry_module);
    tests.root_module.addImport("operations", operations_module);
    tests.root_module.addImport("model", model_module);
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run deterministic data and comparison tests");
    test_step.dependOn(&run_tests.step);
}

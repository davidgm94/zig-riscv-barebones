const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void
{
    var enabled_features = std.Target.Cpu.Feature.Set.empty;
    const features = std.Target.riscv.Feature;
    const target = std.zig.CrossTarget
    {
        .cpu_arch = .riscv64,
        .os_tag = .freestanding,
        .abi = .none,
        .cpu_features_add = enabled_features,
    };

    enabled_features.addFeature(@enumToInt(features.c));

    const exe = b.addExecutable("riscv", "src/main.zig");
    exe.force_pic = true;
    exe.strip = false;
    exe.addAssemblyFile("src/boot.S");
    exe.setLinkerScriptPath(std.build.FileSource.relative("src/linker.ld"));
    exe.setTarget(target);
    exe.setBuildMode(b.standardReleaseOptions());
    exe.setOutputDir("zig-cache");
    b.default_step.dependOn(&exe.step);

    const disk = HDD.create(b);
    const qemu = qemu_command(b);
    qemu.step.dependOn(&exe.step);
    qemu.step.dependOn(&disk.step);
}

const HDD = struct
{
    const block_size = 0x400;
    const block_count = 32;
    var zero_buffer: [block_size * block_count]u8 align(0x1000) = undefined;
    const path = "zig-cache/hdd.bin";

    step: std.build.Step,

    fn create(b: *Builder) *HDD
    {
        const step = b.allocator.create(HDD) catch @panic("out of memory\n");
        step.* = .
        {
            .step = std.build.Step.init(.custom, "hdd_create", b.allocator, make),
        };

        return step;
    }

    fn make(step: *std.build.Step) !void
    {
        _ = step;
        try std.fs.cwd().writeFile(HDD.path, &HDD.zero_buffer);
    }
};

const qemu_command_str = &.
{
    "qemu-system-riscv64",
    "-machine", "virt",
    "-cpu", "rv64",
    "-smp", "4",
    "-m", "128M",
    "-bios", "none",
    "-kernel", "zig-cache/riscv",
    "-serial", "mon:stdio",
    "-drive", "if=none,format=raw,file=zig-cache/hdd.bin,id=foo",
    "-device", "virtio-blk-device,drive=foo",
};
 
fn qemu_command(b: *Builder) *std.build.RunStep
{
    const run_step = b.addSystemCommand(qemu_command_str);
    const step = b.step("run", "run step");
    step.dependOn(&run_step.step);
    return run_step;
}

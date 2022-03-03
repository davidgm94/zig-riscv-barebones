const std = @import("std");
export fn main() callconv(.C) noreturn
{
    log_uart.init();
    log_uart.write("Hello kernel\n");

    while (true)
    {
        std.atomic.spinLoopHint();
    }
}

export fn asm_trap_vector() callconv(.Naked) void
{
    asm volatile("mret");
    unreachable;
}

const log_uart = UART(0x1000_0000);

fn UART(comptime address: u64) type
{
    return struct
    {
        const ptr = @intToPtr([*]volatile u8, address);
        fn init() void
        {
            const lcr = (1 << 0) | (1 << 1);
            (ptr + 3).* = lcr;
            (ptr + 2).* = 1 << 0;
            (ptr + 1).* = 1 << 0;

            const divisor: u16 = 592;
            const divisor_lsb = @truncate(u8, divisor);
            const divisor_msb = @truncate(u8, divisor >> 8);

            (ptr + 3).* = lcr | (1 << 7);
            ptr.* = divisor_lsb;
            (ptr + 1).* = divisor_msb;
            (ptr + 3).* = lcr;
        }

        fn write(message: []const u8) void
        {
            for (message) |ch|
            {
                ptr.* = ch;
            }
        }
    };
}

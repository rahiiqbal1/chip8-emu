const std = @import("std");

const CPU = struct {
    // Memory. 4096 bytes available. The first 512 bytes (0x000 to 0x1FF) are
    // where the original interpreter was located and should not be used by
    // programs:
    ram: [4096]u8,
    registers: Registers,
};

const Registers = struct {
    // 16 General purpose registers:
    v0: u8,
    v1: u8,
    v2: u8,
    v3: u8,
    v4: u8,
    v5: u8,
    v6: u8,
    v7: u8,
    v8: u8,
    v9: u8,
    vA: u8,
    vB: u8,
    vC: u8,
    vD: u8,
    vE: u8,
    vF: u8, // Flag; should not be used by any program.
    I: u16, // Used to store memory addresses in lowest 12 bits (right).
    // Delay timer; when this register is non-zero, the delay timer subtracts
    // 1 from the value in this register at a rate of 60hz:
    dt: u16,
    // Sound timer; buzzer sounds as long as the value in this register is 
    // greater than zero. Decrements at a rate of 60hz:
    st: u16,
    // Program counter, stores the currently executing address:
    pc: u16,
    // Stack, stores the address that the interpreter should return to when
    // finished with a subroutine. Up to 16 levels of nested subroutines are
    // allowed:
    stack: [16]u16,
    // Stack pointer, points to the topmost level of the stack:
    sp: u8,

    pub fn incrementPC(self: *Registers) !void {
        // Incrementing by 2 because instructions are 2 bytes long:
        self.pc += 2;
    }
};

const CPU = struct {
    // Memory. 4096 bytes available. The first 512 bytes (0x000 to 0x1FF) are
    // where the original interpreter was located and should not be used by
    // programs:
    ram: [4096]u8,
    registers: Registers,

    // Gets and executes the instruction where program counter is pointing.
    // Note: Instructions are 2 bytes long, and are stored
    // most-significant-byte first. The first byte of each instruction should
    // be located at an even address.
    fn cycle (self: *CPU) !void {
        // Checking that the pc address is valid:
        if (self.registers.pc > 0xFFF) {
            std.debug.print("The PC address {} is greater than is possible.\n",
                .{self.registers.pc});
            return error.InvalidPCAddress;
        }
        
        // Getting and storing 2-byte instruction. Instructions are stored
        // big-endian, so need to shift left by 8 bits. Or-ing with pc + 1
        // as the pc only points to 1 byte at a time:
        const instruction: u16 = self.ram[self.registers.pc] << 8 |
                                 self.ram[self.registers.pc + 1];

        // Getting first nibble for matching:
        const first_nibble: u4 = instruction >> 12;
        
        // Checking basic cases first:
        if (instruction == 0x00E0) {
            std.debug.print("CLS not implemented\n", .{});
        // RET. Return from a subroutine. Sets to pc to the address at the top
        // of the stack and then decrements the stack pointer:
        } else if (instruction == 0x00EE) {
            self.registers.pc = self.registers.stack[self.registers.sp];
            self.registers.sp -= 1;
        }
        switch (first_nibble) {

        }
    }
};

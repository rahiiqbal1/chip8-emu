const std = @import("std");

const Registers = struct {
    // 16 General purpose 8-bit registers, V0-F, Note; VF is a flag and should
    // not be used by any program:
    gen_regs: [16]u8,
    // I, used to store memory addresses in lowest 12 bits (right).
    I: u16, 
    // Delay timer; when this register is non-zero, the delay timer subtracts
    // 1 from the value in this register at a rate of 60hz:
    dt: u16,
    // Sound timer; buzzer sounds as long as the value in this register is 
    // greater than zero. Decrements at a rate of 60hz:
    st: u16,
    // Program counter, stores the address with the next instruction to
    // execute:
    pc: u16,
    // Stack, stores the address that the interpreter should return to when
    // finished with a subroutine. Up to 16 levels of nested subroutines are
    // allowed:
    stack: [16]u16,
    // Stack pointer, points to the topmost level of the stack:
    sp: u8,

    pub inline fn incrementPC(self: *Registers) void {
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
        const largest_nibble: u4 = instruction & 0xF000 >> 12;
        // Smallest nibble in instruction to switch over:
        const smallest_nibble: u4 = instruction & 0x000F;
        // Rightmost byte in instruction:
        const kk: u8 = instruction & 0x00FF;
        // X and Y, second and third nibbles for each instruction:
        const x: u4 = instruction & 0x0F00 >> 8;
        const y: u4 = instruction & 0x00F0 >> 4;
        // Pointers to corresponding Vx and Vy registers:
        const vx: *u8 = &self.registers.gen_regs[x];
        const vy: *u8 = &self.registers.gen_regs[y];
        // Pointer to flag register:
        const vf: *u8 = &self.registers.gen_regs[0xF];
        
        // Checking basic cases first:
        if (instruction == 0x00E0) {
            std.debug.print("CLS not implemented\n", .{});
        // RET. Return from a subroutine. Sets to pc to the address at the top
        // of the stack and then decrements the stack pointer:
        } else if (instruction == 0x00EE) {
            self.registers.pc = self.registers.stack[self.registers.sp];
            self.registers.sp -= 1;
            // Increment program counter:
            self.registers.incrementPC();
        }
        switch (largest_nibble) {
            // (1nnn) JP addr. Jump to location nnn. Sets the program counter
            // to nnn:
            0x1 => self.registers.pc = instruction & 0xFFF,
            // (2nnn) CALL addr. Calls subroutine at nnn. Increments stack
            // pointer, then puts the current pc on the top of the stack.
            // The PC is then set to nnn:
            0x2 => {
                self.registers.sp += 1;
                self.registers.stack[self.registers.sp] =
                    self.registers.pc;
                self.registers.pc = instruction & 0xFFF;
            },
            // (3xkk) SE Vx, byte. Skip next instruction if Vx = kk. Compares
            // register Vx to kk, and if they are equal, increments the program
            // counter by 2:
            0x3 => {
                if (vx.* == kk) {
                    self.registers.incrementPC();
                }
            },
            // (4xkk) SNE Vx, byte. Skip next instruction if Vx != kk:
            0x4 => {
                if (vx.* != kk) {
                    self.registers.incrementPC();
                }
                self.registers.incrementPC();
            },
            // (5xy0) SE Vx, Vy. Skip next instruction if Vx = Vy:
            0x5 => {
                if (vx.* == vy.*) {
                    self.registers.incrementPC();
                }
                self.registers.incrementPC();
            },
            // (6xkk) LD Vx, byte. Puts the value kk into register Vx:
            0x6 => {
                vx.* = kk;
                self.registers.incrementPC();
            },
            // (7xkk) ADD Vx, byte. Adds the value kk to the value in register
            // Vx, then stores the result in Vx. If the result overflows the 
            // 8-bit register, stores the lowest 8 bits only:
            0x7 => {
                vx.* = @truncate(vx.* + kk);
                self.registers.incrementPC();
            },
            0x8 => {
                switch (smallest_nibble) {
                // (8xy0) LD Vx, Vy. Stores the value of register Vy in
                // register Vx:
                0x0 => {
                    vx.* = vy.*;
                    self.registers.incrementPC();
                },
                // (8xy1) OR Vx, Vy. Performs a bitwise OR on the values in Vx
                // and Vy, then stores the result in Vx:
                0x1 => {
                    vx.* |= vy.*; 
                    self.registers.incrementPC();
                },
                // (8xy2) AND Vx, Vy. Set Vx = Vx AND Vy.
                0x2 => {
                    vx.* &= vy.*; 
                    self.registers.incrementPC();
                },
                // (8xy3) XOR Vx, Vy. Bitwise XOR on Vx and Vy, stores in Vx:
                0x3 => {
                    vx.* ^= vy.*; 
                    self.registers.incrementPC();
                },
                // (8xy4) ADD Vx, Vy. Set Vx = Vx + Vy, set VF = carry:
                0x4 => {
                    const sum: u16 = vx.* + vy.*; 
                    const truncated_sum: u8 = @truncate(sum);
                    vf.* = if (sum > 0xFF) 1 else 0;
                    vx.* = truncated_sum;
                    self.registers.incrementPC();
                },
                // (8xy5) SUB Vx, Vy. Set Vx = Vx - Vy. Set VF = NOT borrow.
                // If Vx > Vy, then VF is set to 1, otherwise 0. Then Vy is 
                // subtracted from Vx, and the result is stored in Vx (with
                // overflow):
                0x5 => {
                    vx.* -%= vy.*;
                    vf.* = if (vx.* > vy.*) 1 else 0;
                    self.registers.incrementPC();
                },
                // (8xy6) SHR Vx {, Vy}. If the least-significant bit of Vx is
                // 1, then VF is set to 1, otherwise 0. Then Vx is divided by
                // 2:
                0x6 => {
                    vf.* = if ((vx.* & 0b00000001) == 0b1) 1 else 0;
                    vx.* /= 2;
                    self.registers.incrementPC();
                },
                // (8xy7) SUBN Vx, Vy. Set Vx = Vy - Vx, set VF = NOT borrow.
                0x7 => {
                    vf.* = if (vy.* > vx.*) 1 else 0;
                    vx.* = vy.* -% vx.*;
                    self.registers.incrementPC();
                },
                // (8xyE) SHL Vx {, Vy}. Set Vx = Vx SHL 1. If the most-
                // significant bit of Vx is 1, then VF is set to 1, otherwise
                // to 0. Then Vx is multiplied by 2:
                0xE => {
                    vf.* = if ((vx.* & 0b10000000) == 0b10000000) 1 else 0;
                    vx.* *= 2;
                    self.registers.incrementPC();
                }
                }
            },
            0x9 => {

            },
        }
    }
};

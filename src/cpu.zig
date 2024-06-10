const std = @import("std");
const Bitmap = @import("bitmap.zig").Bitmap;
const Display = @import("display.zig").Display;

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

    pub fn init() Registers {
        return Registers {
            .gen_regs = [1]u8{0} ** 16,
            .I = 0,
            .dt = 0,
            .st = 0,
            .pc = 0x200, // Starting at 0x200 as that is where files begin.
            .stack = [1]u16{0} ** 16,
            .sp = 0,
        };
    }

    // Stack push and pop methods:
    pub fn stackPush(self: *Registers, address: u16) void {
        if (self.sp > 15) return;

        self.stack[self.sp] = address;
        self.sp += 1;
    }

    pub fn stackPop(self: *Registers) u16 {
        if (self.sp == 0) return 0;

        const val_at_top: u16 = self.stack[self.sp - 1];
        self.sp -= 1;

        return val_at_top;
    }
};

pub const CPU = struct {
    // Memory. 4096 bytes available. The first 512 bytes (0x000 to 0x1FF) are
    // where the original interpreter was located and should not be used by
    // programs:
    ram: [4096]u8,
    registers: Registers,
    bitmap: *Bitmap,
    display: *Display,
    paused: bool,
    paused_x: u8, // for storing key press after unpausing.
    speed: u8,

    // Initialises CPU instance:
    pub fn init(bitmap: *Bitmap, display: *Display) CPU {
        const registers: Registers = Registers.init();

        return CPU {
            .ram = [1]u8{0} ** 4096,
            .registers = registers,
            .bitmap = bitmap,
            .display = display,
            .paused = false,
            .paused_x = 0,
            .speed = 10,
        };
    }

    // Random number generator:
    var prng = std.rand.DefaultPrng.init(0); 
    const random_generator = prng.random();

    // Gets and executes the instruction where program counter is pointing.
    // Note: Instructions are 2 bytes long, and are stored
    // most-significant-byte first. The first byte of each instruction should
    // be located at an even address.
    pub fn cycle (self: *CPU) !void {

        if (self.paused) {
            var i: u8 = 0;
            while (i < 16) : (i += 1) {
                if (self.display.keys[i]) {
                    self.paused = false;
                    self.registers.gen_regs[self.paused_x] = i;
                }
            }
        }

        var i: u8 = 0;
        while (i < self.speed) : (i += 1) {
            // Don't run instructions if the emulator is paused:
            if (!self.paused) {
                try self.executeInstruction();
                // Increment program counter after each instruction:
                self.registers.pc += 2;
            }
        }

        // Update timers:
        if (!self.paused) {
            if (self.registers.dt > 0) self.registers.dt -= 1;
            if (self.registers.st > 0) self.registers.st -= 1;
        }
    }

    fn executeInstruction(self: *CPU) !void {
        // Checking that the pc address is valid:
        if (self.registers.pc > 0xFFF) {
            std.debug.print("The PC address {} is greater than is possible.\n",
                .{self.registers.pc});
            return error.InvalidPCAddress;
        }
        
        // Getting and storing 2-byte instruction. Instructions are stored
        // big-endian, so need to shift left by 8 bits. Or-ing with pc + 1
        // as the pc only points to 1 byte at a time:
        const instruction: u16 = @as(u16, self.ram[self.registers.pc]) << 8 |
                                 self.ram[self.registers.pc + 1];

        // Getting first nibble for matching:
        const largest_nibble: u4 = @truncate((instruction & 0xF000) >> 12);
        // Smallest nibble in instruction to switch over:
        const smallest_nibble: u4 = @truncate(instruction & 0x000F);
        // Rightmost byte in instruction:
        const kk: u8 = @truncate(instruction & 0x00FF);
        // X and Y, second and third nibbles for each instruction:
        const x: u4 = @truncate(instruction & 0x0F00 >> 8);
        const y: u4 = @truncate(instruction & 0x00F0 >> 4);
        // Pointers to corresponding Vx and Vy registers:
        const vx: *u8 = &self.registers.gen_regs[x];
        const vy: *u8 = &self.registers.gen_regs[y];
        // Pointer to flag register:
        const vf: *u8 = &self.registers.gen_regs[0xF];

        std.debug.print("----------\n", .{});
        std.debug.print("Current instruction: {x}\n", .{instruction});
        std.debug.print("Largest nibble: {x}\n", .{largest_nibble});
        std.debug.print("Smallest nibble: {x}\n", .{smallest_nibble});
        
        // Checking basic cases first:
        // (00E0) CLS. Clears the screen:
        if (instruction == 0x00E0) {
            self.bitmap.clear(0);
            
            std.debug.print("00E0\n", .{});
            return;
        // (00EE) RET. Return from a subroutine. Sets the pc to the address at
        // the top of the stack and then decrements the stack pointer:
        } else if (instruction == 0x00EE) {
            self.registers.pc = self.registers.stackPop();

            std.debug.print("00EE\n", .{});
            return;
        }
        switch (largest_nibble) {
            // (1nnn) JP addr. Jump to location nnn. Sets the program counter
            // to nnn:
            0x1 => {
                self.registers.pc = instruction & 0x0FFF;

                std.debug.print("1nnn\n", .{});
            },
            // (2nnn) CALL addr. Calls subroutine at nnn. Increments stack
            // pointer, then puts the current pc on the top of the stack.
            // The PC is then set to nnn:
            0x2 => {
                self.registers.stackPush(self.registers.pc);
                self.registers.pc = instruction & 0x0FFF;

                std.debug.print("2nnn\n", .{});
            },
            // (3xkk) SE Vx, byte. Skip next instruction if Vx = kk. Compares
            // register Vx to kk, and if they are equal, increments the program
            // counter by 2:
            0x3 => {
                if (vx.* == kk) {
                    self.registers.pc += 2;
                }
                
                std.debug.print("3xkk\n", .{});
            },
            // (4xkk) SNE Vx, byte. Skip next instruction if Vx != kk:
            0x4 => {
                if (vx.* != kk) {
                    self.registers.pc += 2;
                }
                
                std.debug.print("4xkk\n", .{});
            },
            // (5xy0) SE Vx, Vy. Skip next instruction if Vx = Vy:
            0x5 => {
                if (vx.* == vy.*) {
                    self.registers.pc += 2;
                }
                
                std.debug.print("5xy0\n", .{});
            },
            // (6xkk) LD Vx, byte. Puts the value kk into register Vx:
            0x6 => {
                vx.* = kk;
                
                std.debug.print("6xkk\n", .{});
            },
            // (7xkk) ADD Vx, byte. Adds the value kk to the value in register
            // Vx, then stores the result in Vx. If the result overflows the 
            // 8-bit register, stores the lowest 8 bits only:
            0x7 => {
                vx.* +%= kk;
                
                std.debug.print("7xkk\n", .{});
            },
            0x8 => {
                switch (smallest_nibble) {
                // (8xy0) LD Vx, Vy. Stores the value of register Vy in
                // register Vx:
                0x0 => {
                    vx.* = vy.*;
                    
                    std.debug.print("8xy0\n", .{});
                },
                // (8xy1) OR Vx, Vy. Performs a bitwise OR on the values in Vx
                // and Vy, then stores the result in Vx:
                0x1 => {
                    vx.* |= vy.*; 
                    
                    std.debug.print("8xy1\n", .{});
                },
                // (8xy2) AND Vx, Vy. Set Vx = Vx AND Vy.
                0x2 => {
                    vx.* &= vy.*; 
                    
                    std.debug.print("8xy2\n", .{});
                },
                // (8xy3) XOR Vx, Vy. Bitwise XOR on Vx and Vy, stores in Vx:
                0x3 => {
                    vx.* ^= vy.*; 
                    
                    std.debug.print("8xy3\n", .{});
                },
                // (8xy4) ADD Vx, Vy. Set Vx = Vx + Vy, set VF = carry:
                0x4 => {
                    const sum: u16 = vx.* + vy.*; 
                    const truncated_sum: u8 = @truncate(sum);
                    vf.* = if (sum > 0xFF) 1 else 0;
                    vx.* = truncated_sum;
                    
                    std.debug.print("8xy4\n", .{});
                },
                // (8xy5) SUB Vx, Vy. Set Vx = Vx - Vy. Set VF = NOT borrow.
                // If Vx > Vy, then VF is set to 1, otherwise 0. Then Vy is 
                // subtracted from Vx, and the result is stored in Vx (with
                // overflow):
                0x5 => {
                    vx.* -%= vy.*;
                    vf.* = if (vx.* > vy.*) 1 else 0;
                    
                    std.debug.print("8xy5\n", .{});
                },
                // (8xy6) SHR Vx {, Vy}. If the least-significant bit of Vx is
                // 1, then VF is set to 1, otherwise 0. Then Vx is divided by
                // 2:
                0x6 => {
                    const lsb_is1: bool = (vx.* & 0b00000001) == 0b1;
                    vx.* /= 2;
                    vf.* = if (lsb_is1) 1 else 0;
                    
                    std.debug.print("8xy6\n", .{});
                },
                // (8xy7) SUBN Vx, Vy. Set Vx = Vy - Vx, set VF = NOT borrow.
                0x7 => {
                    const Vx = vx.*;
                    const Vy = vy.*;
                    vx.* = vy.* -% vx.*;
                    vf.* = if (Vy > Vx) 1 else 0;
                    
                    std.debug.print("8xy7\n", .{});
                },
                // (8xyE) SHL Vx {, Vy}. Set Vx = Vx SHL 1. If the most-
                // significant bit of Vx is 1, then VF is set to 1, otherwise
                // to 0. Then Vx is multiplied by 2:
                0xE => {
                    const Vx = vx.*;
                    vx.* *= 2;
                    vf.* = if ((Vx & 0b10000000) == 0b10000000) 1 else 0;
                    
                    std.debug.print("8xyE\n", .{});
                },
                else => {
                    std.debug.panic("Unknown 8xyn instruction: {x}\n",
                                    .{instruction});
                },
                }
            },
            // (9xy0) SNE Vx, Vy. Skip next instruction if Vx != Vy:
            0x9 => {
                if (vx.* != vy.*) {
                    self.registers.pc += 2;
                }
                
                std.debug.print("9xy0\n", .{});
            },
            // (Annn) LD I, addr. The value of register I is set to nnn:
            0xA => {
                self.registers.I = instruction & 0x0FFF;
                
                std.debug.print("Annn\n", .{});
            },
            // (Bnnn) JP V0, addr. Jump to location nnn + V0. The program 
            // counter is set to nnn plus the value in V0:
            0xB => {
                self.registers.pc = (instruction & 0x0FFF) +
                                    self.registers.gen_regs[0];
                std.debug.print("Bnnn\n", .{});
            },
            // (Cxkk) RND Vx, byte. Generates a random number from 0 to 255,
            // which is then ANDed with the value kk. The result is stored in 
            // Vx:
            0xC => {
                const rand_num: u8 = random_generator.intRangeAtMost(
                    u8, 0, 255);
                vx.* = rand_num & kk;
                
                std.debug.print("Cxkk\n", .{});
            },
            // (Dxyn) DRW Vx, Vy, nibble. Display n-byte sprite starting at
            // memory location I at (Vx, Vy), set VF = collision. Read n bytes
            // from memory, starting at the address stored in I. These are then
            // displayed on screen at (Vx, Vy). Sprites are XORed onto the 
            // screen. If this causes any pixels to be erased, VF is set to 1,
            // otherwise to 0. If the sprite is positioned so part of it is 
            // outside the coordinates of the display, it wraps around to the
            // opposite side of the screen:
            0xD => {
                const width: u16 = 8; // All sprites 8 wide.
                const height: u16 = instruction & 0xF;

                vf.* = 0;

                var row: u8 = 0;
                while (row < height) : (row += 1) {
                    var sprite = self.ram[self.registers.I + row];

                    var col: u8 = 0;
                    while (col < width) : (col += 1) {
                        // Wrap x and y around the screen if out-of-bounds:
                        const px: u8 =
                            self.registers.gen_regs[x] % self.bitmap.width;
                        const py: u8 = 
                            self.registers.gen_regs[y] % self.bitmap.height;

                        // Don't wrap pixels that are outside of the bounds:
                        if (px + col >= self.bitmap.width) continue;
                        if (py + row >= self.bitmap.height) continue;

                        // If the bit (sprite) is not 0 render/erase the pixel:
                        if ((sprite & 0x80) > 0) {
                            // If setPixel returns true a pixel was erased, so
                            // set VF to 1:
                            if (self.bitmap.setPixel(px + col, py + row)) {
                                vf.* = 1;
                            }
                        }
                        
                        // Shift the sprite left 1 and move the next col/bit of
                        // the sprite into the first position:
                        sprite <<= 1;
                    }
                }
                
                std.debug.print("Dxyn\n", .{});
            },
            0xE => {
                switch (kk) {
                    // (Ex9E) SKP Vx. Skip next instruction if key with the 
                    // value of Vx is pressed. Checks the keyboard, and if the
                    // key corresponding to the value of Vx is currently down,
                    // PC is increased by 2:
                    0x9E => {
                        if (self.display.keys[vx.*]) {
                            self.registers.pc += 2;
                        }
                        
                        std.debug.print("Ex9E\n", .{});
                    },
                    // (ExA1) SKNP Vx. Skip next instruction if key with the 
                    // value of Vx is not pressed:
                    0xA1 => {
                        if (!self.display.keys[vx.*]) {
                            self.registers.pc += 2;
                        }
                        
                        std.debug.print("ExA1\n", .{});
                    },
                    else => {
                        std.debug.panic("Unknown Exkk instruction: {x}\n",
                                        .{instruction});
                    },
                }
            },
            0xF => {
                switch (kk) {
                    // (Fx07) LD Vx, DT. Set Vx = delay timer value:
                    0x07 => {
                        vx.* = @truncate(self.registers.dt);
                        
                        std.debug.print("Fx07\n", .{});
                    },
                    // (Fx0A) LD Vx, K. Wait for a key press, store the value
                    // of the key in Vx:
                    0x0A => {
                        self.paused = true;
                        self.paused_x = @as(u8, x);
                        
                        std.debug.print("Fx0A\n", .{});
                    },
                    // (Fx15) LD DT, Vx. Set delay timer = Vx:
                    0x15 => {
                        self.registers.dt = vx.*;
                        
                        std.debug.print("Fx15\n", .{});
                    },
                    // (Fx18) LD ST, Vx. Set sound timer = Vx:
                    0x18 => {
                        self.registers.st = vx.*;
                        
                        std.debug.print("Fx18\n", .{});
                    },
                    // (Fx1E) ADD I, Vx. Set I = I + Vx:
                    0x1E => {
                        self.registers.I += vx.*;
                        
                        std.debug.print("Fx1E\n", .{});
                    },
                    // (Fx29) LD F, Vx. Set I = location of sprite for digit 
                    // Vx. The value of I is set to the location for the
                    // hexadecimal sprite corresponding to the value of Vx:
                    0x29 => {
                        // Multiply by 5 since every sprite is 5 bytes long:
                        self.registers.I = @as(u16, @intCast(vx.*)) * 5;
                        
                        std.debug.print("Fx29\n", .{});
                    },
                    // (Fx33) LD B, Vx. Store BCD representation of Vx in 
                    // memory locations I, I+1, and I+2. Takes the decimal 
                    // value of Vx, and places the hundreds digit in memory
                    // at location I, the tens digit at location I+1, and the 
                    // ones digit at location I+2:
                    0x33 => {
                        const first_digit: u8 = vx.* / 100;
                        const second_digit: u8 = (vx.* / 10) - 
                                                 (first_digit * 10);
                        const third_digit: u8 = vx.* % 10;
                        self.ram[self.registers.I] = first_digit;
                        self.ram[self.registers.I + 1] = second_digit;
                        self.ram[self.registers.I + 2] = third_digit;
                        
                        std.debug.print("Fx33\n", .{});
                    },
                    // (Fx55) LD [I], Vx. Store registers V0 through Vx in 
                    // memory starting at location I:
                    0x55 => {
                        var store_loc: u16 = self.registers.I;
                        var reg_counter: u8 = 0;
                        while (reg_counter <= x) {
                            self.ram[store_loc] =
                                self.registers.gen_regs[reg_counter];
                            reg_counter += 1;
                            store_loc += 1;
                        }
                        
                        std.debug.print("Fx55\n", .{});
                    },
                    // (Fx65) LD Vx, [I]. Read registers V0 through Vx from 
                    // memory starting at location I:
                    0x65 => {
                        var read_loc: u16 = self.registers.I;
                        var reg_counter: u8 = 0;
                        while (reg_counter <= x) {
                            self.registers.gen_regs[reg_counter] =
                                self.ram[read_loc];
                            reg_counter += 1;
                            read_loc += 1;
                        }
                        
                        std.debug.print("Fx65\n", .{});
                    },
                    else => {
                        std.debug.panic("Unknown Fxkk instruction: {x}\n",
                                        .{instruction});
                },
                }
            },
            else => {
                std.debug.panic("Unknown instruction: {x}\n",
                                .{instruction});
        },
        }
    }
};

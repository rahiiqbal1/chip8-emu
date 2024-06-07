const std = @import("std");

// Memory. 4096 bytes available. The first 512 bytes (0x000 to 0x1FF) are where
// the original interpreter was located and should not be used by programs:
var ram: [4096]u8 = undefined;

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
    I: u16, // Generally used to store memory addresses.
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
};

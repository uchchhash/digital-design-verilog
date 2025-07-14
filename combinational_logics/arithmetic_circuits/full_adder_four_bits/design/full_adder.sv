`timescale 1ns/1ps
// Full Adder Circuit
// This module implements a full adder, which adds three single-bit binary numbers (two inputs and a carry-in) and produces a sum and a carry output.
// Build upon the half adder design.
// Inputs: A, B, Cin
// Outputs: Sum, Cout


module full_adder (
    input  logic A,
    input  logic B,
    input  logic Cin,
    output logic Sum,
    output logic Cout
);

    // Intermediate signals for half adder outputs
    logic Sum1, Carry1, Carry2;

    // First half adder
    half_adder HA1 (
        .A     (A),
        .B     (B),
        .Sum   (Sum1),
        .Carry (Carry1)
    );

    // Second half adder
    half_adder HA2 (
        .A     (Sum1),
        .B     (Cin),
        .Sum   (Sum),
        .Carry (Carry2)
    );

    // Final carry output
    assign Cout = Carry1 | Carry2;     
     
endmodule
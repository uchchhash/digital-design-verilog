`timescale 1ns/1ps
// Half Adder Circuit
// This module implements a half adder, which adds two single-bit binary numbers and produces a sum and a carry output.
// Inputs: A, B
// Outputs: Sum, Carry

module half_adder (
    input  logic A,
    input  logic B,
    output logic Sum,
    output logic Carry
);

    // Sum is the XOR of inputs A and B
    assign Sum = A ^ B;

    // Carry is the AND of inputs A and B
    assign Carry = A & B;

endmodule
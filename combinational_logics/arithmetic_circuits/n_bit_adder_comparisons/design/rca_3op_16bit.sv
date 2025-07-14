`timescale 1ns/1ps

//------------------------------------------------------------
// Module: rca_3op_16bit
// Description:
//   16-bit 3-operand ripple-carry adder with external carry-in.
//   Internally uses two 2-operand 16-bit RCAs.
//
// Ports:
//   - A [15:0]  : 1st operand
//   - B [15:0]  : 2nd operand
//   - C [15:0]  : 3rd operand
//   - Cin       : external carry-in
//   - S [16:0]  : 17-bit sum (including final carry-out)
//------------------------------------------------------------

`timescale 1ns/1ps

module rca_3op_16bit (
    input  logic [15:0] A,
    input  logic [15:0] B,
    input  logic [15:0] C,
    input  logic        Cin,
    output logic [16:0] S
);

    // Intermediate sum + carry after first addition (A + B + Cin)
    logic [16:0] sum_with_carry;

    // First 2-op RCA: add A, B and Cin
    rca_2op_16bit RCA0 (
        .A   (A),
        .B   (B),
        .Cin (Cin),
        .S   (sum_with_carry)
    );

    // Second 2-op RCA: add previous sum + C + carry-out from first RCA
    rca_2op_16bit RCA1 (
        .A   (sum_with_carry[15:0]),
        .B   (C),
        .Cin (sum_with_carry[16]),
        .S   (S)
    );

endmodule


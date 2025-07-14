`timescale 1ns/1ps

module rca_2op_16bit (
    input  logic [15:0] A,
    input  logic [15:0] B,
    input  logic        Cin,
    output logic [16:0] S
);

    // Carry-out from lower 8-bit RCA, 1-bit scalar
    logic carry;

    // Lower 8-bit RCA: sum bits + carry-out assigned to carry
    rca_2op_8bit RCA0 (
        .A   (A[7:0]),
        .B   (B[7:0]),
        .Cin (Cin),
        .S   ({carry, S[7:0]}) // carry-out to carry
    );

    // Upper 8-bit RCA: sum bits + final carry-out
    rca_2op_8bit RCA1 (
        .A   (A[15:8]),
        .B   (B[15:8]),
        .Cin (carry),           // carry-in from lower RCA
        .S   ({S[16], S[15:8]}) // upper sum + final carry-out
    );

endmodule

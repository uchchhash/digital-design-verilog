`timescale 1ns/1ps
// Fixed-Point Arithmetic Logic Unit (ALU)
// ---------------------------------------
// Performs signed fixed-point arithmetic (Qm.n format) with configurable precision.
// Supported operations (op):
//   00 - Addition (a + b)
//   01 - Subtraction (a - b)
//   10 - Multiplication (a * b)
//   11 - Division (a / b) [optional]
// 
// Parameters:
//   INT_WIDTH   - Number of integer bits (default: 4)
//   FRAC_WIDTH  - Number of fractional bits (default: 4)
//   DATA_WIDTH  - INT_WIDTH + FRAC_WIDTH + 1 (sign bit)
//
// I/O Ports:
//   input  [DATA_WIDTH-1:0] a, b   : Operands in fixed-point signed format
//   input  [1:0]            op     : Operation selector
//   output [DATA_WIDTH-1:0] result : Computed result
//   output                  overflow: Overflow flag
//   output                  underflow: Underflow flag
//
// Notes:
// - Overflow/underflow are detected and optionally saturated.
// - Multiplication result is truncated/rounded back to DATA_WIDTH.
//

module alu_fixed_point #(
    parameter INT_WIDTH  = 4,
    parameter FRAC_WIDTH = 4,
    parameter DATA_WIDTH = INT_WIDTH + FRAC_WIDTH + 1
)(
    input  logic signed [DATA_WIDTH-1:0] a,
    input  logic signed [DATA_WIDTH-1:0] b,
    input  logic [1:0]                   op,
    output logic signed [DATA_WIDTH-1:0] result,
    output logic overflow,
    output logic underflow
);

    // Internal wide calculation signal
logic signed [(2*DATA_WIDTH)-1:0] temp; // intermediate wide
logic signed [DATA_WIDTH:0]       calc; // one bit wider than DATA_WIDTH

// Constants: maximum and minimum representable values
localparam signed [DATA_WIDTH-1:0] MAX_VAL =
    {1'b0, {DATA_WIDTH-1{1'b1}}};

localparam signed [DATA_WIDTH-1:0] MIN_VAL =
    {1'b1, {DATA_WIDTH-1{1'b0}}};

always_comb begin
    temp      = '0;
    calc      = '0;
    overflow  = 1'b0;
    underflow = 1'b0;

    case (op)
        2'b00: calc = a + b;   // ADD
        2'b01: calc = a - b;   // SUB
        2'b10: begin           // MUL
            temp = a * b;
            calc = temp >>> FRAC_WIDTH; // scale back to Qm.n
        end
        2'b11: begin           // DIV
            if (b == 0) begin
                calc     = '0;
                overflow = 1'b1; // Division by zero
            end else begin
                temp = (a <<< FRAC_WIDTH);
                calc = temp / b; // scale numerator before division
            end
        end
        default: calc = '0;
    endcase

    result    = calc[DATA_WIDTH-1:0];
    overflow  |= (calc > MAX_VAL);
    underflow |= (calc < MIN_VAL);
end


endmodule





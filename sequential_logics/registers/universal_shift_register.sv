/*
Universal_Shift_Register
- N-bit register with: hold, shift-right, shift-left, parallel load
- Active-low reset
- Shift-right pulls from MSB_in (enters at MSB)
- Shift-left pulls from LSB_in (enters at LSB)
- opcode (s1 s0):
    00: hold
    01: shift right
    10: shift left
    11: parallel load
*/

`timescale 1ps/1ps
module universal_shift_register #(
    parameter int N = 4
) (
    input  logic              clk,
    input  logic              rst_n,         // active-low reset
    input  logic [1:0]        opcode,        // {s1,s0}
    input  logic [N-1:0]      parallel_in,   // I_par
    input  logic              MSB_in,        // serial bit into MSB on shift-right
    input  logic              LSB_in,        // serial bit into LSB on shift-left
    output logic [N-1:0]      out            // A_par
);

    // Optional static check (avoid N<1)
    initial begin
        if (N < 1) $fatal(1, "N must be >= 1");
    end

    // Sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out <= '0;
        end else begin
            unique case (opcode)
                2'b00: out <= out;                                 // hold
                2'b01: out <= {MSB_in, out[N-1:1]};                // shift right
                2'b10: out <= {out[N-2:0], LSB_in};                // shift left
                2'b11: out <= parallel_in;                         // parallel load
                default: out <= out;                               // safe hold
            endcase
        end
    end

endmodule
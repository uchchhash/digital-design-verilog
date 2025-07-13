// Majority Voter (4‑Input) using Full Boolean Expression
// This module implements a 4-input majority voter using a full sum of products.
// The output is `1` if at least 3 out of 4 inputs are `1`.
// Inputs: A, B, C, D
// Output: Y

module votes (
    input  logic A,
    input  logic B,
    input  logic C,
    input  logic D,
    output logic Y
);

    // Unminimized sum of minterms (≥3 ones)
    always_comb begin
        Y = (~A &  B &  C &  D) |
            ( A & ~B &  C &  D) |
            ( A &  B & ~C &  D) |
            ( A &  B &  C & ~D) |
            ( A &  B &  C &  D);
    end

endmodule

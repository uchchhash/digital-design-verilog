// Reduced Majority Voter (4‑Input) using K-Map
// This module implements a 4-input majority voter using a minimized sum of products derived from Karnaugh Map (K-Map).
// The output is `1` if at least 3 out of 4 inputs are `1`.
// Inputs: A, B, C, D
// Output: Y   

module votes_reduced (
    input  logic A,
    input  logic B,
    input  logic C,
    input  logic D,
    output logic Y
);

    // Minimized using K-Map
    always_comb begin
        Y = (A & B & C) |
            (A & B & D) |
            (A & C & D) |
            (B & C & D);
    end

endmodule

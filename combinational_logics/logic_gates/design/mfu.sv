module mfu ( 
    input logic a,
    input logic b,
    input logic [2:0] sel,
    output logic y
);

    always_comb begin
        case (sel)
            3'b000: y = a & b;   // AND
            3'b001: y = a | b;   // OR
            3'b010: y = ~a;      // NOT (ignores b)
            3'b011: y = ~(a & b); // NAND
            3'b100: y = ~(a | b); // NOR
            3'b101: y = a ^ b;   // XOR
            3'b110: y = ~(a ^ b); // XNOR
            3'b111: y = 1'b0;    // Reserved, output is 0
            default: y = 1'b0;   // Default case to handle unexpected values
        endcase
    end

    
endmodule
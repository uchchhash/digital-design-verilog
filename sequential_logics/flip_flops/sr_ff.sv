

// SR Flip Flop 

module sr_ff(
    input logic clk, rst_n, s, r,
    output logic q
);


    always_ff @(posedgle clk)begin
        if(!rst_n) q <= 0;
        else begin
          case({s,r})
            2'b00 : q <= q; // hold
            2'b01 : q <= 0; // reset
            2'b10 : q <= 1; // set
            2'b11 : q <= q; // default as hold to avoid illegal state
          endcase
        end
    end


endmodule

// module tb_sr;

//     // Clock generation
//     logic clk;
//     always #5 clk = ~clk;

//     // DUT connection
//     sr_ff dut(.clk(clk), .rst_n(rst_n), .s(s), .r(r), .);



// endmodule
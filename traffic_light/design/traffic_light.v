module traffic_light (clock, light);

  input clock;
  output reg [1:0] light; // 00: Red, 01: Green, 10: Yellow
  parameter S0=0, S1=1, S2=2; // State encoding
  parameter RED=0, GREEN=1, YELLOW=2; // Light encoding
  reg [1:0] state;

  always @(posedge clock) begin
    case(state)
      S0: begin // Red light state
        light <= RED;
        state <= S1; // Transition to Green
      end

      S1: begin // Green light state
        light <= GREEN;
        state <= S2; // Transition to Yellow
      end

      S2: begin // Yellow light state
        light <= YELLOW;
        state <= S0; // Transition back to Red
      end

      default: begin
        light <= RED; // Default to Red if unknown state
        state <= S0; // Reset to Red state
      end
    endcase   
  end
endmodule
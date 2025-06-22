module tb_traffic_light;

  // Parameters
  parameter clock_PERIOD = 10; // Clock period in ns

  // Signals
  reg clock;
  wire [1:0] light; // 00: Red, 01: Green, 10: Yellow

  // Instantiate the traffic light module
  traffic_light uut (
    .clock(clock),
    .light(light)
  );

  // Clock generation
  initial begin
    clock = 0;
    forever #(clock_PERIOD / 2) clock = ~clock;
  end

  // Testbench stimulus
  initial begin

    // Run for a few cycles to observe the light states
    repeat (10) @(posedge clock);
    
    $finish; // End simulation
  end

  // Monitor the light state
  initial begin
    $monitor("Time: %0t, Light State: %b", $time, light);
  end 
  // Dump waveform for analysis
  initial begin 
    $dumpfile("traffic_light.vcd");
    $dumpvars(0, tb_traffic_light);
  end

endmodule
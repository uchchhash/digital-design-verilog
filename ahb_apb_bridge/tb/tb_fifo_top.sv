`timescale 1ns/1ps
`default_nettype none

module tb_fifo_top;

  // ------------ Params ------------
  localparam int DATA_WIDTH = 8;
  localparam int FIFO_DEPTH = 16;

  // ------------ DUT I/O ------------
  logic                     reset_n;
  logic                     wclk, rclk;
  logic                     wen, ren;
  logic [DATA_WIDTH-1:0]    wdata;
  logic [DATA_WIDTH-1:0]    rdata;
  logic                     fifo_full;
  logic                     fifo_empty;
  logic [$clog2(FIFO_DEPTH):0] fifo_space;

  // ------------ DUT ------------
  fifo_top #(
    .DATA_WIDTH (DATA_WIDTH),
    .FIFO_DEPTH (FIFO_DEPTH)
  ) dut (
    .reset_n     (reset_n),
    .wclk        (wclk),
    .rclk        (rclk),
    .wen         (wen),
    .ren         (ren),
    .wdata       (wdata),
    .rdata       (rdata),
    .fifo_full   (fifo_full),
    .fifo_empty  (fifo_empty),
    .fifo_space  (fifo_space)
  );

  // ------------ Clocks ------------
  // wclk = 100 MHz (10 ns), rclk ~71.4 MHz (14 ns)
  initial begin wclk = 0; forever #5  wclk = ~wclk; end
  initial begin rclk = 0; forever #7  rclk = ~rclk; end

  // ------------ Model / Scoreboard ------------
  typedef logic [DATA_WIDTH-1:0] data_t;
  data_t q[$];   // FIFO model queue

  int writes_ok, reads_ok, writes_blocked, reads_blocked, mismatches;

  // ------------ Utilities ------------
  task automatic apply_reset(int wcycles = 5);
    begin
      reset_n = 0;
      wen = 0; ren = 0; wdata = '0;
      q.delete();
      repeat (wcycles) @(posedge wclk);
      reset_n = 1;
      // let status settle on both domains
      repeat (2) @(posedge wclk);
      repeat (2) @(posedge rclk);
      $display("[%0t] Reset released", $time);
    end
  endtask

  // Waiters to respect registered flags
  task automatic wait_not_full();
    while (fifo_space == 0) @(posedge wclk);
  endtask

  task automatic wait_not_empty();
    while (fifo_empty) @(posedge rclk);
  endtask

  // ------------- Transactional Tasks -------------
  // Write one word (self-gated via fifo_space)
  task automatic write_one(input data_t d);
    begin
      wait_not_full();
      @(posedge wclk);
      wen   = 1;
      wdata = d;
      @(posedge wclk);
      wen   = 0;
      writes_ok++;
      q.push_back(d);
    end
  endtask

  // Read one word (matches registered-read DUT)
  task automatic read_one(output data_t d);
    begin
      wait_not_empty();
      @(posedge rclk);
      ren = 1;
      @(posedge rclk); // capture registered rdata
      ren = 0;
      d = rdata;
      reads_ok++;

      if (q.size() == 0) begin
        $error("[%0t] TB underflow: model queue empty but read occurred", $time);
        mismatches++;
      end else begin
        data_t exp = q.pop_front();
        if (d !== exp) begin
          $error("[%0t] DATA MISMATCH: got %0d exp %0d", $time, d, exp);
          mismatches++;
        end
      end
    end
  endtask

  // Burst helpers
  task automatic write_burst(input int n, input int seed = 1);
    data_t v;
    for (int i = 0; i < n; i++) begin
      v = data_t'($urandom(seed+i));
      write_one(v);
    end
  endtask

  task automatic read_burst(input int n);
    data_t v;
    for (int i = 0; i < n; i++) begin
      read_one(v);
    end
  endtask

  // ------------- Phases -------------
  task automatic phase_single_transfer();
    data_t x, y;
    x = 'hA5;
    $display("[%0t] Phase: single write/read", $time);
    write_one(x);
    read_one(y);
  endtask

  task automatic phase_fill_to_full_and_overflow();
    $display("[%0t] Phase: fill to full", $time);
    // push exactly FIFO_DEPTH elements
    for (int i = 0; i < FIFO_DEPTH; i++) begin
      write_one(data_t'(i));
    end
    // let flags settle
    @(posedge wclk);
    $display("[%0t] After fill: fifo_full=%0b space=%0d", $time, fifo_full, fifo_space);

    // Try to overflow: drive wen high for a few beats; DUT should block internally
    $display("[%0t] Phase: overflow attempts", $time);
    repeat (4) begin
      @(posedge wclk);
      wen = 1;
      wdata = 'hFF;
      if (fifo_space == 0) writes_blocked++;
    end
    @(posedge wclk) wen = 0;
  endtask

  task automatic phase_drain_to_empty_and_underflow();
    data_t v;
    $display("[%0t] Phase: drain to empty", $time);
    // Pop everything
    for (int i = 0; i < FIFO_DEPTH; i++) begin
      read_one(v);
    end
    @(posedge rclk);
    $display("[%0t] After drain: fifo_empty=%0b space=%0d", $time, fifo_empty, fifo_space);

    // Underflow attempts
    $display("[%0t] Phase: underflow attempts", $time);
    repeat (4) begin
      @(posedge rclk);
      ren = 1;
      if (fifo_empty) reads_blocked++;
    end
    @(posedge rclk) ren = 0;
  endtask

  task automatic phase_mixed_concurrent(input int cycles = 100, input int seed = 11);
    $display("[%0t] Phase: mixed concurrent R/W", $time);
    fork
      // Write thread (skewed prob)
      begin
        for (int i = 0; i < cycles; i++) begin
          @(posedge wclk);
          if (!$urandom_range(0,3,seed+i)) begin
            if (fifo_space != 0) begin
              wen   = 1;
              wdata = data_t'($urandom(seed+100+i));
              q.push_back(wdata);
              writes_ok++;
            end else begin
              wen = 1; writes_blocked++;
            end
          end else begin
            wen = 0;
          end
        end
        @(posedge wclk) wen = 0;
      end
      // Read thread (skewed prob)
      begin
        for (int j = 0; j < cycles; j++) begin
          @(posedge rclk);
          if (!$urandom_range(0,3,seed+200+j)) begin
            if (!fifo_empty) begin
              ren = 1;
              @(posedge rclk);
              ren = 0;
              reads_ok++;
              if (q.size()==0) begin
                $error("[%0t] Model queue empty during mixed read", $time);
                mismatches++;
              end else begin
                data_t exp = q.pop_front();
                if (rdata !== exp) begin
                  $error("[%0t] MIXED DATA MISMATCH: got %0d exp %0d", $time, rdata, exp);
                  mismatches++;
                end
              end
            end else begin
              ren = 1; reads_blocked++;
              @(posedge rclk) ren = 0;
            end
          end else begin
            ren = 0;
          end
        end
      end
    join
  endtask

  task automatic phase_async_reset_mid_traffic();
    $display("[%0t] Phase: async reset mid-traffic", $time);
    fork
      begin : WGEN
        for (int i = 0; i < 20; i++) begin
          write_one(data_t'($urandom(i)));
        end
      end
      begin : RGEN
        data_t tmp;
        for (int i = 0; i < 20; i++) begin
          read_one(tmp);
        end
      end
      begin : ASYNC_RST
        // Drop reset asynchronously between edges
        #(13); reset_n = 0;
        wen = 0; ren = 0;
        q.delete();
        // keep it low for a couple of wclk/rclk edges
        repeat (3) @(posedge wclk);
        repeat (3) @(posedge rclk);
        reset_n = 1;
        repeat (2) @(posedge wclk);
        repeat (2) @(posedge rclk);
        $display("[%0t] Async reset pulse applied & released", $time);
      end
    join
  endtask

  task automatic phase_random_stress(input int n_ops = 200, input int seed = 42);
    $display("[%0t] Phase: random stress", $time);
    data_t tmp;
    for (int i = 0; i < n_ops; i++) begin
      // Randomly decide op per domain
      @(posedge wclk);
      if ($urandom(seed+i) % 2) begin
        if (fifo_space != 0) begin
          wen   = 1;
          wdata = data_t'($urandom(seed+1000+i));
          q.push_back(wdata);
          writes_ok++;
        end else begin
          wen = 1; writes_blocked++;
        end
      end else begin
        wen = 0;
      end

      @(posedge rclk);
      if ($urandom(seed+2*i) % 2) begin
        if (!fifo_empty) begin
          ren = 1;
          @(posedge rclk);
          ren = 0;
          reads_ok++;
          if (q.size()==0) begin
            $error("[%0t] Model queue empty in stress", $time);
            mismatches++;
          end else begin
            data_t exp = q.pop_front();
            if (rdata !== exp) begin
              $error("[%0t] STRESS DATA MISMATCH: got %0d exp %0d", $time, rdata, exp);
              mismatches++;
            end
          end
        end else begin
          ren = 1; reads_blocked++;
          @(posedge rclk) ren = 0;
        end
      end else begin
        ren = 0;
      end
    end
    @(posedge wclk) wen = 0;
    @(posedge rclk) ren = 0;
  endtask

  // ------------ Simple Assertions (TB hygiene) ------------
  // These catch *testbench* misuse (not DUT bugs), since the DUT already gates internally.
  property no_tb_overflow; @(posedge wclk) disable iff(!reset_n) !(wen && fifo_space==0); endproperty
  property no_tb_underflow; @(posedge rclk) disable iff(!reset_n) !(ren && fifo_empty); endproperty
  assert property(no_tb_overflow) else $warning("[%0t] TB drove wen when space==0", $time);
  assert property(no_tb_underflow) else $warning("[%0t] TB drove ren when empty==1", $time);

  // ------------ Main ------------
  initial begin
    writes_ok = 0; reads_ok = 0; writes_blocked = 0; reads_blocked = 0; mismatches = 0;

    apply_reset();

    $display("[%0t] Starting FIFO full testbench...", $time);

    phase_single_transfer();
    phase_fill_to_full_and_overflow();
    phase_drain_to_empty_and_underflow();
    phase_mixed_concurrent(120, 17);
    phase_async_reset_mid_traffic();
    phase_random_stress(300, 99);

    // Drain anything left to keep scoreboard honest
    data_t v;
    while (!fifo_empty) begin
      read_one(v);
    end

    // Summary
    $display("\n========== TEST SUMMARY ==========");
    $display("Writes accepted      : %0d", writes_ok);
    $display("Reads accepted       : %0d", reads_ok);
    $display("Writes blocked (full): %0d", writes_blocked);
    $display("Reads blocked (empty): %0d", reads_blocked);
    $display("Mismatches           : %0d", mismatches);
    $display("Final fifo_empty=%0b, fifo_full=%0b, space=%0d", fifo_empty, fifo_full, fifo_space);
    $display("==================================\n");

    if (mismatches==0) $display("RESULT: PASS");
    else               $display("RESULT: FAIL");

    repeat (10) @(posedge wclk);
    $finish;
  end

endmodule

`default_nettype wire

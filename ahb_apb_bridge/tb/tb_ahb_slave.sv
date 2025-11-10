`include "/home/ucchash/usarkar_work/github_repos/digital-design-verilog/ahb_apb_bridge/design/ahb_slave.sv"
`timescale 1ns/1ps

module tb_ahb_slave;

  // ------------------------
  // Parameters
  // ------------------------
  localparam int HADDR_W = 8;
  localparam int HDATA_W = 32;
  localparam int HFIFO_D = 16;
  localparam int CTRL_W  = 1 + 2 + 3 + 3 + HADDR_W;

  // ------------------------
  // DUT I/O
  // ------------------------
  logic                  HCLK, HRESETn;
  logic                  HREADYIN;
  logic                  HSEL, HWRITE;
  logic [1:0]            HTRANS;
  logic [2:0]            HBURST, HSIZE;
  logic [HADDR_W-1:0]    HADDR;
  logic [HDATA_W-1:0]    HWDATA;
  logic [HDATA_W-1:0]    HRDATA;
  logic                  HRESP, HREADYOUT;

  logic                  ctrl_wen, ahb_data_wen, apb_data_ren;
  logic                  ctrl_full, ahb_data_full, apb_data_empty;
  logic [$clog2(HFIFO_D):0] ctrl_sp, ahb_data_sp;
  logic [CTRL_W-1:0]     ctrl_pipe;
  logic [HDATA_W-1:0]    ahb_data_pipe;
  logic [HDATA_W-1:0]    apb_data_read;

  // ------------------------
  // Clock / Reset
  // ------------------------
  initial begin
    HCLK = 0;
    forever #5 HCLK = ~HCLK;  // 100 MHz
  end

  initial begin
    HRESETn = 0;
    repeat (3) @(posedge HCLK);
    HRESETn = 1;
  end

  // ------------------------
  // Default FIFO behavior (stubbed)
  // ------------------------
  assign ctrl_full      = 0;
  assign ahb_data_full  = 0;
  assign apb_data_empty = 0;
  assign ctrl_sp        = HFIFO_D;
  assign ahb_data_sp    = HFIFO_D;
  assign apb_data_read  = 32'hDEAD_BEEF;

  // ------------------------
  // DUT Instantiation
  // ------------------------
  ahb_slave #(
    .haddrWidth(HADDR_W),
    .hdataWidth(HDATA_W),
    .hFifoDepth(HFIFO_D)
  ) dut (
    .HCLK,
    .HRESETn,
    .HREADYIN,
    .HSEL,
    .HWRITE,
    .HTRANS,
    .HBURST,
    .HSIZE,
    .HADDR,
    .HWDATA,
    .HRDATA,
    .HRESP,
    .HREADYOUT,
    .ctrl_wen,
    .ahb_data_wen,
    .apb_data_ren,
    .ctrl_full,
    .ahb_data_full,
    .apb_data_empty,
    .ctrl_sp,
    .ahb_data_sp,
    .ctrl_pipe,
    .ahb_data_pipe,
    .apb_data_read
  );

  // ------------------------
  // Task helpers
  // ------------------------
  task automatic drive_idle();
    HSEL = 1; HTRANS = 2'b00; HWRITE = 0; HADDR = 0; HWDATA = 0;
    HREADYIN = 1;
  endtask

  task automatic drive_write(input [7:0] addr, input [31:0] data);
    @(posedge HCLK);
    HSEL = 1; HWRITE = 1; HTRANS = 2'b10; // NONSEQ
    HBURST = 3'b000; HSIZE = 3'b010; HADDR = addr; HWDATA = data;
    HREADYIN = 1;
    @(posedge HCLK);
    HTRANS = 2'b00; HSEL = 0; // back to IDLE
  endtask

  task automatic drive_read(input [7:0] addr);
    @(posedge HCLK);
    HSEL = 1; HWRITE = 0; HTRANS = 2'b10; // NONSEQ read
    HBURST = 3'b000; HSIZE = 3'b010; HADDR = addr;
    HREADYIN = 1;
    @(posedge HCLK);
    HTRANS = 2'b00; HSEL = 0;
  endtask

  // ------------------------
  // Stimulus
  // ------------------------
  initial begin
    drive_idle();
    @(posedge HRESETn);

    $display("=== WRITE phase test ===");
    drive_write(8'h10, 32'hCAFE_BABE);
    repeat (3) @(posedge HCLK);

    $display("=== READ phase test ===");
    drive_read(8'h20);
    repeat (3) @(posedge HCLK);

    $display("=== DONE ===");
    #20 $finish;
  end

  // ------------------------
  // Monitor
  // ------------------------
  always @(posedge HCLK) begin
    if (HRESETn) begin
      $display("%0t | ST=%0d | HADDR=%h | HWRITE=%b | ctrl_wen=%b ahb_wen=%b apb_ren=%b HREADYOUT=%b HRDATA=%h",
               $time, dut.pstate, HADDR, HWRITE, ctrl_wen, ahb_data_wen, apb_data_ren, HREADYOUT, HRDATA);
    end
  end

    always @(posedge HCLK) if (HRESETn) begin
    $display("%0t ST=%0d addr_valid=%0b acc=%0b selD=%0b | ctrl_wen=%0b ahb_wen=%0b apb_ren=%0b",
        $time, dut.pstate, dut.addr_valid, dut.addr_accept, dut.selected_d,
        ctrl_wen, ahb_data_wen, apb_data_ren);
    end



endmodule

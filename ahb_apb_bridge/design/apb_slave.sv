
/*
                                   -----------
    PCLK                      ===>|           | 
    PRESETn                   ===>|           |
    PSEL                      ===>|    APB    | ===> PREADY
    PENABLE                   ===>|   SLAVE   | ===> [pdataWidth-1:0] PRDATA
    PWRITE                    ===>|           |
    PADDR   [paddrWidth-1:0]  ===>|           |
    PWDATA  [pdataWidth-1:0]  ===>|           |
                                   -----------
*/

`timescale 1ps/1ps

module apb_slave #(
  parameter int paddrWidth = 8,   // log2(number of words)
  parameter int pdataWidth = 32   // data width in bits (8*n)
)(
  // ---------------- APB Interface ----------------
  input  logic                  PCLK,
  input  logic                  PRESETn,

  input  logic                  PSEL,      // selects this slave (addr phase)
  input  logic                  PENABLE,   // high in ACCESS phase
  input  logic                  PWRITE,    // 1=write, 0=read
  input  logic [31:0]           PADDR,     // byte address from bus
  input  logic [pdataWidth-1:0] PWDATA,    // write data
  output logic [pdataWidth-1:0] PRDATA,    // valid when ACCESS & PREADY
  output logic                  PREADY     // ready to complete ACCESS
);

  // ===========================================================================
  // Addressing / Memory
  // ===========================================================================
  localparam int DEPTH = (1 << paddrWidth);

  logic [pdataWidth-1:0] mem [0:DEPTH-1];

  // Word index from byte address (natural alignment)
  // 1 KB Address Boundary (0x000–0x3FF)
  wire [paddrWidth-1:0] idx = PADDR[paddrWidth+1 : 2];

  // Latched address/control sampled in SETUP
  logic [paddrWidth-1:0] idx_q;
  logic                  write_q;

  // ===========================================================================
  // APB State Machine
  // ===========================================================================
  typedef enum logic [1:0] { IDLE, SETUP, ACCESS } state_t;
  state_t pstate, nstate;

  // Handshake helpers
  wire apb_setup;
  wire apb_access;
  wire xfer_done;

  assign apb_setup  = PSEL && !PENABLE;
  assign apb_access = PSEL &&  PENABLE;
  assign xfer_done  = apb_access && PREADY;

  // ===========================================================================
  // Sequential: state + datapath
  //   - Capture addr/control in SETUP
  //   - Write on ACCESS handshake
  //   - Prepare PRDATA in SETUP so it’s stable during ACCESS (zero-wait)
  // ===========================================================================
  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      pstate  <= IDLE;
      idx_q   <= '0;
      write_q <= 1'b0;
      PRDATA  <= '0;
    end else begin
      pstate <= nstate;
      // Sample address/control at SETUP handshake
      if (apb_setup) begin
        idx_q   <= idx;
        write_q <= PWRITE;
        if (!PWRITE) begin
          // Prepare read data early for zero-wait ACCESS
          PRDATA <= mem[idx];
        end
      end
      // Perform write on ACCESS handshake
      if (xfer_done && write_q) begin
        mem[idx_q] <= PWDATA;
      end
    end
  end

  // ===========================================================================
  // Combinational: next-state and PREADY
  //   - Zero-wait: PREADY=1 in ACCESS
  //   - Advance state only after handshake completes
  // ===========================================================================
  always_comb begin
    nstate = pstate;
    PREADY = 1'b0;

    unique case (pstate)
      IDLE: begin
        if (PSEL) nstate = SETUP;
      end
      SETUP: begin
        // Next cycle, master either keeps PSEL=1 (back-to-back) 
        // or drops it to go to idle
        nstate = (PSEL ? ACCESS : IDLE);
      end
      ACCESS: begin
        PREADY = 1'b1;                  // zero-wait
        if (xfer_done) nstate = SETUP;  // one-cycle handoff
      end
      default: nstate = IDLE;
    endcase

  end


endmodule



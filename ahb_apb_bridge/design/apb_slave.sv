
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

// ============================================================================
//   Simple APB Slave (single-ported memory)
// - APB timing: SETUP (PSEL=1,PENABLE=0) → ACCESS (PSEL=1,PENABLE=1)
// - Reads: PRDATA must be valid during ACCESS when PREADY=1
// - Writes: commit in ACCESS when PREADY=1 and PWRITE=1
// - This version uses *combinational reads* (zero-wait by default)
// ============================================================================

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
  output logic [pdataWidth-1:0] PRDATA,    // read data (valid when ACCESS & PREADY)
  output logic                  PREADY     // this slave is ready to complete ACCESS
  // (Optional APB4 signals not modeled here: PSTRB, PPROT, PSLVERR)
);

  // ===========================================================================
  // Addressing / Memory
  // - DEPTH is the number of words (pdataWidth-wide locations)
  // - We treat PADDR as *byte* address; index is word-aligned: [paddrWidth+1:2]
  //   (i.e., drop A[1:0] to convert byte address → word index)
  // ===========================================================================
  localparam int DEPTH = (1 << paddrWidth);

  // Simple register array = single-ported "memory"
  logic [pdataWidth-1:0] mem [0:DEPTH-1];

  // Word index from byte address (assumes natural alignment)
  wire [paddrWidth-1:0] idx = PADDR[paddrWidth+1 : 2];

  // ===========================================================================
  // APB State Machine (classic 2-phase: SETUP → ACCESS)
  //  IDLE  : waiting for a transfer (PSEL=0)
  //  SETUP : PSEL=1, PENABLE=0 (address/control phase)
  //  ACCESS: PSEL=1, PENABLE=1 (data phase); transfer completes when PREADY=1
  // ===========================================================================
  typedef enum logic [1:0] { IDLE, SETUP, ACCESS } state_t;
  state_t pstate, nstate;

  // ===========================================================================
  // Sequential: state register and WRITE commit
  // - We ONLY write during ACCESS when PSEL & PENABLE & PREADY & PWRITE.
  //   (APB spec: write occurs in the ACCESS phase when the transfer completes.)
  // - For reads, we use *combinational* PRDATA; no sequential assignment needed.
  // ===========================================================================
  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      pstate <= IDLE;
      // NOTE: Resetting the whole `mem` array in hardware is expensive;
      // synth tools may infer a huge reset network. Prefer leaving it X/undefined
      // in hardware and using $readmemh for simulation init if needed.
      for (int i = 0; i < DEPTH; i++) mem[i] <= '0; // (SIM-ONLY if you really want)
    end
    else begin
      pstate <= nstate;

      // Synchronous write on completed ACCESS
      if (pstate == ACCESS && PSEL && PENABLE && PREADY && PWRITE) begin
        mem[idx] <= PWDATA;
      end
    end
  end

  // ===========================================================================
  // Combinational: next-state and PREADY
  // - This version is zero-wait by default: PREADY goes high in ACCESS.
  // - To add wait states, deassert PREADY in ACCESS until your condition clears.
  // ===========================================================================
  always_comb begin
    nstate = pstate;
    PREADY = 1'b0;             // default: not ready (except in ACCESS below)

    unique case (pstate)
      IDLE: begin
        // Start a transfer when PSEL is asserted
        if (PSEL) nstate = SETUP;
      end

      SETUP: begin
        // APB protocol: next cycle must be ACCESS (PENABLE will be 1)
        nstate = ACCESS;
      end

      ACCESS: begin
        // Zero-wait implementation: we are always ready in ACCESS
        // (If you need wait states, hold PREADY=0 until your resource is ready.)
        PREADY = 1'b1;

        // Back-to-back transfers:
        //  - If PSEL stays high, next cycle becomes a new SETUP.
        //  - If PSEL drops, return to IDLE.
        nstate = (PSEL ? SETUP : IDLE);
      end
    endcase
  end

  // ===========================================================================
  // Read Data Path (zero-wait, combinational)
  // - APB requires PRDATA to be valid *during* ACCESS when PREADY=1.
  // - Since we assert PREADY in ACCESS, drive PRDATA directly from mem[idx].
  // - If you later add wait states, PRDATA must remain stable while ACCESS holds.
  // ===========================================================================
  always_comb begin
    // For reads: PRDATA should reflect the addressed word.
    // For writes: PRDATA is don't-care; drive something benign (e.g., mem[idx]).
    PRDATA = mem[idx];
  end

  // ===========================================================================
  // Notes / Extensibility:
  //  • Alignment: We assume word-aligned accesses (PADDR[1:0]==0 for 32-bit data).
  //    If your upstream might do byte/halfword accesses, you’ll need byte strobes
  //    (APB4 PSTRB) and sub-word masking.
  //  • PSLVERR: Add an output if you need to signal errors (illegal addresses,
  //    alignment, protection, etc.). Assert it only in ACCESS when PREADY=1.
  //  • Wait states: Gate PREADY low in ACCESS until your memory/bridge is ready
  //    (e.g., `if (busy) PREADY=0; else PREADY=1;`).
  //  • Read latency option: If you prefer *registered* PRDATA, preload it in
  //    SETUP (PRDATA_next = mem[idx]) and then assert PREADY in ACCESS. That
  //    introduces one cycle of latency but meets timing easily for large memories.
  // ===========================================================================

endmodule


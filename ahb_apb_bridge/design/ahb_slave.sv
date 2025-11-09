`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// AHB-Lite Slave (front half) — PRE-NSL ONLY
//
// This unit implements everything up to (but not including) the Next-State Logic
// (NSL) and Output/Data Logic (OL). The design follows the AHB-Lite timing rule
// that the slave which completed the previous address phase *owns* the current
// data phase and is the only entity allowed to stretch HREADY.
//
// What’s included:
//  • Parameters, ports, bus encodings
//  • FSM state flops (NSL will be added later)
//  • Burst helpers + latched reservation (captured on accepted NONSEQ)
//  • AHB accept qualifiers (accept / nseq_accept / seq_accept)
//  • Data-phase ownership (selected_d) + address-phase capture (a_d)
//  • Legal HREADYOUT gating template (only data-owner may stall the bus)
//  • Datapath scaffolding to FIFOs (ctrl_pipe, ahb_data_pipe); enables held low
//
// What’s purposely not included yet:
//  • NSL (case on pstate -> nstate transitions)
//  • Output/Data Logic (pulsing ctrl_wen/ahb_data_wen/apb_data_ren,
//    HRDATA muxing, backpressure gating beyond placeholders, HRESP errors)
//
// Integration strategy:
//  1) Write NSL to move through *_ADDR/_WAIT/_DATA/_VALID states using
//     addr_accept/nseq_accept/seq_accept and the space/data-ready checks below.
//  2) In OL, only the data-phase owner (selected_d==1) may deassert HREADYOUT.
//     All stalls must be gated by selected_d.
// -----------------------------------------------------------------------------
module ahb_slave #(
  parameter int haddrWidth = 8,
  parameter int hdataWidth = 32,
  parameter int hFifoDepth = 8,
  // ctrl_pipe payload packed as: {HWRITE, HTRANS, HBURST, HSIZE, HADDR}
  parameter int CTRL_W = 1 + 2 + 3 + 3 + haddrWidth
)(
  // ========================= AHB Slave Interface =========================
  input  logic                  HCLK,
  input  logic                  HRESETn,

  // AHB-Lite handshake:
  //  • HREADYin==1 means the *previous* data phase completed this cycle, so the
  //    current address/control on the bus (if valid) can be *accepted* now.
  //  • HREADYOUT contributes to the global HREADY. Only the data-phase owner may
  //    drive it low to insert wait states.
  input  logic                  HREADYin,

  // Address/control phase signals (driven by master during addr phase):
  input  logic                  HSEL,         // this slave is selected (addr phase)
  input  logic                  HWRITE,
  input  logic [1:0]            HTRANS,       // IDLE/BUSY/NSEQ/SEQ
  input  logic [2:0]            HBURST,       // SINGLE/INCR/WRAPx/INCRx
  input  logic [2:0]            HSIZE,        // byte/half/word/...
  input  logic [haddrWidth-1:0] HADDR,

  // Write data associated with the *previous* accepted write address beat.
  // Remember: addr and data are decoupled by one cycle on AHB.
  input  logic [hdataWidth-1:0] HWDATA,

  // Data-phase outputs from this slave:
  output logic [hdataWidth-1:0] HRDATA,       // valid in read data phase when ready
  output logic                  HRESP,        // 0=OKAY, 1=ERROR (kept OKAY here)
  output logic                  HREADYOUT,    // this slave’s contribution to HREADY

  // ========================== Bridge Side Signals ========================
  // These signals connect to the internal bridge FIFOs (e.g., AHB→APB bridge).
  // Enables are asserted in Output/Data Logic (not here).
  output logic                  ctrl_wen,       // push control (addr-phase accepted)
  output logic                  ahb_data_wen,   // push write data (data-phase)
  output logic                  apb_data_ren,   // pop read data (to drive HRDATA)

  // FIFO status (used to decide when to accept/continue bursts and when to stall):
  input  logic                  ctrl_full,
  input  logic                  ahb_data_full,
  input  logic                  apb_data_empty,

  // FIFO space indicators: these are depth+1 wide to represent 0..depth precisely
  input  logic [$clog2(hFifoDepth):0] ctrl_sp,
  input  logic [$clog2(hFifoDepth):0] ahb_data_sp,

  // FIFO datapaths (wired here, enables will be driven later in OL):
  output logic [CTRL_W-1:0]     ctrl_pipe,      // {HWRITE,HTRANS,HBURST,HSIZE,HADDR}
  output logic [hdataWidth-1:0] ahb_data_pipe,  // write data payload
  input  logic [hdataWidth-1:0] apb_data_read   // read data payload
);

  // ===========================================================================
  // Encodings: HTRANS / HBURST
  //  • HTRANS[1]==1 identifies NSEQ/SEQ (valid transfer types).
  //  • BUSY/IDLE (HTRANS[1]==0) must not be “accepted” or advance internal
  //    counters / FIFOs.
  // ===========================================================================
  localparam logic [1:0] HTRANS_IDLE  = 2'b00;
  localparam logic [1:0] HTRANS_BUSY  = 2'b01;
  localparam logic [1:0] HTRANS_NSEQ  = 2'b10; // start of burst
  localparam logic [1:0] HTRANS_SEQ   = 2'b11; // continuation

  localparam logic [2:0] HBURST_SINGLE = 3'b000; // 1 beat
  localparam logic [2:0] HBURST_INCR   = 3'b001; // unbounded (length unknown)
  localparam logic [2:0] HBURST_WRAP4  = 3'b010;
  localparam logic [2:0] HBURST_INCR4  = 3'b011;
  localparam logic [2:0] HBURST_WRAP8  = 3'b100;
  localparam logic [2:0] HBURST_INCR8  = 3'b101;
  localparam logic [2:0] HBURST_WRAP16 = 3'b110;
  localparam logic [2:0] HBURST_INCR16 = 3'b111;

  // ===========================================================================
  // FSM States (address/data split across states) — NSL will be added later
  //  • Keep states fine-grained so OL can cleanly pulse enables and gate stalls.
  // ===========================================================================
  typedef enum logic [3:0] {
    HIDLE_STATE,        // Idle/park
    HNSEQ_WAIT_STATE,   // Waiting to begin a new NONSEQ (addr accepted)

    // Write path
    HWRITE_ADDR_STATE,  // Accept a write address/control beat (push to ctrl FIFO)
    HWRITE_WAIT_STATE,  // Wait for ctrl FIFO space before starting/continuing write burst
    HWRITE_DATA_STATE,  // Consume a write data beat (push to write-data FIFO)

    // Read path
    HREAD_ADDR_STATE,   // Accept a read address/control beat (push to ctrl FIFO)
    HREAD_WAIT_STATE,   // Wait for read data to become available
    HREAD_VALID_STATE,  // Present read data (drive HRDATA, possibly complete data phase)
    HREAD_HOLD_STATE    // Optional hold/pipeline staging (rarely needed)
  } hstate_t;

  hstate_t pstate, nstate;

  // --------------------------
  // State flops (no NSL yet)
  //  • NSL will compute nstate; we simply register it here.
  // --------------------------
  always_ff @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) pstate <= HIDLE_STATE;
    else          pstate <= nstate;
  end

  // ===========================================================================
  // Burst length helper
  //  • Returns exact beats for fixed bursts (1/4/8/16).
  //  • Returns 0 for INCR/invalid, meaning “length unknown/unbounded”.
  //  • NSL/OL will use this to decide on reservation vs. per-beat checks.
  // ===========================================================================
  function automatic int unsigned burst_len (input logic [2:0] b);
    unique case (b)
      HBURST_SINGLE:                 burst_len = 1;
      HBURST_INCR4,  HBURST_WRAP4:   burst_len = 4;
      HBURST_INCR8,  HBURST_WRAP8:   burst_len = 8;
      HBURST_INCR16, HBURST_WRAP16:  burst_len = 16;
      default:                       burst_len = 0; // INCR or invalid
    endcase
  endfunction

  // ===========================================================================
  // AHB accept qualifiers (addr phase)
  //  • addr_valid : NSEQ/SEQ is on the bus this cycle (independent of HREADYin)
  //  • accept     : a valid beat is *accepted* (requires HREADYin==1)
  //  • nseq_accept/seq_accept : specific accepted type (start/continue)
  //  • OL will pulse ctrl_wen off addr_accept; NSL will use nseq/seq to advance.
  // ===========================================================================
  wire addr_valid  = HSEL && HTRANS[1];      // NSEQ/SEQ present (not IDLE/BUSY)
  logic accept, nseq_accept, seq_accept;
  assign accept      = addr_valid && HREADYin;            // accepted this cycle
  assign nseq_accept = accept && (HTRANS == HTRANS_NSEQ); // start of burst
  assign seq_accept  = accept && (HTRANS == HTRANS_SEQ);  // continuation

  // ===========================================================================
  // Data-phase ownership (selected_d)
  //  • AHB-Lite rule: Only the slave that completed the previous address phase
  //    (i.e., when HREADYin==1) owns the *current* data phase and may stall.
  //  • We latch HSEL on address-phase completion to know if we own the data phase.
  // ===========================================================================
  logic selected_d;
  always_ff @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) selected_d <= 1'b0;
    else if (HREADYin) selected_d <= HSEL; // latch data-phase owner each cycle
  end

  // ===========================================================================
  // Address-phase capture for the upcoming data phase (a_d)
  //  • Capture the fields you need to time-align HRESP, byte-enables, and
  //    per-beat attributes in the *data* phase (one cycle later).
  //  • Captured only when address phase completes (HREADYin==1).
  // ===========================================================================
  typedef struct packed {
    logic                   write;
    logic [2:0]             size;
    logic [2:0]             burst;
    logic [1:0]             trans;
    logic [haddrWidth-1:0]  addr;
  } aphase_t;

  aphase_t a_d;
  always_ff @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
      a_d <= '0;
    end else if (HREADYin && HSEL) begin
      a_d.write <= HWRITE;
      a_d.size  <= HSIZE;
      a_d.burst <= HBURST;
      a_d.trans <= HTRANS;
      a_d.addr  <= HADDR;
    end
  end

  // ===========================================================================
  // Latched reservation on NONSEQ (burst start)
  //  • For fixed-length bursts, we capture the required beats at the true start.
  //  • For INCR (returned 0), we do not “reserve” upfront; we’ll rely on
  //    per-beat checks and allow stalls in our own data phase if needed.
  // ===========================================================================
  logic [4:0] burst_need_q;  // 0,1,4,8,16 (0 means INCR/unbounded)
  logic       is_fixed_burst_d;

  always_ff @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
      burst_need_q      <= '0;
      is_fixed_burst_d  <= 1'b0;
    end else if (nseq_accept) begin
      burst_need_q      <= burst_len(HBURST);
      is_fixed_burst_d  <= (HBURST == HBURST_INCR4)  || (HBURST == HBURST_WRAP4)  ||
                           (HBURST == HBURST_INCR8)  || (HBURST == HBURST_WRAP8)  ||
                           (HBURST == HBURST_INCR16) || (HBURST == HBURST_WRAP16);
    end
  end

  // ===========================================================================
  // Control-FIFO availability aliases
  //  • have_ctrl_space_now       : enough space for a single control beat
  //  • have_ctrl_space_for_burst : enough space for entire fixed-length burst
  //  • have_ctrl_space_needed    : mux between the two (used by NSL decisions)
  // ===========================================================================
  logic have_ctrl_space_now;
  logic have_ctrl_space_for_burst;
  logic have_ctrl_space_needed;

  assign have_ctrl_space_now       = !ctrl_full;
  assign have_ctrl_space_for_burst = (ctrl_sp >= burst_need_q);
  assign have_ctrl_space_needed    = is_fixed_burst_d ? have_ctrl_space_for_burst
                                                      : have_ctrl_space_now;

  // ===========================================================================
  // Default responses and legal HREADYOUT gating
  //
  // HRESP:
  //  • Kept at OKAY here. You will likely add alignment/size checks in OL
  //    based on a_d.* so that HRESP is driven in the correct *data* phase.
  //
  // HREADYOUT:
  //  • Only the *data-phase owner* (selected_d==1) may drive HREADYOUT low.
  //  • If selected_d==0, this slave must drive HREADYOUT==1 (cannot stall).
  //  • We expose “candidate” stall causes; OL will flesh out stall_write_dp /
  //    stall_read_dp to include FIFO backpressure and data-availability.
  // ===========================================================================
  assign HRESP = 1'b0;

  // Candidate: stall during address states when ctrl FIFO is full.
  // NOTE: This condition is *only applied legally* via selected_d gating below.
  wire stall_addr_ctrl = ((pstate==HWRITE_ADDR_STATE) || (pstate==HREAD_ADDR_STATE)) && ctrl_full;

  // Placeholders for data-path backpressure (to be completed in OL):
  //  • Writes: stall when you are about to accept/complete a write data phase
  //    but write-data FIFO is full.
  //  • Reads : stall until read data is available (apb_data_empty deasserts).
  wire stall_write_dp = 1'b0; // e.g., (pstate==HWRITE_DATA_STATE) && ahb_data_full
  wire stall_read_dp  = 1'b0; // e.g., (pstate==HREAD_WAIT_STATE)  && apb_data_empty

  // Simple wait-state states (NSL will place you here when space/data is lacking)
  wire stall_wait = (pstate==HWRITE_WAIT_STATE) || (pstate==HREAD_WAIT_STATE);

  // Legal gating:
  //  • During reset      → ready
  //  • Not data owner    → ready
  //  • Data owner        → ready unless a stall reason is active
  assign HREADYOUT = !HRESETn ? 1'b1
                    : (!selected_d) ? 1'b1
                    : !(stall_addr_ctrl || stall_wait || stall_write_dp || stall_read_dp);

  // ===========================================================================
  // Datapath scaffolding (final gating will be in Output/Data Logic)
  //  • We wire the payloads here so OL can simply pulse enables at the right time.
  //  • ctrl_wen will typically pulse on addr_accept.
  //  • ahb_data_wen will pulse in the write data phase (one cycle after write addr).
  //  • apb_data_ren will pulse when you are completing a read data phase.
  // ===========================================================================
  assign ctrl_pipe     = {HWRITE, HTRANS, HBURST, HSIZE, HADDR};
  assign ahb_data_pipe = HWDATA;
  assign HRDATA        = '0;        // Avoid X-prop; OL will mux apb_data_read
  assign ctrl_wen      = 1'b0;      // OL will drive
  assign ahb_data_wen  = 1'b0;      // OL will drive
  assign apb_data_ren  = 1'b0;      // OL will drive

  // ===========================================================================
  // NSL will be added below (not part of this file by design).
  //
  // NSL tips:
  //  • Only advance on *_accept (qualified by HREADYin==1).
  //  • For fixed bursts, check have_ctrl_space_needed before entering *_ADDR.
  //  • For writes, consider coordinating ctrl FIFO acceptance with write-data
  //    FIFO space policy (reserve upfront or allow data-phase stalls).
  //  • For reads, move HIDLE→HREAD_ADDR when you can enqueue control, then
  //    HREAD_WAIT until data shows, then HREAD_VALID to present HRDATA.
  //  • BUSY must not advance anything (addr_valid filters it out already).
  // ===========================================================================
  // always_comb begin : NSL
  //   nstate = pstate;
  //   unique case (pstate)
  //     HIDLE_STATE: begin
  //       // Example (pseudo-plan):
  //       // if (nseq_accept) begin
  //       //   if (HWRITE)  nstate = have_ctrl_space_needed ? HWRITE_ADDR_STATE : HWRITE_WAIT_STATE;
  //       //   else         nstate = have_ctrl_space_needed ? HREAD_ADDR_STATE  : HREAD_WAIT_STATE;
  //       // end
  //     end
  //     // ...
  //   endcase
  // end


endmodule

// --------------------------- End of PRE-NSL file -----------------------------

`timescale 1ns/1ps

module ahb_slave #(
  parameter int haddrWidth = 8,
  parameter int hdataWidth = 32,
  parameter int hFifoDepth = 16,
  // ctrl_pipe payload packed as: {HWRITE, HTRANS, HBURST, HSIZE, HADDR}
  parameter int CTRL_W = 1 + 2 + 3 + 3 + haddrWidth
)(
  // ========================= AHB Slave Interface =========================
  input  logic                  HCLK,
  input  logic                  HRESETn,

  // AHB-Lite handshake:
  //  • HREADYIN==1 means the *previous* data phase completed this cycle, so the
  //    current address/control on the bus (if valid) can be *accepted* now.
  //  • HREADYOUT contributes to the global HREADY. Only the data-phase owner may
  //    drive it low to insert wait states.
  input  logic                  HREADYIN,

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

  // ===========================================================================
  // Bridge-Side Interface — FIFO Connectivity (AHB ⇄ APB Domain Crossing)
  //
  //  Three independent FIFOs are used to decouple clock domains:
  //   • Control FIFO : carries address/control info  → AHB-to-APB
  //   • AHB-Data FIFO: carries write-data payloads  → AHB-to-APB
  //   • APB-Data FIFO: carries read-data payloads   → APB-to-AHB
  //
  //  Each FIFO has its own handshake flags:
  //   • full / space  → backpressure for AHB side
  //   • empty         → data-availability for APB side
  //
  //  Note: enable pulses (wen/ren) are driven in Output/Data Logic (OL).
  // ===========================================================================

  // ---------------------- FIFO Control Signals (to FIFOs) --------------------
  output logic                  ctrl_wen,       // Control-FIFO:  push command (addr phase accepted)
  output logic                  ahb_data_wen,   // AHB-Data-FIFO: push write-data (data phase complete)
  output logic                  apb_data_ren,   // APB-Data-FIFO: pop read-data  (to drive HRDATA)

  // ---------------------- FIFO Status / Backpressure ------------------------
  input  logic                  ctrl_full,      // Control-FIFO:  full → stall new address acceptance
  input  logic                  ahb_data_full,  // AHB-Data-FIFO: full → stall write-data phase
  input  logic                  apb_data_empty, // APB-Data-FIFO: empty → stall read until data ready

  // ---------------------- FIFO Space Indicators -----------------------------
  //  • Each count is (depth+1) bits wide (0..depth)
  //  • Used by NSL to check fixed-burst reservation and per-beat acceptance.
  input  logic [$clog2(hFifoDepth):0] ctrl_sp,      // available space in Control FIFO
  input  logic [$clog2(hFifoDepth):0] ahb_data_sp,  // available space in AHB-Data FIFO

  // ---------------------- FIFO Datapath Payloads ----------------------------
  //  • These carry actual data/control words between AHB and APB domains.
  //  • OL will assert enables to push/pop when protocol handshakes complete.
  output logic [CTRL_W-1:0]     ctrl_pipe,      // Control-FIFO payload: {HWRITE,HTRANS,HBURST,HSIZE,HADDR}
  output logic [hdataWidth-1:0] ahb_data_pipe,  // AHB-Data-FIFO payload: write-data word
  input  logic [hdataWidth-1:0] apb_data_read   // APB-Data-FIFO payload: read-data word (to HRDATA)

);

  // ===========================================================================
  // Encodings: HTRANS / HBURST
  //  • HTRANS[1]==1 identifies NSEQ/SEQ (valid transfer types).
  //  • BUSY/IDLE (HTRANS[1]==0) must not be “accepted” or advance internal
  //    counters / FIFOs.
  // ===========================================================================
  localparam logic [1:0] IDLE   = 2'b00;
  localparam logic [1:0] BUSY   = 2'b01;
  localparam logic [1:0] NONSEQ = 2'b10; // start of burst
  localparam logic [1:0] SEQ    = 2'b11; // continuation

  localparam logic [2:0] SINGLE = 3'b000; // 1 beat
  localparam logic [2:0] INCR   = 3'b001; // unbounded (length unknown)
  localparam logic [2:0] WRAP4  = 3'b010;
  localparam logic [2:0] INCR4  = 3'b011;
  localparam logic [2:0] WRAP8  = 3'b100;
  localparam logic [2:0] INCR8  = 3'b101;
  localparam logic [2:0] WRAP16 = 3'b110;
  localparam logic [2:0] INCR16 = 3'b111;

  // ===========================================================================
  // FSM States (address/data split across states) — NSL will be added later
  //  • Keep states fine-grained so OL can cleanly pulse enables and gate stalls.
  // ===========================================================================
  typedef enum logic [3:0] {
    IDLE_STATE,              // No active transaction. Waiting for a valid transfer start from the AHB master.
    NONSEQ_WAIT_STATE,       // Waiting to begin a new NONSEQ (addr accepted)

    // Write path
    WRITE_ADDR_WAIT_STATE,   // Wait for ctrl FIFO space before starting/continuing write burst 
    WRITE_ADDR_VALID_STATE,  // Accept a write address/control beat. Push {HWRITE,HTRANS,HBURST,HSIZE,HADDR} into Control FIFO.
    WRITE_DATA_VALID_STATE,  // Consume one write data beat (HWDATA). Push it into AHB Data FIFO.

    // Read path
    READ_ADDR_WAIT_STATE,    // A read transfer is pending, but the Control FIFO is full. Slave must wait before accepting the address.
    READ_ADDR_VALID_STATE,   // Accept a read address/control beat (push into Control FIFO).
    READ_DATA_WAIT_STATE,    // Read data is not yet available from APB domain (apb_data_empty=1).
    READ_DATA_VALID_STATE    // Read data is now valid. Drive HRDATA from apb_data_read and assert HREADYOUT=1 to complete data phase.
  } hstate_t;

  hstate_t pstate, nstate;

  // --------------------------
  // State flops for FSM
  // --------------------------
  always_ff @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) pstate <= IDLE_STATE;
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
      SINGLE:          burst_len = 1;
      INCR4,  WRAP4:   burst_len = 4;
      INCR8,  WRAP8:   burst_len = 8;
      INCR16, WRAP16:  burst_len = 16;
      default:         burst_len = 0; // INCR or invalid
    endcase
  endfunction

  // ===========================================================================
  // AHB accept qualifiers (addr phase)
  //  • addr_valid  : NSEQ/SEQ is on the bus this cycle (independent of HREADYIN)
  //  • addr_accept : a valid beat is *accepted* (requires HREADYIN==1)
  //  • nseq_accept/seq_accept : specific accepted type (start/continue)
  // ===========================================================================
  logic addr_valid, addr_accept, nseq_accept, seq_accept;
  assign addr_valid  = HSEL && HTRANS[1];                 // NSEQ/SEQ present (not IDLE/BUSY)
  assign addr_accept = addr_valid && HREADYIN;            // accepted this addr/ctrl cycle
  assign nseq_accept = addr_accept && (HTRANS == NONSEQ); // start of burst
  assign seq_accept  = addr_accept && (HTRANS == SEQ);    // continuation

  // ============================================================================
  // Data-phase ownership & address-phase capture
  //  • selected_d : remembers if this slave owns the *current* data phase
  //  • a_d        : attributes of the accepted address-phase transfer
  // ============================================================================
  logic selected_d;
  typedef struct packed {
    logic                   write;
    logic [2:0]             size;
    logic [2:0]             burst;
    logic [1:0]             trans;
    logic [haddrWidth-1:0]  addr;
  } aphase_t;
  aphase_t a_d;

  // -----------------------------------------------------------------------------
  // Data-phase ownership & address-phase capture
  //  • selected_d : remembers if this slave owns the *current* data phase
  //  • a_d        : attributes of the accepted address-phase transfer
  // -----------------------------------------------------------------------------
  always_ff @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
      selected_d <= 1'b0;
      a_d        <= '0;
    end else begin
      // 1. Latch new owner when an address phase completes (accepted)
      if (addr_accept)
        selected_d <= 1'b1;

      // 2. Drop ownership only when the data beat completes
      if (selected_d && HREADYIN &&
          (pstate == WRITE_DATA_VALID_STATE || pstate == READ_DATA_VALID_STATE))
        selected_d <= 1'b0;

      // 3. Capture address/control info only on accepted address
      if (addr_accept) begin
        a_d.write <= HWRITE;
        a_d.size  <= HSIZE;
        a_d.burst <= HBURST;
        a_d.trans <= HTRANS;
        a_d.addr  <= HADDR;
      end
    end
  end


// // Replace your selected_d always_ff with this:
// always_ff @(posedge HCLK or negedge HRESETn) begin
//   if (!HRESETn) begin
//     selected_d <= 1'b0;
//     a_d        <= '0;
//   end else begin
//     // 1) Latch a new owner when an address is accepted
//     if (addr_accept) selected_d <= 1'b1;

//     // 2) Drop ownership only when the DATA phase actually completes
//     if (selected_d && HREADYIN &&
//         (pstate == WRITE_DATA_VALID_STATE || pstate == READ_DATA_VALID_STATE))
//       selected_d <= 1'b0;

//     // aphase capture (unchanged)
//     if (addr_accept) begin
//       a_d.write <= HWRITE;
//       a_d.size  <= HSIZE;
//       a_d.burst <= HBURST;
//       a_d.trans <= HTRANS;
//       a_d.addr  <= HADDR;
//     end
//   end
// end




  // ===========================================================================
  // Latched reservation on NONSEQ (burst start)
  //  • For fixed-length bursts, we capture the required beats at the true start.
  //  • For INCR (returned 0), we do not “reserve” upfront; we’ll rely on
  //    per-beat checks and allow stalls in our own data phase if needed.
  // ===========================================================================
  logic [4:0] burst_need_q;  // 0,1,4,8,16 (0 means INCR/unbounded)
  logic       is_fixed_burst_q;

  always_ff @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
      burst_need_q      <= '0;
      is_fixed_burst_q  <= 1'b0;
    end else if (nseq_accept) begin
      burst_need_q      <= burst_len(HBURST);
      is_fixed_burst_q  <= (HBURST == SINGLE) || (HBURST == INCR4)  || (HBURST == WRAP4)  ||
                           (HBURST == INCR8)  || (HBURST == WRAP8)  ||
                           (HBURST == INCR16) || (HBURST == WRAP16);
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
  logic need_full_this_beat;

  assign have_ctrl_space_now       = !ctrl_full;
  assign have_ctrl_space_for_burst = (ctrl_sp >= $unsigned(burst_need_q));
  assign need_full_this_beat       = nseq_accept && is_fixed_burst_q;
  assign have_ctrl_space_needed    = need_full_this_beat ? have_ctrl_space_for_burst
                                                         : have_ctrl_space_now;

  // ===========================================================================
  // Default responses HRESP :
  // HRESP: Kept at Okay by Default
  // ===========================================================================
  assign HRESP = 1'b0;


  // ===========================================================================
  // HREADYOUT:
  //  • Only the *data-phase owner* (selected_d==1) may drive HREADYOUT low.
  //  • If selected_d==0, this slave must drive HREADYOUT==1 (cannot stall).
  // ===========================================================================
  logic stall_addr_ctrl; // Stall during address states when ctrl FIFO is full.
  logic stall_write_dp;  // write data path backpressure, write-data FIFO full 
  logic stall_read_dp;   // read data availability, APB hasn’t produced data yet
  logic stall_wait;      // Simple wait-state states

  assign stall_addr_ctrl = ((pstate==WRITE_ADDR_VALID_STATE) || 
                            (pstate==READ_ADDR_VALID_STATE)) && ctrl_full;

  assign stall_wait = ((pstate == WRITE_ADDR_WAIT_STATE) ||
                       (pstate == READ_ADDR_WAIT_STATE)  ||
                       (pstate == READ_DATA_WAIT_STATE));

  assign stall_write_dp = (pstate == WRITE_DATA_VALID_STATE) &&
                          selected_d && ahb_data_full;

  assign stall_read_dp  = ((pstate == READ_DATA_WAIT_STATE) ||
                          (pstate == READ_DATA_VALID_STATE)) &&
                          selected_d && apb_data_empty;

  // Legal gating:
  //  • During reset      → ready
  //  • Not data owner    → ready
  //  • Data owner        → ready unless a stall reason is active
  assign HREADYOUT = !HRESETn ? 1'b1
                    : (!selected_d) ? 1'b1
                    : !(stall_addr_ctrl || stall_wait || stall_write_dp || stall_read_dp);
  
 
  // ==========================================================
  // Next State Logic
  // ==========================================================

  always_comb begin
    nstate = pstate;

    unique case (pstate)
      // =======================================================================
      // ================================ IDLE =================================
      // =======================================================================
      // IDLE_STATE: begin
      //   // No active transaction. Waiting for a valid transfer start from the AHB master.
      //   nstate = IDLE_STATE;
      //   if (nseq_accept) begin
      //     if (HWRITE) begin
      //       nstate = have_ctrl_space_needed ? WRITE_ADDR_VALID_STATE : WRITE_ADDR_WAIT_STATE;
      //     end 
      //     else begin
      //       nstate = have_ctrl_space_needed ? READ_ADDR_VALID_STATE : READ_ADDR_WAIT_STATE;
      //     end
      //   end
      //   else if (seq_accept) nstate = IDLE_STATE; // or an ERROR state later
      // end
      IDLE_STATE: begin
        nstate = IDLE_STATE;

        if (nseq_accept) begin
          if (HWRITE) begin
            // WRITE: next cycle is data phase
            nstate = have_ctrl_space_needed ? WRITE_DATA_VALID_STATE
                                            : WRITE_ADDR_WAIT_STATE;
          end else begin
            // READ: next cycle is data phase (wait if APB empty)
            if (have_ctrl_space_needed) begin
              nstate = apb_data_empty ? READ_DATA_WAIT_STATE
                                      : READ_DATA_VALID_STATE;
            end else begin
              nstate = READ_ADDR_WAIT_STATE;
            end
          end
        end
        else if (seq_accept) begin
          // Illegal: SEQ seen in IDLE (no prior NONSEQ)
          // TODO: raise error flag or branch to ERROR state
          nstate = IDLE_STATE;
        end
      end
      // ========================================================================
      // ================================ WRITE =================================
      // ========================================================================
      WRITE_ADDR_WAIT_STATE: begin
        // Wait for ctrl FIFO space before starting/continuing write burst
        nstate = WRITE_ADDR_WAIT_STATE;
        if (have_ctrl_space_needed && addr_accept && HWRITE) nstate = WRITE_ADDR_VALID_STATE;
      end
      WRITE_ADDR_VALID_STATE: begin
        // Accept a write address/control beat. Push {HWRITE,HTRANS,HBURST,HSIZE,HADDR} into Control FIFO.
        nstate = WRITE_DATA_VALID_STATE;
      end
      WRITE_DATA_VALID_STATE: begin
        // Consume one write data beat (HWDATA). Push it into AHB Data FIFO.
        nstate = WRITE_DATA_VALID_STATE;
        if (HREADYIN)  begin
            if (addr_accept) begin
              if (HWRITE) nstate = have_ctrl_space_needed ? WRITE_ADDR_VALID_STATE : WRITE_ADDR_WAIT_STATE;
              else nstate = have_ctrl_space_needed ? READ_ADDR_VALID_STATE : READ_ADDR_WAIT_STATE;
            end
            else nstate = IDLE_STATE;
          end
      end
      // ========================================================================
      // ================================= READ =================================
      // ========================================================================
      READ_ADDR_WAIT_STATE: begin
        // Wait for ctrl FIFO space before starting/continuing a read burst.
        nstate = READ_ADDR_WAIT_STATE;
        if (have_ctrl_space_needed && addr_accept && !HWRITE) nstate = READ_ADDR_VALID_STATE;
      end
      READ_ADDR_VALID_STATE: begin
        // Accept a read address/control beat (push into Control FIFO).
        nstate = READ_DATA_WAIT_STATE;
      end
      READ_DATA_WAIT_STATE: begin
        // Read data is not yet available from APB domain (apb_data_empty=1).
        nstate = READ_DATA_WAIT_STATE;
        if (!apb_data_empty) nstate = READ_DATA_VALID_STATE;
      end
      READ_DATA_VALID_STATE: begin
        // Read data is now valid. Drive HRDATA from apb_data_read and assert HREADYOUT=1 to complete data phase.
        nstate = READ_DATA_VALID_STATE;
        if (HREADYIN) begin
          if (addr_accept) begin
            if (HWRITE)
              nstate = have_ctrl_space_needed ? WRITE_ADDR_VALID_STATE
                                              : WRITE_ADDR_WAIT_STATE;
            else
              nstate = have_ctrl_space_needed ? READ_ADDR_VALID_STATE
                                              : READ_ADDR_WAIT_STATE;
          end else begin
            nstate = IDLE_STATE;
          end
        end
      end
      // ========================================================================
      // ================================ DEFAULT ===============================
      // ========================================================================
      default: nstate = IDLE_STATE;
    endcase
  end


// Track remaining beats of the burst (using a counter):

// logic [4:0] write_beats_left;

// always_ff @(posedge HCLK or negedge HRESETn) begin
//     if (!HRESETn) write_beats_left <= '0;
//     else if (nseq_accept && HWRITE) write_beats_left <= burst_len(HBURST); // latch burst length
//     else if (pstate == WRITE_DATA_VALID_STATE && HREADYIN) write_beats_left <= write_beats_left - 1;
// end

// Then the next-state logic becomes simpler:

// WRITE_DATA_VALID_STATE: begin
//     if (write_beats_left > 1) nstate = WRITE_DATA_VALID_STATE;
//     else nstate = IDLE_STATE; // or next addr phase if another transfer queued
// end

// No need to check addr_accept in the middle of a write burst.
// Only return to IDLE when the entire burst is done.


  // ============================================================================
  // Output Logic (OL) — FWFT read FIFO
  //  • ctrl_wen matches NSL’s reservation rule
  //  • ahb_data_wen/apb_data_ren only when owner completes a data beat
  //  • HRDATA is driven directly from apb_data_read during READ_DATA_VALID_STATE
  //    (FWFT ensures it’s already valid when apb_data_empty==0)
  // ============================================================================
  logic ctrl_push_ok;
  assign ctrl_push_ok = need_full_this_beat ? have_ctrl_space_for_burst
                                          : have_ctrl_space_now;
  assign ctrl_pipe = {HWRITE, HTRANS, HBURST, HSIZE, HADDR};
  assign ahb_data_pipe = HWDATA;
  assign ctrl_wen = addr_accept && ctrl_push_ok;
always_comb begin : OUTPUT_LOGIC
  // defaults
  ahb_data_wen  = 1'b0;
  apb_data_ren  = 1'b0;
  HRDATA        = '0;

  unique case (pstate)
    // ------------------------------------------------------------------
    WRITE_ADDR_VALID_STATE: begin
      // Accept address -> push control only if reservation allows (and not full)
     // ctrl_wen = addr_accept && ctrl_push_ok && !ctrl_full;
    end

    // ------------------------------------------------------------------
    WRITE_DATA_VALID_STATE: begin
      // Complete write-data beat -> push write-data if owner and FIFO not full
      ahb_data_wen = selected_d && HREADYIN && !ahb_data_full;
    end

    // ------------------------------------------------------------------
    READ_ADDR_VALID_STATE: begin
      // Accept read address -> push control when allowed
     // ctrl_wen = addr_accept && ctrl_push_ok && !ctrl_full;
    end

    // ------------------------------------------------------------------
    READ_DATA_WAIT_STATE: begin
      // Waiting for APB data; no pops. HRDATA remains '0 (no valid data yet).
    end

    // ------------------------------------------------------------------
    READ_DATA_VALID_STATE: begin
      // APB data available → drive HRDATA and pop when data-phase completes
      // (FWFT: apb_data_read is already valid when apb_data_empty==0)
      HRDATA       = apb_data_read;
      apb_data_ren = selected_d && HREADYIN && !apb_data_empty;
    end

    default: begin
      // keep defaults
    end
  endcase
end



// REMOVE these (XSIM doesn't support the 2nd line):
// default clocking cb @(posedge HCLK); endclocking
// default disable iff (!HRESETn);

// Keep a plain per-property style:
// AHB basic protocol assertions with pass displays
property p_owner_only_stall;
  @(posedge HCLK) disable iff (!HRESETn)
    (HREADYOUT==0) |-> selected_d;
endproperty
assert property (p_owner_only_stall)
  else $error("ASSERT FAIL: owner_only_stall violated");
cover property (p_owner_only_stall)
  $display("%0t PASS: owner_only_stall OK",$time);

property p_accept_only_valid;
  @(posedge HCLK) disable iff (!HRESETn)
    addr_accept |-> HTRANS[1] && HSEL;
endproperty
assert property (p_accept_only_valid)
  else $error("ASSERT FAIL: accept_only_valid violated");
cover property (p_accept_only_valid)
  $display("%0t PASS: accept_only_valid OK",$time);

// repeat for the rest...




endmodule



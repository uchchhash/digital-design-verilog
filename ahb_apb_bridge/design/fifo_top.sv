`timescale 1ns/1ps
module fifo_top #(
  parameter int DATA_WIDTH = 32,
  parameter int FIFO_DEPTH = 16                // must be power of 2
)(
  input  logic                        reset_n,
  input  logic                        wclk,
  input  logic                        rclk,
  input  logic                        wen,
  input  logic                        ren,
  input  logic [DATA_WIDTH-1:0]       wdata,
  output logic [DATA_WIDTH-1:0]       rdata,
  output logic                        fifo_full,
  output logic                        fifo_empty,
  output logic [$clog2(FIFO_DEPTH):0] fifo_space   // free space as seen in write domain
);


// ============================================================================
// Ptr types (ADDR = log2(DEPTH)); pointers are ADDR+1 wide (extra wrap bit)
// ============================================================================
localparam int ADDR = $clog2(FIFO_DEPTH);
localparam int PTRW = ADDR + 1;  // extra wrap bit

// ============================================================================
// Binary <-> Gray
//   • bin2gray: standard (b>>1) ^ b
//   • gray2bin: b = prefix_xor(g);
// ============================================================================

function automatic logic [PTRW-1:0] bin2gray (input logic [PTRW-1:0] b);
  return (b >> 1) ^ b;
endfunction

function automatic logic [PTRW-1:0] gray2bin (input logic [PTRW-1:0] g);
  logic [PTRW-1:0] b;
  // MSB copies straight through
  b[PTRW-1] = g[PTRW-1];
  // Each lower bit is XOR of Gray bit with the higher Binary bit
  for (int k = PTRW-2; k >= 0; k--) begin
    b[k] = b[k+1] ^ g[k];
  end
  return b;
endfunction



// ============================================================================
// Declare storage and pointers
// ============================================================================

(* ram_style = "block" *) logic [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];

// Binary write pointer (current value) — drives memory write address
// Next binary write pointer — wptr_bin + 1 when a valid write occurs
// Gray-coded write pointer (current value) — sent to read domain via synchronizer
// Next Gray-coded write pointer — used for look-ahead full detection
// Binary read pointer (current value) — drives memory read address
// Next binary read pointer — rptr_bin + 1 when a valid read occurs
// Gray-coded read pointer (current value) — sent to write domain via synchronizer
// Next Gray-coded read pointer — optionally used for look-ahead empty detection
logic [PTRW-1:0] wptr_bin, wptr_bin_n, wptr_gray, wptr_gray_n;
logic [PTRW-1:0] rptr_bin, rptr_bin_n, rptr_gray, rptr_gray_n;

// Crossed (synced) Gray pointers
// Read pointer (Gray-coded) synchronized into the write clock domain
// Write pointer (Gray-coded) synchronized into the read clock domain
logic [PTRW-1:0] rptr_gray_wsync, wptr_gray_rsync;


// =============================================================================
// Write-side logic (wclk domain)
// =============================================================================
// wpush        : Indicates a valid write to memory
//              : Asserted when FIFO is not full and write enable is high
// wptr_bin     : Current write pointer in binary form
// wptr_bin_n   : Next write pointer in binary form (increments only if wpush=1)
// wptr_gray    : Current write pointer in Gray code
// wptr_gray_n  : Next write pointer in Gray code (computed from wptr_bin_n)
// The 'next' values act as the pointer counter logic.
// On every posedge of wclk:
//   • If reset_n == 0 → clear pointers
//   • Else:
//       - If wpush == 1 → write wdata to memory at current address
//       - Update current pointers with their next values
//         (If wpush == 0, next == current → no actual change)

wire wpush; // Assigned After the Full Now is calculated later
assign wptr_bin_n  = wptr_bin + (wpush ? 1 : 0);
assign wptr_gray_n = bin2gray(wptr_bin_n);

always_ff @(posedge wclk or negedge reset_n) begin
    if (!reset_n) begin
        wptr_bin  <= '0; 
        wptr_gray <= '0;
    end 
    else begin
        if (wpush) begin
            mem[wptr_bin[ADDR-1:0]] <= wdata;
        end
        wptr_bin  <= wptr_bin_n;
        wptr_gray <= wptr_gray_n;
    end
end


// =============================================================================
// Read-side logic (rclk domain)
// =============================================================================
// rpop        : Indicates a valid read from memory
//             : Asserted when FIFO is not empty and read enable is high
// rptr_bin    : Current read pointer in binary form
// rptr_bin_n  : Next read pointer in binary form (increments only if rpop=1)
// rptr_gray   : Current read pointer in Gray code
// rptr_gray_n : Next read pointer in Gray code (computed from rptr_bin_n)
// The 'next' values act as the pointer counter logic.
// On every posedge of rclk:
//   • If reset_n == 0 → clear pointers and rdata
//   • Else:
//       - If rpop == 1 → read memory at current address into rdata
//       - Update current pointers with their next values
//         (If rpop == 0, next == current → no actual change)

wire rpop; // Assigned After the Empty Now is calculated
assign rptr_bin_n  = rptr_bin + (rpop ? 1 : 0);
assign rptr_gray_n = bin2gray(rptr_bin_n);

always_ff @(posedge rclk or negedge reset_n) begin
    if (!reset_n) begin
        rptr_bin  <= '0;
        rptr_gray <= '0;
        rdata     <= '0;
    end 
    else begin
        if (rpop) begin
            rdata <= mem[rptr_bin[ADDR-1:0]]; // registered read
        end
        rptr_bin  <= rptr_bin_n;
        rptr_gray <= rptr_gray_n;
    end
end


// =============================================================================
// Cross-Domain Synchronization of Gray Pointers
// =============================================================================
// Purpose : Safely transfer read and write Gray pointers across clock domains
// Technique : Two-stage flip-flop synchronizers (double-flop)
// Each pointer from one domain is passed through two flip-flops
// in the other domain to mitigate metastability and ensure clean sampling.
//
// rgray_w_ff1 / rgray_w_ff2 : synchronize rptr_gray (from rclk domain) into wclk domain
// wgray_r_ff1 / wgray_r_ff2 : synchronize wptr_gray (from wclk domain) into rclk domain
//
// After synchronization :
//   rptr_gray_wsync : read pointer Gray value synchronized to wclk domain
//   wptr_gray_rsync : write pointer Gray value synchronized to rclk domain
//
// These synchronized versions are used for FULL and EMPTY flag generation
// in their respective clock domains.
//
// Note :
//  • The two-stage pipeline minimizes metastability risk.
//  • Attributes (* ASYNC_REG="TRUE" *) prevent retiming or optimization.
//  • Both domains use active-low asynchronous reset.
//
// =============================================================================

(* ASYNC_REG="TRUE" *) logic [PTRW-1:0] rgray_w_ff1, rgray_w_ff2;
(* ASYNC_REG="TRUE" *) logic [PTRW-1:0] wgray_r_ff1, wgray_r_ff2;

// -----------------------------------------------------------------------------
// Synchronize read pointer (rptr_gray) into write clock domain
// -----------------------------------------------------------------------------
always_ff @(posedge wclk or negedge reset_n) begin
  if (!reset_n) begin 
    rgray_w_ff1 <= '0; 
    rgray_w_ff2 <= '0;
  end else begin       
    rgray_w_ff1 <= rptr_gray;      // sample asynchronous read pointer
    rgray_w_ff2 <= rgray_w_ff1;    // 2nd stage for metastability filtering
  end
end
assign rptr_gray_wsync = rgray_w_ff2; // stable in wclk domain

// -----------------------------------------------------------------------------
// Synchronize write pointer (wptr_gray) into read clock domain
// -----------------------------------------------------------------------------
always_ff @(posedge rclk or negedge reset_n) begin
  if (!reset_n) begin 
    wgray_r_ff1 <= '0; 
    wgray_r_ff2 <= '0;
  end else begin       
    wgray_r_ff1 <= wptr_gray;      // sample asynchronous write pointer
    wgray_r_ff2 <= wgray_r_ff1;    // 2nd stage for metastability filtering
  end
end
assign wptr_gray_rsync = wgray_r_ff2; // stable in rclk domain


// =============================================================================
// FIFO FULL Logic  (write clock domain, Gray-pointer method)
// =============================================================================
// Goal:
//   Decide if we may PUSH this cycle (no overflow) and produce a stable FULL
//   status. We separate:
//     • full_now        : “already full?” — use this to gate wpush
//     • full_lookahead  : “if we push now, will it become full next?”
//     • fifo_full       : registered/full-status output for visibility only
//
// Pointer facts:
//   • Pointers are ADDR+1 wide (PTRW = ADDR+1). The MSB is the wrap bit.
//   • FULL occurs when write Gray == read Gray with the top two bits inverted.
//     (For PTRW==2 / DEPTH=2, this reduces to inverting both bits.)
//
// CDC inputs (stable in wclk):
//   • rptr_gray_wsync : read-pointer Gray synchronized into wclk (2-FF sync)
//
// No combinational loop policy:
//   • Never use wptr_gray_n (which might depend on wpush) in FULL compares.
//   • Use current pointers (for full_now) and unconditional +1 (for lookahead).
// =============================================================================

// ---------- Invert synced read Gray’s top bits for FULL comparison ----------
wire [PTRW-1:0] rgray_wsync_inv;
generate
  if (PTRW == 2) begin : GEN_FULL_INV_2BIT
    // DEPTH=2 → one wrap bit + one address bit → invert both
    assign rgray_wsync_inv = ~rptr_gray_wsync;
  end else begin : GEN_FULL_INV_WIDE
    // DEPTH>=4 → invert the top two bits, pass the rest through
    assign rgray_wsync_inv = {~rptr_gray_wsync[PTRW-1:PTRW-2],
                               rptr_gray_wsync[PTRW-3:0]};
  end
endgenerate

// ---------- Current FULL (safe to gate push this cycle) ----------
wire full_now;
assign full_now = (wptr_gray == rgray_wsync_inv);

// ---------- Look-ahead FULL (what the flag would be *after* a push) ----------
wire [PTRW-1:0] wptr_bin_inc;
wire [PTRW-1:0] wptr_gray_inc;
wire full_lookahead;
assign wptr_bin_inc = wptr_bin + 1'b1;        // unconditional +1
assign wptr_gray_inc = bin2gray(wptr_bin_inc); // its Gray form
assign full_lookahead = (wptr_gray_inc == rgray_wsync_inv);

// ---------- Usage guidance ----------
// • Gate the actual write enable elsewhere as:
//       wpush = wen && !full_now;
//   (Do NOT gate with full_lookahead — you’d block the last free slot.)
//
// • Registered status output (optional but recommended for stability):
always_ff @(posedge wclk or negedge reset_n) begin
  if (!reset_n)      fifo_full <= 1'b0;
  // If we push, the flag for next cycle should reflect look-ahead;
  // otherwise hold the current view.
  else if (wen && !full_now) fifo_full <= full_lookahead;
  else                       fifo_full <= full_now;
end
assign wpush = wen && !full_now; // allow write only if not currently full



// =============================================================================
// FIFO EMPTY Logic  (read clock domain, Gray-pointer method)
// =============================================================================
// Goal:
//   Decide if we may POP this cycle (no underflow) and produce a stable EMPTY
//   status. We separate:
//     • empty_now        : “already empty?” — use this to gate rpop
//     • empty_lookahead  : “if we pop now, will it become empty next?”
//     • fifo_empty       : registered/visibility-only empty status
//
// Pointer facts:
//   • EMPTY occurs when the current read Gray equals the synced write Gray.
//   • For look-ahead we use the *unconditional* +1 form of the read pointer.
//     (Avoid rptr_gray_n if that depends on rpop to prevent comb loops.)
//
// CDC inputs (stable in rclk):
//   • wptr_gray_rsync : write-pointer Gray synchronized into rclk (2-FF sync)
//
// No combinational loop policy:
//   • Do NOT use rptr_gray_n (which may depend on rpop) in the empty compare.
//   • Use current pointers (for empty_now) and unconditional +1 (for lookahead).
// =============================================================================

// ---------- Current EMPTY (safe to gate pop this cycle) ----------
wire empty_now;
assign empty_now = (rptr_gray == wptr_gray_rsync);

// ---------- Look-ahead EMPTY (what the flag would be *after* a pop) ----------
wire [PTRW-1:0] rptr_bin_inc;
wire [PTRW-1:0] rptr_gray_inc;
wire empty_lookahead;
assign rptr_bin_inc = rptr_bin + 1'b1;        // unconditional +1
assign rptr_gray_inc = bin2gray(rptr_bin_inc); // its Gray form
assign empty_lookahead = (rptr_gray_inc == wptr_gray_rsync);

// ---------- Usage guidance ----------
// • Gate the actual read enable elsewhere as:
//       rpop = ren && !empty_now;
//   (Do NOT gate with empty_lookahead — that would block popping the last word.)
//
// • Registered status output (optional but recommended for stability):
always_ff @(posedge rclk or negedge reset_n) begin
  if (!reset_n)            fifo_empty <= 1'b1;
  // If we pop, next-cycle flag reflects look-ahead; otherwise hold current view.
  else if (ren && !empty_now) fifo_empty <= empty_lookahead;
  else                        fifo_empty <= empty_now;
end
assign rpop = ren && !empty_now; // allow read only if not currently empty

// Notes for FWFT read datapath (if you use FWFT):
//   • Drive rdata from mem[rptr_bin[ADDR-1:0]] whenever !empty_now.
//   • Advance rptr only when rpop (ren && !empty_now) is true.


// =============================================================================
// Compute fifo_space in write domain
//  • Use synced read pointer (Gray→Bin) in wclk domain
//  • diff is the PTRW-bit modular distance (ADDR+1 bits)
//  • used = {full_now, diff[ADDR-1:0]} ∈ [0..DEPTH]
//  • fifo_space = DEPTH - used
// =============================================================================

// 1) Gray → Binary (synced read ptr in wclk)
logic [PTRW-1:0] rptr_bin_wsync;
assign rptr_bin_wsync = gray2bin(rptr_gray_wsync);

// 2) PTRW-bit modular difference (unsigned arithmetic)
wire [PTRW-1:0] diff = $unsigned(wptr_bin) - $unsigned(rptr_bin_wsync);

// 3) Used entries in 0..DEPTH  (ADDR+1 bits)
//    NOTE: reuse full_now from FULL logic above.
wire [ADDR:0] used = {full_now, diff[ADDR-1:0]};

// 4) Free space = DEPTH - used (width-safe sizing)
localparam logic [ADDR:0] DEPTH_V = FIFO_DEPTH;  // auto zero-extends
assign fifo_space = DEPTH_V - used;              // 0..DEPTH



endmodule



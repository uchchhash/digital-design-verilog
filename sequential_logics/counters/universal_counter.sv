/*------------------------------------------------------------------------------
                            ################################
                            ####    Universal Counter   #### 
                            ################################

Purpose
  Small, first-pass counter for a single clock domain.
  Up/Down, enable, sync load, async reset. Step = 1. Wrap mode only.
  No division/modulo operators; optional power-of-two modulus via mask.

Parameters
  WIDTH        : integer > 0. Counter bit width.
  USE_P2_MOD   : 0 = free-run over 2**WIDTH, 1 = apply power-of-two modulus.
  MOD_BITS     : valid only when USE_P2_MOD=1. Range: 1..WIDTH.
                 Effective range when USE_P2_MOD=1: 0 .. (2**MOD_BITS - 1).
                 Implementation uses a mask to clamp/flag max: ((1<<MOD_BITS)-1).

Ports
  clk          : input. Rising-edge clock.
  rst_n        : input. Async active-low reset (clears state).
  en           : input. Count enable (1=advance, 0=hold).
  up_n_down    : input. 1=up, 0=down.
  load         : input. One-cycle synchronous load strobe (wins over count).
  load_val     : input [WIDTH-1:0]. Loaded value when load=1.
  count        : output [WIDTH-1:0]. Current count.
  tc           : output. Terminal-count prediction: high when the *nextenabled*
                 step would wrap (based on direction and current value).

Reset
  - Asynchronous: when rst_n=0, count <= '0, tc <= 0.

Priority (same cycle)
  1) !rst_n (async) → clear to 0
  2) load=1         → count <= load_val_reduced
  3) en=1           → count <= next_up_or_down
  4) else           → hold

Load semantics
  - load has priority over counting.
  - load_val_reduced:
      if USE_P2_MOD==0: use load_val as-is.
      if USE_P2_MOD==1: mask load_val with MOD_MASK = (1<<MOD_BITS)-1.

Counting (step = 1, wrap only)
  - If USE_P2_MOD==0 (free-run over WIDTH):
      up:   count_next = count + 1 (natural WIDTH wrap)
      down: count_next = count - 1 (natural WIDTH wrap)
  - If USE_P2_MOD==1 (power-of-two modulus):
      let MOD_MASK = (1<<MOD_BITS)-1
      up:   count_next = (count + 1) & MOD_MASK
      down: count_next = (count - 1) & MOD_MASK

Terminal count (tc) — combinational prediction of wrap on next enabled step
  - USE_P2_MOD==0:
      up:   tc = (count == {WIDTH{1'b1}})
      down: tc = (count == '0)
  - USE_P2_MOD==1:
      let MOD_MASK = (1<<MOD_BITS)-1
      up:   tc = (count == MOD_MASK)
      down: tc = (count == '0)

Corner cases
  - en=0 → hold state; tc computed from current count/direction.
  - Changing up_n_down any time is allowed; effect is from next enabled cycle.
  - load wins over en; tc reflects the post-load value on the next cycle.

Non-goals (kept out to stay lite)
  - No saturate mode.
  - No STEP > 1.
  - No arbitrary (non power-of-two) modulus.
  - No wrapped pulse output; only tc is provided.

Integration notes
  - Keep all controls (en, load, up_n_down) in the same clock domain or sync them.
  - For power-of-two modulus, choose MOD_BITS ≤ WIDTH.
------------------------------------------------------------------------------*/

/*

Ports
  clk          : input. Rising-edge clock.
  rst_n        : input. Async active-low reset (clears state).
  en           : input. Count enable (1=advance, 0=hold).
  up_n_down    : input. 1=up, 0=down.
  load         : input. One-cycle synchronous load strobe (wins over count).
  load_val     : input [WIDTH-1:0]. Loaded value when load=1.
  count        : output [WIDTH-1:0]. Current count.
  tc           : output. Terminal-count prediction: high when the *nextenabled*
                 step would wrap (based on direction and current value).

*/


module universal_counter #(
  parameter int WIDTH      = 3,
  parameter bit USE_P2_MOD = 0,   // 0 = free-run, 1 = mod 2**MOD_BITS
  parameter int MOD_BITS   = 3    // valid only if USE_P2_MOD=1; 1..WIDTH
)(
  input  logic                 clk,
  input  logic                 rst_n,        // async active-low
  input  logic                 en,
  input  logic                 up_n_down,    // 1=up, 0=down
  input  logic                 load,
  input  logic [WIDTH-1:0]     load_val,
  output logic [WIDTH-1:0]     count,
  output logic                 tc
);

  localparam int M = (MOD_BITS > WIDTH) ? WIDTH : MOD_BITS;

  // A WIDTH-wide constant '1' so shifts stay WIDTH-wide.
  localparam logic [WIDTH-1:0] ONE = {{(WIDTH-1){1'b0}}, 1'b1};

  // Power-of-two mask:
  //  - if USE_P2_MOD==0 → all ones (free-run)
  //  - if USE_P2_MOD==1 and M==WIDTH → all ones (full range)
  //  - else → ((1<<M) - 1) computed WIDTH-wide as ((ONE<<M) - ONE)
  localparam logic [WIDTH-1:0] P2_MASK =
      (USE_P2_MOD == 1'b0) ? {WIDTH{1'b1}} :
      (M == WIDTH)         ? {WIDTH{1'b1}} :
                             ((ONE << M) - ONE);

  // Next-state
  logic [WIDTH-1:0] next_count;

  always_comb begin
    if (load) begin
      next_count = USE_P2_MOD ? (load_val & P2_MASK) : load_val;
    end else if (!en) begin
      next_count = count;
    end else if (up_n_down) begin
      // UP
      if (USE_P2_MOD) next_count = (count + 1'b1) & P2_MASK;
      else            next_count =  count + 1'b1;   // natural WIDTH wrap
    end else begin
      // DOWN
      if (USE_P2_MOD) next_count = (count - 1'b1) & P2_MASK;
      else            next_count =  count - 1'b1;   // natural WIDTH wrap
    end
  end

  // Register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) count <= '0;
    else        count <= next_count;
  end

  // Terminal-count prediction
  wire [WIDTH-1:0] up_max = (USE_P2_MOD ? P2_MASK : {WIDTH{1'b1}});
  assign tc = up_n_down ? (count == up_max)
                        : (count == '0);

endmodule



# CDC Handshake Policy — AHB-Lite ⇄ APB Bridge

This note locks down the **request/ack** handshake you’ll use when `HCLK ≠ PCLK`. It’s small, deterministic, and fits a single-outstanding APB transfer.

---

## Scope

* Two clock domains: **AHB domain (HCLK)** and **APB domain (PCLK)**.
* One transaction in flight at a time.
* Control crosses domains via **level handshakes** plus **2-flop synchronizers**.
* Data/ctrl for the APB transfer are **latched in the AHB domain** before asserting the request; no multi-bit buses cross unsynchronized.

---

## Signals

**AHB → APB**

* `req_ahb` : AHB raises to request one APB transfer.
* `req_apb_sync` : synchronized copy of `req_ahb` in APB domain.

**APB → AHB**

* `ack_apb` : APB raises when the requested APB transfer is **completed**.
* `ack_ahb_sync` : synchronized copy of `ack_apb` in AHB domain.

**Local enables (not crossing)**

* `cap_req_en` (HCLK): latch `HADDR/HWRITE/HSIZE/HWDATA`.
* `run_apb_en` (PCLK): drive APB SETUP/ENABLE until `PREADY=1`.

Each crossing signal uses a standard 2-flop sync (`(* ASYNC_REG *)`).

---

## Handshake Flow (level protocol)

1. **AHB prepares request (HCLK)**

   * When `HSEL & HREADYin & HTRANS[1]`, latch AHB addr/ctrl/data into local flops.
   * Assert `req_ahb = 1`.
   * Hold request info stable until handshake finishes.

2. **APB executes (PCLK)**

   * Detect `req_apb_sync == 1` and APB side idle.
   * Start APB **SETUP** (`PSEL=1, PENABLE=0`), then **ENABLE**.
   * Wait while `PREADY=0`. Keep `PADDR/PWRITE/PWDATA/PSEL` stable.
   * On `PREADY=1`, sample `PRDATA/PSLVERR`, then assert `ack_apb = 1`.

3. **AHB completes (HCLK)**

   * Detect `ack_ahb_sync == 1`.
   * Finish AHB side (drive `HREADYout=1`, set `HRESP`).
   * Deassert `req_ahb = 0`.

4. **Return to idle (PCLK)**

   * When `req_apb_sync` drops to 0, deassert `ack_apb = 0`.
   * Both sides are idle; next request may start.

**Key rule:** `req_ahb` stays high from “request armed” until AHB sees `ack_ahb_sync`. `ack_apb` stays high from “APB done” until APB sees `req_apb_sync` low.

---

## Synchronizer Blocks (sketch)

```sv
module sync_2ff #(parameter WIDTH=1) (
  input  logic clk, rst_n,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q
);
  (* ASYNC_REG="TRUE" *) logic [WIDTH-1:0] s1, s2;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) {s1,s2} <= '0; else begin s1 <= d; s2 <= s1; end
  end
  assign q = s2;
endmodule
```

* Use one instance for `req_ahb` into PCLK, and one for `ack_apb` into HCLK.
* Do **not** sync multi-bit control bundles; sync only the **single-bit** handshake flags.

---

## Reset Policy

* On reset deassertion: `req_ahb=0`, `ack_apb=0`, both FSMs in IDLE.
* Synchronizer flops reset to 0. First request must transition 0→1 to be seen.

---

## FSM Contracts

**AHB-side FSM (HCLK)**

* IDLE: wait for valid AHB transfer, latch, raise `req_ahb`, set `HREADYout=0`.
* WAIT_ACK: hold `req_ahb=1` until `ack_ahb_sync=1`.
* COMPLETE: drop `req_ahb`, set `HREADYout=1`, return IDLE.

**APB-side FSM (PCLK)**

* IDLE: wait `req_apb_sync=1`, capture latched request.
* SETUP (1 cycle): drive `PSEL=1, PENABLE=0`.
* ENABLE: `PENABLE=1` until `PREADY=1`. Then raise `ack_apb=1`.
* HOLD_ACK: keep `ack_apb=1` until `req_apb_sync=0`, then drop and return IDLE.

---

## Data/Control Stability Rules

* **Crossing rule:** Only `req_ahb` and `ack_apb` cross domains.
* **AHB-latched**: `addr_hold, size_hold, write_hold, wdata_hold`.
* **APB uses** these holds; they must **not change** while `req_ahb=1`.
* No multi-bit bus crosses unsynchronized. No combinational path from PCLK back into HCLK.

---

## Timing Notes

* Handshake latency includes up to two cycles of sync delay each way.
* Throughput: one APB transfer per `req/ack` roundtrip (fits APB).
* If PCLK is slower, the AHB side stalls via `HREADYout=0` during WAIT_ACK.

---

## Variants (choose one)

* **Level handshake (used here):** simple, robust.
* **Toggle handshake:** use a toggling bit for req and ack; slightly more wiring, same idea.
* **Pulse handshake:** avoid for unrelated clocks; pulses can be missed.

Stick to **level** for clarity.

---

## Verification Checklist

**Assertions**

* AHB: `req_ahb |-> !HREADYout` until `ack_ahb_sync`.
* APB: `(PENABLE) |-> PSEL` and APB controls stable during ENABLE.
* Handshake: `ack_apb` can rise only when an APB transfer completed (`PENABLE & PREADY`).
* Liveness: `req_ahb` implies `ack_ahb_sync` eventually (within a bound in TB).

**TB Hooks**

* Randomize `PREADY` wait states.
* Inject `PSLVERR` on completion and check AHB `HRESP`.
* Vary clock ratios and phases.

---

## Common Pitfalls

* Dropping `req_ahb` before `ack_ahb_sync` is seen.
* Driving APB controls before `req_apb_sync` is high.
* Changing `PADDR/PWRITE/PSEL/PWDATA` while `PENABLE=1`.
* Sending multi-bit controls across the boundary.
* Using a one-cycle pulse instead of a level for req/ack.

---

## Integration Points

* Place handshake in a small **CDC wrapper** between `ahb_apb_bridge_ctrl` (HCLK) and the APB FSM (PCLK).
* Keep all request fields in HCLK flops. APB reads those through the CDC wrapper once `req_apb_sync` is high.

---

## Minimal To-Do (when you implement)

1. Add `req_ahb`/`ack_apb` and two synchronizers.
2. Gate AHB FSM stalls with `req_ahb & ~ack_ahb_sync`.
3. Start APB FSM when `req_apb_sync` rises.
4. Assert `ack_apb` exactly on APB completion.
5. Drop both signals in the order: AHB drops `req_ahb` → APB drops `ack_apb`.

This page is the single source of truth for your CDC policy.

// ============================================================
// CASE FAMILY DEMONSTRATION
// ============================================================
// This example shows how different SystemVerilog case types behave:
//   - case     → exact bit match only
//   - casez    → Z or ? in case items treated as don't care
//   - casex    → X and Z treated as don't care (dangerous in RTL)
//   - unique case   → exactly one match must occur (parallel decode)
//   - priority case → first match wins (priority chain)
//   - unique0 case  → allows no matches, warns only on overlap
//
// Run this in a simulator and observe:
//   - Output value y
//   - Any simulation warnings for unique/priority
//   - How X/Z bits are handled in each type
// ============================================================

`timescale 1ns/1ps


module case_demo;
  logic [2:0] sel;
  logic [7:0] y_case, y_casez, y_casex, y_unique, y_priority, y_unique0;

  // Stimulus
  initial begin
    sel = 3'b000; #5;
    sel = 3'b001; #5;
    sel = 3'b010; #5;
    sel = 3'b0x1; #5;   // X in input
    sel = 3'b0z1; #5;   // Z in input
    sel = 3'b111; #5;
    $finish;
  end

  // 1) Plain CASE – strict match, X/Z don't match, default prevents latch
  always_comb begin
    case (sel)
      3'b000: y_case = 8'hA0;
      3'b001: y_case = 8'hA1;
      3'b010: y_case = 8'hA2;
      default: y_case = 8'hFF;
    endcase
  end

  // 2) CASEZ – Z/? in items are wildcards (X still unknown)
  always_comb begin
    casez (sel)
      3'b0?0:  y_casez = 8'hB0; // matches 000,010
      3'b0?1:  y_casez = 8'hB1; // matches 001,011
      default: y_casez = 8'hBF;
    endcase
  end

  // 3) CASEX – X/Z are wildcards (can hide bugs; avoid in RTL)
  always_comb begin
    casex (sel)
      3'b0x0:  y_casex = 8'hC0; // matches 000,010,0x0,0z0,...
      3'b0x1:  y_casex = 8'hC1; // matches 001,011,0x1,0z1,...
      default: y_casex = 8'hCF;
    endcase
  end

  // 4) UNIQUE CASE – exactly one match expected
  // Intentionally overlapping items to trigger runtime warning when sel==000/010
  always_comb begin
    unique case (sel)
      3'b000: y_unique = 8'hD0;
      3'b0?0: y_unique = 8'hD1; // overlaps 000 & 010 with above
      default: y_unique = 8'hDF;
    endcase
  end

  // 5) PRIORITY CASE – ordered; first match wins
  always_comb begin
    priority case (sel)
      3'b0?0: y_priority = 8'hE0; // wins over below if both match
      3'b0?1: y_priority = 8'hE1;
      default: y_priority = 8'hEF;
    endcase
  end

  // 6) UNIQUE0 CASE – like unique but allows zero matches
  always_comb begin
    unique0 case (sel)
      3'b000: y_unique0 = 8'hF0;
      3'b001: y_unique0 = 8'hF1;
      3'b010: y_unique0 = 8'hF2;
      default: y_unique0 = 8'hFE; // keep default to avoid X in waves
    endcase
  end

  // Monitor
  initial begin
    $display("                time | sel | case  casez casex  unique  prior  uniq0");
    $monitor("%4t | %b |  %h     %h     %h     %h     %h     %h",
             $time, sel, y_case, y_casez, y_casex, y_unique, y_priority, y_unique0);
  end
endmodule

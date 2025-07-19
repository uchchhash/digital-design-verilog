# 🧮 Adder Comparison Project Specification

## 📋 Project Title
**Synthesis and Comparison of RCA, CLA, and CSA Adders in Vivado**

---

## 📝 Problem Statement

Design and implement a digital circuit that performs the **summation of three unsigned 16-bit binary numbers: A, B, and C**.  
The circuit must produce the final 17-bit sum (`S = A + B + C`) and be capable of synthesizing on an FPGA.

The problem will be solved using three alternative adder architectures to implement the core addition operation:
1. **Ripple-Carry Adder (RCA)**: The three operands are added sequentially using two stages of ripple-carry adders.
2. **Carry Lookahead Adder (CLA)**: The three operands are added sequentially using two stages of carry lookahead adders.
3. **Carry Save Adder (CSA)**: The three operands are added in parallel using one CSA stage followed by a final carry-propagation adder (e.g., RCA or CLA) to produce the final sum.

---

### Inputs
- `A` : 16-bit unsigned binary operand
- `B` : 16-bit unsigned binary operand
- `C` : 16-bit unsigned binary operand

### Output
- `S` : 17-bit unsigned binary sum (`A + B + C`)

---

### Constraints
- All operands are unsigned.
- The circuit must be fully synthesizable in Verilog.
- The design should target a Xilinx FPGA and be evaluated for area, delay, and power in Vivado.

---

### Goal
Compare and analyze how the choice of adder architecture (RCA, CLA, CSA) affects the hardware cost and performance of the circuit when performing the summation of three numbers.

---

## 🎯 Objective

Design, synthesize, and analyze three types of digital adders:
- **Ripple-Carry Adder (RCA)**
- **Carry Lookahead Adder (CLA)**
- **Carry Save Adder (CSA)**

Compare their performance in terms of:
- Area utilization (LUTs, FFs, carry logic)
- Timing (critical path delay / maximum frequency)
- Power consumption (optional)

---

## 📐 Scope of Work

✅ Implement synthesizable Verilog modules for:
- RCA-based 3-number adder
- CLA-based 3-number adder
- CSA-based 3-number adder

✅ Create a Vivado project to:
- Synthesize each design individually
- Generate reports for:
  - Area utilization
  - Timing summary
  - Power estimation (optional)

✅ Analyze and document:
- Trade-offs between area, speed, and complexity

Optional: Write testbenches for functional verification of each design in simulation.

---

## 🔌 Inputs and Outputs

### 📐 Ripple-Carry Adder (RCA-based solution)
| Signal      | Direction | Width  | Description                |
|-------------|-----------|--------|----------------------------|
| `A`         | Input     | 16     | First operand              |
| `B`         | Input     | 16     | Second operand             |
| `C`         | Input     | 16     | Third operand              |
| `S`         | Output    | 17     | Final sum (`A+B+C`)        |

### 📐 Carry Lookahead Adder (CLA-based solution)
| Signal      | Direction | Width  | Description                |
|-------------|-----------|--------|----------------------------|
| `A`         | Input     | 16     | First operand              |
| `B`         | Input     | 16     | Second operand             |
| `C`         | Input     | 16     | Third operand              |
| `S`         | Output    | 17     | Final sum (`A+B+C`)        |

### 📐 Carry Save Adder (CSA-based solution)
| Signal      | Direction | Width  | Description                |
|-------------|-----------|--------|----------------------------|
| `A`         | Input     | 16     | First operand              |
| `B`         | Input     | 16     | Second operand             |
| `C`         | Input     | 16     | Third operand              |
| `S`         | Output    | 17     | Final sum (`A+B+C`)        |

---


# 📘 Combinational Logic Design

---

## 📚 Table of Contents
- [🎯 Overview](#🎯-overview)
- [🔷 Combinational Logic Blocks](#🔷-combinational-logic-blocks)
  - [1️⃣ Logic Gates & Minimization](#1️⃣-logic-gates--minimization)
  - [2️⃣ Arithmetic Circuits](#2️⃣-arithmetic-circuits)
  - [3️⃣ Multiplexers & Demultiplexers](#3️⃣-multiplexers--demultiplexers)
  - [4️⃣ Encoders & Decoders](#4️⃣-encoders--decoders)
  - [5️⃣ Code Converters](#5️⃣-code-converters)
  - [6️⃣ Shifters & Rotators](#6️⃣-shifters--rotators)
  - [7️⃣ Comparators & Detectors](#7️⃣-comparators--detectors)
  - [8️⃣ Parity, Error Detection & Cryptographic Primitives](#8️⃣-parity-error-detection--cryptographic-primitives)
  - [9️⃣ ALU, Datapath](#9️⃣-alu-datapath)
  - [🔟 Advanced Functional Blocks](#🔟-advanced-functional-blocks)

---

## 🎯 Overview

✅ *Combinational logic circuits* have **no memory or state** — outputs depend only on current inputs.

---

## 🔷 Combinational Logic Blocks

### 1️⃣ [Logic Gates & Minimization](logic_gates/)
- **Theory:** Boolean Algebra, SOP/POS Forms, K-Maps, Duality, Positive/Negative Logic
- **RTL:**
  - Basic Logic Gates: AND, OR, NOT
  - Universal Logic Gates: NAND, NOR
  - Exclusive Logic Gates: XOR, XNOR
  - Bitwise Operations: AND, OR, NOT, NAND, NOR, XOR, XNOR
  - Bitwise Reduction Operators: AND-Reduce, OR-Reduce, XOR-Reduce
  - Logic Obfuscation Primitives: XOR/AND camouflaging, Dummy Logic Gates
  - Majority Gate
  - Minority Gate

---

### 2️⃣ [Arithmetic Circuits](arithmetic_circuits/)
- **Theory:** Binary, Octal, Hex Arithmetic; Complements
- **RTL:**
  - **Adders:**
    - Half-Adder
    - Full-Adder
    - Ripple-Carry Adder (N-bit)
    - Parallel Adder with Overflow Detection
    - Carry-Skip Adder
    - Carry-Select Adder
    - Carry-Save Adder
    - Prefix Adders
    - Approximate Adder
  - **Subtractors:**
    - Half-Subtractor
    - Full-Subtractor
    - Ripple-Borrow Subtractor (N-bit)
    - Adder-Subtractor Unit
    - Carry-Lookahead Subtractor
    - Approximate Subtractor
  - **Multipliers:**
    - 2×2 Multiplier
    - 4×4 Multiplier
    - Array Multiplier (Combinational)
    - Parameterizable N×N Multiplier
    - Booth Multiplier (Signed)
    - Wallace Tree Multiplier
    - Approximate Multiplier
    - Shift-and-Add Multiplier
    - Modified Booth (Radix-4) Multiplier
    - Dadda Multiplier
  - **Dividers:**
    - Restoring Divider
    - Non-Restoring Divider
    - SRT Divider (Radix-2/4)
    - Newton–Raphson or Goldschmidt

---

### 3️⃣ [Multiplexers & Demultiplexers](multiplexers_demultiplexers/)
- **Theory:** MUX/DEMUX Operation, Boolean Realization
- **RTL:**
  - **MUX:**
    - 2:1, 4:1, 8:1, 16:1 MUX
    - N:1 Hierarchical MUX
    - Tree-based MUX
    - High-Speed MUX Tree
    - Pipelined MUX
    - Bus Multiplexer
    - Crossbar Switch (N×M)
    - Bidirectional Bus Switch
  - **DEMUX:**
    - 1:2, 1:4, 1:8, 1:16 DEMUX
    - 1:N Parameterizable DEMUX
    - DEMUX as Decoder
    - One-Hot DEMUX

---

### 4️⃣ [Encoders & Decoders](encoders_decoders/)
- **Theory:** Encoder/Decoder Operation, Seven-Segment, Priority Encoding
- **RTL:**
  - **Encoders:**
    - 2:1, 4:2, 8:3, 16:4 Encoder
    - N:log₂(N) Parameterizable Encoder
    - Priority Encoder (4:2, 8:3, N:log₂N)
    - Pipelined Priority Encoder
    - One-Hot-to-Binary Converter
    - Thermometer-to-Binary Encoder
  - **Decoders:**
    - 1:2, 2:4, 3:8, 4:16 Decoder
    - N:2ᴺ Parameterizable Decoder
    - Binary-to-One-Hot Decoder
    - Binary-to-Seven-Segment Decoder
    - Decoder with Enable

---

### 5️⃣ [Code Converters](code_converters/)
- **Theory:** BCD, Excess-3, Gray Code
- **RTL:**
  - Binary-to-Gray Code Converter
  - Gray-to-Binary Code Converter
  - Binary-to-BCD Converter
  - BCD-to-Binary Converter
  - Excess-3-to-BCD Converter
  - BCD-to-Excess-3 Converter
  - Binary-to-Seven-Segment Code Converter
  - BCD-to-Seven-Segment Code Converter
  - Parity Generator & Parity Checker (Even/Odd)
  - 2’s Complement Converter

---

### 6️⃣ [Shifters & Rotators](shifters_rotators/)
- **Theory:** Logical vs Arithmetic Shifting
- **RTL:**
  - **Shifters:**
    - Logical Left Shifter
    - Logical Right Shifter
    - Arithmetic Right Shifter
    - Bidirectional Shifter
    - Barrel Shifter
    - Pipelined Shifter
    - Dynamic Shifter
  - **Rotators:**
    - Rotate Left (aka Circular Left Rotator)
    - Rotate Right (aka Circular Right Rotator)
    - Bidirectional Rotator
    - Barrel Rotator
  - Leading Zero Counter (LZC)
  - Trailing Zero Counter (TZC)

---

### 7️⃣ [Comparators & Detectors](comparators_detectors/)
- **Theory:** Magnitude Comparison, Priority Resolution, Window Detection, Overflow/Underflow Conditions, Voting Logic
- **RTL:**
  - **Comparators:**
    - 1-bit, 2-bit, 4-bit, N-bit Magnitude Comparators
    - Cascaded Comparator  
    - Threshold Comparator
    - Window Comparator
  - **Detectors:**
    - Equality/Inequality Detector
    - Priority Detector
    - Min/Max Detector
    - Overflow/Underflow Detector
    - Sign Detector
    - Parity Detector (Even/Odd)
    - Zero Detector
    - Window Detector
    - Edge Detector (Rising/Falling)
  - **Priority Logic / Arbiters:**
    - Fixed Priority Arbiter
    - Arbiter (Priority Resolver)
    - Priority Grant Logic
  - **Majority Voter:**
    - 3-input, 5-input, N-input Majority Voter
    - Minority Voter

---

### 8️⃣ [Parity, Error Detection & Cryptographic Primitives](parity_error_detection/)
- **Theory:** Parity (Even/Odd), Hamming Codes, Cyclic Redundancy Check (CRC), S-Boxes & P-Boxes, Feistel Networks, Lightweight Block Ciphers
- **RTL:**
  - **Parity Circuits:**
    - Even Parity Generator & Checker
    - Odd Parity Generator & Checker
  - **Error Detection/Correction:**
    - Hamming Code Generator & Checker
    - CRC (Cyclic Redundancy Check) Generator & Checker
  - **Cryptographic Primitives:**
    - AES Components:
      - Substitution Box (S-Box)
      - Permutation Box (P-Box)
      - AES Round Function
    - DES Feistel Function
    - Lightweight Cipher Components (e.g., PRESENT Cipher)
  - Bit Shuffler / Bit Permutation Logic

---

### 9️⃣ [ALU, Datapath](alu_datapath_elements/)
- **Theory:** ALU Operations, Datapath Elements
- **RTL:**
  - Arithmetic Operations: Add, Subtract, Increment, Decrement
  - Logic Operations: AND, OR, XOR, NOT, NAND, NOR
  - Shifts & Rotates: Logical, Arithmetic, Circular
  - Comparisons: Equality, Greater/Less, Min/Max
  - Status Flags: Carry, Zero, Overflow, Sign, Parity
  - Operation Select Logic
  - Parameterizable ALU
  - Pipelined ALU

---

### 🔟 [Advanced Functional Blocks](advanced_blocks/)
- **Theory:** Networking Logic, CAM Matchers, DSP Units, ML Inference Primitives
- **RTL:**
  - **Networking / Matching Logic:**
    - Bit-Mask Generator
    - Ternary CAM (TCAM) Match Logic
    - Packet Header Field Extractor
    - Data Duplication Shuffler
  - **DSP / ML Acceleration:**
    - Multiply-Accumulate (MAC) Unit
    - Bit-Serial MAC Unit
    - Activation Function Approximators:
      - ReLU
      - Sigmoid (Piecewise Linear or LUT-based)
      - Tanh (Piecewise Linear or LUT-based)
    - Quantizer / Dequantizer
    - Max Pooling Unit
    - Normalization (Approximate)

---

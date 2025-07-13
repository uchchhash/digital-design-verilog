# 📘 Combinational Logic Design

---

## 📚 Table of Contents
- [🎯 Overview](#🎯-overview)
- [🔷 General Combinational Logic Blocks](#🔷-general-combinational-logic-blocks)
  - [1️⃣ Logic Gates](#1️⃣-logic-gates)
  - [2️⃣ Arithmetic Circuits](#2️⃣-arithmetic-circuits)
  - [3️⃣ Multiplexers & Demultiplexers](#3️⃣-multiplexers--demultiplexers)
  - [4️⃣ Encoders & Decoders](#4️⃣-encoders--decoders)
  - [5️⃣ Code Converters](#5️⃣-code-converters)
  - [6️⃣ Parity & Error Detection](#6️⃣-parity--error-detection)
  - [7️⃣ Shifters & Rotators](#7️⃣-shifters--rotators)
  - [8️⃣ Comparators & Detectors](#8️⃣-comparators--detectors)
  - [9️⃣ ALU & Datapath Elements](#9️⃣-alu--datapath-elements)
  - [🔟 Miscellaneous](#🔟-miscellaneous)

---

## 🎯 Overview

✅ *Combinational logic circuits* have **no memory or state** — outputs depend only on current inputs.  
✅ Each section below has:
- 📄 Theory: key principles and algorithms
- 💻 RTL: Verilog/SystemVerilog implementations
- 📂 [Docs, Design, TB, Sim folders](.) in each [category folder](.)  

---

## 🔷 General Combinational Logic Blocks

### 1️⃣ [Logic Gates](logic_gates/)
- Theory: Signals, digital vs analog, need for digital
- Theory: Boolean algebra, duality, complement, redundancy
- Theory: SOP & POS forms, minimal vs canonical forms
- Theory: K-map minimization (2–5 variables), Quine-McCluskey method
- RTL:
  - AND, OR, NOT
  - NAND, NOR
  - XOR, XNOR
  - Universal gates (NAND/NOR only implementations)
  - Logic obfuscation primitives (XOR/AND camouflaging — security)

---

### 2️⃣ [Arithmetic Circuits](arithmetic_circuits/)
- Theory: Binary addition, subtraction, multiplication, division
- Theory: Data representations: signed magnitude, 1’s complement, 2’s complement
- Theory: Binary arithmetic in different number systems
- RTL:
  - Half-adder
  - Full-adder
  - Ripple-carry adder (N-bit)
  - Subtractor (N-bit), half & full
  - Carry-lookahead adder
  - Parallel adder/subtractor with overflow detection
  - Carry-save adder
  - Wallace tree multiplier
  - Booth multiplier (signed)
  - Array multiplier (combinational)
  - Approximate adder (AI/ML)
  - Approximate multiplier (AI/ML)
  - In-memory adder (PIM)
  - In-memory multiplier (PIM)

---

### 3️⃣ [Multiplexers & Demultiplexers](multiplexers_demultiplexers/)
- Theory: MUX introduction, hierarchical MUX trees
- Theory: Realizing Boolean functions using MUX
- RTL:
  - 2:1 MUX
  - 4:1 MUX
  - 8:1 MUX
  - N:1 hierarchical MUX
  - 1:2 DEMUX
  - 1:4 DEMUX
  - DEMUX as decoder
  - Crossbar switch (N×M)
  - High-speed MUX tree (HPC)

---

### 4️⃣ [Encoders & Decoders](encoders_decoders/)
- Theory: Encoders, priority encoders, decoders, seven-segment display
- RTL:
  - 2:4 decoder
  - 3:8 decoder
  - 4:16 decoder
  - Binary-to-one-hot decoder
  - Binary-to-seven-segment decoder
  - Thermometer-to-binary encoder
  - Priority encoder
  - Priority encoder with valid output
  - Decimal-to-BCD encoder
  - Octal-to-binary encoder
  - Hex-to-binary encoder
  - One-hot-to-binary converter
  - Dummy-cell comparator (PIM)

---

### 5️⃣ [Code Converters](code_converters/)
- Theory: Number systems — binary, octal, decimal, hexadecimal
- Theory: Codes — BCD, Excess-3, 2421, Gray
- Theory: Shift-add-3 method for binary-to-BCD
- RTL:
  - Binary to Gray
  - Gray to Binary
  - BCD to Binary
  - Binary to BCD
  - Excess-3 encoder/decoder
  - 2’s complement converter

---

### 6️⃣ [Parity & Error Detection](parity_error_detection/)
- Theory: Parity concept, error detection & correction
- Theory: Hamming codes, CRC
- RTL:
  - Even parity generator
  - Odd parity generator
  - Parity checker
  - Hamming code generator
  - Hamming code checker
  - CRC generator
  - CRC checker
  - S-Box (AES substitution box — security)
  - P-Box (permutation box — security)
  - AES round function components
  - DES Feistel function
  - Lightweight cipher components (PRESENT)

---

### 7️⃣ [Shifters & Rotators](shifters_rotators/)
- Theory: Logical vs arithmetic shifting
- Theory: Rotations & barrel shifters
- RTL:
  - Logical left shifter
  - Logical right shifter
  - Arithmetic right shifter
  - Circular left rotator
  - Circular right rotator
  - Barrel shifter
  - Dynamic shifter (variable shift amount)
  - Leading zero counter
  - Trailing zero counter

---

### 8️⃣ [Comparators & Detectors](comparators_detectors/)
- Theory: Comparators — 1-bit, 2-bit, N-bit
- RTL:
  - 1-bit comparator
  - N-bit comparator
  - Cascaded comparator
  - Min/Max detector
  - Threshold comparator
  - Zero detector
  - Bitline XOR, AND, Majority gates (PIM)

---

### 9️⃣ [ALU & Datapath Elements](alu_datapath_elements/)
- Theory: Arithmetic Logic Unit operations
- RTL:
  - ALU:
    - AND, OR, XOR, NOT
    - ADD, SUB, INC, DEC
    - SLT
    - Zero/carry/overflow flags
  - Dot-product unit (AI/ML)
  - Multiply-accumulate (MAC) unit (AI/ML)
  - Bit-serial MAC unit (AI/ML)
  - Activation function approximators (ReLU, sigmoid, tanh)
  - Quantizer, dequantizer
  - Max pooling unit
  - Normalization (approximate)
  - Data duplication shuffler
  - In-BRAM compute unit

---

### 🔟 [Miscellaneous](miscellaneous/)
- Theory: Switching circuits & practice problems
- Theory: Practice with K-map, Quine-McCluskey
- RTL:
  - Priority logic (arbitration/grant)
  - Priority arbiters
  - Majority voter
  - Bit-mask generator
  - Ternary CAM (TCAM) match logic
  - Packet header field extractor

---

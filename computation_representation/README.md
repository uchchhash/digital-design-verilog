# 📘 Fundamental Theories of Numerical Representations in Computing

This document summarizes foundational theories of numerical representations and their impact on digital design and computation. These concepts form the basis for understanding how data is represented, manipulated, and optimized in hardware (RTL).

---

## 📒 Topics Covered

### 🔷 1. Binary Representation
- Numbers are represented using only two symbols: `0` and `1`.
- Basis for all digital systems.
- Can represent:
  - Unsigned integers
  - Signed integers (e.g., two’s complement)
  - Fractions (binary point)

---

### 🔷 2. Fixed-Point Representation
- Represents fractional numbers by **fixing the position of the binary point**.
- **Advantages:**
  - Simple and fast.
  - Hardware-efficient.
- **Disadvantages:**
  - Limited dynamic range.
  - Fixed precision — cannot adapt to very large or very small numbers.

---

### 🔷 3. Floating-Point Representation
- Represents real numbers using **scientific notation**
- **Advantages:**
  - Large dynamic range.
  - Precision scales with magnitude.
- **Disadvantages:**
  - More complex hardware.
  - Slower and more power-consuming.

---

### 🔷 4. Trade-offs: Fixed-Point vs. Floating-Point
| Feature            | Fixed-Point       | Floating-Point     |
|--------------------|-------------------|--------------------|
| Range              | Small             | Large              |
| Precision          | Fixed             | Scales with size   |
| Hardware complexity| Low               | High               |
| Speed & power      | High & efficient  | Slower, more power |

---

### 🔷 5. Numerical Precision in Computing
- Precision refers to how accurately numbers are represented and manipulated.
- Limited by the number of bits used.
- Loss of precision can happen due to:
  - Rounding
  - Truncation
  - Insufficient bit-width

---

### 🔷 6. Overflow and Underflow
- **Overflow:**
  - Result exceeds maximum representable value.
  - Can wrap around or saturate, depending on design.
- **Underflow:**
  - Result is smaller than the smallest representable value (in magnitude).
  - Common in floating-point when result approaches zero.

---

### 🔷 7. IEEE Standard for Floating-Point Arithmetic
- IEEE 754 defines standard formats for floating-point representation.
- Common formats:
  - **Single Precision (32-bit):**
    - 1 bit sign, 8 bits exponent, 23 bits mantissa.
  - **Double Precision (64-bit):**
    - 1 bit sign, 11 bits exponent, 52 bits mantissa.
- Includes rules for rounding, special values (NaN, Infinity), and exceptions.

---

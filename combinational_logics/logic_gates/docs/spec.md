# 🔷 Multi-Function Logic Unit (MFU)

## 📘 Overview
The **Multi-Function Logic Unit (MFU)** is a combinational digital logic block that performs one of several fundamental 1-bit logic operations (AND, OR, NOT, NAND, NOR, XOR, XNOR) based on a 3-bit function select input.

---

## 🖥️ Features
✅ Supports the following operations on 1-bit inputs `a` and `b`:
| `sel[2:0]` | Operation   | Output |
|------------|-------------|--------|
| `000`      | AND         | `a & b` |
| `001`      | OR          | `a | b` |
| `010`      | NOT         | `~a` (ignores `b`) |
| `011`      | NAND        | `~(a & b)` |
| `100`      | NOR         | `~(a | b)` |
| `101`      | XOR         | `a ^ b` |
| `110`      | XNOR        | `~(a ^ b)` |
| `111`      | Reserved    | `0` |

---

## 📐 Interface

### Inputs
| Name    | Width | Description |
|---------|-------|-------------|
| `a`     | 1     | First input |
| `b`     | 1     | Second input |
| `sel`   | 3     | Function select |

### Outputs
| Name    | Width | Description |
|---------|-------|-------------|
| `y`     | 1     | Output of selected logic operation |

---


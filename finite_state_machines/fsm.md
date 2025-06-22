# Sequential Circuits and Finite State Machines (FSM)

In a **sequential circuit**, the output depends not only on the current input values but also on the **internal state**, which evolves over time. The number of internal states is **finite**, so sequential circuits are also known as **Finite State Machines (FSMs)**. The internal state changes with every clock cycle based on the inputs.

An FSM can be represented in one of the following ways:
- **State Table** – Tabular representation of states, inputs, outputs, and transitions.
- **State Transition Diagram** – Graphical representation showing how states change.
- **Algorithmic State Machine (ASM) Chart** – Flowchart-like representation combining control flow and logic.

---

### 📌 Example: 3-Consecutive-1 Detector FSM

- Detects three or more consecutive ‘1’s in a serial bit stream.
- Bits are applied serially, synchronized with a clock.
- Output becomes `1` whenever the FSM detects three or more consecutive '1’s in the input stream.

📷 *State Table & State Diagram*  
![FSM State Diagram](./images/fsm-3-consecutive-1s.png)

---

A **deterministic FSM** always has a single, unique next state for any combination of current state and input. All practical FSM-based digital systems are deterministic.

A deterministic FSM is mathematically defined as a 6-tuple:

**(Σ, Γ, S, S₀, δ, ω)**

Where:
- **Σ** = Input alphabet (set of input combinations)
- **Γ** = Output alphabet (set of output combinations)
- **S** = Set of all states
- **S₀** = Initial state (S₀ ∈ S)
- **δ** = State transition function
- **ω** = Output function

---

### ➕ State Transition Function  
**δ: S × Σ → S**  
Next state is determined by the current state and current input.

---

### ⚙️ Output Functions

- **Mealy Machine**:  
  **ω: S × Σ → Γ**  
  Output depends on both the current state and input.

- **Moore Machine**:  
  **ω: S → Γ**  
  Output depends only on the current state.

📷 *Mealy vs Moore Pictorial Depiction*  
![Mealy vs Moore](./images/mealy-vs-moore.png)

---

FSMs are fundamental to designing control logic, pattern detectors, protocol engines, and digital systems where past behavior (state) affects future behavior.

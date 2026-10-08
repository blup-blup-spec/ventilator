# Simulink Implementation Guide
## Mechanical Ventilator Control System

---

## 1. Tech Stack

| Tool | Version | Role |
|------|---------|------|
| MATLAB | R2026a | Script execution, signal simulation, plotting |
| Simulink | R2026a | Block diagram model, visual simulation environment |
| Control System Toolbox | R2026a | `tf()`, `pid()`, `feedback()`, `lsim()` |
| Signal Processing | Built-in | `square()` wave for breathing reference |

---

## 2. How the Blocks Are Organised

The model follows a strict **left-to-right signal flow**. Every block has a specific role and connects to the next in a defined order.

```
[Breathing Cycle Input] ---> [Error Signal] ---> [Ventilator Controller] ---> [Patient Lung Model]
      (Pulse Generator)          (Sum +-)              (PID Controller)           (Transfer Fcn)
                                    ^                                                    |
                                    |                                                    v
                            [From LungPressure] <---------- [Goto LungPressure] <-------+
                             (Feedback path)                    (Signal tag)
```

### Block-by-Block Breakdown

| # | Block Name | Type | What It Does |
|---|-----------|------|-------------|
| 1 | **Breathing Cycle Input** | Pulse Generator | Generates the breathing reference signal — 20 cmH2O, every 4 seconds, 50% duty cycle |
| 2 | **Error Signal** | Sum (+-) | Subtracts actual lung pressure from reference. The difference is the "error" |
| 3 | **Ventilator Controller** | PID Controller | Takes the error and computes how much airflow the machine must push. P=2, I=0.5, D=0.1 |
| 4 | **Patient Lung Model** | Transfer Fcn 1/(0.1s+1) | Models how the patient's lung responds to airflow — how quickly pressure builds |
| 5a | **Goto LungPressure** | Goto tag | Captures the lung pressure and broadcasts it with tag name `LungPressure` |
| 5b | **From LungPressure** | From tag | Receives the `LungPressure` signal and feeds it back to the Sum block (-) |
| 6 | **High Pressure Alarm** | Compare To Constant > 25 | Outputs 1 (ON) when lung pressure exceeds 25 cmH2O |
| 7 | **Low Pressure Alarm** | Compare To Constant < 5 | Outputs 1 (ON) when lung pressure drops below 5 cmH2O |
| 8a | **Lung Pressure Monitor** | Scope | Displays the lung pressure waveform over time |
| 8b | **Airflow Rate Monitor** | Scope | Displays the PID controller output (airflow command) over time |
| 8c | **Alarm Status** | Scope (via Mux) | Displays both High and Low alarm signals on one scope |
| 9 | **Current Pressure Value** | Display | Shows the live numeric pressure value at the current simulation time |

---

## 3. The Closed-Loop Feedback Mechanism

```
Step 1: Pulse Generator outputs Reference = 20 cmH2O (target pressure)

Step 2: Sum block computes:
        Error = Reference - Actual Lung Pressure

Step 3: PID Controller sees the error and calculates airflow needed

Step 4: Airflow goes into the Lung (Transfer Fcn) -> builds pressure

Step 5: New pressure is captured by Goto tag -> sent back via From tag

Step 6: Goes back to Sum block as NEGATIVE input -> Error recalculated

Step 7: Loop repeats every 10ms until pressure matches reference
```

> The **Goto/From** pair is how the feedback wire is routed without crossing other signal lines.
> `[LungPressure]` is the shared tag name that connects them invisibly.

---

## 4. All 11 Signal Connections

| Wire | From | To | Signal |
|------|------|----|--------|
| 1 | Breathing Cycle Input | Error Signal (+) | Reference waveform |
| 2 | Error Signal | Ventilator Controller | Error value |
| 3 | Ventilator Controller | Patient Lung Model | Airflow command |
| 4 | Patient Lung Model | Goto LungPressure | Actual lung pressure |
| 5 | Patient Lung Model | Lung Pressure Monitor | Pressure for scope |
| 6 | Patient Lung Model | Current Pressure Value | Numeric display |
| 7 | Patient Lung Model | High Pressure Alarm | Pressure for comparison |
| 8 | Patient Lung Model | Low Pressure Alarm | Pressure for comparison |
| 9a | High Pressure Alarm | Alarm Mux input 1 | 0 or 1 alarm signal |
| 9b | Low Pressure Alarm | Alarm Mux input 2 | 0 or 1 alarm signal |
| 10 | Alarm Mux | Alarm Status Scope | Both alarm channels |
| 11 | From LungPressure | Error Signal (-) | Feedback — closes the loop |
| 12 | Ventilator Controller | Airflow Rate Monitor | Airflow for scope |

---

## 5. How to Generate Disturbance and See It on the Monitors

> Open the `.slx` model, double-click a block, change a value, click OK,
> press Run, then double-click a scope to see the result.

---

### Disturbance 1 — HIGH PRESSURE ALARM on Lung Pressure Monitor

1. Double-click **`Breathing Cycle Input`** (pulse wave block, far left)
2. Change `Amplitude`: **20 -> 38**
3. Click OK -> press Run
4. Double-click **`Lung Pressure Monitor`** -> pressure goes above 25 line
5. Double-click **`Alarm Status`** -> HIGH alarm channel jumps to ON

**Effect:** Pressure peaks above 25 cmH2O every breath cycle.

---

### Disturbance 2 — LOW PRESSURE ALARM on Lung Pressure Monitor

1. Double-click **`Breathing Cycle Input`**
2. Change `Amplitude`: **20 -> 3**
3. Click OK -> press Run
4. Open **`Lung Pressure Monitor`** -> pressure barely rises
5. Open **`Alarm Status`** -> LOW alarm jumps to ON

**Effect:** System is under-ventilating — pressure never reaches a safe level.

---

### Disturbance 3 — UNSTABLE OSCILLATION on Airflow Rate Monitor

1. Double-click **`Ventilator Controller`** (PID block)
2. Change:
   - `P` (Proportional): **2 -> 12**
   - `I` (Integral): **0.5 -> 2**
   - `D` (Derivative): **0.1 -> 0.8**
3. Click OK -> press Run
4. Open **`Airflow Rate Monitor`** -> wild oscillations appear
5. Open **`Lung Pressure Monitor`** -> pressure overshoots and oscillates

**Effect:** Controller too aggressive — system cannot settle, alarms fire repeatedly.

---

### Disturbance 4 — STIFF LUNG (Disease Model) on Lung Pressure Monitor

1. Double-click **`Patient Lung Model`** (Transfer Fcn block)
2. Change `Denominator`: **[0.1 1] -> [0.7 1]**
3. Click OK -> press Run
4. Open **`Lung Pressure Monitor`** -> pressure rises much more slowly

**Effect:** Models a stiff/diseased lung (ARDS, fibrosis) — sluggish pressure response.

---

### Reset to Normal Values

| Block | Parameter | Normal Value |
|-------|-----------|-------------|
| Breathing Cycle Input | Amplitude | 20 |
| Breathing Cycle Input | Period | 4 |
| Ventilator Controller | P | 2 |
| Ventilator Controller | I | 0.5 |
| Ventilator Controller | D | 0.1 |
| Patient Lung Model | Denominator | [0.1 1] |

---

## 6. Opening Scopes After Running

- Double-click **`Lung Pressure Monitor`** -> breathing waveform
- Double-click **`Airflow Rate Monitor`** -> PID output (airflow command)
- Double-click **`Alarm Status`** -> alarm 0/1 signals (two channels)
- **`Current Pressure Value`** -> live numeric pressure

> If scope appears empty after run, click the **binoculars icon (Autoscale)** inside the scope window.

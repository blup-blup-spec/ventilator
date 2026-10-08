# Theoretical Knowledge
## Mechanical Ventilator Control System

---

## 1. What Is a Mechanical Ventilator?

A mechanical ventilator is a machine that **breathes for a patient** when they cannot breathe on their own — due to surgery, respiratory failure, or conditions like ARDS, COVID-19, or pneumonia.

The ventilator's job is to:
- Push pressurised air into the lungs (inhalation)
- Allow the lungs to deflate (exhalation)
- Maintain pressure within a safe range at all times

> **Key danger:** Too much pressure → lung injury (barotrauma).
> Too little pressure → insufficient oxygen delivery (hypoxia).

---

## 2. Why a Control System?

Without control, the ventilator would push the same airflow regardless of whether the patient's lung pressure is already high or low. This is called **open-loop** and it is dangerous.

### Open-Loop (No Control)
```
Command --> Ventilator --> Lungs
                          (no feedback, no correction)
```
Problem: If lung stiffness changes (e.g. fluid buildup), pressure becomes dangerously wrong.

### Closed-Loop (With Control — Our System)
```
Command --> Ventilator --> Lungs --> Pressure sensor --> Subtract from command --> Correction
    ^                                                                                    |
    +------------------------------------------------------------------------------------+
```
The system **continuously measures actual pressure** and corrects the airflow so the pressure always matches the target.

---

## 3. The Reference Signal — Pulse Generator

The breathing reference is a **square wave** (Pulse Generator):

```
Amplitude  = 20 cmH2O    (target peak pressure — tidal volume)
Period     = 4 seconds   (one breath every 4 seconds = 15 breaths/min)
Pulse Width = 50%        (2 seconds inhale, 2 seconds exhale)
```

Mathematical form:
```
r(t) = 20 * square(2*pi/4 * t, 50)    for positive half only
```

This mimics the breathing pattern of a resting adult:
- Normal breathing rate: 12-20 breaths/min
- Normal tidal volume: ~500 mL mapped to 20 cmH2O pressure

---

## 4. The Error Signal — Sum Block

The **Sum block** computes the error at every moment in time:

```
e(t) = r(t) - y(t)

Where:
  e(t) = error signal        (how far off we are)
  r(t) = reference signal    (target lung pressure)
  y(t) = actual lung pressure (measured output)
```

- If **e(t) > 0**: Lung pressure is BELOW target → push more air
- If **e(t) < 0**: Lung pressure is ABOVE target → reduce airflow
- If **e(t) = 0**: Perfectly on target → maintain current airflow

---

## 5. The PID Controller — Mathematics

PID stands for **Proportional - Integral - Derivative**. It is the most widely used controller in the world.

The PID output (airflow command) is:

```
u(t) = P*e(t)  +  I * integral(e(t) dt)  +  D * d/dt(e(t))

Where:
  P = 2    (Proportional gain)
  I = 0.5  (Integral gain)
  D = 0.1  (Derivative gain)
  e(t) = error at time t
```

### What Each Term Does

| Term | Formula | Effect | In Ventilator Context |
|------|---------|--------|-----------------------|
| **P** — Proportional | `2 * e(t)` | Responds instantly to current error | More error = push more air immediately |
| **I** — Integral | `0.5 * sum of past errors` | Eliminates steady-state error over time | Corrects slow drift — ensures pressure reaches exact target |
| **D** — Derivative | `0.1 * rate of change of error` | Responds to how fast error is changing | Dampens rapid pressure spikes — prevents overshoot |

### Transfer Function of PID (in Laplace domain):

```
C(s) = P + I/s + D*s
     = 2 + 0.5/s + 0.1*s
```

In MATLAB: `ctrl = pid(2, 0.5, 0.1)`

### What Happens If You Change PID Gains?

| Change | Effect |
|--------|--------|
| P too high (e.g. 15) | System overreacts, oscillates, pressure spikes |
| I too high (e.g. 2) | System becomes slow and windup occurs |
| D too high (e.g. 0.8) | System becomes noisy and jerky |
| All gains too low | System is sluggish, pressure never reaches target |

---

## 6. The Lung Plant Model — Transfer Function

The **Patient Lung Model** is a first-order linear system:

```
           Output Pressure (Y)       1
G(s) = ------------------------- = -------
           Input Airflow (U)       0.1s + 1
```

This is derived from the equation of a lung:

```
Compliance * dP/dt + (1/Resistance) * P = Flow
```

Where:
- **Compliance** (C) = 0.1 = how easily the lung stretches (L/cmH2O)
- **Resistance** (R) = 1 = airway resistance to flow

Combined: `tau = C*R = 0.1 * 1 = 0.1 seconds` (time constant)

### What the Time Constant Means

```
tau = 0.1 seconds  ->  lung reaches 63% of target pressure in 0.1 seconds (healthy)
tau = 0.7 seconds  ->  lung reaches 63% of target in 0.7 seconds (diseased, stiff)
```

In MATLAB: `plant = tf([1], [0.1, 1])`

---

## 7. Closed-Loop System — Feedback Mathematics

When PID controller and Lung Plant are connected in a feedback loop:

```
                  C(s)*G(s)
H_closed(s) = ---------------
               1 + C(s)*G(s)
```

In MATLAB:
```matlab
cl = feedback(ctrl * plant, 1)
```

The `1` in `feedback(..., 1)` means **unity feedback** — the full output is fed back (no sensor scaling).

### Step Response Characteristics (Normal Parameters)
```
Rise Time   ~ 0.05 seconds   (fast response due to P=2)
Overshoot   ~ 8%             (small due to D=0.1 damping)
Settling    ~ 0.3 seconds    (integral removes steady-state error)
```

---

## 8. The Alarm Logic — Compare To Constant

Both alarm blocks perform a simple threshold comparison:

```
High Pressure Alarm:
  If  y(t) > 25 cmH2O  -->  alarm_high = 1  (ON)
  Else                  -->  alarm_high = 0  (OFF)

Low Pressure Alarm:
  If  y(t) < 5 cmH2O   -->  alarm_low = 1   (ON)
  Else                  -->  alarm_low = 0   (OFF)
```

### Clinical Meaning of Thresholds
```
Upper limit = 25 cmH2O  ->  Plateau pressure limit (lung injury risk above this)
Lower limit = 5 cmH2O   ->  PEEP minimum (positive end-expiratory pressure)
```

Both alarm signals are combined by the **Mux block** into a 2-channel signal so they can be displayed together on the **Alarm Status Scope**.

---

## 9. Goto/From Tag — How Virtual Wiring Works

In a complex Simulink model, running wires across the diagram causes visual clutter. The **Goto/From** pair solves this:

```
[Goto: LungPressure]  -- broadcasts pressure signal with tag "LungPressure"
[From: LungPressure]  -- receives the same signal anywhere in the model
```

Mathematically this is identical to a direct wire:
```
y_feedback(t) = y(t)    (same signal, no modification)
```

This is purely a **visual routing tool** — no mathematics changes.

---

## 10. Simulation — How lsim Works

```matlab
[y, t] = lsim(system, input_signal, time_vector)
```

`lsim` (Linear Simulation) solves the differential equations of the closed-loop system numerically using the input signal as a forcing function.

For our system:
```matlab
t      = 0 : 0.01 : 30           % time from 0 to 30 seconds, step 0.01s
ref    = 20 * square wave         % reference breathing signal
cl     = feedback(pid*tf, 1)      % closed-loop transfer function
lp     = lsim(cl, ref, t)         % lung pressure over 30 seconds
```

The solver used is **ode45** (Runge-Kutta 4th/5th order adaptive step):
- Automatically chooses step size for accuracy
- Max step size = 0.01 seconds (100 Hz resolution)

---

## 11. Summary — Complete Mathematical Chain

```
1. Reference:      r(t) = 20 * pulse(t, T=4s)

2. Error:          e(t) = r(t) - y(t)

3. PID Output:     u(t) = 2*e(t) + 0.5*integral(e) + 0.1*d(e)/dt

4. Lung Response:  Y(s) = U(s) * [1 / (0.1s + 1)]

5. Feedback:       y(t) fed back to step 2 (via Goto/From tags)

6. Alarms:         HIGH if y(t) > 25
                   LOW  if y(t) < 5

7. Result:         y(t) tracks r(t) within safe pressure limits
```

This is a complete **closed-loop feedback control system** — the same mathematical
structure used in autopilots, industrial robots, and medical devices worldwide.

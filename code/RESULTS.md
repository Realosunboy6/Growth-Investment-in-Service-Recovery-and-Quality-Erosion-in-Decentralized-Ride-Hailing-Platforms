# ISYE 681 Julia prototype — test results (2026-10-12)

> SUPERSEDED (marked 2026-10-26): this note is from the provisional placeholder-parameter era (8 tests). Current values are in CALIBRATION.md and RESULTS_64.md and the executed model (10 of 10 tests pass). Do not quote figures from this note.

**Code:** `model.jl` (8-stock SD model, explicit Euler, h = 0.05) + `tests.jl`.
Run: `~/julia-1.11.7/bin/julia tests.jl`. No external packages.

**Source of truth:** `~/workspace/your_files/ISYE681/ConsolidatedEquations.docx`
(finalized, clean PASS from Claude Opus 5.5 and all three GPTs).
All parameter values are PROVISIONAL placeholders (Table 1 bands for paper
params, [A] closures uncalibrated). Nothing here is a calibrated finding.

## Results

| Test | Result | Key numbers |
|------|--------|-------------|
| T1 fixed-policy equilibrium (funds idealized nonbinding, per test spec) | PASS | max drift 0.0% on C and U for (τ_turn,τ_dev) = (24,7.5), (12,12), (36,3) over 60 mo |
| T2 step C* 100→200 at t=30 | PASS | overshoot −0.0008 units (≈0%), C(90) = 199.999 |
| T3 α=0 from init | PASS | B monotone nondecreasing; B(60) = 11,807.5 (bound 240,000); Q 0.9587 → 0.0 |
| T4 f_s=0 from init | PASS | max B(t) = 0 |
| T5 unlimited capacity (equation-level: constant g_B, nonbinding r_B) | PASS | B(60) = 500.0 vs g_B·τ_B = 500, err 0.0% |
| T6 funds nonnegativity (full-feedback fixed rule) | PASS | min F(t) = 0.30 USD ≥ 0 |
| T7 h=0.05 vs 0.025 at t=60 | PASS | rel diff C 0.075%, B 0.027%; F 3.38% relative = 0.01 USD absolute on near-zero balance |
| T8 revenue-cut s_R=0 | PASS | max\|C−C0\| = 0, max\|U−U0\| = 0, ΔF = ∫I_F dt exactly (125,497.2 USD) |

## Honest caveats

1. **T1 tests the controller in isolation** ("with funds nonbinding" per the test
   spec — funds constraint idealized away, as in Claude's verification sims).
   In the FULL model with provisional parameters, funds do NOT stay nonbinding:
   the t=0 coverage ratio is 0.617 < 1, so the backlog grows, quality collapses
   (Q → 0), riders leave, revenue turns negative, funds drain to ~0, and capacity
   erodes (C: 0.651 → 0.264). This is genuine model behavior under uncalibrated
   parameters — the doc's own coverage diagnostic predicts exactly this initial
   imbalance — not a controller defect. Calibration (or higher α) is needed
   before full-model runs are meaningful.
2. **T5 is an equation-level check** of Ḃ = g_B − min(B/τ_B, m_C·ρ_C·C) under the
   doc's stated conditions (constant arrivals, nonbinding resolution), not a
   full-model run.
3. **T7's F figure**: the 3.38% is relative to a near-zero funds balance
   (F(60) ≈ 0.3 USD after the drain described above); the absolute difference is
   0.01 USD. C and B converge cleanly (≤0.08%).
4. Parameters are placeholders; no empirical claims are made.

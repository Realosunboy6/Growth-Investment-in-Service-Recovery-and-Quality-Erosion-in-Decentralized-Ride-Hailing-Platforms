# Sampling-convention fix — Job 1 behavior test (Fig. 4 / Sections 3.5, 4.6)

## Diagnosis: CONFIRMED (Claude's concern is correct)

In `behavior_test.jl`, `run_shock` records `aux.T` — the instantaneous trips
**rate** computed from the state at the start of each Euler step — and
`monthly()` subsamples every 20th record. Because record k holds the rate at
state time (k−1)·h, the value written for CSV `month_index` m is the
instantaneous rate at t = m − 0.05: effectively the **end of the previous
month**. The observed TLC series is **monthly totals**. Evidence from the
original series (floor 0.25, all rules):

| Label | Instantaneous value | State time it actually is |
|---|---|---|
| Mar 2020 (m=1) | 1.000 | t = 0.95 — before the floor steps down at t = 1 |
| Apr 2020 (m=2) | 0.281 | t = 1.95 — end of March |
| May 2020 (m=3) | 0.273 | t = 2.95 — end of April |

So the figure compared end-of-month instantaneous rates against monthly
totals, shifted by one month. The C2 "+1 month lag" was produced by that
shift, not by the model's dynamics.

## Fix applied

`sampling_fix.jl` recomputes the simulated comparison series as **monthly
averages** of the simulated trips rate over each calendar month (mean of
`aux.T` over the 20 steps with state time in [m, m+1)), the convention that
matches observed monthly totals (average rate and monthly total differ only
by the month length, which cancels in the Feb-2020 normalization). No other
change: same Feb-2020 rescaling, same s(t) path and floor, same rules, same
h = 0.05. The run is extended to t = 37 only so the last plotted month
(Feb 2023) has a complete month to average; months 0–35 are unaffected.
Integrity re-verified in the same run: the shock code reproduces model.jl's
`run!()` exactly at s ≡ 1 (max diff 0.0), and the regenerated instantaneous
CSV is byte-identical to the original (md5 d408bab8…).

Files: corrected series in `behavior_test_series_monthlyavg.csv`; original
series preserved in `behavior_test_series_instantaneous.csv`.

## Before / after verdicts (responsive rule, floor 0.25; identical trough
## values under all three rules)

| Quantity | Instantaneous (old) | Monthly average (corrected) |
|---|---|---|
| Mar 2020 | 1.000 | **0.285** (observed 0.619) |
| Apr 2020 | 0.281 | **0.277** (observed 0.201) |
| May 2020 | 0.273 | **0.298** (observed 0.284) |
| Trough depth | 0.273 | **0.277** |
| Trough month | May 2020 | **Apr 2020** |
| First month ≥ 0.9 | Jun 2021 (m=16) | **May 2021 (m=15)** |

- **C1 (depth, band [0.051, 0.351]): PASS, unchanged in substance.**
  0.277 vs observed 0.201. Depth remains set mainly by the imposed floor.
- **C2 (timing, ±1 month of Apr 2020): the "+1 month lag" DISAPPEARS.**
  The simulated trough month is April 2020, the observed month. However, the
  simulated bottom is nearly flat — Mar 0.285, Apr 0.277, May 0.298, a total
  spread of 0.021 — so the trough month is **weakly determined** and the
  month agreement carries little evidential weight. The old
  "stock-adjustment lag" explanation is withdrawn.
- **Collapse speed reverses sign.** Under matched conventions the model
  collapses **faster** than the market: simulated March averages 0.285 against
  the observed 0.619, because the imposed floor binds for the whole of March
  while the real lockdown (NY PAUSE, Mar 22) cut only the last part of the
  month, and the observed monthly total blends the pre-lockdown weeks. The
  observed April (0.201) then falls **below** the simulated April (0.277):
  the real trough was deeper than the model's floor-level plateau. Faster,
  but shallower.
- **C3 (recovery, ±3 months of Oct 2022): FAIL, unchanged and one month
  worse.** First monthly-averaged crossing of 0.9 moves from Jun 2021 to
  May 2021 (peak 0.932 in Jul 2021; back below 0.9 from Oct 2021; 0.458 by
  Feb 2023 vs observed 0.845). Under the reserve rule the averaged series
  never reaches 0.9 at all. Diagnosed causes unchanged (demand plateau;
  Feb-2020 coverage 0.728 with the decentralized take applied to the 2020
  market; no-shock control declines on its own).

Nothing was retuned: floor, s(t) timing, rescaling, and all feedback
parameters are exactly as pre-stated in job1_design_prestated.md.

## Item-3 check (Claude round after the PASS): May 2020 multiplier average

Question: in the runs as executed, does the demand multiplier s(t) average
exactly 0.25 over May 2020 — i.e. does the floor hold through May, with
restoration starting in June — or does restoration begin inside May?

Method: `shock_s` copied verbatim from `behavior_test.jl` and averaged over
the same step convention as the monthly-average series (the 20 steps with
state times in [m, m+1), h = 0.05).

| Month | s min | s max | s step-average |
|---|---|---|---|
| Mar 2020 (m=1) | 0.25 | 0.25 | **0.2500** |
| Apr 2020 (m=2) | 0.25 | 0.25 | **0.2500** |
| May 2020 (m=3) | 0.25 | 0.3048 | **0.2774** |
| Jun 2020 (m=4) | 0.3077 | 0.3625 | 0.3351 |

Finding: the May average is **not** 0.25. In the code, the floor branch is
`t <= 3.0` and the restoration branch is `floor + (1 - floor)(t - 3)/13` for
`3 < t < 16`, so restoration begins at t = 3 — the start of **May 2020** —
and reaches 1.0 at t = 16 (June 2021) over a 13-month ramp. This differs
from the pre-stated design note in job1_design_prestated.md ("floor held
through t = 3 (May 2020); linear restoration from t = 4"), which the code
does not implement: in the code t = 3 is the ramp's origin, not a floor
month. Consequently the April-to-May rise in simulated trips (0.277 to
0.298) occurs while s itself is already rising (May mean 0.2774 vs 0.25),
so the rise cannot be credited to endogenous dynamics alone, and no
endogenous-mechanism clause was added.

Action taken (paper, both formats): Section 3.5 corrected from "holds
through May 2020, and restores linearly from June 2020 to June 2021" to
"holds through April 2020, and restores linearly from May 2020 to
June 2021", matching the runs as executed. No numbers, criteria, or
verdicts change: C1–C3 were computed on the executed path.

# ISYE 681 — 64-run experiment results (corrected)

**Date:** 2026-10-12 (revised after external review). **Code:** `experiment.jl`
(h = 0.05, T = 60 mo, β = 1).
**Design (docx §5):** (4 intact-revenue configs × 3 rules + 4 revenue-cut
configs × 1 reference) × 4 scenarios = **64 runs, verified**.
**Scenarios:** α ∈ {0.05, 0.10} × τ_dev ∈ {3, 12} mo → t=0 coverage 0.585 / 1.170.
**Configs:** (s_D, s_E) ∈ {(1,1),(1,0),(0,1),(0,0)}.
**Ranking:** pre-registered D9 — mean complaint exposure per rider X̄_B primary,
2% ties (differences under 2% count as tied; no tie-break — ties reported as
ties); spending reported alongside; cumulative ∫g_B dt
scale-only.
**Raw data:** `results_64.csv` (one row per run).
**Follow-ups:** `beta_sweep.csv` (16 cells × β ∈ {0, 0.5}),
`coverage_sweep.csv` (boundary sweep per rule), `lhs_sensitivity.csv`
(200-draw Latin hypercube over Table 1 bands), `lhs_sensitivity_682.csv`
(supplementary 200-draw batch, seed 682).

## 1. Rankings per scenario (D9)

Headline intact cell (s_D=1, s_E=1), X̄_B in complaints/rider:

| Scenario | 1st | 2nd | 3rd | Tie? |
|---|---|---|---|---|
| a05_d3 (low fund, fast build) | reserve 1.352 | responsive 1.426 | fixed 1.680 | No (5.2% gap) |
| a05_d12 (low fund, slow build) | reserve 1.524 | responsive 1.639 | fixed 1.680 | No |
| a10_d3 (high fund, fast build) | reserve 0.069 | responsive 0.083 | fixed 0.407 | No |
| a10_d12 (high fund, slow build) | reserve 0.073 | responsive 0.098 | fixed 0.407 | No |

Across all 16 cells the strict order **reserve > responsive > fixed holds in
14**; in the other two (a05_d3, s_D=0, s_E∈{0,1}) reserve and responsive are
1.28% and 1.20% apart — under the 2% D9 rule these are **ties** (reported as
tied, fixed third; D9 has no tie-break).

**Tradeoff flags:** one pairwise flag fires — a05_d12 intact: responsive beats
fixed on X̄_B by 2.4% but ends with 2.1% fewer riders (480k vs 490k). The X̄_B
leader does *not* lead on A(60) in 7 cells (all within the 2% tolerance).

**Cost of the win:** reserve spends the most everywhere (a10_d3: $187M vs
responsive $176M vs fixed $85M) and ends nearly cash-empty (min F ≈ $0.01);
responsive keeps a $1.5M+ buffer. Part of reserve's edge is extra spending
(+6% for 17% lower exposure at a10_d3) — the edge cannot be separated from
spending without a spend-matched run.

## 2. Reference mode (Objective 3 pattern rules)

- **Low funding (α=0.05, t=0 coverage 0.585): all 32 runs overshoot and
  decline** — every rule, every switch combo, both delays. In intact cells
  quality falls to Q(60) 0.10–0.12 and the backlog grows to 20.5–22.3× B(0)
  (~1.4–1.5M complaints); riders roughly halve (A60 ≈ 0.48–0.49M vs
  A0 = 1.01M). With the exposure link cut (s_E=0), quality falls less far
  (Q(60) 0.34–0.43) because the B/A → quality channel is severed.
- **High funding (α=0.10, coverage 1.170):** the fixed rule and the revenue-cut
  reference overshoot and decline in every cell; responsive and reserve show
  **sustained growth** (one cell: responsive at a10_d12, s_D=1, s_E=0 =
  "recovery after a dip").
- **Delay changes magnitudes and one pattern label:** τ_dev = 3 vs 12 shifts
  X̄_B modestly (responsive 0.083 → 0.098) and flips responsive in the
  α=0.10, s_D=1, s_E=0 cell from sustained growth (τ_dev=3) to recovery
  after a dip (τ_dev=12). It flips no ranking.
- **The two funding levels do not locate a boundary** — they show it lies
  somewhere between t=0 coverage 0.585 and 1.170. See §5 for the mapped
  boundary (rule-dependent, in coverage terms).

## 3. The fixed-budget mechanism (a10_d3, headline cell)

| Rule | A(60) | B(60) | Q(60) | Spending |
|---|---|---|---|---|
| fixed | 1.10M | 328k (4.7× B0) | 0.784 | $84.8M |
| responsive | 2.02M | 140k (≈ B*) | 0.949 | $175.7M |
| reserve | 2.03M | 140k (≈ B*) | 0.949 | $186.9M |

The fixed rule's budget is set from early revenue (B_prot at t=0), so installed
capacity freezes at C(0) = 205 while the platform doubles: the backlog grows
nearly fivefold, quality erodes 0.95 → 0.78, and ridership stalls at 1.1M
against a 2.0M equilibrium. The adaptive rules grow capacity ~2.3× and hold
quality at the calibrated 0.949. Note: the fixed rule's B/Q/A paths are
numerically identical to the revenue-cut reference (capacity frozen in both) —
expected per docx §5; they differ only in funds accounting. That is itself a
finding: R1 is inactive under a fixed budget at adequate funding.

## 4. β-sensitivity of the rankings (`beta_sweep.csv`)

The 16 full-feedback cells were re-run at β = 0 and β = 0.5 (96 runs) and
ranked under D9; β = 1 is the 64-run experiment above.

- **High funding (α=0.10): the strict order reserve > responsive > fixed holds
  in 6/8 cells at β = 0** (the two s_D=0, s_E=0 cells rank reserve first with
  fixed/responsive tied under 2%), **and in 8/8 cells at β = 0.5 and β = 1**
  — no ties. The policy ranking is robust to the rider-return assumption
  exactly where the comparison is policy-meaningful.
- **Low funding (α=0.05): rankings are unstable across β** — at β=0 several
  cells rank fixed first; at β=0.5 a mix with ties. But outcomes there are
  practically indistinguishable across rules (intact cells: A(60) 480–491k,
  Q(60) 0.10–0.12), so the low-funding ranking is real-but-not-policy-meaningful
  regardless of β. The instability itself reflects that no rule matters much
  when funding is inadequate.
- This supersedes the earlier headline-cell-only T10 claim: full-cell
  robustness holds at adequate funding, not unconditionally.

## 5. Coverage sweep — the overshoot boundary per rule (`coverage_sweep.csv`)

Method: per rule, α swept 0.04–0.13 (t=0 coverage 0.47–1.52; α > 0.10
exceeds Table 1's band and is documented as boundary-mapping only),
intact-revenue, τ_dev=3, β=1, 60 months, Objective 3 classification.

- **Fixed rule: overshoot-and-decline at every coverage 0.47–1.52 — it never
  flips.** A frozen budget cannot escape the reference mode even at 1.5×
  coverage (though Q(60) improves from 0.06 to 0.90 across the sweep).
- **Responsive: overshoot-decline through coverage 0.88**; **sustained growth from ≈0.94**. (An earlier classifier labeled the
  0.82 run "multiple peaks"; under the pre-set Objective 3 rule — a peak
  counts as separate only if the rise above the intervening trough is ≥10% —
  its second local max does not qualify, so the run is overshoot-decline.)
- **Reserve: overshoot-decline through 0.82; sustained growth from ≈0.88.**
- The boundary is rule-dependent and lives in coverage space, not in α
  alone. The nominal sweep points above are coarse; the two 200-draw
  hypercube batches (§6) locate the transition as a **band, not a point**
  — band = highest coverage still overshooting vs lowest coverage
  sustaining growth, combined across both batches: reserve **0.85–0.91**,
  responsive **0.86–1.46**, fixed **1.59–1.87**. In seed 682 the fixed
  rule's band does not overlap (highest collapse 1.76 < lowest sustained
  growth 1.87). The two experiment funding levels (0.585, 1.170) straddle
  the reserve and responsive bands, which is why the 64-run design shows
  the full contrast; the fixed band lies above the mapped sweep range.

## 6. Global sensitivity — 200-draw Latin hypercube (`lhs_sensitivity.csv`)

Method: hand-rolled LHS (stratified uniform per dimension + random
permutation, seed 681) over the 12 banded Table 1 parameters
(f_s, s_c, ρ_C, c_C, τ_turn, τ_Q, τ_dev, κ_Q, α, θ, φ, τ_D); B_trig and m_R
held as policy levers; τ_A re-derived per draw from the equilibrium
identities; 3 rules × intact switches × β=1 × 60 months = 600 runs
(~7 s total). **Zero numerical failures** (no negatives, non-finites, or
explosions in any draw).

- **Rankings:** among the 80 decisive draws of 200 (top two rules >2% apart),
  **70 (88%) rank reserve > responsive > fixed** with both gaps ≥2% — 41/49
  at coverage < 1 and 29/31 at coverage ≥ 1; reserve ranks first in 76 (95%).
  (An earlier draft reported 73 (91%); the 3-draw difference is
  responsive/fixed pairs under 2% that the removed quality tie-break had
  ordered — D9 has no tie-break, so they are ties.) The other 120 draws are
  D9 ties (median t=0 coverage 0.33): 95 of them are draws where all three
  rules overshoot and decline (median coverage 0.228), where funding
  dominates and the rules' outcomes are practically indistinguishable —
  the tie rule correctly refuses to rank near-identical collapses.
- **Patterns:** fixed overshoots-and-declines in 173/200 draws (26 sustained
  growth draws, all at coverage ≥ 1.59; 1 recovery after a dip at coverage 1.35); responsive 138
  overshoot-decline / 9 recovery-after-a-dip / 3 recurrent fluctuations /
  50 sustained growth; reserve 138 overshoot-decline / 1 recovery-after-a-dip
  / 61 sustained growth. No run in any file classifies as "multiple peaks":
  under the pre-set Objective 3 rule (a peak is separate only if the rise
  above the intervening trough is ≥10%), all multi-peak runs either merge
  to a single peak or qualify as recurrent fluctuations. Two boundaries,
  not one: the bands reported here are *collapse* boundaries (highest
  overshoot-decline coverage vs lowest sustained-growth coverage),
  whereas the logistic below contrasts sustained growth with everything
  else, oscillatory patterns included — for responsive, recovery-after-
  a-dip and recurrent-fluctuation runs reach coverage 1.78 (seed 681)
  and 1.42 (seed 682), overlapping its 0.86–1.46 collapse band and extending
  above it to roughly 1.8; oscillatory runs can carry high κ_Q, though
  the groups overlap — sustaining runs also reach high κ_Q. Above coverage
  1.9, every run under
  every rule sustains growth in both batches.
- **What separates the outcomes:** complaint inflow per trip f_s·s_c
  (3×: 0.0153 vs 0.0052) and t=0 coverage (0.38 vs 2.49) dominate the
  overshoot-decline vs sustained-growth split for the responsive rule;
  cost per resolution c_C/ρ_C is secondary (15.0 vs 12.8); α, θ differ
  modestly; τ_turn, τ_Q, τ_dev, κ_Q, φ, τ_D show essentially no separation.
  As the reviewer hypothesized, f_s·s_c and c_C/ρ_C are the parameters to
  watch — the boundary is where complaint inflow overwhelms funded
  resolution capacity. (The "no separation" statement for κ_Q is about
  unconditional group means across all draws, which the coverage split
  dominates; it does not hold coverage fixed. With coverage held fixed,
  κ_Q does shift the boundary — see the next bullet. The two statements
  are consistent: no visible unconditional separation, but a real
  conditional effect near the boundary.)
- **Does the boundary move? (Objective 3 follow-up):** a hand-fit logistic
  classifier (IRLS) for P(sustained growth) on the 200 draws. Log-coverage
  alone already separates well (responsive: McFadden R² = 0.80, AUC = 0.99;
  reserve: R² = 0.95; fixed: R² = 0.91). Adding the non-coverage parameters
  κ_Q, τ_Q, τ_dev, τ_D improves the responsive fit (deviance drops 31.6 on
  4 df; R² = 0.94, AUC = 0.999), and the improvement is carried by κ_Q, in
  the direction of a higher threshold. The coefficient itself is *not*
  reported as a headline number: the augmented fit is close to separation
  (only 17 of 200 draws have a fitted probability in (0.01, 0.99)), which
  inflates coefficients and makes likelihood-ratio p-values optimistic;
  for reserve and fixed the augmented fit separates perfectly (R² = 1.00,
  no intermediate fitted probabilities), so no coefficients are reported
  for them at all. The claim rests on the band evidence instead:
  **coverage sets where the boundary is, and high κ_Q shifts the
  sustained-growth threshold upward by turning near-boundary runs
  oscillatory.** Inside the responsive hypercube band (14 draws, coverage
  0.97–1.19), the 8 draws that sustain growth have κ_Q ∈ [0.16, 0.73],
  while the 6 that fail have κ_Q ∈ [0.65, 0.99]; of those 6 failures, 3
  are recurrent fluctuations and 2 are recovery after a dip — only 1 is
  overshoot-and-decline (coverage 1.19, the band's edge). A supplementary
  200-draw batch (seed 682, `lhs_sensitivity_682.csv`, 0 failures)
  broadly confirms the reserve band (≈0.85–0.90 vs 0.89–0.91) and the
  fixed transition (≈1.76–1.87 vs 1.59–1.78), but places the responsive
  transition at ≈0.86–1.46, so across the two batches the responsive
  boundary region spans ≈0.86–1.46 — a single 200-draw batch understates
  batch-to-batch variability. Conclusion: the boundary's *location* is
  set by coverage; its *exact position* shifts with κ_Q (and secondarily
  τ_Q, τ_dev, τ_D) — the boundary moves.

## 7. Numerical health

**All 64 runs clean**: no negative stocks, no NaN/Inf, no explosions,
Q ∈ [0,1] everywhere, F(t) ≥ 0 in every run (min $0.0037; responsive/reserve
at low funding run funds essentially to zero — economically binding, not a
bug). LHS: 0/200 failed draws.

**Compute (all wall-clock, Julia 1.11.7, Euler h=0.05):** 64-run experiment
~4 s; β-sensitivity 96 runs ~3 s; coverage sweep 57 runs ~3 s; LHS 600 runs
~6 s. Total well under a minute — the model is cheap enough to re-run
end-to-end on any parameter change.

## 8. What Section 8 (Results) should say — one paragraph

> Funding dominates the investment-rule choice, and the relevant variable is
> t=0 coverage, not the allocation share alone. The decision rule matters
> only in an **intermediate coverage band**: below it (roughly <0.9) no rule
> saves the platform — every policy overshoots and declines regardless of
> decision rule or development delay, with quality falling to 0.10–0.12 and
> the backlog growing more than twentyfold in intact low-funding cells, so
> the rules' outcomes there are practically indistinguishable (riders
> 480–491k across rules). Above ≈1.9 no rule is needed —
> all three rules sustain growth, the fixed rule flipping from
> overshoot-decline to sustained growth over coverage ≈1.59–1.87; for the
> responsive rule the collapse boundary (≈0.86–1.46) overlaps oscillation, which
> extends above it to roughly 1.8,
> concentrated at high κ_Q, before growth is reliably sustained. Inside the
> band the rule decides: the fixed-capacity rule, whose budget is frozen at
> early revenue, overshoots and declines throughout, stalling at 1.1M riders
> with the backlog nearly quintupling and quality eroding to 0.78 at the
> 64-run high-funding point, while the backlog-responsive and
> reserve-capacity rules grow installed capacity with the workload, hold
> quality at 0.95, and reach the calibrated ridership equilibrium. Ranked by
> pre-registered mean complaint exposure per rider, the order reserve >
> responsive > fixed holds in 14 of 16 scenario–configuration cells (2 ties)
> and in 70 of the 80 decisive Latin-hypercube draws of 200 (88%; reserve
> ranks first in 95%) — a second 200-draw batch (seed 682) replicates this,
> with 70 of 78 decisive draws in strict order (90%) and reserve first in
> 74 (95%) — and is unchanged across β ∈ {0, 0.5, 1} at adequate
> funding except two β=0 cells where fixed and responsive tie under 2%. The
> reserve rule's edge costs more ($187M vs $176M cumulative, +6% for 17%
> lower exposure) and leaves funds nearly exhausted, while the responsive
> rule retains a $1.5M buffer — the edge cannot be separated from spending
> without a spend-matched run. Development delay (3 vs 12 months) shifts
> magnitudes and one pattern label but changes no ranking.

## Caveats for the paper

- Parameters are TLC-anchored where observable, band-midpoint assumed elsewhere
  (see CALIBRATION.md); conclusions rest on the comparison holding across the
  Table 1 bands (tested: §6), not on point estimates.
- The 120-month diagnostic (T9) confirms the β=1 structure does not collapse;
  the paper reports the 60-month horizon.
- f = 0.5 (growth-from-below) is a design choice documented in the equations
  file; runs start below equilibrium so growth is observable per Objective 3.
- The revenue-cut reference beats all three rules on exposure in the two
  low-funding s_D=0, s_E=1 cells (1.185 vs 1.223–1.226) because its operating
  cost is not charged to funds — it is an R1-attribution device, not a
  policy comparator.
- The draft Section 8 paragraph above is AI-drafted text for graded work;
  confirm the instructor's AI-use approval covers results prose.
- The paper is currently written as planned/future work throughout; adding
  results requires converting the framing, per the course template.

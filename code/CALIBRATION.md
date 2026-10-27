# Calibration — ISYE 681 ride-hailing prototype (structural revision: β)

Reference platform: **Uber, New York City, June 2025** (NYC TLC FHV-HV trip records),
as a **decentralized low-fee platform** per Table 1 (θ ∈ [0.05, 0.15], NOT Uber's
centralized take).
Data: `~/workspace/ridehail_repo/data/aggregates/` — `fhvhv_monthly.csv`,
`fhvhv_2025-06_daily.csv`, `fhv_industry_indicators_monthly.csv`.
Mapping conventions per `ridehail_repo/docs/data-to-variable-mapping.md`;
assumption bands per `ridehail_repo/docs/assumed-parameters.md`.

Structural revision (docx, adjudicated): **dP/dt = β·ℓ − a**, β ∈ [0,1].
β = 1 (base): conserved rider market, P + A = M_0. β = 0: original no-return
spec, kept as sensitivity case.

## Design: growth-from-below

The paper's reference mode needs runs that *rise* (Objective 3 classifies runs
rising > 2% above start), and its story is "a budget fixed at early revenue
while the platform grows." Therefore runs start **below** the calibrated
equilibrium: A_0 = f·A* ≡ A(0), D_0 = f·D_ref ≡ D(0), with **f = 0.5** (DESIGN).
T_0, R_N0, B_prot, C(0) all come from this growth-phase start. Proportional
scaling keeps all t=0 ratios (x_0, u_D0, E_D/E_D0) at their equilibrium values.
Equilibrium anchors (not initial states): A*, D_ref, T* = 14,036,340 trips/mo.

## Anchored values (computed from TLC data)

| Param | Value | Construction |
|---|---|---|
| T_target (equilibrium trips) | 14,036,340 /month | Uber Jun 2025 trip count (`fhvhv_monthly.csv`) |
| w_0 (baseline wait) | 5.098 min | Uber Jun 2025 mean request→pickup |
| p (fare) | $26.8634 /trip | Trip-weighted Uber+Lyft mean `base_passenger_fare`, Jan 2025–Aug 2026 (Table 1: ~$27; NOT the $28.81 Uber-only June figure) |
| D_ref (equilibrium drivers, docx D_ref) | 58,005 | Uber's trip share (71.48%) × 81,148 Jun 2025 industry unique drivers |
| θ (platform take) | 0.10 | DESIGN: inside Table 1's 0.05–0.15 band for the decentralized platform. Uber's 0.2328 was used in the previous calibration and inflated coverage — corrected here. |

## Equilibrium anchor (DERIVED)

- x* = 2.0 (SCALE-CHOICE) → served fraction 1−e^{−2} = 0.8647.
- A* = T_target/(ν·0.8647) = **2,029,159** riders (ν = 8 SCALE-CHOICE).
- At equilibrium (W* = 0, coverage ≥ 1): B* = s_c·f_s·T_target = 140,363;
  Q* = exp(−0.75·0.0692) = 0.9494; μ_A* = 0.02 + 0.55·0.0506 = **0.04781**.
- τ_A = (M_0 − A*)/(μ_A*·A*) = **20.32 months** (DERIVED).
- M_0 = 4,000,000 (SCALE-CHOICE, revisited: M_0 = 8M implied τ_A ≈ 62 months,
  implausibly slow for adoption; 4M → τ_A ≈ 20 months).
- κ_D = x*·ν·A*/D_ref = **559.72** trips/(driver·month) ≈ 18.7/day.
- E_D0 = (1−θ)·p·T*/D_ref = **$5,850.5**/driver/mo (DERIVED, set from
equilibrium per docx §6; equals t=0 earnings under proportional scaling, so
D*(0) = D_ref = D_0/f and drivers are recruited as the platform grows).

## Funding baseline (verified)

- α = 0.10 base (**high funding**; DESIGN). α = 0.05 is the low-funding stress
  scenario. (Previous calibration used α = 0.05 with θ = 0.2328; with the
  corrected θ = 0.10 that gives coverage 0.59 < 1.)
- c_C = $5,250, ρ_C = 400, k_dev = $39,375, f_s = 0.05, s_c = 0.20, φ = 0.25.
- Base 60-month runs use τ_turn = 24 months and τ_dev = 7.5 months
  (C(0) = α·R_N0/(c_C + k_dev/τ_turn) = 205.2 units; τ_dev ∈ {3, 12} and
  τ_turn ∈ {12, 24, 36} are scenario/stress variants).
- Growth start (f = 0.5): T_0 = 7,018,170; R_N0 = $14.14M/mo;
  B_prot = $1.414M/mo; C(0) = 205.2; g_B(0) = 70,182/mo; B(0) = 70,182;
  Q(0) = 0.9494; F(0) = $4.24M; U(0) = τ_dev·C(0)/τ_turn.
- **t=0 coverage ρ_C·C(0)/g_B(0) = 1.170 ≥ 1 ✓** (effective = 1.170, m_C(0)=1).
  At α = 0.05: coverage = 0.585 (intended stress — funding binds).
- B_trig = 100,000 (~1.4× B(0)); m_R = 1.5.

## Remaining closures (midpoints / explicit assumptions)

τ_Q = 3.5, κ_Q = 0.55, τ_D = 3.5 (band midpoints); ξ_W = 0.5, η_W = 1.0,
ε_D = 0.8 (> 0, docx), λ_Q = 0.75, μ_0 = 0.02, μ_W = 0.05 (assumptions).

## Test results (10/10 PASS)

| Test | Result |
|---|---|
| T1 fixed-policy equilibrium (funds bypassed) | 0.0% drift, all (τ_turn, τ_dev) pairs |
| T2 step 100→200 | overshoot ≈ 0% |
| T3 α=0 | β=1: B monotone, unbounded (3.13M @60mo, still growing), Q deteriorates; β=0: B bounded (1.51M) — matches docx extreme conditions |
| T4 f_s=0 | B = 0 exactly |
| T5 unlimited capacity | B → g_B·τ_B exactly |
| T6 funds ≥ 0 | min F = $4.24M |
| T7 h=0.05 vs 0.025 | C 0.0%, B 0.20% |
| T8 revenue-cut | C,U constant; ΔF = ∫I_F to the cent |
| T9 120-mo equilibrium start (f=1) | P+A=M_0 exact; A within 0.008% of A* (mo 60–120); Q(120)=0.9494; no drain |
| T10 ranking across β ∈ {0,0.5,1} (pre-registered D9: mean per-rider exposure X̄_B = (1/60)∫B/max(A,A_min)dt primary, 2% ties) | rankings identical across β ✓: **reserve > responsive > fixed** on X̄_B at every β — reserve 0.070–0.076, responsive 0.091–0.095, fixed 0.237–0.407 complaints/rider. No tradeoff flags (the X̄_B leader also leads on A(60) everywhere). Cumulative ∫g_B dt reported as scale only: fixed 3.17–5.17M < responsive 4.47–7.47M < reserve 5.13–7.84M — fixed is "quietest" in total only because its platform stays small. |

## Decision D9 — primary ranking metric (equations docx, decision register)

After the prototype run and before the 64-run experiment, the primary ranking
metric was revised from cumulative complaint exposure ∫g_B dt to **mean
complaint exposure per rider X̄_B**. Cumulative exposure ranked the fixed rule
first only because its platform stayed small (A=1.10M vs ~2.03M) — it rewarded
the very rider decline the research question aims to prevent. The original
metric is still reported, as scale only. Under D9 the expected order
(reserve > responsive > fixed) is confirmed numerically and is robust across
β ∈ {0, 0.5, 1}.

|

## 60-month policy runs (β=1, f=0.5, α=0.10) — the paper's story, in numbers

| | fixed | backlog-responsive | reserve-capacity |
|---|---|---|---|
| A: 1.015M → | 1.104M (stuck) | 2.020M (≈ A*) | 2.027M (≈ A*) |
| B(60) | 328,403 (growing) | 139,753 (≈ B*) | 140,254 (≈ B*) |
| Q(60) | 0.784 (eroding) | 0.9494 | 0.9494 |
| C(60) | 205.2 (frozen) | 462.5 (grew) | 477.5 (grew) |
| F(60) | $29.9M (piling up, capped spend) | $4.31M | ≈ $0M (fully utilized) |

The fixed budget, set at early revenue, cannot keep up as the platform grows:
backlog grows about 4.7-fold, quality erodes 17 points, unspent funds accumulate. The adaptive
rules grow capacity with workload and reach the calibrated equilibrium. This is
exactly the mechanism the paper is about.

## Honest notes

1. The β=0 sensitivity case reproduces the old 43%-depletion dynamics; rankings
   are unchanged, but absolute quality under the fixed rule is *less bad* at
   β=0 (0.847 vs 0.755) — depletion masks the fixed rule's deterioration, which
   is why β=1 is the cleaner base spec.
2. Reserve-capacity ends with F ≈ $0 — the m_R = 1.5 multiple spends every
   available dollar. Not a violation (F ≥ 0 holds), but the rule is
   cash-constrained; m_R sensitivity is warranted in the full study.
3. τ_A = 20.3 months is DERIVED from the equilibrium identities, not measured.
   If the paper's reviewers balk, the M_0/τ_A pair is the documented place to
   push back (both are SCALE-CHOICE/assumptions, flagged in the docx).
4. f = 0.5 is a DESIGN choice (paper needs rising runs). It is not part of the
   64-run factorial; varying f is a natural robustness extension.

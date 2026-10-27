# =====================================================================
# lhs_sensitivity.jl -- Objective 3 global sensitivity (reviewer requirement).
#
# Latin hypercube over the 12 banded Table 1 parameters (docx Table 1):
#   f_s 0.01-0.10 | s_c 0.05-0.40 | rho_C 200-600 | c_C 3500-7000 |
#   tau_turn 12-36 | tau_Q 1-6 | tau_dev 3-12 | kappa_Q 0.1-1.0 |
#   alpha 0.01-0.10 | theta 0.05-0.15 | phi 0.10-0.40 | tau_D 1-6
# B_trig and m_R are policy levers (fixed at base). p ~= 27 fixed.
# Closure/anchored params fixed (w_0, nu, x_star, M_0, D_ref, lambda_Q,
# mu_0, mu_W, xi_W, eta_W, eps_D); tau_A re-derived per draw from the
# equilibrium identities (CALIBRATION.md procedure).
#
# Per draw: 3 rules, intact switches (s_D=s_E=1), beta=1, 60 months.
# Records D9 ranking, Objective 3 pattern per rule, t=0 coverage.
# LHS implemented by hand: stratified uniform per dimension + random
# permutation. No external packages.
#
# Run: ~/julia-1.11.7/bin/julia lhs_sensitivity.jl
# Writes: lhs_sensitivity.csv
# =====================================================================
include("model.jl")
using Printf, Random

const H = 0.05
const T_END = 60.0
const N_DRAWS = 200

# (name, lo, hi) for the 12 sampled dimensions, in default_params order
const DIMS = [
    (:f_s,      0.01, 0.10),
    (:s_c,      0.05, 0.40),
    (:rho_C,    200.0, 600.0),
    (:c_C,      3500.0, 7000.0),
    (:tau_turn, 12.0, 36.0),
    (:tau_Q,    1.0, 6.0),
    (:tau_dev,  3.0, 12.0),
    (:kappa_Q,  0.1, 1.0),
    (:alpha,    0.01, 0.10),
    (:theta,    0.05, 0.15),
    (:phi,      0.10, 0.40),
    (:tau_D,    1.0, 6.0),
]

# Hand-rolled LHS: N stratified samples per dim, independently permuted.
function lhs_sample(N, dims; seed=681)
    rng = MersenneTwister(seed)
    d = length(dims)
    U = zeros(N, d)
    for j in 1:d
        strata = rand(rng, N) ./ N .+ (0:N-1) ./ N   # one uniform per stratum
        U[:, j] = strata[randperm(rng, N)]            # random permutation
    end
    X = zeros(N, d)
    for j in 1:d
        lo, hi = dims[j][2], dims[j][3]
        X[:, j] = lo .+ (hi - lo) .* U[:, j]
    end
    return X
end

# Objective 3 pattern classification (same as experiment.jl).
function classify_pattern(A, A0)
    m = A[1:20:length(A)]
    if maximum(m) <= 1.02 * A0
        return "non-growing"
    end
    # candidate peaks: local maxima with a >=10% fall afterwards
    cand = Int[]
    for i in 2:length(m)-1
        if m[i] >= m[i-1] && m[i] >= m[i+1]
            if minimum(m[i:end]) <= 0.90 * m[i]
                push!(cand, i)
            end
        end
    end
    # qualify: a peak counts as separate only if the rise above the
    # intervening trough is >= 10% (pre-set Objective 3 rule); two or
    # more qualifying peaks = "recurrent fluctuations"
    peaks = Int[]
    for pk in cand
        if isempty(peaks)
            push!(peaks, pk)
        else
            trough = minimum(m[peaks[end]:pk])
            if trough > 0 && m[pk] >= 1.10 * trough
                push!(peaks, pk)
            end
        end
    end
    if isempty(peaks)
        return m[end] > A0 ? "sustained growth" : "overshoot and decline"
    elseif length(peaks) >= 2
        return "recurrent fluctuations"
    else
        pk = m[peaks[1]]
        trough = minimum(m[peaks[1]:end])
        return m[end] >= trough + 0.5 * (pk - trough) ? "recovery after a dip" : "overshoot and decline"
    end
end

function rank_rules(xbar_B, mean_q; tol=0.02)
    order = collect(1:length(xbar_B))
    # D9 has no tie-break. Sort STRICTLY by Xbar_B (ascending,
    # deterministic); the 2% tolerance defines ties for reporting
    # (tie flags), never for ordering.
    sort!(order, by=i -> xbar_B[i])
    return order
end

# Re-derive tau_A per draw from the equilibrium identities
# (CALIBRATION.md): A* anchored to T_star; mu_A* from the draw's
# kappa_Q, s_c, f_s; closure lambda_Q, mu_0 fixed.
function derive_tau_A(M_0, T_star, nu, x_star, lambda_Q, mu_0, s_c, f_s, kappa_Q)
    served = 1 - exp(-x_star)
    A_star = T_star / (nu * served)
    Q_star = exp(-lambda_Q * s_c * f_s * T_star / A_star)
    mu_A_star = mu_0 + kappa_Q * (1 - Q_star)
    return (M_0 - A_star) / (mu_A_star * A_star)
end

function run_rule(p, rule)
    r = run!(p; rule=rule, s_R=1, s_D=1, s_E=1,
             h=H, T_end=T_END, record=true)
    A = r.rec[:A]; B = r.rec[:B]; Q = r.rec[:Q]; F = r.rec[:F]
    xbar = sum(B ./ max.(A, p.A_min)) * H / T_END
    bad = any(v -> v < -1e-9, (minimum(r.rec[:P]), minimum(A),
             minimum(r.rec[:D]), minimum(B), minimum(r.rec[:C]),
             minimum(r.rec[:U]), minimum(F))) ||
          any(x -> !isfinite(x), A) || any(x -> !isfinite(x), B) ||
          any(x -> !isfinite(x), F) || maximum(A) > 10 * p.M_0 ||
          maximum(B) > 1e12
    return (xbar=xbar, mean_Q=sum(Q)/length(Q), A60=A[end],
            pattern=classify_pattern(A, r.derived.A_0),
            coverage=p.rho_C * r.derived.C0 / (p.s_c * p.f_s * r.derived.T_0),
            bad=bad)
end

function main()
    t_start = time()
    X = lhs_sample(N_DRAWS, DIMS)
    names = [string(d[1]) for d in DIMS]
    header = vcat(["draw"], names,
                  ["coverage0", "rank1", "rank2", "rank3", "tie",
                   "pat_fixed", "pat_responsive", "pat_reserve",
                   "bad_draw"])
    rows = String[join(header, ",")]
    rules = [:fixed, :responsive, :reserve]
    nfail = 0
    for i in 1:N_DRAWS
        kw = Dict{Symbol,Float64}()
        for (j, d) in enumerate(DIMS)
            kw[d[1]] = X[i, j]
        end
        tau_A = derive_tau_A(4_000_000.0, 14_036_340.0, 8.0, 2.0,
                             0.75, 0.02, kw[:s_c], kw[:f_s], kw[:kappa_Q])
        p = merge(default_params(; tau_turn=kw[:tau_turn], tau_dev=kw[:tau_dev],
                                  alpha=kw[:alpha], f_s=kw[:f_s], beta=1.0, f=0.5),
                  (s_c=kw[:s_c], rho_C=kw[:rho_C], c_C=kw[:c_C],
                   tau_Q=kw[:tau_Q], kappa_Q=kw[:kappa_Q], theta=kw[:theta],
                   phi=kw[:phi], tau_D=kw[:tau_D], tau_A=tau_A))
        ms = [run_rule(p, r) for r in rules]
        bad = any(m.bad for m in ms)
        if bad
            nfail += 1
        end
        xs = [m.xbar for m in ms]; qs = [m.mean_Q for m in ms]
        ord = rank_rules(xs, qs)
        tie = abs(xs[ord[1]] - xs[ord[2]]) /
              max(abs(xs[ord[1]]), abs(xs[ord[2]]), 1e-12) < 0.02
        vals = Any[i, [round(X[i, j], digits=5) for j in 1:length(DIMS)]...,
                   round(ms[1].coverage, digits=4),
                   rules[ord[1]], rules[ord[2]], rules[ord[3]], tie,
                   ms[1].pattern, ms[2].pattern, ms[3].pattern, bad]
        push!(rows, join(string.(vals), ","))
        if i % 50 == 0
            println("  $i / $N_DRAWS draws ($(round(time()-t_start, digits=1))s)")
        end
    end
    open("lhs_sensitivity.csv", "w") do io
        for r in rows; println(io, r); end
    end
    println("wrote lhs_sensitivity.csv ($N_DRAWS draws, $nfail failed draws, " *
            "$(round(time()-t_start, digits=1))s total)")
end

main()

# =====================================================================
# experiment.jl -- The full 64-run ISYE 681 experiment.
#
# SOURCE OF TRUTH: ConsolidatedEquations.docx, Section 5:
#   (4 intact-revenue configurations x 3 rules
#    + 4 revenue-cut configurations x 1 reference) x 4 scenarios = 64
# Scenarios: alpha in {0.05, 0.10} x tau_dev in {3, 12} months.
# Configurations: (s_D, s_E) in {(1,1),(1,0),(0,1),(0,0)}.
# Ranking: docx Section 5 / decision D9 -- mean complaint exposure per
# rider Xbar_B primary, 2% tie tolerance (ties reported as ties),
# realized spending reported alongside; cumulative g_B scale-only.
# Objective 3 pattern rules applied to recorded active riders A(t).
#
# Run: ~/julia-1.11.7/bin/julia experiment.jl
# Writes: results_64.csv, and prints the summary used for RESULTS_64.md
# =====================================================================
include("model.jl")
using Dates, Printf

const H = 0.05
const T_END = 60.0

struct RunSpec
    scenario::String
    alpha::Float64
    tau_dev::Float64
    s_D::Int
    s_E::Int
    s_R::Int
    rule::Symbol   # :fixed/:responsive/:reserve, or :reference (s_R=0)
end

function build_specs()
    specs = RunSpec[]
    for (alpha, al) in ((0.05, "a05"), (0.10, "a10"))
        for (tau_dev, dl) in ((3.0, "d3"), (12.0, "d12"))
            scen = "$(al)_$(dl)"
            for (s_D, s_E) in ((1,1), (1,0), (0,1), (0,0))
                for rule in (:fixed, :responsive, :reserve)
                    push!(specs, RunSpec(scen, alpha, tau_dev, s_D, s_E, 1, rule))
                end
                push!(specs, RunSpec(scen, alpha, tau_dev, s_D, s_E, 0, :reference))
            end
        end
    end
    return specs
end

# Pre-registered ranking (docx D9): lower Xbar_B wins; differences under
# 2% (relative) count as tied. No tie-break: rank_groups returns groups of
# tied rule indices, best group first. A rule joins the current group if it
# is within tol of the group leader.
function rank_groups(xbar_B; tol=0.02)
    order = sortperm(xbar_B)  # ascending, deterministic
    groups = Vector{Vector{Int}}()
    for idx in order
        if !isempty(groups)
            lead = groups[end][1]
            denom = max(abs(xbar_B[idx]), abs(xbar_B[lead]), 1e-12)
            if abs(xbar_B[idx] - xbar_B[lead]) / denom < tol
                push!(groups[end], idx)
                continue
            end
        end
        push!(groups, [idx])
    end
    return groups
end

# Objective 3 pattern classification on monthly-sampled active riders.
# Peak = local max after which riders fall >= 10% below the peak;
# a peak is separate only if the rise above the intervening trough is
# >= 10% (pre-set Objective 3 rule). Only runs rising > 2% above start
# are classified; rest = non-growing.
function classify_pattern(A, A0)
    m = A[1:20:length(A)]  # monthly at h = 0.05
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

function run_metrics(spec)
    p = default_params(alpha=spec.alpha, tau_dev=spec.tau_dev, beta=1.0)
    r = run!(p; rule=(spec.rule == :reference ? :fixed : spec.rule),
             s_R=spec.s_R, s_D=spec.s_D, s_E=spec.s_E,
             h=H, T_end=T_END, record=true, track_minF=true)
    rec = r.rec
    A = rec[:A]; B = rec[:B]; Q = rec[:Q]; F = rec[:F]
    n = length(A)
    xbar_B = sum(B ./ max.(A, p.A_min)) * H / T_END
    mean_Q = sum(Q) / n
    A60 = A[end]; B60 = B[end]; Q60 = Q[end]
    cum_gB = sum(rec[:g_B]) * H
    spend = (sum(rec[:O_C]) + sum(rec[:I_C])) * H
    # numerical-suspicion flags
    mins = Dict(k => minimum(rec[k]) for k in (:P,:A,:D,:B,:C,:U,:F))
    neg = any(v < -1e-9 for v in values(mins))
    nonfinite = any(x -> !isfinite(x), A) || any(x -> !isfinite(x), B) ||
                any(x -> !isfinite(x), F) || any(x -> !isfinite(x), Q)
    explosion = maximum(A) > 10 * p.M_0 || maximum(B) > 1e12
    Qrange = minimum(Q) >= 0.0 && maximum(Q) <= 1.0
    pattern = classify_pattern(A, r.derived.A_0)
    return (xbar_B=xbar_B, mean_Q=mean_Q, A60=A60, B60=B60, Q60=Q60,
            cum_gB=cum_gB, spend=spend, minF=r.minF, F60=F[end],
            pattern=pattern, neg=neg, nonfinite=nonfinite,
            explosion=explosion, Qrange=Qrange, A0=r.derived.A_0,
            C0=r.derived.C0, coverage=p.rho_C * r.derived.C0 /
                     (p.s_c * p.f_s * r.derived.T_0))
end

function main()
    println("ISYE 681 64-run experiment -- $(now())\n")
    specs = build_specs()
    @assert length(specs) == 64 "run count = $(length(specs)), expected 64"
    println("Run count verified: 64\n")

    # CSV header
    header = ["scenario","alpha","tau_dev","s_D","s_E","s_R","rule",
              "Xbar_B","mean_Q","A60","B60","Q60","cum_gB","spend_USD",
              "minF_USD","F60_USD","A0","C0","coverage0","pattern",
              "neg","nonfinite","explosion","Qrange"]
    rows = String[]
    push!(rows, join(header, ","))

    results = Dict{Tuple{String,Int,Int,Int,Symbol},Any}()
    for (i, spec) in enumerate(specs)
        m = run_metrics(spec)
        key = (spec.scenario, spec.s_D, spec.s_E, spec.s_R, spec.rule)
        results[key] = m
        vals = [spec.scenario, spec.alpha, spec.tau_dev, spec.s_D, spec.s_E,
                spec.s_R, string(spec.rule), m.xbar_B, m.mean_Q, m.A60,
                m.B60, m.Q60, m.cum_gB, m.spend, m.minF, m.F60, m.A0, m.C0,
                m.coverage, m.pattern, m.neg, m.nonfinite, m.explosion,
                m.Qrange]
        push!(rows, join(string.(vals), ","))
        if i % 16 == 0
            println("  completed $i / 64 runs")
        end
    end
    open("results_64.csv", "w") do io
        for r in rows
            println(io, r)
        end
    end
    println("\nwrote results_64.csv\n")

    rules = [:fixed, :responsive, :reserve]
    scenarios = ["a05_d3", "a05_d12", "a10_d3", "a10_d12"]
    cells = [(1,1), (1,0), (0,1), (0,0)]

    println("=== D9 RANKINGS (full-feedback runs, Xbar_B primary, 2% ties) ===")
    for scen in scenarios
        for (s_D, s_E) in cells
            xs = Float64[]; qs = Float64[]
            for rule in rules
                m = results[(scen, s_D, s_E, 1, rule)]
                push!(xs, m.xbar_B); push!(qs, m.mean_Q)
            end
            groups = rank_groups(xs)
            tag = (s_D == 1 && s_E == 1) ? " [headline cell]" : ""
            println("scenario=$scen s_D=$s_D s_E=$s_E$tag")
            for (gpos, g) in enumerate(groups)
                tie = length(g) > 1 ? " (tied)" : ""
                for idx in g
                    m = results[(scen, s_D, s_E, 1, rules[idx])]
                    @printf("  %d. %-10s Xbar_B=%.4f  meanQ=%.4f  A60=%.4g  spend=\$%.3g  cum_gB=%.3g%s\n",
                            gpos, rules[idx], m.xbar_B, m.mean_Q, m.A60,
                            m.spend, m.cum_gB, tie)
                end
            end
            # tradeoff flags (docx D9): any pairwise case where a rule in a
            # better group leads on Xbar_B but trails >2% on A(60)
            for a_g in 1:length(groups), b_g in (a_g+1):length(groups)
                for ia in groups[a_g], ib in groups[b_g]
                    ma = results[(scen, s_D, s_E, 1, rules[ia])]
                    mb = results[(scen, s_D, s_E, 1, rules[ib])]
                    if ma.A60 < 0.98 * mb.A60
                        println("  TRADEOFF FLAG: $(rules[ia]) leads $(rules[ib]) " *
                                "on Xbar_B but trails >2% on A(60)")
                    end
                end
            end
        end
    end

    println("\n=== PATTERN CLASSIFICATION (Objective 3 rules) ===")
    for scen in scenarios
        println("scenario=$scen")
        for (s_D, s_E) in cells
            for rule in [:fixed, :responsive, :reserve, :reference]
                s_R = rule == :reference ? 0 : 1
                m = results[(scen, s_D, s_E, s_R, rule)]
                println("  s_D=$s_D s_E=$s_E s_R=$s_R $(rpad(rule,10)): " *
                        "$(m.pattern)")
            end
        end
    end

    println("\n=== NUMERICAL SUSPICION FLAGS ===")
    nflag = 0
    for (i, spec) in enumerate(specs)
        key = (spec.scenario, spec.s_D, spec.s_E, spec.s_R, spec.rule)
        m = results[key]
        if m.neg || m.nonfinite || m.explosion || !m.Qrange
            nflag += 1
            println("  run $i $(spec.scenario) s_D=$(spec.s_D) s_E=$(spec.s_E) " *
                    "s_R=$(spec.s_R) $(spec.rule): neg=$(m.neg) " *
                    "nonfinite=$(m.nonfinite) explosion=$(m.explosion) " *
                    "Qrange=$(m.Qrange)")
        end
    end
    println(nflag == 0 ? "  none -- all 64 runs numerically clean" :
            "  $nflag runs flagged")

    println("\n=== COVERAGE AT t=0 (per scenario) ===")
    for scen in scenarios
        m = results[(scen, 1, 1, 1, :fixed)]
        println("  $scen: coverage=$(round(m.coverage, digits=3))")
    end
end

main()

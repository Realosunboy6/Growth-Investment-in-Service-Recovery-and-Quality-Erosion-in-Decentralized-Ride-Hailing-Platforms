# =====================================================================
# sweep_beta.jl -- Run the 16 full-feedback cells (4 scenarios x 4 switch
# configs x 3 rules = 48 runs) at beta = 0 and beta = 0.5, applying the
# D9 ranking per cell. Tests whether the T10 headline-cell robustness
# (rankings unchanged across beta) holds across all cells.
#
# Run: ~/julia-1.11.7/bin/julia sweep_beta.jl
# Writes: beta_sweep.csv
# =====================================================================
include("model.jl")
using Printf

const H = 0.05
const T_END = 60.0

# D9 ranking (same as experiment.jl/tests.jl): lower Xbar_B wins;
# ties within 2% (relative); no tie-break per D9.
function rank_rules(xbar_B, mean_q; tol=0.02)
    order = collect(1:length(xbar_B))
    # D9 has no tie-break. Sort STRICTLY by Xbar_B (ascending,
    # deterministic); the 2% tolerance defines ties for reporting
    # (tie flags), never for ordering.
    sort!(order, by=i -> xbar_B[i])
    return order
end

function cell_metrics(alpha, tau_dev, s_D, s_E, beta)
    p = default_params(alpha=alpha, tau_dev=tau_dev, beta=beta)
    out = Dict{Symbol,Any}()
    for rule in (:fixed, :responsive, :reserve)
        r = run!(p; rule=rule, s_R=1, s_D=s_D, s_E=s_E,
                 h=H, T_end=T_END, record=true)
        A = r.rec[:A]; B = r.rec[:B]; Q = r.rec[:Q]
        xbar = sum(B ./ max.(A, p.A_min)) * H / T_END
        out[rule] = (xbar=xbar, mean_Q=sum(Q)/length(Q), A60=A[end])
    end
    return out
end

function main()
    rows = String[]
    push!(rows, "scenario,alpha,tau_dev,s_D,s_E,beta,rank1,rank2,rank3,tie12,tie23")
    scenarios = [(0.05, "a05"), (0.10, "a10")]
    devs = [(3.0, "d3"), (12.0, "d12")]
    cells = [(1,1), (1,0), (0,1), (0,0)]
    rules = [:fixed, :responsive, :reserve]
    n = 0
    for beta in (0.0, 0.5)
        for (alpha, al) in scenarios, (td, dl) in devs, (sd, se) in cells
            m = cell_metrics(alpha, td, sd, se, beta)
            xs = [m[r].xbar for r in rules]
            qs = [m[r].mean_Q for r in rules]
            ord = rank_rules(xs, qs)
            # tie detection: relative gap < 2%
            function gap(i, j)
                abs(xs[i] - xs[j]) / max(abs(xs[i]), abs(xs[j]), 1e-12)
            end
            t12 = gap(ord[1], ord[2]) < 0.02
            t23 = gap(ord[2], ord[3]) < 0.02
            push!(rows, join([al*"_"*dl, alpha, td, sd, se, beta,
                              rules[ord[1]], rules[ord[2]], rules[ord[3]],
                              t12, t23], ","))
            n += 1
        end
        println("  beta=$beta done")
    end
    open("beta_sweep.csv", "w") do io
        for r in rows; println(io, r); end
    end
    println("wrote beta_sweep.csv ($n runs)")
end

main()

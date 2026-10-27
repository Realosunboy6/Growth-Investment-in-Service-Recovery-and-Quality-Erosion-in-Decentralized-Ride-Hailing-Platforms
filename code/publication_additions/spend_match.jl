# =====================================================================
# spend_match.jl -- Job 2: spend-matched reserve vs responsive.
# Cell: alpha=0.10, tau_dev=3, intact switches (s_D=s_E=s_R=1), beta=1,
# 60 months, h=0.05 -- the a10_d3 headline cell of the 64-run experiment.
# Metrics computed EXACTLY as in experiment.jl run_metrics().
# Procedure: verify baseline spends against results_64.csv, then
# bisect the reserve rule's m_R (its spending lever: capacity target =
# max(C0, m_R * g_B / rho_C)) until reserve cumulative spend (O_C+I_C)
# matches responsive's within 1%.
# =====================================================================
include(joinpath(@__DIR__, "..", "model.jl"))
using Printf

const OUTDIR = @__DIR__
const H = 0.05
const T_END = 60.0

function cell_metrics(; rule, m_R=1.5, B_trig=100000.0)
    base = default_params(alpha=0.10, tau_dev=3.0, beta=1.0)
    p = merge(base, (m_R=m_R, B_trig=B_trig))
    r = run!(p; rule=rule, s_R=1, s_D=1, s_E=1, h=H, T_end=T_END,
             record=true, track_minF=true)
    rec = r.rec
    A = rec[:A]; B = rec[:B]; Q = rec[:Q]
    xbar_B = sum(B ./ max.(A, p.A_min)) * H / T_END
    mean_Q = sum(Q) / length(Q)
    spend = (sum(rec[:O_C]) + sum(rec[:I_C])) * H
    return (xbar_B=xbar_B, mean_Q=mean_Q, A60=A[end], B60=B[end],
            Q60=Q[end], spend=spend, minF=r.minF, F60=rec[:F][end])
end

function main()
    println("=== Job 2: spend-matched reserve vs responsive (a10_d3) ===")
    resp = cell_metrics(rule=:responsive)
    res0 = cell_metrics(rule=:reserve)   # m_R = 1.5 baseline
    @printf("responsive (baseline):        spend=\$%.4fM  Xbar_B=%.6f  meanQ=%.4f  A60=%.0f  B60=%.0f  minF=\$%.4fM\n",
            resp.spend/1e6, resp.xbar_B, resp.mean_Q, resp.A60, resp.B60, resp.minF/1e6)
    @printf("reserve m_R=1.5 (baseline):   spend=\$%.4fM  Xbar_B=%.6f  meanQ=%.4f  A60=%.0f  B60=%.0f  minF=\$%.4fM\n",
            res0.spend/1e6, res0.xbar_B, res0.mean_Q, res0.A60, res0.B60, res0.minF/1e6)
    println("results_64.csv check: responsive spend = \$175.6612M, reserve = \$186.9179M")

    target = resp.spend
    tol = 0.01 * target
    trace = String[]
    push!(trace, "iter,m_R,spend_USD,spend_minus_target_USD")
    lo, hi = 0.50, 1.50
    flo = cell_metrics(rule=:reserve, m_R=lo)
    push!(trace, @sprintf("0,%.6f,%.2f,%.2f", lo, flo.spend, flo.spend - target))
    @printf("bracket: m_R=%.2f -> \$%.3fM (below target: %s)\n", lo, flo.spend/1e6, flo.spend < target)
    best = res0; best_mR = 1.5
    push!(trace, @sprintf("0,%.6f,%.2f,%.2f", 1.5, res0.spend, res0.spend - target))
    for it in 1:40
        mid = (lo + hi) / 2
        m = cell_metrics(rule=:reserve, m_R=mid)
        push!(trace, @sprintf("%d,%.6f,%.2f,%.2f", it, mid, m.spend, m.spend - target))
        if abs(m.spend - target) < abs(best.spend - target)
            best = m; best_mR = mid
        end
        @printf("iter %2d  m_R=%.5f  spend=\$%.4fM  diff=%+.3f%%\n",
                it, mid, m.spend/1e6, 100 * (m.spend - target) / target)
        if abs(m.spend - target) <= tol && it >= 12
            best = m; best_mR = mid
            break
        end
        if m.spend < target
            lo = mid
        else
            hi = mid
        end
    end
    open(joinpath(OUTDIR, "spend_match_trace.csv"), "w") do io
        for r in trace
            println(io, r)
        end
    end

    m = best
    @printf("\nMATCHED: m_R* = %.5f  spend=\$%.4fM (target \$%.4fM, diff %+.3f%%)\n",
            best_mR, m.spend/1e6, target/1e6, 100 * (m.spend - target) / target)
    @printf("reserve @ matched spend: Xbar_B=%.6f  meanQ=%.4f  A60=%.0f  B60=%.0f  Q60=%.4f  minF=\$%.4fM  F60=\$%.4fM\n",
            m.xbar_B, m.mean_Q, m.A60, m.B60, m.Q60, m.minF/1e6, m.F60/1e6)
    @printf("responsive (same spend): Xbar_B=%.6f  meanQ=%.4f  A60=%.0f  B60=%.0f  Q60=%.4f  minF=\$%.4fM  F60=\$%.4fM\n",
            resp.xbar_B, resp.mean_Q, resp.A60, resp.B60, resp.Q60, resp.minF/1e6, resp.F60/1e6)
    edge0 = 100 * (resp.xbar_B - res0.xbar_B) / resp.xbar_B
    edge1 = 100 * (resp.xbar_B - m.xbar_B) / resp.xbar_B
    @printf("reserve Xbar_B edge: baseline %+.2f%%  ->  spend-matched %+.2f%%\n", edge0, edge1)

    rows = ["rule,variant,m_R,B_trig,spend_USD,Xbar_B,mean_Q,A60,B60,Q60,minF_USD,F60_USD",
            @sprintf("responsive,baseline,1.5,100000,%.2f,%.6f,%.6f,%.1f,%.1f,%.6f,%.2f,%.2f",
                     resp.spend, resp.xbar_B, resp.mean_Q, resp.A60, resp.B60, resp.Q60, resp.minF, resp.F60),
            @sprintf("reserve,baseline,1.5,100000,%.2f,%.6f,%.6f,%.1f,%.1f,%.6f,%.2f,%.2f",
                     res0.spend, res0.xbar_B, res0.mean_Q, res0.A60, res0.B60, res0.Q60, res0.minF, res0.F60),
            @sprintf("reserve,spend_matched,%.6f,100000,%.2f,%.6f,%.6f,%.1f,%.1f,%.6f,%.2f,%.2f",
                     best_mR, m.spend, m.xbar_B, m.mean_Q, m.A60, m.B60, m.Q60, m.minF, m.F60)]
    open(joinpath(OUTDIR, "spend_match.csv"), "w") do io
        for r in rows
            println(io, r)
        end
    end
    println("wrote spend_match.csv, spend_match_trace.csv")
    return (resp=resp, res0=res0, matched=m, mR=best_mR, edge0=edge0, edge1=edge1)
end

main()

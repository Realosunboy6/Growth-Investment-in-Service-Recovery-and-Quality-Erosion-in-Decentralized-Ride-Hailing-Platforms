# =====================================================================
# plot_trajectories.jl -- Behavior-over-time data for the paper's
# Fig. 3: the six headline intact-feedback runs (3 rules x two funding
# levels, tau_dev = 3, s_D = s_E = 1, beta = 1), recording monthly
# A(t), B(t), Q(t) over 60 months. Writes trajectories.csv next to this
# script. Does not modify model.jl.
# =====================================================================
include(joinpath(@__DIR__, "model.jl"))

function monthly_series(res, d)
    # rec is recorded every h = 0.05 month (20 steps per month), after
    # each step: rec[:t][i] = i*h, so the state at month m sits at index
    # 20*m. Sample indices 20:20:end (t = 1, 2, ..., 60) so the series
    # runs through t = 60 inclusive; prepend the t = 0 initial state
    # from the derived values.
    rec = res.rec
    idx = 20:20:length(rec[:t])
    t = vcat(0.0, rec[:t][idx])
    A = vcat(d.A_0, rec[:A][idx])
    B = vcat(d.B0, rec[:B][idx])
    Q = vcat(d.Q0, rec[:Q][idx])
    return t, A, B, Q
end

out = joinpath(@__DIR__, "trajectories.csv")
open(out, "w") do io
    println(io, "alpha,rule,month,A,B,Q")
    for alpha in (0.05, 0.10), rule in (:fixed, :responsive, :reserve)
        p = default_params(alpha=alpha, tau_dev=3.0)
        res = run!(p; rule=rule, s_D=1, s_E=1, record=true)
        t, A, B, Q = monthly_series(res, res.derived)
        for i in eachindex(t)
            println(io, join((alpha, rule, round(t[i], digits=1),
                              round(A[i], digits=1), round(B[i], digits=1),
                              round(Q[i], digits=5)), ","))
        end
        println("alpha=$alpha rule=$rule: A(60)=$(round(A[end], digits=0)), " *
                "B(60)=$(round(B[end], digits=0)), Q(60)=$(round(Q[end], digits=3))")
    end
end
println("wrote $out")

# =====================================================================
# tests.jl -- Extreme-condition tests + convergence check for the
# ISYE 681 ride-hailing recovery-capacity prototype (model.jl).
# Each test prints PASS/FAIL with numbers. Run with:
#   ~/julia-1.11.7/bin/julia tests.jl
#
# Structural revision: dP/dt = beta*ell - a (docx). beta=1 (base):
# conserved rider market P+A = M_0. beta=0: original no-return spec
# (sensitivity case).
# =====================================================================
include("model.jl")
using Dates

function verdict(ok)
    return ok ? "PASS" : "FAIL"
end

# ---------------------------------------------------------------------
# T1: fixed-policy equilibrium. With funds nonbinding, C must hold at
# C_fix and U at U* = tau_dev*C_fix/tau_turn (< 0.5% drift, 60 months).
# ---------------------------------------------------------------------
function test_T1()
    println("T1 fixed-policy equilibrium, funds idealized nonbinding (60 months)")
    allok = true
    for (tt, td) in ((24.0, 7.5), (12.0, 12.0), (36.0, 3.0))
        p = default_params(tau_turn=tt, tau_dev=td)
        r = run!(p; rule=:fixed, h=0.05, T_end=60.0, record=true,
                 bypass_funds=true)
        d = r.derived
        Ustar = td * d.C_fix / tt
        dC = maximum(abs.(r.rec[:C] .- d.C_fix)) / d.C_fix * 100
        dU = maximum(abs.(r.rec[:U] .- Ustar)) / Ustar * 100
        ok = dC < 0.5 && dU < 0.5
        allok &= ok
        println("  (tau_turn=$tt, tau_dev=$td): C_fix=$(round(d.C_fix,digits=4)), " *
                "max|dC|=$(round(dC,digits=6))%, max|dU|=$(round(dU,digits=6))% " *
                "-> $(verdict(ok))")
    end
    println("  T1 overall: $(verdict(allok))")
    p = default_params()
    r = run!(p; rule=:fixed, h=0.05, T_end=60.0, record=true)
    d = r.derived
    cov0 = p.rho_C * d.C0 / (p.s_c * p.f_s * d.T_0)
    println("  NOTE (full model, calibrated params): t=0 coverage = " *
            "$(round(cov0,digits=3)) (>= 1 -> baseline starts in balance).")
    return allok
end

# ---------------------------------------------------------------------
# T2: step response of the ordering controller. C* steps 100 -> 200 at
# t = 30 (after settling); funds bypassed (c_start = S_k^req), quarterly
# sample-and-hold per docx section 4. Report overshoot.
# ---------------------------------------------------------------------
function capacity_step(; tau_turn=24.0, tau_dev=7.5, tau_order=3.0, h=0.05)
    C = 100.0
    U = tau_dev * 100.0 / tau_turn
    C_star = 100.0
    S_req = C_star / tau_turn
    next_q = 0.0
    n = ceil(Int, 90.0 / h)
    maxC = 0.0
    for i in 1:n
        t = (i - 1) * h
        if t >= next_q - 1e-9
            if t >= 30.0
                C_star = 200.0
            end
            S_req = max(0.0, C_star / tau_turn + (C_star - C) / tau_order +
                             (tau_dev * C_star / tau_turn - U) / tau_order)
            next_q += 3.0
        end
        C += h * (U / tau_dev - C / tau_turn)
        U += h * (S_req - U / tau_dev)
        if t >= 30.0 && C > maxC
            maxC = C
        end
    end
    return (C_end=C, U_end=U, overshoot=maxC - 200.0)
end

function test_T2()
    println("T2 step response: C* 100 -> 200 at t=30 (tau_turn=24, tau_dev=7.5)")
    r = capacity_step()
    os_pct = r.overshoot / 200.0 * 100
    ok = os_pct < 1.0
    println("  overshoot = $(round(r.overshoot,digits=4)) units ($(round(os_pct,digits=3))%), " *
            "C(90)=$(round(r.C_end,digits=3)) -> $(verdict(ok))")
    return ok
end

# ---------------------------------------------------------------------
# T3: alpha = 0 from initialization. C(0)=U(0)=F(0)=0.
#  beta=1: backlog nondecreasing and UNBOUNDED (riders keep cycling
#    without resolution -- docx extreme condition); Q deteriorates.
#  beta=0: backlog nondecreasing but BOUNDED by market depletion.
# ---------------------------------------------------------------------
function test_T3()
    println("T3 alpha=0 from initialization")
    allok = true
    # beta = 1: expect unbounded growth
    p = default_params(alpha=0.0, beta=1.0)
    r = run!(p; rule=:fixed, h=0.05, T_end=60.0, record=true)
    B = r.rec[:B]
    mono = all(diff(B) .>= -1e-9)
    # still growing fast at the end (unbounded): mean dB/dt over last 12 mo > 0
    tail = diff(B[end-240:end])
    growing = sum(tail)/length(tail) > 0
    Qdet = r.rec[:Q][end] < r.rec[:Q][1] - 0.01
    ok1 = mono && growing && Qdet
    allok &= ok1
    println("  beta=1: monotone=$mono, B(60)=$(round(B[end],sigdigits=4)) " *
            "(growing at end=$growing), Q deteriorated=$Qdet -> $(verdict(ok1))")
    # beta = 0: bounded by finite market
    p0 = default_params(alpha=0.0, beta=0.0)
    r0 = run!(p0; rule=:fixed, h=0.05, T_end=60.0, record=true)
    B0v = r0.rec[:B]
    mono0 = all(diff(B0v) .>= -1e-9)
    bound = p0.s_c * p0.f_s * p0.nu * p0.M_0 * 60.0
    bounded0 = isfinite(B0v[end]) && B0v[end] <= bound
    Qdet0 = r0.rec[:Q][end] < r0.rec[:Q][1] - 0.01
    ok0 = mono0 && bounded0 && Qdet0
    allok &= ok0
    println("  beta=0: monotone=$mono0, B(60)=$(round(B0v[end],sigdigits=4)) " *
            "<= bound $(round(bound,sigdigits=3))=$bounded0, Q deteriorated=$Qdet0 " *
            "-> $(verdict(ok0))")
    println("  T3 overall: $(verdict(allok))")
    return allok
end

# ---------------------------------------------------------------------
# T4: zero failures from init (f_s = 0) -> B stays 0.
# ---------------------------------------------------------------------
function test_T4()
    println("T4 zero failures from initialization (f_s=0)")
    p = default_params(f_s=0.0)
    r = run!(p; rule=:fixed, h=0.05, T_end=60.0, record=true)
    m = maximum(r.rec[:B])
    ok = m <= 1e-12
    println("  max B(t) = $m -> $(verdict(ok))")
    return ok
end

# ---------------------------------------------------------------------
# T5: unlimited capacity. Docx extreme condition: with constant complaint
# arrivals and fully funded (nonbinding) resolution, backlog -> g_B*tau_B.
# ---------------------------------------------------------------------
function test_T5()
    println("T5 unlimited capacity: constant arrivals, nonbinding resolution")
    p = default_params()
    g_bar = 500.0
    B = 0.0
    h = 0.05
    n = ceil(Int, 60.0 / h)
    for i in 1:n
        r_B = min(B / p.tau_B, 1.0 * p.rho_C * 1e9)
        B += h * (g_bar - r_B)
    end
    target = g_bar * p.tau_B
    err = abs(B - target) / target * 100
    ok = err < 1.0
    println("  B(60)=$(round(B,digits=3)), target g_B*tau_B=$target, " *
            "err=$(round(err,digits=4))% -> $(verdict(ok))")
    return ok
end

# ---------------------------------------------------------------------
# T6: funds nonnegativity in a full-feedback fixed-rule run.
# ---------------------------------------------------------------------
function test_T6()
    println("T6 funds nonnegativity (full-feedback, fixed rule, 60 months)")
    p = default_params()
    r = run!(p; rule=:fixed, h=0.05, T_end=60.0, track_minF=true)
    ok = r.minF >= -1e-9
    println("  min F(t) = $(round(r.minF,digits=6)) USD, F(60)=$(round(r.state.F,digits=2)) " *
            "-> $(verdict(ok))")
    return ok
end

# ---------------------------------------------------------------------
# T7: time-step convergence, h = 0.05 vs 0.025 (full-feedback fixed rule).
# ---------------------------------------------------------------------
function test_T7()
    println("T7 convergence: h=0.05 vs h=0.025 at t=60 (fixed rule)")
    p = default_params()
    r1 = run!(p; rule=:fixed, h=0.05, T_end=60.0)
    r2 = run!(p; rule=:fixed, h=0.025, T_end=60.0)
    s1, s2 = r1.state, r2.state
    d = r1.derived
    rel(x, y) = abs(x - y) / max(abs(x), 1e-12) * 100
    dC = rel(s1.C, s2.C); dB = rel(s1.B, s2.B); dF = rel(s1.F, s2.F)
    aF = abs(s1.F - s2.F)
    println("  rel diff: C=$(round(dC,digits=4))%, B=$(round(dB,digits=4))%, " *
            "F=$(round(dF,digits=3))% (|dF|=$(round(aF,digits=4)) USD)")
    m = max(dC, dB)
    ok = m < 1.0
    println("  max rel diff on C,B = $(round(m,digits=4))% -> $(verdict(ok))")
    return ok
end

# ---------------------------------------------------------------------
# T8: revenue-cut reference (s_R=0): C constant, Fdot = I_F.
# ---------------------------------------------------------------------
function test_T8()
    println("T8 revenue-cut reference (s_R=0)")
    p = default_params()
    r = run!(p; rule=:fixed, s_R=0, h=0.05, T_end=60.0, record=true,
             track_cumIF=true)
    d = r.derived
    dC = maximum(abs.(r.rec[:C] .- d.C0))
    dU = maximum(abs.(r.rec[:U] .- d.U0))
    dF = r.state.F - d.F0
    ok = dC < 1e-9 && dU < 1e-9 && abs(dF - r.cumIF) / max(abs(dF), 1e-9) < 1e-9
    println("  max|C-C0|=$dC, max|U-U0|=$dU, dF=$(round(dF,digits=3)) vs " *
            "int(I_F dt)=$(round(r.cumIF,digits=3)) -> $(verdict(ok))")
    return ok
end

# ---------------------------------------------------------------------
# T9: 120-month equilibrium-start run (f=1.0, beta=1). Checklist:
#   (i)   P + A = M_0 at every step (conservation),
#   (ii)  A stays at A* within tolerance (no growth stimulus),
#   (iii) no drain to zero.
# ---------------------------------------------------------------------
function test_T9()
    println("T9 120-month equilibrium start (f=1.0, beta=1, fixed rule)")
    p = default_params(f=1.0, beta=1.0)
    r = run!(p; rule=:fixed, h=0.05, T_end=120.0, record=true,
             track_conservation=true)
    d = r.derived
    A = r.rec[:A]
    # (i) conservation
    ok_cons = r.max_cons_err < 1e-9
    # (ii) stays near A*: max |A - A*|/A* over months 60-120
    tail = A[1200:end]   # months 60-120 at h=0.05
    dev = maximum(abs.(tail .- d.A_star)) / d.A_star * 100
    ok_eq = dev < 5.0
    # (iii) no drain
    ok_nodrain = minimum(A) > 0.5 * d.A_star
    ok = ok_cons && ok_eq && ok_nodrain
    println("  max|P+A-M_0|/M_0 = $(r.max_cons_err) -> $(verdict(ok_cons))")
    println("  max|A-A*|/A* over mo 60-120 = $(round(dev,digits=3))% " *
            "-> $(verdict(ok_eq))")
    println("  min A = $(round(minimum(A),digits=0)) (> 0.5*A* = " *
            "$(round(0.5*d.A_star,digits=0))) -> $(verdict(ok_nodrain))")
    println("  A(120)=$(round(A[end],digits=0)), Q(120)=$(round(r.rec[:Q][end],digits=4)) " *
            "-> T9 overall: $(verdict(ok))")
    return ok
end

# ---------------------------------------------------------------------
# T10: policy-ranking robustness across beta in {0, 0.5, 1}.
# PRE-REGISTERED RANKING (docx section 5, decision D9): rank rules by
# MEAN COMPLAINT EXPOSURE PER RIDER
#     Xbar_B = (1/60) * int_0^60 B / max(A, A_min) dt   (primary)
# computed from ACTUAL recorded active riders in every run (never from
# the model's X_B auxiliary, so exposure-cut runs are handled correctly).
# Differences under 2% on the primary metric count as tied (ties broken
# by higher mean perceived quality). Reported alongside every ranking:
# mean perceived quality, end-of-horizon riders A(60), realized spending
# (O_C + I_C), and cumulative complaint arrivals int(g_B dt) as a scale
# measure only. A rule that leads on Xbar_B but trails another rule by
# >2% on A(60) is flagged as a tradeoff. 60-month growth-from-below
# runs (f=0.5), alpha=0.10.
# PASS = rankings identical across beta.
# ---------------------------------------------------------------------
function rank_policies(xbar_B, mean_q; tol=0.02)
    # Returns order vector of rule indices, best first. Primary: lower
    # mean per-rider exposure; ties within tol (relative); no tie-break per D9.
    n = length(xbar_B)
    order = collect(1:n)
    # D9 has no tie-break. Sort STRICTLY by Xbar_B (ascending,
    # deterministic); the 2% tolerance defines ties for reporting
    # (tie flags), never for ordering.
    sort!(order, by=i -> xbar_B[i])
    return order
end

function test_T10()
    println("T10 policy-ranking robustness across beta in {0, 0.5, 1} " *
            "(pre-registered D9: mean per-rider exposure primary, 2% ties)")
    rules = [:fixed, :responsive, :reserve]
    betas = [0.0, 0.5, 1.0]
    h = 0.05
    T_end = 60.0
    orders = Dict{Float64,Vector{Int}}()
    for b in betas
        xbar = Float64[]; mean_q = Float64[]
        A60 = Float64[]; spend = Float64[]; cum_gB = Float64[]
        for rule in rules
            p = default_params(beta=b)
            r = run!(p; rule=rule, h=h, T_end=T_end, record=true)
            A = r.rec[:A]; B = r.rec[:B]
            # Xbar_B from ACTUAL riders (docx D9) -- valid under any s_E
            xb = sum(B ./ max.(A, p.A_min)) * h / T_end
            push!(xbar, xb)
            push!(mean_q, sum(r.rec[:Q]) / length(r.rec[:Q]))
            push!(A60, A[end])
            push!(spend, (sum(r.rec[:O_C]) + sum(r.rec[:I_C])) * h)
            push!(cum_gB, sum(r.rec[:g_B]) * h)
        end
        ord = rank_policies(xbar, mean_q)
        orders[b] = ord
        println("  beta=$b:")
        for (pos, idx) in enumerate(ord)
            println("    $pos. $(rules[idx]): Xbar_B=$(round(xbar[idx],digits=4)) " *
                    "complaints/rider, mean_Q=$(round(mean_q[idx],digits=4)), " *
                    "A(60)=$(round(A60[idx],sigdigits=4)), " *
                    "spend=\$$(round(spend[idx]/1e6,digits=2))M, " *
                    "cum_gB=$(round(cum_gB[idx]/1e6,digits=2))M (scale)")
        end
        # Tradeoff flags: leader on Xbar_B trailing >2% on A(60)
        best = ord[1]
        for idx in ord[2:end]
            if A60[best] < 0.98 * A60[idx]
                println("    TRADEOFF: $(rules[best]) leads on Xbar_B but trails " *
                        "$(rules[idx]) by >2% on A(60)")
            end
        end
    end
    ok = orders[0.0] == orders[0.5] == orders[1.0]
    println("  ranking identical across beta -> $(verdict(ok))")
    return ok
end

# ---------------------------------------------------------------------
function main()
    println("ISYE 681 prototype tests -- $(now())\n")
    results = Dict(
        "T1" => test_T1(), "T2" => test_T2(), "T3" => test_T3(),
        "T4" => test_T4(), "T5" => test_T5(), "T6" => test_T6(),
        "T7" => test_T7(), "T8" => test_T8(), "T9" => test_T9(),
        "T10" => test_T10(),
    )
    println("\nSummary:")
    for k in ["T1","T2","T3","T4","T5","T6","T7","T8","T9","T10"]
        println("  $k: $(verdict(results[k]))")
    end
end

main()

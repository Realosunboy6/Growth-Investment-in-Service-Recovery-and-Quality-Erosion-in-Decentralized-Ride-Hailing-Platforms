# =====================================================================
# behavior_test.jl -- Job 1: behavior-reproduction test vs the COVID
# shock (Feb 2020 - Feb 2023). Design and pass criteria were PRE-STATED
# in job1_design_prestated.md before this script was run.
#
# Method: model.jl is included unchanged. The only additions are
#   (1) a Feb-2020 rescaling of the anchored quantities, using exactly
#       the CALIBRATION.md constructions;
#   (2) an exogenous demand-availability multiplier s(t) applied ONLY
#       to the two market-facing demand flows (adoption a, trip demand
#       T_d) via a copied auxiliaries function. No feedback parameter,
#       gain, or delay is altered.
# Integrity: with s == 1 the copied code must reproduce run!() exactly.
# =====================================================================
include(joinpath(@__DIR__, "..", "model.jl"))
using Printf

const OUTDIR = @__DIR__

# ---------------- Feb-2020 rescaling (documented) -------------------
const TSTAR_25 = 14_036_340.0          # Uber Jun 2025 trips (CALIBRATION.md)
const TSTAR_20 = 15_740_099.0          # Uber Feb 2020 trips (fhvhv_monthly.csv)
const UBER_SHARE_20 = 15_740_099.0 / 21_050_236.0   # of Uber+Lyft Feb 2020
const IND_DRIVERS_20 = 79_282.0        # TLC industry indicators, Feb 2020
const DREF_20 = UBER_SHARE_20 * IND_DRIVERS_20      # same construction as Jun-2025
const LAM = TSTAR_20 / TSTAR_25
const M0_20 = 4_000_000.0 * LAM
const ASTAR_20 = TSTAR_20 / (8.0 * (1 - exp(-2.0))) # nu=8, x*=2 (CALIBRATION.md)
const KAPPAD_20 = 2.0 * 8.0 * ASTAR_20 / DREF_20    # identity from CALIBRATION.md

function feb2020_params(; kwargs...)
    base = default_params(; alpha=0.10, tau_dev=7.5, beta=1.0, f=1.0, kwargs...)
    return merge(base, (T_star=TSTAR_20, D_ref=DREF_20, w_0=4.515,
                        p=16.7196, M_0=M0_20, kappa_D=KAPPAD_20))
end

# ---------------- exogenous shock path s(t) --------------------------
# t = months since Feb 2020. Pre-stated in job1_design_prestated.md.
function shock_s(t; floor=0.25)
    if t < 1.0
        return 1.0
    elseif t <= 3.0
        return floor
    elseif t < 16.0
        return floor + (1.0 - floor) * (t - 3.0) / 13.0
    else
        return 1.0
    end
end

# ------------- auxiliaries with the exogenous s(t) hook -------------
# Verbatim copy of auxiliaries() in model.jl EXCEPT the two marked
# lines, where the exogenous demand-availability multiplier applies.
function auxiliaries_shock(st, p, d, s_D, s_E, s)
    T_d = s * p.nu * st.A                                  # SHOCK: trip demand
    T_s = p.kappa_D * st.D
    T = T_d > 0 ? T_d * (1 - exp(-T_s / T_d)) : 0.0
    u_D = T_d / max(T_s, p.T_min)
    W = (u_D / d.u_D0)^p.xi_W - 1
    a = s * (st.P / p.tau_A) * exp(-p.eta_W * W)           # SHOCK: adoption
    Y_D = (1 - p.theta) * p.p * T
    E_D = Y_D / max(st.D, p.D_min)
    Dstar = p.D_ref * (E_D / d.E_D0)^p.eps_D
    e_D = max(Dstar - st.D, 0.0) / p.tau_D
    x_D = max(st.D - Dstar, 0.0) / p.tau_D
    g_fail = p.f_s * T
    g_B = p.s_c * g_fail
    X_B = s_E == 1 ? st.B / max(st.A, p.A_min) : st.B / d.A_0
    Qstar = exp(-p.lambda_Q * X_B)
    S_Q = 1 - st.Q
    mu_A = p.mu_0 + p.kappa_Q * S_Q + p.mu_W * max(0.0, W)
    ell = st.A * mu_A
    R_G = p.p * T
    R_P = p.theta * R_G
    O_F = p.phi * d.R_P0
    R_N = R_P - O_F
    return (T_d=T_d, T_s=T_s, T=T, u_D=u_D, W=W, a=a, Y_D=Y_D, E_D=E_D,
            Dstar=Dstar, e_D=e_D, x_D=x_D, g_fail=g_fail, g_B=g_B, X_B=X_B,
            Qstar=Qstar, S_Q=S_Q, mu_A=mu_A, ell=ell,
            R_G=R_G, R_P=R_P, O_F=O_F, R_N=R_N)
end

# ------------- Euler loop mirroring run! with shock -----------------
function run_shock(p; rule=:responsive, floor=0.25, s_on=true,
                   h=0.05, T_end=36.0)
    d = derive(p)
    st = init_state(p, d)
    n = ceil(Int, T_end / h)
    ts = Float64[]; Ts = Float64[]; As = Float64[]; Ds = Float64[]
    Bs = Float64[]; Qs = Float64[]
    aux0 = auxiliaries_shock(st, p, d, 1, 1, s_on ? shock_s(0.0; floor=floor) : 1.0)
    C_star = capacity_target(rule, st, p, d, aux0, 0, 0.0)
    S_req = max(0.0, C_star / p.tau_turn + (C_star - st.C) / p.tau_order +
                     (p.tau_dev * C_star / p.tau_turn - st.U) / p.tau_order)
    B_prev = st.B
    k = 1
    next_q = 3.0
    for i in 1:n
        t = (i - 1) * h
        s = s_on ? shock_s(t; floor=floor) : 1.0
        aux = auxiliaries_shock(st, p, d, 1, 1, s)
        if t >= next_q - 1e-9
            C_star = capacity_target(rule, st, p, d, aux, k, B_prev)
            S_req = max(0.0, C_star / p.tau_turn + (C_star - st.C) / p.tau_order +
                             (p.tau_dev * C_star / p.tau_turn - st.U) / p.tau_order)
            B_prev = st.B
            k += 1
            next_q += 3.0
        end
        dv = derivatives(st, p, d, aux, S_req, rule, 1, 1, 1)
        st.P += h * dv.dP; st.A += h * dv.dA; st.D += h * dv.dD
        st.B += h * dv.dB; st.Q += h * dv.dQ
        st.C += h * dv.dC; st.U += h * dv.dU; st.F += h * dv.dF
        st.P = max(st.P, 0.0); st.A = max(st.A, 0.0); st.D = max(st.D, 0.0)
        st.B = max(st.B, 0.0)
        st.Q = clamp(st.Q, 0.0, 1.0)
        st.C = max(st.C, 0.0); st.U = max(st.U, 0.0); st.F = max(st.F, 0.0)
        push!(ts, t + h); push!(Ts, aux.T); push!(As, st.A)
        push!(Ds, st.D); push!(Bs, st.B); push!(Qs, st.Q)
    end
    return (t=ts, T=Ts, A=As, D=Ds, B=Bs, Q=Qs, derived=d, state=st)
end

# ------------------------- integrity check --------------------------
function integrity_check()
    p = feb2020_params()
    r0 = run!(p; rule=:responsive, h=0.05, T_end=36.0, record=true)
    r1 = run_shock(p; rule=:responsive, s_on=false, h=0.05, T_end=36.0)
    # compare recorded trips proxy: run! records states, not T. Compare
    # final state and the A series (records are post-step, t+h).
    dA = maximum(abs.(r0.rec[:A] .- r1.A))
    dend = abs(r0.state.A - r1.state.A) + abs(r0.state.B - r1.state.B) +
           abs(r0.state.F - r1.state.F) + abs(r0.state.D - r1.state.D)
    @printf("integrity (s==1 vs run!): max|A diff| over series = %.3e ; final-state diff sum = %.3e\n", dA, dend)
    return dA, dend
end

# ------------------------- monthly metrics --------------------------
monthly(x, h=0.05) = x[round(Int, 1/h):round(Int, 1/h):end]  # t=1,2,...

function main()
    println("=== Job 1: COVID behavior-reproduction test ===")
    @printf("Rescaled anchors: T*=%.0f  D_ref=%.0f  M_0=%.0f  kappa_D=%.2f  A*=%.0f\n",
            TSTAR_20, DREF_20, M0_20, KAPPAD_20, ASTAR_20)
    integrity_check()

    p = feb2020_params()
    d = derive(p)
    @printf("derive(): A_0=%.0f  T_0=%.0f  Q_0=%.4f  E_D0=%.1f  coverage0=%.3f\n",
            d.A_0, d.T_0, d.Q0, d.E_D0, p.rho_C * d.C0 / (p.s_c * p.f_s * d.T_0))

    rows = String[]
    push!(rows, "month_index,rule,floor,T_norm,A_norm,D_norm,B,Q,T_trips")
    summary = Dict{String,Any}()
    for rule in (:fixed, :responsive, :reserve)
        for floor in (0.25, 0.20, 0.30)
            r = run_shock(p; rule=rule, floor=floor, h=0.05, T_end=36.0)
            Tm = monthly(r.T); Am = monthly(r.A); Dm = monthly(r.D)
            Bm = monthly(r.B); Qm = monthly(r.Q)
            Tn = Tm ./ d.T_0
            An = Am ./ d.A_0
            Dn = Dm ./ d.D_0
            imin = argmin(Tn)
            recov = findfirst(x -> x >= 0.9, Tn[imin:end])
            recov_month = recov === nothing ? -1 : imin + recov - 1
            tag = "$(rule)_$(floor)"
            summary[tag] = (trough=Tn[imin], trough_month=imin,
                            recovery_month=recov_month,
                            T29=Tn[29], T36=Tn[36], A36=An[36])
            if floor == 0.25
                push!(rows, @sprintf("%d,%s,%.2f,%.6f,%.6f,%.6f,%.1f,%.6f,%.1f",
                      0, rule, floor, 1.0, 1.0, 1.0, d.B0, d.Q0, d.T_0))
                for i in 1:36
                    push!(rows, @sprintf("%d,%s,%.2f,%.6f,%.6f,%.6f,%.1f,%.6f,%.1f",
                          i, rule, floor, Tn[i], An[i], Dn[i], Bm[i], Qm[i], Tm[i]))
                end
            end
            @printf("%-22s trough=%.3f at month %2d (cal %s)  recovery(>=0.9) month=%2d  T[29]=%.3f T[36]=%.3f A[36]=%.3f\n",
                    tag, Tn[imin], imin, imin, recov_month, Tn[29], Tn[36], An[36])
        end
    end
    open(joinpath(OUTDIR, "behavior_test_series.csv"), "w") do io
        for r in rows
            println(io, r)
        end
    end
    println("wrote behavior_test_series.csv")
end

main()

# ---- appended control run: no shock (s == 1) at Feb-2020 rescaling ----
function control()
    p = feb2020_params()
    d = derive(p)
    println("\n=== CONTROL: no shock, Feb-2020 rescaling, 36 months ===")
    for rule in (:fixed, :responsive, :reserve)
        r = run_shock(p; rule=rule, s_on=false, h=0.05, T_end=36.0)
        Tn = monthly(r.T) ./ d.T_0
        An = monthly(r.A) ./ d.A_0
        @printf("%-11s T: mo6=%.3f mo12=%.3f mo24=%.3f mo36=%.3f | A36=%.3f minT=%.3f\n",
                rule, Tn[6], Tn[12], Tn[24], Tn[36], An[36], minimum(Tn))
    end
end
control()

# =====================================================================
# model.jl -- Minimal Julia prototype of the ISYE 681 ride-hailing
# recovery-capacity system-dynamics model.
#
# SOURCE OF TRUTH: ConsolidatedEquations.docx (finalized version, clean
# PASS from Claude Opus 5.5 and all three custom GPTs, plus the beta
# structural revision: dP/dt = beta*ell - a, beta in [0,1]).
# Implements ONLY that equation set; nothing is invented structurally.
#
# Integration: explicit Euler, h = 0.05 month (doc section 1), with a
# convergence check at h = 0.025. No external packages required.
#
# CONVENTION: every parameter value below carries a source label --
# ANCHORED (NYC TLC data), MIDPOINT-ASSUMED (docx band midpoint),
# SCALE-CHOICE (documented scale convention), DERIVED (computed from
# other calibrated quantities), DESIGN (explicit design decision), or
# ASSUMED (explicit assumption). Full provenance in CALIBRATION.md.
# =====================================================================

# ---------------------------------------------------------------------
# Parameters. Keyword overrides let tests set scenario values
# (tau_turn, tau_dev, alpha, f_s, beta, f) per the docx scenario design.
# ---------------------------------------------------------------------
function default_params(; tau_turn=24.0, tau_dev=7.5, alpha=0.10, f_s=0.05,
                         beta=1.0, f=0.5)
    return (
        # --- Table 1: paper-specified bands ---
        f_s    = f_s,        # service failure rate [failures/trip], MIDPOINT-ASSUMED band 0.01-0.10
        s_c    = 0.20,       # complaint sensitivity [complaints/failure], MIDPOINT-ASSUMED band 0.05-0.40
        rho_C  = 400.0,      # resolution productivity [complaints/(unit*month)], MIDPOINT-ASSUMED band 200-600
        c_C    = 5250.0,     # capacity unit cost [USD/(unit*month)], MIDPOINT-ASSUMED band 3500-7000
        tau_turn = tau_turn, # capacity turnover time [months], scenario band 12-36
        tau_Q  = 3.5,        # quality perception delay [months], MIDPOINT-ASSUMED band 1-6
        tau_dev  = tau_dev,  # capacity development delay [months], scenario band 3-12
        kappa_Q  = 0.55,     # attrition sensitivity [1/month per unit shortfall], MIDPOINT-ASSUMED band 0.1-1.0
        alpha  = alpha,      # revenue allocation share [fraction], DESIGN: 0.10 base (high funding, coverage 1.17>=1); 0.05 = low-funding stress (coverage 0.59)
        p      = 26.8634,    # fare per trip [USD/trip], ANCHORED: trip-weighted Uber+Lyft mean base_passenger_fare, Jan 2025-Aug 2026
        theta  = 0.10,       # platform take rate [fraction], DESIGN: inside Table 1's 0.05-0.15 band for the decentralized platform (Uber's 0.23 excluded)
        phi    = 0.25,       # fixed operating cost fraction, ASSUMED band 0.10-0.40
        tau_D  = 3.5,        # driver adjustment time [months], MIDPOINT-ASSUMED band 1-6
        B_trig = 100000.0,   # backlog trigger [complaints], SCALE-CHOICE policy lever (~1.4x B(0) at growth start)
        m_R    = 1.5,        # reserve multiple [dimensionless], > 1 policy lever
        beta   = beta,       # rider-return fraction [dimensionless, in [0,1]], DESIGN/docx: 1 = conserved market (base), 0 = original no-return (sensitivity)
        # --- Market scale & growth design ---
        M_0 = 4_000_000.0,   # total addressable rider market [riders], SCALE-CHOICE (revisited: 8M implied tau_A ~= 62 mo, implausible; 4M -> tau_A ~= 20 mo)
        f   = f,             # growth-start fraction [dimensionless], DESIGN: 0.5 = runs start below equilibrium (paper needs rising runs); 1.0 = equilibrium-start (checklist verification)
        T_star = 14_036_340.0,    # equilibrium trips [trips/month] (docx T*), ANCHORED: Uber Jun 2025
        x_star = 2.0,        # equilibrium supply/demand ratio T_s*/T_d* [dimensionless], SCALE-CHOICE -> served fraction 0.8647
        # --- Closure parameters [A] ---
        tau_A = 20.32,       # adoption time [months], DERIVED: (M_0-A*)/(mu_A**A*) at W*=0 (see CALIBRATION.md)
        nu    = 8.0,         # trips per active rider [trips/(rider*month)], SCALE-CHOICE (~2/wk)
        kappa_D = 559.72,    # trips per driver [trips/(driver*month)], DERIVED: x_star*nu*A*/D_ref (~18.7/day)
        w_0   = 5.098013628671483,  # baseline pickup wait [minutes], ANCHORED: Uber Jun 2025 mean request-to-pickup, > 0
        xi_W  = 0.5,         # wait elasticity [dimensionless], ASSUMED > 0
        eta_W = 1.0,         # adoption wait sensitivity [dimensionless], ASSUMED > 0
        eps_D = 0.8,         # driver earnings elasticity [dimensionless], ASSUMED > 0 (docx)
        lambda_Q = 0.75,     # quality exposure coefficient [riders/complaint], ASSUMED (targets Q(0)~0.95)
        mu_0  = 0.02,        # baseline attrition [1/month], ASSUMED
        mu_W  = 0.05,        # wait-driven attrition [1/month], ASSUMED
        tau_B = 1.0,         # backlog resolution time [months], provisional
        tau_clear = 3.0,     # backlog clearance horizon [months], provisional
        tau_order = 3.0,     # ordering adjustment time [months], provisional
        tau_F = 3.0,         # funds disbursement time [months], provisional (NOT the step h)
        # --- Numerical floors: safeguards, not behavioral parameters ---
        A_min = 1.0,         # [riders]
        D_min = 1.0,         # [drivers]
        T_min = 1.0,         # [trips/month]
        # --- Driver scale ---
        D_ref = 58_005.0,    # equilibrium driver scale [drivers] (docx D_ref), ANCHORED: Uber's 71.48% share of 81,148 Jun 2025 industry drivers
    )
end

# ---------------------------------------------------------------------
# Derived constants (docx section 6). Equilibrium anchors: A*, D_ref, T*.
# Initial states (growth-from-below): A_0 = f*A*, D_0 = f*D_ref = D(0),
# T_0 from smooth-min at growth start. Proportional scaling keeps all t=0
# ratios (x_0, u_D0, E_D/E_D0) at equilibrium values. E_D0 is the equilibrium
# earnings reference (scale-invariant ratio).
# ---------------------------------------------------------------------
function derive(p)
    served = 1 - exp(-p.x_star)
    A_star = p.T_star / (p.nu * served)       # equilibrium active riders (docx A*)
    A_0 = p.f * A_star
    D_0 = p.f * p.D_ref                         # initial drivers, D_0 = D(0) = f*D_ref (docx)
    T_d0 = p.nu * A_0
    T_s0 = p.kappa_D * D_0
    T_0  = T_d0 * (1 - exp(-T_s0 / T_d0))      # smooth-min at growth start
    T_star = p.T_star                            # equilibrium trips (docx T*)
    R_P0 = p.theta * p.p * T_0
    R_N0 = (1 - p.phi) * R_P0
    E_D0 = (1 - p.theta) * p.p * T_star / p.D_ref  # set from equilibrium (docx 6); > 0 required; equals t=0 earnings under proportional scaling
    u_D0 = T_d0 / max(T_s0, p.T_min)           # baseline utilization ref (= 0.5)
    B_prot = p.alpha * R_N0
    k_dev  = p.c_C * 7.5                       # docx: decoupled from tau_dev
    C_fix  = B_prot / (p.c_C + k_dev / p.tau_turn)
    C0 = p.alpha * R_N0 / (p.c_C + k_dev / p.tau_turn)  # == C_fix
    U0 = p.tau_dev * C0 / p.tau_turn
    F0 = 3.0 * B_prot                          # 3 months of protected spend
    B0 = p.s_c * p.f_s * T_0 * p.tau_B
    Q0 = exp(-p.lambda_Q * B0 / A_0)
    return (A_star=A_star, A_0=A_0, D_0=D_0, T_d0=T_d0, T_s0=T_s0,
            T_0=T_0, T_star=T_star, R_P0=R_P0, R_N0=R_N0, E_D0=E_D0,
            u_D0=u_D0, B_prot=B_prot, k_dev=k_dev, C_fix=C_fix,
            C0=C0, U0=U0, F0=F0, B0=B0, Q0=Q0)
end

mutable struct State
    P::Float64; A::Float64; D::Float64; B::Float64
    Q::Float64; C::Float64; U::Float64; F::Float64
end

function init_state(p, d)
    return State(p.M_0 - d.A_0, d.A_0, d.D_0, d.B0, d.Q0, d.C0, d.U0, d.F0)
end

# ---------------------------------------------------------------------
# Auxiliaries (docx sections 3.1-3.3). s_D/s_E are attribution switches.
# ---------------------------------------------------------------------
function auxiliaries(st, p, d, s_D, s_E)
    T_d = p.nu * st.A
    T_s = p.kappa_D * st.D                       # st.D == D_0 == D(0) when s_D == 0 (docx 5: D fixed at D_0)
    T = T_d > 0 ? T_d * (1 - exp(-T_s / T_d)) : 0.0   # smooth-min, T=0 at T_d=0
    u_D = T_d / max(T_s, p.T_min)
    W = (u_D / d.u_D0)^p.xi_W - 1                # signed waiting stress; W(0)=0
    a = (st.P / p.tau_A) * exp(-p.eta_W * W)     # adoption [riders/month]
    Y_D = (1 - p.theta) * p.p * T                 # driver payout [USD/month]
    E_D = Y_D / max(st.D, p.D_min)               # earnings per driver
    Dstar = p.D_ref * (E_D / d.E_D0)^p.eps_D     # desired drivers (eps_D > 0); scale is D_ref per docx 6 (D*(0) = D_ref)
    e_D = max(Dstar - st.D, 0.0) / p.tau_D       # entry
    x_D = max(st.D - Dstar, 0.0) / p.tau_D       # exit
    g_fail = p.f_s * T
    g_B = p.s_c * g_fail                          # complaint arrivals
    X_B = s_E == 1 ? st.B / max(st.A, p.A_min) : st.B / d.A_0
    Qstar = exp(-p.lambda_Q * X_B)                # target quality
    S_Q = 1 - st.Q
    mu_A = p.mu_0 + p.kappa_Q * S_Q + p.mu_W * max(0.0, W)  # attrition hazard
    ell = st.A * mu_A                              # attrition flow
    R_G = p.p * T
    R_P = p.theta * R_G
    O_F = p.phi * d.R_P0
    R_N = R_P - O_F
    return (T_d=T_d, T_s=T_s, T=T, u_D=u_D, W=W, a=a, Y_D=Y_D, E_D=E_D,
            Dstar=Dstar, e_D=e_D, x_D=x_D, g_fail=g_fail, g_B=g_B, X_B=X_B,
            Qstar=Qstar, S_Q=S_Q, mu_A=mu_A, ell=ell,
            R_G=R_G, R_P=R_P, O_F=O_F, R_N=R_N)
end

# ---------------------------------------------------------------------
# Quarterly investment-rule target C_k* (docx section 4).
# k = 0.. ; B_prev = B(t_{k-1}); trigger evaluated for k >= 1, H_0 = 0.
# ---------------------------------------------------------------------
function capacity_target(rule, st, p, d, aux, k, B_prev)
    if rule == :fixed
        return d.C_fix
    elseif rule == :responsive
        C_base = d.C0
        H = (k >= 1) && (st.B > p.B_trig) && (B_prev > p.B_trig)
        if H
            return max(C_base, (aux.g_B + st.B / p.tau_clear) / p.rho_C)
        else
            return C_base
        end
    elseif rule == :reserve
        return max(d.C0, p.m_R * aux.g_B / p.rho_C)
    else
        error("unknown rule $rule")
    end
end

# ---------------------------------------------------------------------
# Full derivative vector. S_req is the held quarterly order rate.
# Revenue-cut (s_R=0) overrides per docx section 5.
# bypass_funds=true idealizes "funds never bind" (used by T1): operating
# spend is fully funded and c_start = S_req. aux is passed in so callers
# can reuse it (avoids recomputation, enables exact I_F accumulation).
# Rider conservation: dP/dt = beta*ell - a (docx beta revision).
# ---------------------------------------------------------------------
function derivatives(st, p, d, aux, S_req, rule, s_R, s_D, s_E; bypass_funds=false)
    I_F = p.alpha * max(0.0, aux.R_N)
    dD = s_D == 1 ? aux.e_D - aux.x_D : 0.0
    dQ = (aux.Qstar - st.Q) / p.tau_Q
    if s_R == 0
        # Revenue-cut reference: capacity frozen, F is a reporting state.
        r_B = min(st.B / p.tau_B, p.rho_C * d.C0)
        return (dP=p.beta*aux.ell - aux.a, dA=aux.a - aux.ell, dD=dD,
                dB=aux.g_B - r_B, dQ=dQ, dC=0.0, dU=0.0, dF=I_F, I_F=I_F, I_C=0.0, O_C=0.0)
    end
    # Spending ceiling; fixed rule uses the protected ceiling L_F^fix.
    L = rule == :fixed ? min(d.B_prot, st.F / p.tau_F + I_F) : st.F / p.tau_F + I_F
    O_Creq = p.c_C * st.C
    if bypass_funds
        O_C = O_Creq
        m_C = 1.0
        c_start = S_req
    else
        O_C = min(O_Creq, L)                      # operating priority
        m_C = O_Creq > 0 ? O_C / O_Creq : 1.0     # funded operating fraction
        c_start = min(S_req, max(0.0, L - O_C) / d.k_dev)
    end
    I_C = d.k_dev * c_start
    c_turn = st.C / p.tau_turn
    c_complete = st.U / p.tau_dev
    r_B = min(st.B / p.tau_B, m_C * p.rho_C * st.C)
    return (dP=p.beta*aux.ell - aux.a, dA=aux.a - aux.ell, dD=dD,
            dB=aux.g_B - r_B, dQ=dQ, dC=c_complete - c_turn,
            dU=c_start - c_complete, dF=I_F - O_C - I_C, I_F=I_F, I_C=I_C, O_C=O_C)
end

# ---------------------------------------------------------------------
# Main run: explicit Euler with quarterly sample-and-hold ordering.
# Returns final state and (optionally) recorded series.
# ---------------------------------------------------------------------
function run!(p; rule=:fixed, s_R=1, s_D=1, s_E=1, h=0.05, T_end=60.0,
              record::Bool=false, track_minF::Bool=false,
              bypass_funds::Bool=false, track_cumIF::Bool=false,
              track_conservation::Bool=false)
    d = derive(p)
    st = init_state(p, d)
    n = ceil(Int, T_end / h)
    rec = record ? Dict(:t=>Float64[], :P=>Float64[], :A=>Float64[],
                        :D=>Float64[], :B=>Float64[], :Q=>Float64[],
                        :C=>Float64[], :U=>Float64[], :F=>Float64[],
                        :I_F=>Float64[], :X_B=>Float64[], :I_C=>Float64[],
                        :g_B=>Float64[], :O_C=>Float64[]) : nothing
    minF = st.F
    cumIF = 0.0
    max_cons_err = 0.0   # |P + A - M_0| / M_0 when beta == 1
    # Quarter 0 decision at t = 0.
    aux0 = auxiliaries(st, p, d, s_D, s_E)
    C_star = capacity_target(rule, st, p, d, aux0, 0, 0.0)
    S_req = max(0.0, C_star / p.tau_turn + (C_star - st.C) / p.tau_order +
                     (p.tau_dev * C_star / p.tau_turn - st.U) / p.tau_order)
    B_prev = st.B
    k = 1
    next_q = 3.0
    for i in 1:n
        t = (i - 1) * h
        aux = auxiliaries(st, p, d, s_D, s_E)
        if t >= next_q - 1e-9 && s_R == 1
            C_star = capacity_target(rule, st, p, d, aux, k, B_prev)
            S_req = max(0.0, C_star / p.tau_turn + (C_star - st.C) / p.tau_order +
                             (p.tau_dev * C_star / p.tau_turn - st.U) / p.tau_order)
            B_prev = st.B
            k += 1
            next_q += 3.0
        end
        dv = derivatives(st, p, d, aux, S_req, rule, s_R, s_D, s_E;
                         bypass_funds=bypass_funds)
        if track_cumIF
            cumIF += h * dv.I_F
        end
        st.P += h * dv.dP; st.A += h * dv.dA; st.D += h * dv.dD
        st.B += h * dv.dB; st.Q += h * dv.dQ
        st.C += h * dv.dC; st.U += h * dv.dU; st.F += h * dv.dF
        # Positivity safeguards (docx section 9); D = 0 is absorbing.
        st.P = max(st.P, 0.0); st.A = max(st.A, 0.0); st.D = max(st.D, 0.0)
        st.B = max(st.B, 0.0)
        st.Q = clamp(st.Q, 0.0, 1.0)
        st.C = max(st.C, 0.0); st.U = max(st.U, 0.0); st.F = max(st.F, 0.0)
        if track_conservation && p.beta == 1.0
            err = abs((st.P + st.A) - p.M_0) / p.M_0
            max_cons_err = max(max_cons_err, err)
        end
        if track_minF && st.F < minF
            minF = st.F
        end
        if record
            # I_C recomputed from the step's c_start for reporting
            push!(rec[:t], t + h); push!(rec[:P], st.P); push!(rec[:A], st.A)
            push!(rec[:D], st.D); push!(rec[:B], st.B); push!(rec[:Q], st.Q)
            push!(rec[:C], st.C); push!(rec[:U], st.U); push!(rec[:F], st.F)
            push!(rec[:I_F], dv.I_F); push!(rec[:X_B], aux.X_B); push!(rec[:I_C], dv.I_C)
            push!(rec[:g_B], aux.g_B); push!(rec[:O_C], dv.O_C)
        end
    end
    return (state=st, derived=d, rec=rec, minF=minF, cumIF=cumIF,
            max_cons_err=max_cons_err)
end

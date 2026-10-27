# =====================================================================
# f_sweep.jl -- Foil's proposed test (house review, 2026-10-26):
# does the fixed rule's collapse boundary track 1/f?
#
# Protocol: identical to coverage_sweep.jl (coverage varied via alpha,
# tau_dev = 3, beta = 1, intact switches, 60 months, Objective 3 pattern
# classification copied verbatim), repeated at f in {0.3, 0.5, 0.7, 1.0}.
# Coverage0 is exactly proportional to alpha with an f-independent
# constant (T_0 cancels in rho_C*C0/(s_c*f_s*T_0)); coverage is still
# computed from derive() on every run, not from the constant.
# Alpha extends to 0.31, far outside Table 1's band: inherent to tracing
# the fixed boundary at low f (1/f = 3.33 at f = 0.3). Boundary mapping
# only; no policy claim is made at those alphas.
#
# Pre-stated predictions (written before the run):
#   fixed boundary ~ (1/f) * s, s in [0.80, 0.94] (the settling factor
#     implied by the paper's f = 0.5 interval 1.59-1.87 vs 1/f = 2.0):
#     f=0.3 -> [2.66, 3.13]; f=0.5 -> [1.60, 1.88];
#     f=0.7 -> [1.14, 1.34]; f=1.0 -> [0.80, 0.94].
#   reserve boundary ~ 0.857 at every f (Foil's closed form), if the
#     adaptive boundary is f-invariant.
#
# Run: ~/julia-1.11.7/bin/julia f_sweep.jl
# Writes: f_sweep.csv
# =====================================================================
include("model.jl")
using Printf

const H = 0.05
const T_END = 60.0

# Objective 3 pattern classification (verbatim from coverage_sweep.jl).
function classify_pattern(A, A0)
    m = A[1:20:length(A)]
    if maximum(m) <= 1.02 * A0
        return "non-growing"
    end
    cand = Int[]
    for i in 2:length(m)-1
        if m[i] >= m[i-1] && m[i] >= m[i+1]
            if minimum(m[i:end]) <= 0.90 * m[i]
                push!(cand, i)
            end
        end
    end
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

function main()
    rows = String[]
    push!(rows, "f,rule,alpha,coverage0,Xbar_B,mean_Q,A60,B60,Q60,pattern,minF_USD")
    alphas = [round(a, digits=3) for a in 0.035:0.005:0.310]
    n = 0
    for f in (0.3, 0.5, 0.7, 1.0)
        for rule in (:fixed, :responsive, :reserve)
            for alpha in alphas
                p = default_params(alpha=alpha, tau_dev=3.0, beta=1.0, f=f)
                r = run!(p; rule=rule, s_R=1, s_D=1, s_E=1,
                         h=H, T_end=T_END, record=true, track_minF=true)
                d = r.derived
                A = r.rec[:A]; B = r.rec[:B]; Q = r.rec[:Q]
                coverage = p.rho_C * d.C0 / (p.s_c * p.f_s * d.T_0)
                xbar = sum(B ./ max.(A, p.A_min)) * H / T_END
                pattern = classify_pattern(A, d.A_0)
                push!(rows, join([f, rule, alpha, round(coverage, digits=4),
                                  round(xbar, digits=4),
                                  round(sum(Q)/length(Q), digits=4),
                                  round(A[end], digits=1),
                                  round(B[end], digits=1),
                                  round(Q[end], digits=4), pattern,
                                  round(r.minF, digits=2)], ","))
                n += 1
            end
        end
        println("  f=$f done")
    end
    open("f_sweep.csv", "w") do io
        for r in rows; println(io, r); end
    end
    println("wrote f_sweep.csv ($n runs)")
end

main()

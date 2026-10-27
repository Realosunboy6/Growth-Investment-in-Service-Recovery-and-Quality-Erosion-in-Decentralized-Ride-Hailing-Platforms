# =====================================================================
# coverage_sweep.jl -- Objective 3 boundary sweep (reviewer requirement).
#
# For each of the 3 rules, sweep t=0 coverage from ~0.5 to ~1.5 by
# varying alpha (coverage is exactly proportional to alpha holding all
# other Table 1 values fixed: coverage = 11.6956 * alpha at base params).
# Intact-revenue (s_D = s_E = 1), tau_dev = 3 base, beta = 1, 60 months.
# Each run classified with the Objective 3 pre-set rules. Reports the
# coverage at which each rule's pattern flips from overshoot-and-decline
# to sustained growth.
#
# NOTE: alpha up to 0.13 slightly exceeds Table 1's 0.01-0.10 band; the
# exceedance is documented and needed to map the boundary above 1.17.
#
# Run: ~/julia-1.11.7/bin/julia coverage_sweep.jl
# Writes: coverage_sweep.csv
# =====================================================================
include("model.jl")
using Printf

const H = 0.05
const T_END = 60.0

# Objective 3 pattern classification (same as experiment.jl).
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

function main()
    rows = String[]
    push!(rows, "rule,alpha,coverage0,Xbar_B,mean_Q,A60,B60,Q60,cum_gB,spend_USD,pattern")
    alphas = [round(a, digits=3) for a in 0.04:0.005:0.13]
    n = 0
    for rule in (:fixed, :responsive, :reserve)
        for alpha in alphas
            p = default_params(alpha=alpha, tau_dev=3.0, beta=1.0)
            r = run!(p; rule=rule, s_R=1, s_D=1, s_E=1,
                     h=H, T_end=T_END, record=true, track_minF=true)
            d = r.derived
            A = r.rec[:A]; B = r.rec[:B]; Q = r.rec[:Q]
            coverage = p.rho_C * d.C0 / (p.s_c * p.f_s * d.T_0)
            xbar = sum(B ./ max.(A, p.A_min)) * H / T_END
            pattern = classify_pattern(A, d.A_0)
            spend = (sum(r.rec[:O_C]) + sum(r.rec[:I_C])) * H
            push!(rows, join([rule, alpha, round(coverage, digits=4),
                              round(xbar, digits=4), round(sum(Q)/length(Q), digits=4),
                              round(A[end], digits=1), round(B[end], digits=1),
                              round(Q[end], digits=4), round(sum(r.rec[:g_B])*H, digits=1),
                              round(spend, digits=1), pattern], ","))
            n += 1
        end
        println("  rule=$rule done")
    end
    open("coverage_sweep.csv", "w") do io
        for r in rows; println(io, r); end
    end
    println("wrote coverage_sweep.csv ($n runs)")
end

main()

# =====================================================================
# sampling_fix.jl -- Correct the Fig. 4 / Sec. 4.6 comparison convention.
#
# Diagnosis (see SAMPLING_FIX.md): behavior_test.jl records aux.T, the
# instantaneous trips RATE at the start of each Euler step, and
# monthly() subsamples every 20th record. CSV month_index m therefore
# holds the instantaneous rate at t = m - 0.05 -- effectively the END
# of the PREVIOUS month -- while the observed TLC series is monthly
# TOTALS. The two conventions are mixed in the published comparison.
#
# Fix: recompute the simulated comparison series as MONTHLY AVERAGES of
# the simulated trips rate over each calendar month (mean of aux.T over
# the 20 steps with state-time in [m, m+1)), matching the observed
# monthly-totals convention (average rate <-> monthly total differ only
# by the constant month length, which cancels in the normalization).
# Nothing else is changed: same rescaling, same s(t), same floor, same
# rules, same h. The run is extended to t = 37 only so that the final
# plotted month (Feb 2023, month_index 36, spanning [36,37)) has a
# complete month of steps to average; months 0..35 are unaffected.
# =====================================================================
include(joinpath(@__DIR__, "behavior_test.jl"))   # runs its main()+control(); harmless, deterministic
using Printf
using Statistics

# calendar label for month_index m (0 = Feb 2020)
function cal_label(m)
    y = 2020 + (1 + m) ÷ 12
    mo = mod(1 + m, 12) + 1
    return @sprintf("%04d-%02d", y, mo)
end

function monthly_avg_series(rule; floor=0.25)
    p = feb2020_params()
    d = derive(p)
    r = run_shock(p; rule=rule, floor=floor, h=0.05, T_end=37.0)
    # r.T[k] = aux.T for step k, evaluated at state time (k-1)*h, i.e.
    # the (piecewise-constant Euler) rate over [(k-1)h, k*h).
    steps_per_month = round(Int, 1 / 0.05)
    avg = Float64[]
    for m in 0:36
        ks = (m * steps_per_month + 1):((m + 1) * steps_per_month)
        push!(avg, mean(r.T[ks]) / d.T_0)
    end
    return avg
end

function main_fix()
    println("\n=== SAMPLING FIX: monthly averages ===")
    old = Dict{Tuple{Int,String},Float64}()
    for line in readlines(joinpath(OUTDIR, "behavior_test_series_instantaneous.csv"))[2:end]
        f = split(line, ",")
        old[(parse(Int, f[1]), f[2])] = parse(Float64, f[4])
    end

    rows = String[]
    push!(rows, "month_index,calendar_month,rule,T_norm_monthlyavg,T_norm_instantaneous_old")
    results = Dict{String,Any}()
    for rule in (:fixed, :responsive, :reserve)
        avg = monthly_avg_series(rule)
        imin = argmin(avg) - 1                     # month_index of trough
        # first month >= 0.9 at or after the trough month
        cross = findfirst(i -> avg[i + 1] >= 0.9, imin:36)
        cross_month = cross === nothing ? -1 : imin + cross - 1
        results[String(rule)] = (trough=avg[imin + 1], trough_month=imin,
                                 mar=avg[2], apr=avg[3], may=avg[4],
                                 cross=cross_month)
        @printf("%-11s MONTHLY-AVG trough=%.3f at month %2d (%s) | Mar=%.3f Apr=%.3f May=%.3f | first >=0.9 after trough: month %2d (%s)\n",
                rule, avg[imin + 1], imin, cal_label(imin), avg[2], avg[3], avg[4],
                cross_month, cross_month >= 0 ? cal_label(cross_month) : "none")
        for m in 0:36
            push!(rows, @sprintf("%d,%s,%s,%.6f,%.6f", m, cal_label(m), rule,
                                 avg[m + 1], old[(m, String(rule))]))
        end
    end
    open(joinpath(OUTDIR, "behavior_test_series_monthlyavg.csv"), "w") do io
        for r in rows
            println(io, r)
        end
    end
    println("wrote behavior_test_series_monthlyavg.csv")
    return results
end

main_fix()

# Funding-Constrained Service Recovery and Platform Growth: A System Dynamics Study of a Decentralized Ride-Hailing Platform

Ibrahim E. Oyeyinka. Term paper for ISYE 681, Northern Illinois University, Fall 2026.

This repository is the supporting record for the paper: the Julia implementation of the model, the experiment outputs the paper reports, the public trip data and aggregates behind the calibration and the behaviour test, and the documentation of parameters, mappings, and sources. The paper was retitled before submission; the repository name keeps the project's original working title.

## Model and code

In `code/`. Julia 1.11, no external packages. Run the scripts from inside `code/`; each script writes its output CSV beside itself, and the CSVs deposited here are the ones the paper reports.

| File | What it does |
|---|---|
| `code/model.jl` | The eight-stock system dynamics model (explicit Euler, step 0.05 months) |
| `code/tests.jl` | Ten structural and behavioural tests. Run first: `julia tests.jl` |
| `code/experiment.jl` | The 64-run factorial over the three allocation rules (fixed-capacity, backlog-responsive, reserve-capacity), the funding budget, and the development delay. Writes `results_64.csv` and `trajectories.csv` |
| `code/coverage_sweep.jl` | Initial-coverage sweep locating where the rule choice starts and stops mattering |
| `code/lhs_sensitivity.jl`, `code/lhs_sensitivity_682.jl` | The two 200-draw Latin-hypercube sensitivity batches (seeds 681 and 682) |
| `code/f_sweep.jl`, `code/sweep_beta.jl` | Take-rate sweep and complaint-sensitivity sweep |
| `code/plot_trajectories.jl` | Plots the headline trajectories from `trajectories.csv` |
| `code/publication_additions/behavior_test.jl` | The COVID-19 behaviour-reproduction test. Its observed benchmarks are constants taken from `data/aggregates/fhvhv_monthly.csv` |
| `code/publication_additions/spend_match.jl` | The matched-spend comparison between the responsive and reserve rules |
| `code/publication_additions/sampling_fix.jl` | The sampling correction documented in `SAMPLING_FIX.md` |

Trajectories are classified by the criterion stated in the paper: a run counts as recovery if it regains at least half of its peak-to-trough fall.

Headline finding: at high funding the reserve-capacity rule outperforms the backlog-responsive rule, which outperforms fixed-capacity, and the choice of rule matters only in an intermediate band of initial demand coverage. Below the band every rule overshoots and declines at the low-funding calibration; above it every rule sustains.

Supporting notes in `code/`: `CALIBRATION.md` (calibration record), `RESULTS_64.md` (factorial results), `F_SWEEP_RESULTS.md` (take-rate sweep results), and `RESULTS.md` (an early prototype note, marked superseded at its head).

## Data

All trip records are public data from the NYC Taxi and Limousine Commission (TLC):

- TLC Trip Record Data: https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page
- Data dictionary: https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_hvfhs.pdf (copy in `data/`)

| File | Contents |
|---|---|
| `data/samples/fhvhv_tripdata_2025-06_sample1pct.parquet` | 1% uniform random sample (seed 681) of June 2025 high-volume for-hire vehicle trips (~197k trips) |
| `data/aggregates/fhvhv_2025-06_daily.csv` | Daily aggregates, June 2025: trips, mean request-to-pickup time, mean fare, mean driver pay, mean trip miles, mean trip time |
| `data/aggregates/fhvhv_monthly.csv` | Monthly per-company aggregates, Feb 2019 - Aug 2026 (91 months): trips, trips per day, mean request-to-pickup time, mean fare, mean driver pay, mean trip miles, mean trip time; Uber (HV0003), Lyft (HV0005), Juno (HV0002, through Nov 2019), Via (HV0004, through Oct 2021). Via's `driver_pay` values are unusable and left blank. |
| `data/aggregates/fhv_industry_indicators_monthly.csv` | TLC Industry Indicators for FHV - High Volume, Jan 2015 - Aug 2026 (140 months): trips per day, unique drivers, unique vehicles, vehicles per day, utilization stats. Source: NYC TLC via NYC Open Data. |
| `data/data_dictionary_trip_records_hvfhs.pdf` | Official TLC field definitions |

Raw monthly files are ~500 MB each and are not stored here. `scripts/download_tlc_data.sh` fetches them; `scripts/make_sample.py` and `scripts/tlc_monthly.py` regenerate the sample and the aggregates exactly.

## Definitions that matter

- **Waiting time** = `pickup_datetime - request_datetime`. `trip_time` is in-vehicle time only.
- **`driver_pay`** is per-trip compensation, not hourly earnings.
- **`fare - driver_pay` is not platform revenue.** Taxes, surcharges, and fees sit between them.

Details: `docs/field-definitions.md`. Model-variable mapping: `docs/data-to-variable-mapping.md`. Assumed parameters: `docs/assumed-parameters.md`. References: `docs/literature.md`. Verified source documents: `docs/sources/`.

## Citation

Oyeyinka, Ibrahim E. (2026). Funding-Constrained Service Recovery and Platform Growth: A System Dynamics Study of a Decentralized Ride-Hailing Platform. ISYE 681 term paper, Northern Illinois University.

Trip records: NYC Taxi and Limousine Commission, Trip Record Data (public data).

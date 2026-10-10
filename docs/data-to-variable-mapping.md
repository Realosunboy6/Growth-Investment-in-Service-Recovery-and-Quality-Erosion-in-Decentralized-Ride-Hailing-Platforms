# Data-to-variable mapping

How the study's observable quantities are constructed from public data, and which model
variables have no public-data counterpart.

## Anchored in the TLC trip records

| Model quantity | Construction from trip records |
|---|---|
| Completed trips | Row count per day (`data/aggregates/fhvhv_2025-06_daily.csv`); per company per month (`data/aggregates/fhvhv_monthly.csv`) |
| Request-to-pickup (waiting) time | `pickup_datetime − request_datetime`, daily mean (and monthly per-company mean) |
| Fares | `base_passenger_fare` (before tolls and surcharges), daily mean (and monthly per-company mean) |
| Trip-level driver compensation | `driver_pay`, daily mean (and monthly per-company mean) |
| Trip distance / duration | `trip_miles`, `trip_time` (converted from seconds to minutes), daily means (and monthly per-company means) |

Data notes: Juno's series ends November 2019 and Via's ends October 2021, so only
Uber and Lyft span the full 91 months. Via's `driver_pay` values are unusable
($0.35–$14.41, 7% of fare in 2019) and are left blank in the monthly file. The
monthly file includes `trips_per_day` so months of different lengths compare directly.

## Driver and vehicle series (`data/aggregates/fhv_industry_indicators_monthly.csv`)

Monthly unique drivers and vehicles for FHV – High Volume (Jan 2015 – Aug 2026)
support one validation use: the COVID shock as a test of the driver loop's delay.
Drivers fell from 79,282 (Feb 2020) to 22,390 (Apr 2020) and were still 26% below
pre-COVID levels in Jun 2021 while trips recovered faster — the supply lag behind
the observed wait-time spike. `avg_minutes_per_trip` is zero before Jun 2017
(source-data gap, left as published).

## Long series (`data/aggregates/fhvhv_monthly.csv`)

The 91-month per-company series (February 2019 – August 2026) supports three uses:

- **Long-run trip-demand reference** — monthly trip volumes anchor the scale of demand
  the model must reproduce over multi-year horizons.
- **External-shock recovery test** — the 2020 demand collapse is an external shock, not
  evidence of endogenous overshoot and decline; it can test how the model recovers from
  an imposed demand drop.
- **Rough check on the growth loop** — the Uber/Lyft trip split offers a loose
  cross-check on the rider–driver–waiting-time reinforcing loop.

It cannot calibrate complaints, backlog, recovery capacity, or perceived quality (none
appear in the TLC records), and it cannot test the decentralized funding constraint:
Uber and Lyft are large centralized platforms with access to outside capital.

## Benchmarked externally

- **Complaint incidence** — TLC annual reports publish regulatory complaint summaries for
  licensed bases. These benchmark the external complaint rate only; they describe complaints
  filed with the regulator, not the platform's internal complaint arrivals, and cannot
  calibrate an internal backlog model.

## Not observable in public data (assumed parameters)

The following are stated as assumptions and examined through sensitivity analysis
(see `assumed-parameters.md`):

- Complaint arrivals per service failure (complaint sensitivity)
- Unresolved complaint backlog and case-resolution times
- Installed service-recovery capacity and its unit cost
- Revenue-allocation rules (share of platform revenue directed to service recovery)
- Quality-perception delays (how fast riders update perceived service quality)
- Capacity-development times (approval, funding, hiring, training, system implementation)

The study is therefore a partially data-anchored structural experiment: demand, waiting
time, fare, and driver-pay dynamics are grounded in public trip records, while the
service-recovery subsystem is modeled structurally with documented assumptions.

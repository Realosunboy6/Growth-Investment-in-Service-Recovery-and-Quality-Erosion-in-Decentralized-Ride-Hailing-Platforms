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
| Trip distance / duration | `trip_miles`, `trip_time`, daily means (and monthly per-company means) |

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

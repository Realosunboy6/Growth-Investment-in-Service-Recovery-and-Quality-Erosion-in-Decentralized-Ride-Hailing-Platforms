# Data-to-variable mapping

How the study's observable quantities are constructed from public data, and which model
variables have no public-data counterpart.

## Anchored in the TLC trip records

| Model quantity | Construction from trip records |
|---|---|
| Completed trips | Row count per day (`data/aggregates/fhvhv_2025-06_daily.csv`) |
| Request-to-pickup (waiting) time | `pickup_datetime − request_datetime`, daily mean |
| Fares | `base_passenger_fare` plus applicable tolls and surcharges, daily mean |
| Trip-level driver compensation | `driver_pay`, daily mean |
| Trip distance / duration | `trip_miles`, `trip_time`, daily means |

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

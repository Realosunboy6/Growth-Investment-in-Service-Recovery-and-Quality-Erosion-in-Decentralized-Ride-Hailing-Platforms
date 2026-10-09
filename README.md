# Growth, Investment in Service Recovery, and Quality Erosion in Decentralized Ride-Hailing Platforms

Public trip-record and industry data supporting a system dynamics study of growth, service-recovery investment, and quality erosion in decentralized ride-hailing platforms (ISYE 681, Northern Illinois University).

## Contents

- `data/` — trip-record extracts and aggregates
  - `data_dictionary_trip_records_hvfhs.pdf` — official NYC TLC data dictionary for high-volume for-hire vehicle trip records
  - `samples/fhvhv_tripdata_2025-06_sample1pct.parquet` — 1% uniform random sample (seed 681) of June 2025 NYC high-volume for-hire vehicle trips
  - `aggregates/fhvhv_2025-06_daily.csv` — daily aggregates for June 2025: completed trips, mean request-to-pickup time, mean fare, mean driver pay, mean trip miles, mean trip time
- `docs/` — definitions, mappings, and references
  - `field-definitions.md` — vetted definitions of every trip-record field used, including common misinterpretations
  - `data-to-variable-mapping.md` — how each observable model quantity is constructed from the trip records, and which model variables have no public-data counterpart
  - `assumed-parameters.md` — parameters not observable in public data, documented with the ranges examined in sensitivity analysis
  - `literature.md` — verified reference list with DOIs
- `scripts/` — reproducible data preparation
  - `download_tlc_data.sh` — fetches the full monthly trip-record files from the NYC TLC
  - `make_sample.py` — regenerates the 5% sample and the daily aggregates from a downloaded month

## Data sources

All trip records are published by the New York City Taxi and Limousine Commission (TLC) as public data:

- TLC Trip Record Data: https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page
- High-volume for-hire vehicle data dictionary: https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_hvfhs.pdf (copy included in `data/`)
- TLC annual reports (regulatory complaint summaries used as external complaint-incidence benchmarks)

Full monthly files are several hundred megabytes each and are not stored here; `scripts/download_tlc_data.sh` retrieves them, and `scripts/make_sample.py` reproduces the included sample and aggregates exactly.

## Reading the data correctly

Two definitions matter for any analysis built on these files:

- **Passenger waiting time** is `pickup_datetime − request_datetime`. The `trip_time` field measures in-vehicle time only and is not waiting time.
- **`driver_pay`** is per-trip compensation. Dividing it by `trip_time` gives an occupied-trip hourly rate, not true driver earnings, and `fare − driver_pay` is not platform revenue.

`docs/field-definitions.md` documents each field and the misinterpretations it guards against.

## Citation

Ibrahim, O. E. (2026). Growth, Investment in Service Recovery, and Quality Erosion in Decentralized Ride-Hailing Platforms: A System Dynamics Study. ISYE 681, Northern Illinois University.

Trip records: New York City Taxi and Limousine Commission, Trip Record Data (public data).

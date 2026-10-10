# Growth, Investment in Service Recovery, and Quality Erosion in Decentralized Ride-Hailing Platforms

Trip records and documentation for a system dynamics study of growth, service-recovery investment, and quality erosion in decentralized ride-hailing platforms (ISYE 681, Northern Illinois University).

## Data

All trip records are public data from the NYC Taxi and Limousine Commission (TLC):

- TLC Trip Record Data: https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page
- Data dictionary: https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_hvfhs.pdf (copy in `data/`)

| File | Contents |
|---|---|
| `data/samples/fhvhv_tripdata_2025-06_sample1pct.parquet` | 1% uniform random sample (seed 681) of June 2025 high-volume for-hire vehicle trips (~197k trips) |
| `data/aggregates/fhvhv_2025-06_daily.csv` | Daily aggregates, June 2025: trips, mean request-to-pickup time, mean fare, mean driver pay, mean trip miles, mean trip time |
| `data/aggregates/fhvhv_monthly.csv` | Monthly per-company aggregates, Feb 2019 – Aug 2026 (91 months): trips, trips per day, mean request-to-pickup time, mean fare, mean driver pay, mean trip miles, mean trip time; Uber (HV0003), Lyft (HV0005), Juno (HV0002, through Nov 2019), Via (HV0004, through Oct 2021). Via's `driver_pay` values are unusable and left blank. |
| `data/data_dictionary_trip_records_hvfhs.pdf` | Official TLC field definitions |

Raw monthly files are ~500 MB each and are not stored here. `scripts/download_tlc_data.sh` fetches them; `scripts/make_sample.py` and `scripts/tlc_monthly.py` regenerate the sample and the aggregates exactly.

## Definitions that matter

- **Waiting time** = `pickup_datetime − request_datetime`. `trip_time` is in-vehicle time only.
- **`driver_pay`** is per-trip compensation, not hourly earnings.
- **`fare − driver_pay` is not platform revenue.** Taxes, surcharges, and fees sit between them.

Details: `docs/field-definitions.md`. Model-variable mapping: `docs/data-to-variable-mapping.md`. Assumed parameters: `docs/assumed-parameters.md`. References: `docs/literature.md`.

## Citation

Oyeyinka, Ibrahim E. (2026). Growth, Investment in Service Recovery, and Quality Erosion in Decentralized Ride-Hailing Platforms: A System Dynamics Study. ISYE 681, Northern Illinois University.

Trip records: NYC Taxi and Limousine Commission, Trip Record Data (public data).

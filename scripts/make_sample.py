#!/usr/bin/env python3
"""Build the repo's sample and daily aggregates from a full-month FHVHV parquet file.

Streams the file in batches (memory-safe for ~20M-row months).

Usage:
    python3 make_sample.py <input_parquet> <out_dir>

Outputs in <out_dir>:
    samples/fhvhv_tripdata_2025-06_sample1pct.parquet    1% uniform random sample (seed 681)
    aggregates/fhvhv_2025-06_daily.csv                  daily aggregates

Sampling is seeded per batch, so outputs regenerate identically.
"""
import os
import sys

import numpy as np
import pandas as pd
import pyarrow.parquet as pq

SEED = 681
FRAC = 0.01
BATCH = 500_000

KEEP = [
    "hvfhs_license_num", "dispatching_base_num",
    "request_datetime", "on_scene_datetime", "pickup_datetime", "dropoff_datetime",
    "PULocationID", "DOLocationID",
    "trip_miles", "trip_time",
    "base_passenger_fare", "tolls", "bcf", "sales_tax",
    "congestion_surcharge", "airport_fee", "tips", "driver_pay",
    "shared_request_flag", "shared_match_flag",
]


def main():
    src, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir + "/samples", exist_ok=True)
    os.makedirs(out_dir + "/aggregates", exist_ok=True)

    pf = pq.ParquetFile(src)
    sample_parts = []
    # per-day accumulators: date -> [n, wait_sum, fare_sum, pay_sum, miles_sum, time_sum]
    acc = {}
    total = 0
    for bi, batch in enumerate(pf.iter_batches(batch_size=BATCH, columns=KEEP)):
        df = batch.to_pandas()
        total += len(df)
        for c in ("request_datetime", "pickup_datetime", "dropoff_datetime"):
            df[c] = pd.to_datetime(df[c], errors="coerce")
        # Passenger waiting time (minutes): pickup minus request. trip_time is in-vehicle.
        df["wait_min"] = (df["pickup_datetime"] - df["request_datetime"]).dt.total_seconds() / 60.0
        df = df[(df["wait_min"] >= 0) & (df["wait_min"] <= 120)]

        rng = np.random.default_rng(SEED + bi)
        mask = rng.random(len(df)) < FRAC
        sample_parts.append(df.loc[mask])

        df["date"] = df["pickup_datetime"].dt.date
        g = df.groupby("date").agg(
            n=("wait_min", "size"),
            wait=("wait_min", "sum"),
            fare=("base_passenger_fare", "sum"),
            pay=("driver_pay", "sum"),
            miles=("trip_miles", "sum"),
            ttime=("trip_time", "sum"),
        )
        for date, row in g.iterrows():
            a = acc.setdefault(date, [0, 0.0, 0.0, 0.0, 0.0, 0.0])
            a[0] += int(row["n"]); a[1] += row["wait"]; a[2] += row["fare"]
            a[3] += row["pay"]; a[4] += row["miles"]; a[5] += row["ttime"]
        print(f"batch {bi}: {total:,} rows", flush=True)

    sample = pd.concat(sample_parts).sort_index()
    sp = f"{out_dir}/samples/fhvhv_tripdata_2025-06_sample1pct.parquet"
    sample.to_parquet(sp, index=False)
    print(f"sample -> {sp} ({len(sample):,} rows)")

    daily = pd.DataFrame([
        {"date": d, "completed_trips": a[0],
         "mean_wait_min": round(a[1] / a[0], 3),
         "mean_fare": round(a[2] / a[0], 3),
         "mean_driver_pay": round(a[3] / a[0], 3),
         "mean_trip_miles": round(a[4] / a[0], 3),
         "mean_trip_time_s": round(a[5] / a[0], 3)}
        for d, a in sorted(acc.items())
    ])
    ap = f"{out_dir}/aggregates/fhvhv_2025-06_daily.csv"
    daily.to_csv(ap, index=False)
    print(f"aggregates -> {ap} ({len(daily)} days)")
    print(daily.head(3).to_string(index=False))


if __name__ == "__main__":
    main()

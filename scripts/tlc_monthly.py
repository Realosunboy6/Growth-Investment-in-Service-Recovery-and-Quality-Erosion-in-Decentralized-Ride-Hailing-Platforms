#!/usr/bin/env python3
"""Monthly NYC TLC HVFHV aggregates, Feb 2019 - Aug 2026, per company.
Streams one month at a time: download -> aggregate per company -> append CSV -> delete raw.
Resume-safe: months already in the CSV are skipped.
Needs: pyarrow, pandas, requests.
"""
import os, sys, traceback
import requests
import pandas as pd
import pyarrow.parquet as pq

BASE = "https://d37ci6vzurychx.cloudfront.net/trip-data/fhvhv_tripdata_{}.parquet"
WANT = ["hvfhs_license_num", "request_datetime", "pickup_datetime",
        "base_passenger_fare", "driver_pay", "trip_miles", "trip_time"]
NAMES = {"HV0002": "Juno", "HV0003": "Uber", "HV0004": "Via", "HV0005": "Lyft"}
SCRATCH = os.path.expanduser("~/workspace/isye681/data_scratch")
OUT = os.path.join(SCRATCH, "fhvhv_monthly.csv")
LOG = os.path.join(SCRATCH, "tlc_monthly.log")

def log(msg):
    with open(LOG, "a") as f:
        f.write(msg + "\n")
    print(msg, flush=True)

def months():
    for p in pd.period_range("2019-02", "2026-08", freq="M"):
        yield p.strftime("%Y-%m")

def main():
    os.makedirs(SCRATCH, exist_ok=True)
    done = set()
    if os.path.exists(OUT) and os.path.getsize(OUT) > 0:
        done = set(pd.read_csv(OUT, usecols=["month"])["month"].astype(str))
        log(f"resuming: {len(done)} months already in {OUT}")
    for m in months():
        if m in done:
            continue
        path = os.path.join(SCRATCH, f"fhvhv_{m}.parquet")
        try:
            with requests.get(BASE.format(m), stream=True, timeout=180) as r:
                r.raise_for_status()
                with open(path, "wb") as f:
                    for chunk in r.iter_content(1 << 22):
                        f.write(chunk)
            pf = pq.ParquetFile(path)
            schema_cols = set(pf.schema.names)
            cols = [c for c in WANT if c in schema_cols]
            missing = [c for c in WANT if c not in schema_cols]
            parts = []
            for rg in range(pf.num_row_groups):
                t = pf.read_row_group(rg, columns=cols).to_pandas()
                if "request_datetime" in t.columns and "pickup_datetime" in t.columns:
                    t["wait_min"] = (t["pickup_datetime"] - t["request_datetime"]).dt.total_seconds() / 60
                    t = t[(t["wait_min"] >= 0) & (t["wait_min"] < 120)]
                grp = t.groupby("hvfhs_license_num")
                d = {"trips": grp.size()}
                if "wait_min" in t.columns:
                    d["wait_sum"] = grp["wait_min"].sum()
                for c, s in [("base_passenger_fare", "fare_sum"), ("driver_pay", "pay_sum"),
                             ("trip_miles", "miles_sum"), ("trip_time", "dur_sum")]:
                    if c in t.columns:
                        d[s] = grp[c].sum()
                parts.append(pd.DataFrame(d))
            g = pd.concat(parts).groupby(level=0).sum()
            g["mean_wait_min"] = g["wait_sum"] / g["trips"] if "wait_sum" in g.columns else float("nan")
            for s, mc in [("fare_sum", "mean_fare"), ("pay_sum", "mean_driver_pay"),
                          ("miles_sum", "mean_miles"), ("dur_sum", "mean_duration_min")]:
                g[mc] = g[s] / g["trips"] if s in g.columns else float("nan")
            g["mean_duration_min"] = g["mean_duration_min"] / 60  # trip_time is in seconds
            g = g.reset_index().rename(columns={"hvfhs_license_num": "license"})
            g.loc[g["license"] == "HV0004", "mean_driver_pay"] = float("nan")  # Via pay unusable
            y, mo = int(m[:4]), int(m[5:7])
            g["trips_per_day"] = (g["trips"] / __import__("calendar").monthrange(y, mo)[1]).round(1)
            g.insert(0, "month", m)
            g["company"] = g["license"].map(NAMES).fillna("Other")
            keep = ["month", "license", "company", "trips", "trips_per_day", "mean_wait_min",
                    "mean_fare", "mean_driver_pay", "mean_miles", "mean_duration_min"]
            if missing:
                g["missing_cols"] = ";".join(missing)
                keep.append("missing_cols")
            fresh = (not os.path.exists(OUT)) or os.path.getsize(OUT) == 0
            g[keep].to_csv(OUT, mode="a", header=fresh, index=False)
            log(f"{m} ok trips={int(g['trips'].sum())} missing={missing if missing else 'none'}")
        except Exception as e:
            log(f"{m} FAILED: {type(e).__name__}: {e}")
            traceback.print_exc()
        finally:
            if os.path.exists(path):
                os.remove(path)
    log("ALL DONE")

if __name__ == "__main__":
    main()

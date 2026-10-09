#!/usr/bin/env bash
# Download full monthly NYC TLC high-volume FHV trip-record files.
# Usage: ./download_tlc_data.sh [YYYY-MM ...]   (default: 2025-06)
# Files are ~500 MB per month and are not stored in this repository.
set -euo pipefail

BASE="https://d37ci6vzurychx.cloudfront.net/trip-data"
OUTDIR="${OUTDIR:-./tlc_raw}"
mkdir -p "$OUTDIR"

MONTHS=("$@")
if [ ${#MONTHS[@]} -eq 0 ]; then
    MONTHS=("2025-06")
fi

for m in "${MONTHS[@]}"; do
    f="fhvhv_tripdata_${m}.parquet"
    echo "Fetching ${f} ..."
    curl -fL -C - -o "${OUTDIR}/${f}" "${BASE}/${f}"
done

echo "Done. Files in ${OUTDIR}/"
ls -la "$OUTDIR"

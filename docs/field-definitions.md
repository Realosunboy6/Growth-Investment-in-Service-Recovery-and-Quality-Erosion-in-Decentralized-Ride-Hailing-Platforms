# Field definitions: NYC TLC high-volume for-hire vehicle trip records

Source: NYC Taxi and Limousine Commission, data dictionary for high-volume FHV trip records
(`data/data_dictionary_trip_records_hvfhs.pdf`). Field behavior below reflects the dictionary
together with checks run against the June 2025 file.

## Identity and dispatch

- `hvfhs_license_num` — TLC license number of the high-volume for-hire service (the base/company).
- `dispatching_base_num` — base that dispatched the trip. This is a base identifier, **not** a driver identifier. It cannot be used to track individual drivers.
- `originating_base_num` — base where the trip originated, if different from the dispatching base.

## Timestamps

- `request_datetime` — when the passenger requested the trip.
- `on_scene_datetime` — when the driver arrived on scene (may be absent).
- `pickup_datetime` — when the passenger was picked up.
- `dropoff_datetime` — when the passenger was dropped off.

**Passenger waiting time** is defined as `pickup_datetime − request_datetime`, in minutes.
`trip_time` measures in-vehicle time only (seconds) and is not waiting time. Waiting times
below zero or above 120 minutes are treated as data errors and excluded.

## Money

- `base_passenger_fare` — fare charged to the passenger before tolls, taxes, surcharges, and tips.
- `tolls`, `bcf` (black car fund surcharge), `sales_tax`, `congestion_surcharge`,
  `airport_fee`, `cbd_congestion_fee` — additive charges; present only where applicable.
- `tips` — gratuity paid to the driver.
- `driver_pay` — compensation paid to the driver for the trip. This is a **per-trip** figure.
  Dividing `driver_pay` by `trip_time` yields an occupied-trip hourly rate, not true driver
  earnings (it excludes unpaid waiting and repositioning time). The difference between the
  passenger fare and `driver_pay` is **not** platform revenue: it includes third-party fees,
  taxes, and surcharges that never reach the platform.

## Trip attributes

- `PULocationID`, `DOLocationID` — pickup and drop-off taxi zones (not coordinates).
- `trip_miles` — trip distance in miles.
- `shared_request_flag`, `shared_match_flag` — whether a shared ride was requested / matched.
- `access_a_ride_flag`, `wav_request_flag`, `wav_match_flag` — accessible-service indicators.

## Coverage

One row per completed trip. Cancelled requests, unfulfilled requests, and driver
repositioning without a passenger are not present. Internal platform quantities —
complaint arrivals, unresolved complaint backlogs, case-resolution times, and support
capacity — are not in these files (see `data-to-variable-mapping.md`).

# Geometry and coverage

Parcel geometry is keyed by `Parcel_ID`/county `PIN`. The coverage gate only
authorizes parcel IDs present in the imported CSV snapshot. Tile coverage is
bounded to the CSV-backed county envelope until the county geometry import
populates an exact tile index.

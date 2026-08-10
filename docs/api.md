# Read-only API

The first Zig service exposes:

- `GET /healthz`
- `GET /api/v1/years`
- `GET /api/v1/properties/search?q=...&year=...`
- `GET /api/v1/properties/{parcel_id}?year=...`
- `GET /api/v1/rankings?year=...`
- `GET /api/v1/map?year=...`
- `GET /tiles/{z}/{x}/{y}.png`

All routes are read-only. Unknown parcel IDs are rejected; no upload or
external geocoder route exists. Geometry remains null until the county GIS
join is published, so the service cannot expose non-CSV property shapes.

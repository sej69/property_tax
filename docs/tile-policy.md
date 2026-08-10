# Tile proxy policy

MapLibre requests OpenStreetMap raster tiles through the Zig `/tiles/{z}/{x}/{y}.png`
route. The policy object fixes a seven-day maximum cache age, restricts the
upstream host to `tile.openstreetmap.org`, and requires a non-empty CSV-backed
coverage index before a tile request is authorized. OpenStreetMap attribution
is visible in the UI. The proxy must use HTTPS upstream and an identifiable
User-Agent in production.

# Tile proxy policy

MapLibre requests OpenStreetMap raster tiles through the Zig `/tiles/{z}/{x}/{y}.png`
route. The policy object fixes a seven-day maximum cache age, restricts the
upstream host to `tile.openstreetmap.org`, and requires a non-empty CSV-backed
county coverage envelope before a tile request is authorized. Fresh tiles are
fetched over HTTPS and stored under `.cache/tiles/{z}/{x}/{y}.png`; subsequent
requests within seven days are served locally. OpenStreetMap attribution is
visible in the UI, and the proxy sends an identifiable User-Agent upstream.

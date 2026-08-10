# Ingestion

The importer reads the enhanced county CSV schema, discovers tax years from
the `Tax_Year` column, and keeps `Parcel_ID` as a 12-character text value.
Duplicate normalized parcel IDs are rejected. Tax and physical fields remain
typed; blank comparable inputs remain zero/unknown and are reflected in
confidence rather than silently becoming match features.

The production import path is intended to publish immutable annual snapshots
through the PolymorphDB provider boundary.

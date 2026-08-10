# PolymorphDB provider boundary

`provider.Provider` is the application seam for PolymorphDB. It exposes parcel
lookup and normalized address search without allowing HTTP handlers to depend
on a database-specific API. The current in-memory store is a deterministic
vertical-slice fixture; the Linux deployment replaces its backing operations
with the documented native Zig PolymorphDB interface.

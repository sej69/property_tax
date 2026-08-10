# Service contract

The service accepts `--csv <path>`, `--port <port>`, and `--check`. `--check`
loads and validates the operator dataset, reports accepted records and years,
then exits without opening a listener.

Public routes are read-only GET routes. Upload, mutation, and authentication
routes are intentionally absent.


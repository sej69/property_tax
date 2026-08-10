---
work_package_id: WP01
title: Build Zig service and versioned ingestion
dependencies: []
requirement_refs: [FR-001, FR-002, FR-003, FR-004, FR-005, NFR-004, NFR-005]
planning_base_branch: main
merge_target_branch: main
subtasks: [T001, T002, T003, T004]
task_type: implement
tracker_refs:
  - https://github.com/sej69/property_tax/issues/1
  - https://github.com/sej69/property_tax/issues/2
---

# Objective

Create the initial Linux Zig service and deterministic staged CSV ingestion.
Python remains an operator download utility, not an application runtime.

## Subtasks

- T001: Create `build.zig`, service entry point, configuration, health endpoint,
  logging, and minimal static-asset response.
- T002: Implement strict CSV parsing and normalized property/property-year rows
  containing the comparable fields from the mission specification.
- T003: Normalize `Parcel_ID`/`PIN` as 12-character text, detect duplicates,
  quarantine invalid rows, discover years, and produce checksums/reports.
- T004: Add fixtures for leading zeroes, missing fields, non-standard classes,
  zero market value, and failed publication.

## Validation and definition of done

- `zig fmt --check` or repository equivalent and `zig build test` pass.
- A fixture publishes only after validation and leaves the prior version active
  after a deliberate failure.
- No raw CSV is required in Git or sent to the browser.

# Work Packages: property-tax-explorer-01KZPH51

The work packages below are the executable decomposition of the mission plan.
GitHub issues remain the public ticket record; every issue is mapped to at least
one package in `wps.yaml`.

## WP01 — Zig service and versioned ingestion

**Dependencies**: None  
**Issues**: #1, #2  
**Prompt**: `tasks/WP01-zig-service-and-ingestion.md`

## WP02 — PolymorphDB provider vertical slice

**Dependencies**: WP01  
**Issue**: #3  
**Prompt**: `tasks/WP02-polymorphdb-provider.md`

## WP03 — County geometry and coverage

**Dependencies**: WP01  
**Issue**: #4  
**Prompt**: `tasks/WP03-geometry-and-coverage.md`

## WP04 — Hierarchical comparable engine

**Dependencies**: WP01, WP02  
**Issue**: #5  
**Prompt**: `tasks/WP04-comparable-engine.md`

## WP05 — Rankings and read-only API

**Dependencies**: WP02, WP03, WP04  
**Issues**: #6, #7  
**Prompt**: `tasks/WP05-rankings-and-api.md`

## WP06 — Seven-day tile proxy and cache

**Dependencies**: WP03, WP05  
**Issue**: #8  
**Prompt**: `tasks/WP06-tile-proxy.md`

## WP07 — Property search and detail UI

**Dependencies**: WP05, WP06  
**Issue**: #9  
**Prompt**: `tasks/WP07-property-ui.md`

## WP08 — County-wide map explorer

**Dependencies**: WP05, WP06  
**Issue**: #10  
**Prompt**: `tasks/WP08-county-map-ui.md`

## WP09 — Import publication and operations

**Dependencies**: WP01–WP08  
**Issue**: #11  
**Prompt**: `tasks/WP09-operations.md`

## WP10 — Validation and release evidence

**Dependencies**: WP05–WP09  
**Issue**: #12  
**Prompt**: `tasks/WP10-validation.md`

## WP11 — Independent statistical model

**Dependencies**: WP04, WP05, WP10  
**Issue**: #13  
**Prompt**: `tasks/WP11-statistical-model.md`

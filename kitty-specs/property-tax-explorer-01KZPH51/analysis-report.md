---
schema_version: 1
artifact_type: spec-kitty.analysis-report
command: /spec-kitty.analyze
mission_slug: property-tax-explorer-01KZPH51
mission_id: 01KZPH51EJ9CBPM1GSHPHTS75M
generated_at: '2026-08-10T20:00:48.999435+00:00'
analyzer_agent: codex
input_artifacts:
  spec.md:
    path: D:\dev case\taxes\.spec-kitty-root\kitty-specs\property-tax-explorer-01KZPH51\spec.md
    sha256: 5ec82b75f089b94a1d3763417e621911e2e6364e29e916f1a94a917a43895a6f
  plan.md:
    path: D:\dev case\taxes\.spec-kitty-root\kitty-specs\property-tax-explorer-01KZPH51\plan.md
    sha256: 3615b0f28cf5d07f2bcdd76b666cc8c86fa85bf48de177bf0f838785d0a49b05
  tasks.md:
    path: D:\dev case\taxes\.spec-kitty-root\kitty-specs\property-tax-explorer-01KZPH51\tasks.md
    sha256: ab6a26c8103cab79d8f8fb73bcf50755990c31cc24bdc524de02bbcd07b4e9f0
  charter:
    path: D:\dev case\taxes\.spec-kitty-root\.kittify\charter\charter.md
    sha256: e84b82c31cb2c15a8401b8db2f16ff68016594f4f45603b893560cf39b9d6717
verdict: unknown
issue_counts:
  info:
  critical:
  low:
  medium:
  high:
findings: []
---

---
schema_version: 1
artifact_type: spec-kitty.analysis-report
command: /spec-kitty.analyze
mission_slug: property-tax-explorer-01KZPH51
mission_id: 01KZPH51EJ9CBPM1GSHPHTS75M
generated_at: '2026-08-10T20:00:31.355650+00:00'
analyzer_agent: codex
input_artifacts:
  spec.md:
    path: D:\dev case\taxes\.spec-kitty-root\kitty-specs\property-tax-explorer-01KZPH51\spec.md
    sha256: 5ec82b75f089b94a1d3763417e621911e2e6364e29e916f1a94a917a43895a6f
  plan.md:
    path: D:\dev case\taxes\.spec-kitty-root\kitty-specs\property-tax-explorer-01KZPH51\plan.md
    sha256: 3615b0f28cf5d07f2bcdd76b666cc8c86fa85bf48de177bf0f838785d0a49b05
  tasks.md:
    path: D:\dev case\taxes\.spec-kitty-root\kitty-specs\property-tax-explorer-01KZPH51\tasks.md
    sha256: ab6a26c8103cab79d8f8fb73bcf50755990c31cc24bdc524de02bbcd07b4e9f0
  charter:
    path: D:\dev case\taxes\.spec-kitty-root\.kittify\charter\charter.md
    sha256: e84b82c31cb2c15a8401b8db2f16ff68016594f4f45603b893560cf39b9d6717
verdict: unknown
issue_counts:
  critical:
  medium:
  low:
  high:
  info:
findings: []
---

# Mission analysis: property tax explorer

## Scope and current repository

The repository currently contains the Anoka County downloader scripts, field-map metadata, architecture recommendation, functionality requirements, and `save/` operational notes. The published CSV files remain local/ignored source inputs. The application is a read-only public explorer and must not expose an upload path.

## Architectural decisions confirmed by the mission

- The implementation language is Zig, targeting Linux and self-hosted deployment.
- PolymorphDB is the database provider. The application will depend on a narrow native Zig provider boundary so database integration can be tested independently from the HTTP and map layers.
- MapLibre is the browser map renderer. OpenStreetMap is the default basemap/source attribution path. Parcel coverage is limited to addresses present in the imported CSV data.
- Map tile access is proxied and cached for seven days. The proxy must enforce the approved tile source, HTTPS upstream access, rate limits, and the CSV-backed coverage rule.
- Projection handling is isolated behind a geometry boundary; `proj.org` is optional and only used when source and display coordinate systems require transformation.
- Data is versioned by year. Available years are discovered from imported files rather than hard-coded.

## Data and comparison model

Parcel identifiers are text values and must preserve leading zeroes. Each annual record retains the tax-context fields needed by the comparable engine: `Levy_Code`, `Property_Class`, `Homestead`, and assessor `Neighborhood`. Candidate eligibility is constrained by those fields before physical similarity is scored.

Physical similarity uses normalized living area, market/assessed value, year built, lot acreage, bedrooms, bathrooms, structure/stories/basement, and related building/land values. Tax amount and effective tax rate are excluded from matching. The engine applies tolerance limits, selects approximately 10–20 nearest eligible properties, reports the median and percentile range, and emits comparable and confidence scores. Anomaly rankings are calculated per selected year across the county.

## Dependency order and integration risks

1. Establish the Zig build, typed annual ingestion, and stable parcel keys.
2. Add the PolymorphDB provider contract and fixture-backed vertical slice.
3. Join geometry and build CSV-backed coverage indexes.
4. Implement hierarchical comparables and annual ranking projections.
5. Expose read-only property/year/ranking endpoints.
6. Add the seven-day tile proxy.
7. Build property detail and county map views with year cycling.
8. Add import publication, HTTPS/self-hosting configuration, and validation.
9. Keep the independent statistical model as a separately documented phase-two projection that does not gate the initial explorer.

## Acceptance risks to test explicitly

- Leading-zero parcel IDs must survive ingestion, provider round trips, API serialization, and search.
- A property outside the imported CSV coverage must not receive parcel geometry or tile access.
- Comparables from a different levy code, class, homestead status, or neighborhood must be rejected before scoring.
- Effective tax rate is never a comparable feature.
- Missing years and sparse/rural comparable pools must produce an explicit confidence level, not fabricated precision.
- Public endpoints remain read-only, do not accept uploads, and do not require authentication.
- Tile caching and attribution must remain within the seven-day policy and OpenStreetMap/MapLibre licensing requirements.

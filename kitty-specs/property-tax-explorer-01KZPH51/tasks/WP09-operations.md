---
work_package_id: WP09
title: Add import publication and self-hosted operations
dependencies:
- WP01
- WP02
- WP03
- WP04
- WP05
- WP06
- WP07
- WP08
requirement_refs:
- FR-005
- FR-023
- NFR-004
- NFR-005
tracker_refs:
- https://github.com/sej69/property_tax/issues/11
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
subtasks:
- T028
- T029
- T030
history: []
authoritative_surface: operations/
create_intent:
- operations/operations.zig
- deploy/Caddyfile
- docs/deployment.md
- tests/lifecycle_test.zig
execution_mode: code_change
owned_files:
- operations/operations.zig
- deploy/Caddyfile
- docs/deployment.md
- tests/lifecycle_test.zig
tags: []
task_type: implement
---

# Objective

Make import, derived rebuild, publication, restart, and HTTPS-compatible
self-hosting operationally safe.

## Subtasks

- T028: Add import/rebuild commands, staging, checksums, reports, and
  last-known-good publication.
- T029: Add lifecycle logging, restart recovery, cache persistence, and
  Caddy/reverse-proxy deployment guidance.
- T030: Exercise failed and successful imports against a Linux lifecycle fixture.

## Definition of done

- Failed imports cannot replace active data.
- All derived views publish together under one dataset version.

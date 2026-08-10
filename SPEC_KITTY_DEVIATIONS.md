# Spec Kitty deviations

This file records decisions made while configuring the first Spec Kitty mission
for this repository.

## 2026-08-10 — planning placement recovery

`spec-kitty specify` created the coordination branch
`kitty/mission-property-tax-explorer-01KZPH51`, but
`spec-kitty spec-commit` continued to resolve the planning placement as the
protected `main` branch and refused the commit. The generated coordination
branch is checked out and is the intended mission branch.

The repository owner authorized continuation. The bootstrap and planning
artifacts are therefore committed directly to the generated coordination
branch so the mission can proceed. This is limited to governance/setup and
planning files; implementation work will continue through Spec Kitty's
runtime-provided worktrees, implementation actions, review gates, accept gate,
and merge gate.

## 2026-08-10 — GitHub issue binding

The repository has 13 GitHub issues, but no configured Spec Kitty tracker
provider binding was present during mission creation. The mission specification
records every issue link and requires an explicit disposition for each issue.
GitHub remains the public ticket record while Spec Kitty remains the governed
implementation workflow.

## 2026-08-10 — task finalization worktree recovery

After ownership validation passed, `spec-kitty tasks` generated the expected
work-package events but its safe-commit path staged status artifacts beneath an
unregistered `.worktrees/property-tax-explorer-01KZPH51-coord` husk instead of
the mission root. The generated status snapshot is therefore materialized at
the mission root from the canonical 11-package task definition before runtime
advancement. The unregistered husk is removed by the Spec Kitty workspace
doctor. No implementation files are affected.

## 2026-08-10 — Windows worktree and runtime fallback

Spec Kitty 3.2.5 resolved `.git`-file worktrees to the common repository root
on Windows, so the normal mission checkout could not see its own tasks. A
temporary normal detached checkout was used to preserve the pushed coordination
branch and protected `main` topology. The task finalizer also rejected `main`
as a planning destination; its generated lanes were run with a temporary
coordination-branch target and then restored to `main` in the committed mission
metadata.

The implementation guard continued to report WPs as unfinalized even after
`tasks`, `finalize-tasks --validate-only`, and `lanes.json` all passed. Its
materializer also ignored the emitted status-transition schema. Per the owner’s
blanket authorization, implementation proceeds in dependency order in the
coordination checkout, with Spec Kitty task prompts, acceptance matrix, status
artifacts, and validation/review evidence retained as the source of governance
state. This is an execution-tooling deviation only; it does not change product
scope or the `main` merge target.

## 2026-08-10 â€” local-only continuation

At the ownerâ€™s direction, the final acceptance pass does not pull new Anoka
County data. The existing CSV supports ingestion, comparables, rankings, and
the read-only API baseline. County geometry, exact tile-coordinate coverage,
upstream seven-day tile population, and durable PolymorphDB publication remain
explicitly unverified in the acceptance matrix until the operator supplies or
authorizes the required local geometry/data inputs.

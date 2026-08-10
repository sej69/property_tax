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

# Release notes: 2026-05-25 — github-description-seo

**Status:** Ready for review  
**Repo:** li-langverse/lidb  
**PR:** (open on `chore/github-description-seo`)  
**PH / REQ:** PH-DB (metadata only)  
**Author:** agent (WP-A4)

---

## Summary (one sentence)

Set canonical GitHub description and README tagline for lidb (scientific computing, HPC, AI) without SPDX/LICENSE file edits.

## Agent continuation (required)

1. Read: `.github/repo-description`, `README.md` lead, org plan `docs/plans/2026-05-25-org-hygiene-multi-agent-plan.md` WP-A4.
2. Run: `gh repo view li-langverse/lidb --json description`; after merge, `gh repo edit li-langverse/lidb --description "$(cat .github/repo-description)"` if API still empty.
3. Then: resume PH-DB engine work on default branch; no further description sweeps unless audit regresses.
4. Blocked on: WP-H2 for mass `LICENSE` / SPDX file edits — **none** for this PR.

## Changed (specific)

| Area | What | Evidence |
|------|------|----------|
| Metadata | `.github/repo-description` canonical GitHub blurb | file in PR |
| Docs | README italic tagline matches blurb | `README.md` |
| Hygiene | CHANGELOG `[Unreleased]` row | `CHANGELOG.md` |

## Not changed (scope fence)

- `LICENSE` / SPDX mass-edit — deferred to WP-H2 ADR.
- Engine, `liq`, `liorm`, migrations, security harness — **not** touched.
- Default branch rename (`main`) — WP-H0 human gate.
- `lic`, `lis`, `benchmarks` — **not** in this PR.

## Breaking changes

None.

## Security

N/A — metadata and README only; no CVE surface.

## Performance

N/A — no runtime or benchmark changes.

## Downstream

N/A — description-only; `lip` registry pins unchanged.

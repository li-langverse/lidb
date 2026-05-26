# PH-DB cross-repo CI gate (WP-G)

Per-repo **`ci`** runs full pytest + security harness. **WP-G** adds a faster cross-repo signal: native smoke + key pytest subset + optional `lidb_embed` artifact.

## Local

```bash
./scripts/ci_ph_db_gate.sh
```

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `LIDB_BUILD_DIR` | `./build/smoke` | CMake out dir for `lidb_embed` |
| `LIDB_CI_REF` | `main` | Git ref when **consumers** checkout this repo (set in caller workflow) |
| `LIDB_REPO` | sibling `../lidb` | Path used by **lis** / agents |
| `LI_LIDB_REPO` | sibling `../lidb` | Path used by **li-cursor-agents** bridge |

## Workflows

| Workflow | Trigger | What it proves |
|----------|---------|----------------|
| `ci.yml` | PR, push | Full native smoke + pytest + security harness |
| `ph-db-gate.yml` | PR, push, dispatch | Smoke + subset pytest + uploads `lidb_embed` artifact |
| `ph-db-reusable-embed.yml` | `workflow_call` | Same as gate; consumed by **lis** when merged to default branch |

## Downstream consumers

- **lis** — `.github/workflows/ph-db-cross-repo.yml` checks out lidb, runs this gate + `db-smoke.sh`
- **li-cursor-agents** — `ph-db-lidb-engine.yml` (`workflow_dispatch` only) runs `npm run test:e2e:lidb-engine`
- **lic** — optional `ph-db-cross-repo-gate.yml` manual aggregator (dispatch only; not a PR matrix)

**Honest scope:** engine e2e in cloud CI is **manual dispatch only** until quota and flake budget allow PR gating.

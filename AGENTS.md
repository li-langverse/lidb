# Agent instructions (`lidb`)

1. **Roadmap agent-kit** — `./scripts/sync-agent-kit.sh` after `../roadmap/agent-kit/` changes.
2. **Shared policy** — `li-pr-only.mdc`, `li-ecosystem-gates.mdc`, `li-release-notes.mdc` (synced from roadmap).
3. **Commit when done** — verified slice → feature branch commit, push, open/update PR; do not self-merge.
4. **Preflight** — sibling `benchmarks` `scripts/agent-briefing.py`; agents read `data/latest/agent-briefing.json`.

Skills: `li-ecosystem-discipline`, `write-li-release-notes` (from agent-kit).

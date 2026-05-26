"""Catalog allowlist — registry + control-plane tables (PH-DB-2)."""

from __future__ import annotations

from liorm.errors import CatalogError

# schema.table -> allowed columns (None = all columns allowed at compile time)
_REGISTRY: dict[str, frozenset[str] | None] = {
    "public.publishers": frozenset(
        {"id", "name", "display_name", "public_key", "created_at", "revoked_at"}
    ),
    "public.packages": frozenset(
        {"id", "name", "description", "repository_url", "created_at"}
    ),
    "public.package_versions": frozenset(
        {
            "id",
            "package_id",
            "version",
            "tree_digest",
            "tarball_sha256",
            "proof_digest",
            "coverage_pct",
            "publisher_id",
            "published_at",
            "yanked",
        }
    ),
    "public.attestations": frozenset(
        {"id", "package_version_id", "kind", "digest", "signature", "created_at"}
    ),
    "public.yanks": frozenset(
        {"id", "package_version_id", "reason", "yanked_by", "yanked_at"}
    ),
    "public.blocklist": frozenset(
        {"id", "package_name", "tree_digest", "reason", "created_at"}
    ),
    "public.schema_migrations": frozenset({"version", "checksum", "applied_at"}),
}

_CONTROL_PLANE: dict[str, frozenset[str] | None] = {
    "public.agent_runs": frozenset(
        {
            "id",
            "run_id",
            "agent_id",
            "publisher_id",
            "created_at",
            "started_at",
            "finished_at",
            "completed_at",
            "status",
            "backend",
            "briefing_hash",
            "reason",
            "fingerprint",
            "coordinator",
            "duration_ms",
            "output",
            "output_md",
            "output_path",
            "error",
            "completion",
            "pr_urls",
            "deliverables",
            "meta",
            "updated_at",
        }
    ),
    "public.agent_run_events": frozenset({"run_id", "seq", "event_type", "payload"}),
    "public.control_plane_state": frozenset({"id", "payload", "updated_at"}),
    "public.control_plane_reports": frozenset(
        {"id", "briefing_hash", "generated_at", "is_latest", "payload"}
    ),
    "public.interventions_snapshots": frozenset(
        {"id", "briefing_hash", "generated_at", "items"}
    ),
    "public.briefing_snapshots": frozenset(
        {"briefing_hash", "generated_at", "payload"}
    ),
    "public.heap_plan_snapshots": frozenset(
        {"briefing_hash", "generated_at", "payload"}
    ),
    "public.queued_agent_tasks": frozenset(
        {"briefing_hash", "fingerprint", "agent_id", "reason", "payload"}
    ),
    "public.repo_workflow_rollouts": frozenset(
        {"run_id", "repo", "pr_url", "install_ok", "created_at"}
    ),
}

CATALOG_ALLOWLIST: dict[str, frozenset[str] | None] = {
    **_REGISTRY,
    **_CONTROL_PLANE,
}


def _split_ident(raw: str) -> tuple[str, str]:
    parts = raw.split(".")
    if len(parts) == 1:
        return "public", parts[0]
    if len(parts) == 2:
        return parts[0], parts[1]
    raise CatalogError(f"invalid ident: {raw}")


def resolve_table(raw: str) -> tuple[str, str]:
    schema, name = _split_ident(raw)
    key = f"{schema}.{name}"
    if key not in CATALOG_ALLOWLIST:
        raise CatalogError(f"table not in catalog allowlist: {key}")
    return schema, name


def resolve_column(table_raw: str, column: str) -> tuple[str, str, str]:
    schema, name = resolve_table(table_raw)
    key = f"{schema}.{name}"
    allowed = CATALOG_ALLOWLIST[key]
    if allowed is not None and column not in allowed:
        raise CatalogError(f"column not in catalog: {key}.{column}")
    return schema, name, column

"""Frozen registry-min plans aligned with migrations/001_registry.sql and lip read paths."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class RegistryPlanSpec:
    name: str
    plan_id: str
    sql: str
    param_schema: dict[str, str]
    ir: dict[str, Any]


# Unquoted identifiers — native embed flatten + exec-json (PH-DB-3.1).
_REGISTRY_PLANS: tuple[RegistryPlanSpec, ...] = (
    RegistryPlanSpec(
        name="registry.package_by_name",
        plan_id="registry:package_by_name:v1",
        sql="SELECT id, name, description, repository_url FROM packages WHERE name = $1 LIMIT 1",
        param_schema={"name": "text"},
        ir={"verb": "read", "table": "packages", "filter": "name"},
    ),
    RegistryPlanSpec(
        name="registry.version_by_pkg_version",
        plan_id="registry:version_by_pkg_version:v1",
        sql=(
            "SELECT id, package_id, version, tree_digest, proof_digest, coverage_pct, "
            "publisher_id, published_at, yanked FROM package_versions "
            "WHERE package_id = $1 AND version = $2 LIMIT 1"
        ),
        param_schema={"package_id": "uuid", "version": "text"},
        ir={"verb": "read", "table": "package_versions", "filter": ["package_id", "version"]},
    ),
    RegistryPlanSpec(
        name="registry.versions_for_package",
        plan_id="registry:versions_for_package:v1",
        sql=(
            "SELECT id, version, tree_digest, proof_digest, coverage_pct, published_at, yanked "
            "FROM package_versions WHERE package_id = $1"
        ),
        param_schema={"package_id": "uuid"},
        ir={"verb": "read", "table": "package_versions", "filter": "package_id"},
    ),
    RegistryPlanSpec(
        name="registry.insert_package",
        plan_id="registry:insert_package:v1",
        sql="INSERT INTO packages (id, name, description, repository_url) VALUES ($1, $2, $3, $4)",
        param_schema={
            "id": "uuid",
            "name": "text",
            "description": "text",
            "repository_url": "text",
        },
        ir={"verb": "insert", "table": "packages"},
    ),
    RegistryPlanSpec(
        name="registry.insert_package_version",
        plan_id="registry:insert_package_version:v1",
        sql=(
            "INSERT INTO package_versions "
            "(id, package_id, version, tree_digest, proof_digest, coverage_pct, publisher_id) "
            "VALUES ($1, $2, $3, $4, $5, $6, $7)"
        ),
        param_schema={
            "id": "uuid",
            "package_id": "uuid",
            "version": "text",
            "tree_digest": "text",
            "proof_digest": "text",
            "coverage_pct": "text",
            "publisher_id": "uuid",
        },
        ir={"verb": "insert", "table": "package_versions"},
    ),
    RegistryPlanSpec(
        name="registry.publisher_by_name",
        plan_id="registry:publisher_by_name:v1",
        sql="SELECT id, name FROM publishers WHERE name = $1 LIMIT 1",
        param_schema={"name": "text"},
        ir={"verb": "read", "table": "publishers", "filter": "name"},
    ),
    RegistryPlanSpec(
        name="registry.insert_publisher",
        plan_id="registry:insert_publisher:v1",
        sql="INSERT INTO publishers (id, name, public_key) VALUES ($1, $2, $3)",
        param_schema={"id": "uuid", "name": "text", "public_key": "text"},
        ir={"verb": "insert", "table": "publishers"},
    ),
)


def all_registry_plans() -> tuple[RegistryPlanSpec, ...]:
    return _REGISTRY_PLANS

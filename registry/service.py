"""Registry OLTP service — real lidb reads/writes via liorm (PH-DB-4 MVP)."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from typing import Any

from registry.bootstrap import register_registry_plans
from liorm.embed_engine import engine_ready, probe_engine_ready
from liorm.execute import ExecuteResult, execute


@dataclass(frozen=True)
class PackageVersionRecord:
    """Shape aligned with lip GET /packages/{name}/{version} (read path only)."""

    name: str
    version: str
    tree_digest: str
    proof_digest: str | None
    coverage_pct: float
    publisher_id: str
    published_at: str | None
    yanked: bool
    package_id: str
    version_id: str

    def to_api_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "version": self.version,
            "tree_digest": self.tree_digest,
            "proof_digest": self.proof_digest,
            "coverage_pct": self.coverage_pct,
            "publisher_id": self.publisher_id,
            "published_at": self.published_at,
            "yanked": self.yanked,
        }


class RegistryOltp:
    """
    Central registry OLTP facade over lidb embed + frozen liorm plans.

    Multi-table joins are composed in Python until the native executor gains JOIN.
    """

    def __init__(self) -> None:
        register_registry_plans()

    @staticmethod
    def ready() -> bool:
        return probe_engine_ready()

    @staticmethod
    def engine_available() -> bool:
        return engine_ready()

    def get_package_version(self, name: str, version: str) -> PackageVersionRecord | None:
        pkg_rows = self._run("registry:package_by_name:v1", {"name": name}).rows
        if not pkg_rows:
            return None
        pkg = pkg_rows[0]
        pkg_id = str(pkg["id"])
        for row in self._run("registry:versions_for_package:v1", {"package_id": pkg_id}).rows:
            if str(row.get("version")) == version:
                row = dict(row)
                row["package_id"] = pkg_id
                return self._row_to_record(name, row)
        return None

    def list_package_versions(
        self,
        name: str,
        *,
        include_yanked: bool = False,
    ) -> list[PackageVersionRecord]:
        pkg_rows = self._run("registry:package_by_name:v1", {"name": name}).rows
        if not pkg_rows:
            return []
        pkg_id = str(pkg_rows[0]["id"])
        rows = self._run("registry:versions_for_package:v1", {"package_id": pkg_id}).rows
        out: list[PackageVersionRecord] = []
        for row in rows:
            rec = self._row_to_record(name, row)
            if not include_yanked and rec.yanked:
                continue
            out.append(rec)
        return out

    def publish_package_version(
        self,
        *,
        publisher_name: str,
        publisher_public_key: bytes | str,
        package_name: str,
        version: str,
        tree_digest: str,
        coverage_pct: float,
        proof_digest: str | None = None,
        package_description: str | None = None,
        repository_url: str | None = None,
    ) -> PackageVersionRecord:
        pub_id = self._ensure_publisher(publisher_name, publisher_public_key)
        pkg_id = self._ensure_package(package_name, package_description, repository_url)
        ver_id = str(uuid.uuid4())
        self._run(
            "registry:insert_package_version:v1",
            {
                "id": ver_id,
                "package_id": pkg_id,
                "version": version,
                "tree_digest": tree_digest,
                "proof_digest": proof_digest if proof_digest else "-",
                "coverage_pct": str(coverage_pct),
                "publisher_id": pub_id,
            },
        )
        rec = self.get_package_version(package_name, version)
        if rec is None:
            raise RuntimeError("publish succeeded but read-back failed")
        return rec

    def _ensure_publisher(self, name: str, public_key: bytes | str) -> str:
        existing = self._run("registry:publisher_by_name:v1", {"name": name}).rows
        if existing:
            return str(existing[0]["id"])
        pub_id = str(uuid.uuid4())
        key = public_key.decode("latin-1") if isinstance(public_key, bytes) else public_key
        self._run(
            "registry:insert_publisher:v1",
            {"id": pub_id, "name": name, "public_key": key},
        )
        return pub_id

    def _ensure_package(
        self,
        name: str,
        description: str | None,
        repository_url: str | None,
    ) -> str:
        existing = self._run("registry:package_by_name:v1", {"name": name}).rows
        if existing:
            return str(existing[0]["id"])
        pkg_id = str(uuid.uuid4())
        # Non-empty sentinels — liorm rejects param values that appear verbatim in SQL text (empty str matches).
        self._run(
            "registry:insert_package:v1",
            {
                "id": pkg_id,
                "name": name,
                "description": description if description else "-",
                "repository_url": repository_url if repository_url else "-",
            },
        )
        return pkg_id

    @staticmethod
    def _run(plan_id: str, params: dict[str, Any]) -> ExecuteResult:
        return execute(plan_id, params)

    @staticmethod
    def _row_to_record(package_name: str, row: dict[str, Any]) -> PackageVersionRecord:
        yanked_raw = row.get("yanked", False)
        yanked = yanked_raw in (True, "true", "1", 1)
        proof = row.get("proof_digest")
        return PackageVersionRecord(
            name=package_name,
            version=str(row["version"]),
            tree_digest=str(row["tree_digest"]),
            proof_digest=str(proof) if proof not in (None, "") else None,
            coverage_pct=float(row.get("coverage_pct", 0)),
            publisher_id=str(row.get("publisher_id", "")),
            published_at=str(row["published_at"]) if row.get("published_at") else None,
            yanked=yanked,
            package_id=str(row.get("package_id", "")),
            version_id=str(row["id"]),
        )

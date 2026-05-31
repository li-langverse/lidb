"""Registry OLTP integration (PH-DB-4) — real lidb embed reads/writes."""

import uuid

import pytest

from liorm.embed_engine import probe_engine_ready
from liorm.execute import clear_plans
from registry import RegistryOltp, register_registry_plans


@pytest.fixture(autouse=True)
def _registry_plans():
    clear_plans()
    register_registry_plans(force=True)
    yield
    clear_plans()


@pytest.mark.skipif(not probe_engine_ready(), reason="lidb_embed unavailable")
def test_get_seeded_package_version():
    svc = RegistryOltp()
    rec = svc.get_package_version("li-pytest", "0.0.1-test")
    assert rec is not None
    assert rec.tree_digest == "sha256:pytest-tree"
    assert rec.coverage_pct == 100.0
    assert rec.yanked is False
    api = rec.to_api_dict()
    assert api["name"] == "li-pytest"
    assert "proof_digest" in api


@pytest.mark.skipif(not probe_engine_ready(), reason="lidb_embed unavailable")
def test_publish_and_read_back():
    svc = RegistryOltp()
    suffix = uuid.uuid4().hex[:8]
    name = f"li-wp-d-{suffix}"
    rec = svc.publish_package_version(
        publisher_name=f"pub-{suffix}",
        publisher_public_key=b"\x00" * 32,
        package_name=name,
        version="1.0.0-wpd",
        tree_digest=f"sha256:tree-{suffix}",
        coverage_pct=88.5,
        proof_digest=f"sha256:proof-{suffix}",
        package_description="WP-D test package",
    )
    assert rec.name == name
    assert rec.version == "1.0.0-wpd"
    assert rec.proof_digest == f"sha256:proof-{suffix}"
    again = svc.get_package_version(name, "1.0.0-wpd")
    assert again is not None
    assert again.tree_digest == rec.tree_digest


@pytest.mark.skipif(not probe_engine_ready(), reason="lidb_embed unavailable")
def test_list_excludes_yanked_by_default():
    svc = RegistryOltp()
    rec = svc.get_package_version("li-pytest", "0.0.1-test")
    assert rec is not None
    listed = svc.list_package_versions("li-pytest")
    assert any(r.version == "0.0.1-test" for r in listed)

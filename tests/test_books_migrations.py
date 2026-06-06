"""WP-020: li-books schema migration smoke tests."""

from __future__ import annotations

import re
from pathlib import Path

import pytest

pytestmark = pytest.mark.schema_only

ROOT = Path(__file__).resolve().parents[1]

REQUIRED_TABLES = (
    "finance_org",
    "org_member",
    "bookkeeping_account",
    "de_tax_category",
    "blob_object",
    "receipts",
    "receipt_line_items",
    "clarification_thread",
    "clarification_question",
    "clarification_answer",
    "chat_session",
    "chat_message",
    "finance_action_audit",
)


def test_finance_org_migration_exists():
    path = ROOT / "migrations" / "007_finance_org.sql"
    assert path.is_file()
    text = path.read_text(encoding="utf-8")
    for table in REQUIRED_TABLES:
        assert f"CREATE TABLE {table}" in text, f"missing table {table}"


def test_books_rls_migration_exists():
    path = ROOT / "migrations" / "008_books_rls.sql"
    assert path.is_file()
    text = path.read_text(encoding="utf-8")
    assert "CREATE SCHEMA IF NOT EXISTS books_auth" in text
    assert "books_auth.set_jwt_claims" in text
    assert "ENABLE ROW LEVEL SECURITY" in text
    for table in REQUIRED_TABLES:
        assert f"ALTER TABLE {table} ENABLE ROW LEVEL SECURITY" in text


def test_de_tax_category_seed_stub():
    path = ROOT / "seeds" / "de_tax_category.sql"
    assert path.is_file()
    text = path.read_text(encoding="utf-8")
    assert "EXP_BEWIRTUNG_70" in text
    assert "REV_KLEINUNTERNEHMER" in text
    count = len(re.findall(r"\('EXP_|\('REV_|\('INC_", text))
    assert count >= 80, f"expected >= 80 categories, got {count}"


def test_rls_cross_org_deny_policies():
    text = (ROOT / "migrations" / "008_books_rls.sql").read_text(encoding="utf-8")
    for token in (
        "books_auth.is_org_member",
        "books_auth.has_book_access",
        "books_tenant_read_receipts",
    ):
        assert token in text
    assert "books_auth.is_org_member(org_id)" in text


def test_law_corpus_migration_exists():
    path = ROOT / "migrations" / "009_law_corpus.sql"
    assert path.is_file()
    text = path.read_text(encoding="utf-8")
    for table in (
        "law_source",
        "law_document",
        "law_chunk",
        "law_embedding",
        "law_refresh_run",
    ):
        assert f"CREATE TABLE {table}" in text

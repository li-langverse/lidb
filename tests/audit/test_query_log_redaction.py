"""tier_db_audit: exported query logs must redact secrets."""

from liorm.audit import redact_query_log


def test_redacts_password_and_api_key_literals():
    raw = "WHERE password='p' AND api_key='k'"
    out = redact_query_log(raw)
    assert "password='p'" not in out
    assert "api_key='k'" not in out
    assert "[REDACTED]" in out


def test_redacts_bearer_and_jwt_shapes():
    raw = "Authorization: Bearer abc.def.ghi eyJhbGciOiJIUzI1NiJ9.a.b"
    out = redact_query_log(raw)
    assert "Bearer abc" not in out
    assert "eyJhbGci" not in out

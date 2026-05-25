"""tier_db_audit: capability denials produce append-only audit events."""

import pytest

from liorm.audit import AppendOnlyAuditLog, record_capability_denial
from liorm.capabilities import Profile, RawSqlCapability, assert_capability
from liorm.errors import CapabilityDenied


def test_denial_events_are_chained():
    log = AppendOnlyAuditLog()
    with pytest.raises(CapabilityDenied):
        assert_capability(Profile.AGENT, RawSqlCapability.SESSION)
    record_capability_denial(log, Profile.AGENT, RawSqlCapability.SESSION)
    assert log.entries()[-1].event == "capability.denied"
    assert log.entries()[-1].payload["profile"] == "agent"
    assert log.verify_chain()

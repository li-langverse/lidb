"""liorm capability gate tests."""

import pytest

from liorm.capabilities import Profile, RawSqlCapability, assert_capability
from liorm.errors import CapabilityDenied


def test_agent_denied_raw_sql():
    with pytest.raises(CapabilityDenied):
        assert_capability(Profile.AGENT, RawSqlCapability.SESSION)


def test_mcp_denied_migration_sql():
    with pytest.raises(CapabilityDenied):
        assert_capability(Profile.MCP, RawSqlCapability.MIGRATION)


def test_cli_admin_session_allowed():
    assert_capability(Profile.CLI_ADMIN, RawSqlCapability.SESSION)

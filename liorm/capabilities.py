"""Raw SQL capability gates — agent/MCP profiles denied by default."""

from __future__ import annotations

from enum import Enum

from liorm.errors import CapabilityDenied


class RawSqlCapability(str, Enum):
    SESSION = "raw_sql:session"
    MIGRATION = "raw_sql:migration"


class Profile(str, Enum):
    AGENT = "agent"
    MCP = "mcp"
    CLI_ADMIN = "cli_admin"
    MIGRATION_RUNNER = "migration_runner"


_PROFILE_CAPS: dict[Profile, frozenset[RawSqlCapability]] = {
    Profile.AGENT: frozenset(),
    Profile.MCP: frozenset(),
    Profile.CLI_ADMIN: frozenset({RawSqlCapability.SESSION}),
    Profile.MIGRATION_RUNNER: frozenset({RawSqlCapability.MIGRATION}),
}


def assert_capability(profile: Profile, cap: RawSqlCapability) -> None:
    """Raise CapabilityDenied when profile cannot use raw SQL."""
    allowed = _PROFILE_CAPS.get(profile, frozenset())
    if cap not in allowed:
        raise CapabilityDenied(
            f"profile {profile.value} denied capability {cap.value}"
        )

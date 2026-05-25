"""liorm — secure Li ORM (PH-DB-2 stub)."""

from liorm.capabilities import Profile, RawSqlCapability, assert_capability
from liorm.catalog import CATALOG_ALLOWLIST
from liorm.errors import CatalogError
from liorm.errors import OrmError
from liorm.execute import execute, register_plan

__all__ = [
    "CATALOG_ALLOWLIST",
    "CatalogError",
    "OrmError",
    "Profile",
    "RawSqlCapability",
    "assert_capability",
    "execute",
    "register_plan",
]

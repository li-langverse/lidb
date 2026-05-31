"""Registry central DB OLTP (PH-DB-4) — liorm plans over lidb embed."""

from registry.bootstrap import register_registry_plans
from registry.service import RegistryOltp

__all__ = ["RegistryOltp", "register_registry_plans"]

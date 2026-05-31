"""Register registry-min plans into the global liorm plan registry."""

from __future__ import annotations

from registry.plans import RegistryPlanSpec, all_registry_plans
from liorm.execute import register_plan

_REGISTERED = False


def register_registry_plans(*, force: bool = False) -> list[str]:
    """Idempotent registration; returns plan_ids registered this call."""
    global _REGISTERED
    if _REGISTERED and not force:
        return []
    ids: list[str] = []
    for spec in all_registry_plans():
        register_plan(
            spec.name,
            plan_id=spec.plan_id,
            ir=spec.ir,
            sql=spec.sql,
            param_schema=spec.param_schema,
        )
        ids.append(spec.plan_id)
    _REGISTERED = True
    return ids

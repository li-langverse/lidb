"""liorm errors."""


class OrmError(Exception):
    """Base ORM error."""


class CatalogError(OrmError):
    """Identifier not in catalog allowlist."""


class ParameterMismatch(OrmError):
    """execute params do not match plan schema."""


class UnknownPlan(OrmError):
    """plan_id not registered."""


class CapabilityDenied(OrmError):
    """Profile lacks required capability."""

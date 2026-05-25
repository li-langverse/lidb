"""liq parse/compile errors."""


class LiqError(Exception):
    """Base liq error."""


class ParseError(LiqError):
    """Surface syntax rejected or malformed."""


class CompileError(LiqError):
    """Catalog resolution or lowering failed."""

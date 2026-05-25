"""Append-only audit trail and query log redaction (WP-N5 / tier_db_audit)."""

from __future__ import annotations

import hashlib
import json
import re
import time
from dataclasses import dataclass
from typing import Any

from liorm.capabilities import Profile, RawSqlCapability

_GENESIS = "genesis"

_REDACT_PATTERNS: tuple[tuple[re.Pattern[str], str], ...] = (
    (re.compile(r"(?i)(password\s*=\s*)'[^']*'", re.MULTILINE), r"\1'[REDACTED]'"),
    (re.compile(r"(?i)(api_key\s*=\s*)'[^']*'", re.MULTILINE), r"\1'[REDACTED]'"),
    (re.compile(r"(?i)Bearer\s+[A-Za-z0-9._~+/=-]+"), "Bearer [REDACTED]"),
    (re.compile(r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+"), "[REDACTED_JWT]"),
)


@dataclass(frozen=True)
class AuditEntry:
    seq: int
    event: str
    payload: dict[str, Any]
    recorded_at: float
    prev_hash: str
    entry_hash: str


def _entry_hash(
    *,
    seq: int,
    event: str,
    payload: dict[str, Any],
    recorded_at: float,
    prev_hash: str,
) -> str:
    body = {
        "seq": seq,
        "event": event,
        "payload": payload,
        "recorded_at": recorded_at,
        "prev_hash": prev_hash,
    }
    digest = hashlib.sha256(
        json.dumps(body, sort_keys=True, separators=(",", ":")).encode()
    )
    return digest.hexdigest()


class AppendOnlyAuditLog:
    """Hash-chained append-only log; prior entries are immutable."""

    __slots__ = ("_entries",)

    def __init__(self) -> None:
        self._entries: tuple[AuditEntry, ...] = ()

    def append(self, event: str, **payload: Any) -> AuditEntry:
        seq = len(self._entries)
        prev_hash = self._entries[-1].entry_hash if self._entries else _GENESIS
        raw_ts = payload.pop("recorded_at", None)
        recorded_at = time.time() if raw_ts is None else float(raw_ts)
        frozen_payload = dict(payload)
        entry_hash = _entry_hash(
            seq=seq,
            event=event,
            payload=frozen_payload,
            recorded_at=recorded_at,
            prev_hash=prev_hash,
        )
        entry = AuditEntry(
            seq=seq,
            event=event,
            payload=frozen_payload,
            recorded_at=recorded_at,
            prev_hash=prev_hash,
            entry_hash=entry_hash,
        )
        self._entries = self._entries + (entry,)
        return entry

    def entries(self) -> tuple[AuditEntry, ...]:
        return self._entries

    def verify_chain(self) -> bool:
        prev = _GENESIS
        for idx, entry in enumerate(self._entries):
            if entry.seq != idx:
                return False
            if entry.prev_hash != prev:
                return False
            expected = _entry_hash(
                seq=entry.seq,
                event=entry.event,
                payload=entry.payload,
                recorded_at=entry.recorded_at,
                prev_hash=entry.prev_hash,
            )
            if entry.entry_hash != expected:
                return False
            prev = entry.entry_hash
        return True


def redact_query_log(line: str) -> str:
    """Redact secrets from a query/audit log line before export."""
    out = line
    for pattern, repl in _REDACT_PATTERNS:
        out = pattern.sub(repl, out)
    return out


def record_capability_denial(
    log: AppendOnlyAuditLog,
    profile: Profile,
    cap: RawSqlCapability,
    *,
    reason: str | None = None,
) -> AuditEntry:
    return log.append(
        "capability.denied",
        profile=profile.value,
        capability=cap.value,
        reason=reason or "profile_denied",
    )

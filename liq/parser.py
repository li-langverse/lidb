"""liq surface parser — read/insert/update/delete; rejects ${} and ;."""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any

from liq.errors import ParseError

_FORBIDDEN = re.compile(r"\$\{|;")
_PARAM = re.compile(r"^\$([a-zA-Z_][a-zA-Z0-9_]*)$")
_IDENT = re.compile(r"^[a-zA-Z_][a-zA-Z0-9_]*(?:\.[a-zA-Z_][a-zA-Z0-9_]*)?$")


@dataclass(frozen=True)
class IdentRef:
    raw: str
    parts: tuple[str, ...]


@dataclass(frozen=True)
class ParamRef:
    name: str


@dataclass(frozen=True)
class Const:
    value: str | int


@dataclass(frozen=True)
class Predicate:
    column: str
    op: str
    rhs: ParamRef | Const


@dataclass(frozen=True)
class ReadStmt:
    table: IdentRef
    columns: tuple[str, ...] | None
    where: Predicate | None
    order_column: str | None
    order_desc: bool
    limit: int | None


@dataclass(frozen=True)
class InsertStmt:
    table: IdentRef
    bindings: tuple[tuple[str, ParamRef | Const], ...]


@dataclass(frozen=True)
class UpdateStmt:
    table: IdentRef
    bindings: tuple[tuple[str, ParamRef | Const], ...]
    where: Predicate | None
    returning: tuple[str, ...] | None


@dataclass(frozen=True)
class DeleteStmt:
    table: IdentRef
    where: Predicate | None


Stmt = ReadStmt | InsertStmt | UpdateStmt | DeleteStmt


def _reject_forbidden(source: str) -> None:
    if _FORBIDDEN.search(source):
        raise ParseError("forbidden token: ${} interpolation and semicolons are not allowed")


def _ident(token: str) -> IdentRef:
    if not _IDENT.match(token):
        raise ParseError(f"invalid identifier: {token}")
    return IdentRef(raw=token, parts=tuple(token.split(".")))


def _param(token: str) -> ParamRef:
    m = _PARAM.match(token)
    if not m:
        raise ParseError(f"expected $param, got: {token}")
    return ParamRef(name=m.group(1))


def _const(token: str) -> Const:
    if token.isdigit():
        return Const(value=int(token))
    if (token.startswith("'") and token.endswith("'")) or (
        token.startswith('"') and token.endswith('"')
    ):
        return Const(value=token[1:-1])
    raise ParseError(f"invalid literal: {token}")


def _rhs(token: str) -> ParamRef | Const:
    if token.startswith("$"):
        return _param(token)
    return _const(token)


def _predicate(tokens: list[str], i: int) -> tuple[Predicate, int]:
    if i + 2 >= len(tokens) or tokens[i + 1] != "=":
        raise ParseError("where clause requires: <column> = <value|$param>")
    col = tokens[i]
    rhs = _rhs(tokens[i + 2])
    return Predicate(column=col, op="=", rhs=rhs), i + 3


def _parse_bindings(inner: str) -> tuple[tuple[str, ParamRef | Const], ...]:
    parts = [p.strip() for p in inner.split(",") if p.strip()]
    out: list[tuple[str, ParamRef | Const]] = []
    for part in parts:
        if ":" not in part:
            raise ParseError(f"binding requires field: value — {part}")
        field, val = part.split(":", 1)
        field = field.strip()
        val = val.strip()
        out.append((field, _rhs(val)))
    return tuple(out)


def _parse_read(tokens: list[str]) -> ReadStmt:
    if len(tokens) < 2:
        raise ParseError("read requires a table name")
    table = _ident(tokens[1])
    i = 2
    columns: tuple[str, ...] | None = None
    where: Predicate | None = None
    order_column: str | None = None
    order_desc = False
    limit: int | None = None

    while i < len(tokens):
        tok = tokens[i]
        if tok == "{":
            cols: list[str] = []
            i += 1
            while i < len(tokens) and tokens[i] != "}":
                cols.append(tokens[i].rstrip(","))
                i += 1
            if i >= len(tokens) or tokens[i] != "}":
                raise ParseError("unclosed projection")
            columns = tuple(cols)
            i += 1
            continue
        if tok == "where":
            where, i = _predicate(tokens, i + 1)
            continue
        if tok == "order":
            if i + 1 >= len(tokens):
                raise ParseError("order requires column")
            order_column = tokens[i + 1]
            i += 2
            if i < len(tokens) and tokens[i] in ("asc", "desc"):
                order_desc = tokens[i] == "desc"
                i += 1
            continue
        if tok == "limit":
            if i + 1 >= len(tokens):
                raise ParseError("limit requires integer")
            if not tokens[i + 1].isdigit():
                raise ParseError("limit must be integer literal")
            limit = int(tokens[i + 1])
            i += 2
            continue
        raise ParseError(f"unexpected token in read: {tok}")
    return ReadStmt(
        table=table,
        columns=columns,
        where=where,
        order_column=order_column,
        order_desc=order_desc,
        limit=limit,
    )


def _parse_insert(tokens: list[str]) -> InsertStmt:
    if len(tokens) < 4 or tokens[2] != "{":
        raise ParseError("insert requires: insert <table> { field: value, ... }")
    table = _ident(tokens[1])
    if tokens[-1] != "}":
        raise ParseError("insert bindings must end with }")
    inner = " ".join(tokens[3:-1])
    return InsertStmt(table=table, bindings=_parse_bindings(inner))


def _parse_update(tokens: list[str]) -> UpdateStmt:
    if len(tokens) < 5 or tokens[0] != "update" or tokens[2] != "set":
        raise ParseError("update requires: update <table> set <col> = <value> ...")
    table = _ident(tokens[1])
    bindings: list[tuple[str, ParamRef | Const]] = []
    i = 3
    while i < len(tokens) and tokens[i] not in ("where", "returning"):
        if i + 2 >= len(tokens) or tokens[i + 1] != "=":
            raise ParseError("update set clause requires: <col> = <value|$param>")
        bindings.append((tokens[i], _rhs(tokens[i + 2])))
        i += 3
    where: Predicate | None = None
    returning: tuple[str, ...] | None = None
    while i < len(tokens):
        tok = tokens[i]
        if tok == "where":
            where, i = _predicate(tokens, i + 1)
            continue
        if tok == "returning":
            cols: list[str] = []
            i += 1
            while i < len(tokens):
                cols.append(tokens[i].rstrip(","))
                i += 1
            returning = tuple(cols)
            break
        raise ParseError(f"unexpected token in update: {tok}")
    if not bindings:
        raise ParseError("update requires at least one set binding")
    return UpdateStmt(table=table, bindings=tuple(bindings), where=where, returning=returning)


def _parse_delete(tokens: list[str]) -> DeleteStmt:
    i = 1
    if i < len(tokens) and tokens[i] == "from":
        i += 1
    if i >= len(tokens):
        raise ParseError("delete requires table name")
    table = _ident(tokens[i])
    i += 1
    where: Predicate | None = None
    if i < len(tokens):
        if tokens[i] != "where":
            raise ParseError("delete only supports optional where clause")
        where, _ = _predicate(tokens, i + 1)
    return DeleteStmt(table=table, where=where)


def parse(source: str) -> Stmt:
    """Parse a single liq statement."""
    _reject_forbidden(source)
    text = source.strip()
    if not text:
        raise ParseError("empty liq program")
    tokens = text.split()
    verb = tokens[0].lower()
    if verb == "read":
        return _parse_read(tokens)
    if verb == "insert":
        return _parse_insert(tokens)
    if verb == "update":
        return _parse_update(tokens)
    if verb == "delete":
        return _parse_delete(tokens)
    raise ParseError(f"unsupported statement: {verb}")


def stmt_to_ir(stmt: Stmt) -> dict[str, Any]:
    """Serialize statement to JSON-friendly LiqIr."""

    def ident(i: IdentRef) -> dict[str, Any]:
        return {"kind": "IdentRef", "raw": i.raw, "parts": list(i.parts)}

    def rhs(r: ParamRef | Const) -> dict[str, Any]:
        if isinstance(r, ParamRef):
            return {"kind": "ParamRef", "name": r.name}
        return {"kind": "Const", "value": r.value}

    def pred(p: Predicate | None) -> dict[str, Any] | None:
        if p is None:
            return None
        return {"column": p.column, "op": p.op, "rhs": rhs(p.rhs)}

    if isinstance(stmt, ReadStmt):
        return {
            "op": "read",
            "table": ident(stmt.table),
            "columns": list(stmt.columns) if stmt.columns else None,
            "where": pred(stmt.where),
            "order": (
                {"column": stmt.order_column, "desc": stmt.order_desc}
                if stmt.order_column
                else None
            ),
            "limit": stmt.limit,
        }
    if isinstance(stmt, InsertStmt):
        return {
            "op": "insert",
            "table": ident(stmt.table),
            "bindings": [{"field": f, "rhs": rhs(v)} for f, v in stmt.bindings],
        }
    if isinstance(stmt, UpdateStmt):
        return {
            "op": "update",
            "table": ident(stmt.table),
            "bindings": [{"field": f, "rhs": rhs(v)} for f, v in stmt.bindings],
            "where": pred(stmt.where),
            "returning": list(stmt.returning) if stmt.returning else None,
        }
    return {"op": "delete", "table": ident(stmt.table), "where": pred(stmt.where)}

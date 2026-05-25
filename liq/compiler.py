"""liq compiler — Lang → LiqIr → parameterized SQL."""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from typing import Any

from liq.errors import CompileError
from liq.parser import (
    Const,
    DeleteStmt,
    InsertStmt,
    ParamRef,
    Predicate,
    ReadStmt,
    UpdateStmt,
    parse,
    stmt_to_ir,
)
from liorm.catalog import resolve_column, resolve_table

_PARAM_TYPES: dict[str, str] = {
    "status": "text",
    "publisher_id": "uuid",
    "pub": "uuid",
    "pkg": "uuid",
    "ver": "text",
    "sha": "text",
    "name": "text",
    "id": "uuid",
    "rid": "uuid",
}


@dataclass(frozen=True)
class CompileResult:
    plan_id: str
    ir: dict[str, Any]
    sql: str
    param_schema: dict[str, str]


def _collect_params(stmt: ReadStmt | InsertStmt | UpdateStmt | DeleteStmt) -> list[str]:
    names: list[str] = []

    def add(rhs: ParamRef | Const) -> None:
        if isinstance(rhs, ParamRef) and rhs.name not in names:
            names.append(rhs.name)

    def pred(p: Predicate | None) -> None:
        if p is not None:
            add(p.rhs)

    if isinstance(stmt, ReadStmt):
        pred(stmt.where)
    elif isinstance(stmt, InsertStmt):
        for _, v in stmt.bindings:
            add(v)
    elif isinstance(stmt, UpdateStmt):
        for _, v in stmt.bindings:
            add(v)
        pred(stmt.where)
    else:
        pred(stmt.where)
    return names


def _quoted_table(table_raw: str) -> str:
    schema, name = resolve_table(table_raw)
    return f'"{schema}"."{name}"'


def _quoted_col(table_raw: str, column: str) -> str:
    schema, table, col = resolve_column(table_raw, column)
    return f'"{schema}"."{table}"."{col}"'


def _lower_read(stmt: ReadStmt) -> tuple[str, dict[str, str]]:
    qtable = _quoted_table(stmt.table.raw)
    cols = "*"
    if stmt.columns:
        cols = ", ".join(_quoted_col(stmt.table.raw, c) for c in stmt.columns)
    sql = f"SELECT {cols} FROM {qtable}"
    params: list[str] = []
    schema: dict[str, str] = {}
    if stmt.where:
        if not isinstance(stmt.where.rhs, ParamRef):
            raise CompileError("read where rhs must be a parameter in stub compiler")
        pname = stmt.where.rhs.name
        params.append(pname)
        schema[pname] = _PARAM_TYPES.get(pname, "text")
        sql += f' WHERE {_quoted_col(stmt.table.raw, stmt.where.column)} = ${len(params)}'
    if stmt.order_column:
        sql += f' ORDER BY {_quoted_col(stmt.table.raw, stmt.order_column)}'
        sql += " DESC" if stmt.order_desc else " ASC"
    if stmt.limit is not None:
        sql += f" LIMIT {int(stmt.limit)}"
    return sql, schema


def _lower_insert(stmt: InsertStmt) -> tuple[str, dict[str, str]]:
    qtable = _quoted_table(stmt.table.raw)
    fields: list[str] = []
    placeholders: list[str] = []
    schema: dict[str, str] = {}
    idx = 0
    for field, rhs in stmt.bindings:
        resolve_column(stmt.table.raw, field)
        fields.append(_quoted_col(stmt.table.raw, field))
        if isinstance(rhs, ParamRef):
            idx += 1
            placeholders.append(f"${idx}")
            schema[rhs.name] = _PARAM_TYPES.get(rhs.name, "text")
        else:
            placeholders.append("%s")
    sql = f"INSERT INTO {qtable} ({', '.join(fields)}) VALUES ({', '.join(placeholders)})"
    return sql, schema


def _lower_update(stmt: UpdateStmt) -> tuple[str, dict[str, str]]:
    qtable = _quoted_table(stmt.table.raw)
    sets: list[str] = []
    schema: dict[str, str] = {}
    idx = 0
    for field, rhs in stmt.bindings:
        resolve_column(stmt.table.raw, field)
        if isinstance(rhs, ParamRef):
            idx += 1
            sets.append(f"{_quoted_col(stmt.table.raw, field)} = ${idx}")
            schema[rhs.name] = _PARAM_TYPES.get(rhs.name, "text")
        else:
            sets.append(f"{_quoted_col(stmt.table.raw, field)} = %s")
    sql = f"UPDATE {qtable} SET {', '.join(sets)}"
    if stmt.where:
        if not isinstance(stmt.where.rhs, ParamRef):
            raise CompileError("update where rhs must be a parameter in stub compiler")
        idx += 1
        pname = stmt.where.rhs.name
        schema[pname] = _PARAM_TYPES.get(pname, "text")
        sql += f' WHERE {_quoted_col(stmt.table.raw, stmt.where.column)} = ${idx}'
    if stmt.returning:
        ret = ", ".join(_quoted_col(stmt.table.raw, c) for c in stmt.returning)
        sql += f" RETURNING {ret}"
    return sql, schema


def _lower_delete(stmt: DeleteStmt) -> tuple[str, dict[str, str]]:
    qtable = _quoted_table(stmt.table.raw)
    sql = f"DELETE FROM {qtable}"
    schema: dict[str, str] = {}
    if stmt.where:
        if not isinstance(stmt.where.rhs, ParamRef):
            raise CompileError("delete where rhs must be a parameter in stub compiler")
        schema[stmt.where.rhs.name] = _PARAM_TYPES.get(stmt.where.rhs.name, "text")
        sql += f' WHERE {_quoted_col(stmt.table.raw, stmt.where.column)} = $1'
    return sql, schema


def _plan_id(source: str, ir: dict[str, Any]) -> str:
    digest = hashlib.sha256((source + json.dumps(ir, sort_keys=True)).encode()).hexdigest()
    return f"liq:{digest[:16]}"


def compile(source: str) -> CompileResult:
    """Compile liq source to plan metadata + parameterized SQL."""
    stmt = parse(source)
    ir = stmt_to_ir(stmt)
    if isinstance(stmt, ReadStmt):
        sql, param_schema = _lower_read(stmt)
    elif isinstance(stmt, InsertStmt):
        sql, param_schema = _lower_insert(stmt)
    elif isinstance(stmt, UpdateStmt):
        sql, param_schema = _lower_update(stmt)
    elif isinstance(stmt, DeleteStmt):
        sql, param_schema = _lower_delete(stmt)
    else:
        raise CompileError("unsupported statement")
    plan_id = _plan_id(source, ir)
    return CompileResult(plan_id=plan_id, ir=ir, sql=sql, param_schema=param_schema)

#include "lidb/sql/registry_parse.hpp"

#include <cctype>
#include <regex>

#include "lidb/sql/lexer.hpp"

namespace lidb::sql {

std::string flatten_catalog_sql(std::string_view sql) {
  std::string out(sql);
  static const std::regex triple(R"x("([^"]+)"\."([^"]+)"\."([^"]+)")x");
  static const std::regex dbl(R"x("([^"]+)"\."([^"]+)")x");
  static const std::regex param(R"(\$(\d+))");
  out = std::regex_replace(out, triple, "$3");
  out = std::regex_replace(out, dbl, "$2");
  out = std::regex_replace(out, param, "?");
  while (!out.empty() && std::isspace(static_cast<unsigned char>(out.back()))) out.pop_back();
  if (!out.empty() && out.back() == ';') out.pop_back();
  return out;
}

std::optional<ParsedStatement> parse_registry_statement(std::string_view sql) {
  const std::string flat = flatten_catalog_sql(sql);
  Lexer lex(flat);
  auto next = [&]() { return lex.next(); };

  Token head = next();
  if (head.kind == TokenKind::kKwInsert) {
    ParsedStatement ps;
    ps.kind = ParsedStatement::Kind::kInsert;
    InsertStmt ins;
    if (next().kind != TokenKind::kKwInto) return std::nullopt;
    ins.table = next().text;
    if (next().kind != TokenKind::kLParen) return std::nullopt;
    for (;;) {
      ins.columns.push_back(next().text);
      Token sep = next();
      if (sep.kind == TokenKind::kRParen) break;
      if (sep.kind != TokenKind::kComma) return std::nullopt;
    }
    if (next().kind != TokenKind::kKwValues) return std::nullopt;
    if (next().kind != TokenKind::kLParen) return std::nullopt;
    for (;;) {
      ins.values.push_back(next().text);
      Token sep = next();
      if (sep.kind == TokenKind::kRParen) break;
      if (sep.kind != TokenKind::kComma) return std::nullopt;
    }
    ps.insert = std::move(ins);
    return ps;
  }

  if (head.kind != TokenKind::kKwSelect) return std::nullopt;

  ParsedStatement ps;
  ps.kind = ParsedStatement::Kind::kSelect;
  SelectStmt sel;
  Token col = next();
  if (col.kind == TokenKind::kStar) {
    sel.columns = {"*"};
  } else {
    lex.put_back(col);
    for (;;) {
      sel.columns.push_back(next().text);
      Token sep = next();
      if (sep.kind != TokenKind::kComma) {
        lex.put_back(sep);
        break;
      }
    }
  }
  if (next().kind != TokenKind::kKwFrom) return std::nullopt;
  sel.table = next().text;
  ps.select = std::move(sel);
  return ps;
}

}  // namespace lidb::sql

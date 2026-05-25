#pragma once

#include <optional>
#include <string>
#include <string_view>

#include "lidb/sql/ast.hpp"

namespace lidb::sql {

std::string flatten_catalog_sql(std::string_view sql);
std::optional<ParsedStatement> parse_registry_statement(std::string_view sql);

}  // namespace lidb::sql

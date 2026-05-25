#pragma once

#include <optional>
#include <string>
#include <vector>

namespace lidb::sql {

struct InsertStmt {
  std::string table;
  std::vector<std::string> columns;
  std::vector<std::string> values;
};

struct SelectStmt {
  std::vector<std::string> columns;
  std::string table;
  std::optional<std::string> where_column;
  std::optional<std::string> where_value;
  bool count_star{false};
};

struct ParsedStatement {
  enum class Kind { kInsert, kSelect } kind;
  InsertStmt insert;
  SelectStmt select;
};

}  // namespace lidb::sql

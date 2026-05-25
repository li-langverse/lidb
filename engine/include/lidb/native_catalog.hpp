#pragma once

#include <filesystem>
#include <map>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace lidb {

struct NativeRow {
  std::map<std::string, std::string> cols;
};

struct NativeExecResult {
  std::vector<NativeRow> rows;
  std::size_t affected{0};
};

class NativeCatalog {
 public:
  explicit NativeCatalog(std::filesystem::path snapshot_path);
  bool load_or_create();
  bool apply_bootstrap_schema();
  std::optional<std::size_t> table_count(const std::string& table) const;
  NativeExecResult exec(std::string_view sql, const std::vector<std::string>& params = {});

 private:
  bool replay_snapshot();
  bool persist_row(const std::string& table, const NativeRow& row);
  bool save_snapshot() const;
  static std::string trim_sql(std::string_view sql);
  static std::vector<std::string> split_csv(std::string_view s);
  static std::string unquote_literal(std::string_view lit);
  NativeExecResult exec_select(std::string_view sql, const std::vector<std::string>& params);
  NativeExecResult exec_insert(std::string_view sql, const std::vector<std::string>& params);

  std::filesystem::path snapshot_path_;
  std::map<std::string, std::vector<NativeRow>> tables_;
};

}  // namespace lidb

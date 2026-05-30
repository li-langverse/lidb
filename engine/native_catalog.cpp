#include "lidb/native_catalog.hpp"

#include <algorithm>
#include <cctype>
#include <fstream>
#include <sstream>

namespace lidb {
namespace {

std::string lower(std::string s) {
  std::transform(s.begin(), s.end(), s.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  return s;
}

std::string trim(std::string_view s) {
  while (!s.empty() && std::isspace(static_cast<unsigned char>(s.front()))) s.remove_prefix(1);
  while (!s.empty() && std::isspace(static_cast<unsigned char>(s.back()))) s.remove_suffix(1);
  return std::string(s);
}

std::vector<std::string> split_top_level_commas(std::string_view s) {
  std::vector<std::string> out;
  std::string cur;
  bool in_quote = false;
  for (char c : s) {
    if (c == '\'' && !in_quote) in_quote = true;
    else if (c == '\'' && in_quote) in_quote = false;
    if (!in_quote && c == ',') {
      out.push_back(trim(cur));
      cur.clear();
      continue;
    }
    cur.push_back(c);
  }
  if (!cur.empty()) out.push_back(trim(cur));
  return out;
}

}  // namespace

NativeCatalog::NativeCatalog(std::filesystem::path snapshot_path)
    : snapshot_path_(std::move(snapshot_path)) {}

bool NativeCatalog::load_or_create() {
  std::filesystem::create_directories(snapshot_path_.parent_path());
  if (!replay_snapshot()) tables_.clear();
  return true;
}

bool NativeCatalog::replay_snapshot() {
  if (!std::filesystem::exists(snapshot_path_)) return false;
  std::ifstream in(snapshot_path_);
  if (!in.is_open()) return false;
  tables_.clear();
  std::string line;
  std::string current_table;
  while (std::getline(in, line)) {
    if (line.empty() || line[0] == '#') continue;
    if (line.rfind("@table:", 0) == 0) {
      current_table = line.substr(7);
      tables_[current_table] = {};
      continue;
    }
    if (current_table.empty()) continue;
    NativeRow row;
    for (const auto& field : split_csv(line)) {
      auto eq = field.find('=');
      if (eq == std::string::npos) continue;
      row.cols[field.substr(0, eq)] = field.substr(eq + 1);
    }
    tables_[current_table].push_back(std::move(row));
  }
  return !tables_.empty();
}

bool NativeCatalog::save_snapshot() const {
  std::ofstream out(snapshot_path_, std::ios::trunc);
  if (!out.is_open()) return false;
  for (const auto& [table, rows] : tables_) {
    out << "@table:" << table << "\n";
    for (const auto& row : rows) {
      bool first = true;
      for (const auto& [k, v] : row.cols) {
        if (!first) out << "|";
        first = false;
        out << k << "=" << v;
      }
      out << "\n";
    }
  }
  return true;
}

bool NativeCatalog::persist_row(const std::string& table, const NativeRow& row) {
  std::ofstream out(snapshot_path_, std::ios::app);
  if (!out.is_open()) return false;
  if (tables_[table].size() == 1) out << "@table:" << table << "\n";
  bool first = true;
  for (const auto& [k, v] : row.cols) {
    if (!first) out << "|";
    first = false;
    out << k << "=" << v;
  }
  out << "\n";
  return true;
}

bool NativeCatalog::apply_bootstrap_schema() {
  tables_.clear();
  tables_["schema_migrations"] = {};
  tables_["publishers"] = {};
  tables_["packages"] = {};
  tables_["package_versions"] = {};
  tables_["agent_runs"] = {};
  tables_["control_plane_state"] = {};
  tables_["control_plane_reports"] = {};
  tables_["agent_handoffs"] = {};
  NativeRow mig;
  mig.cols["version"] = "001_registry";
  mig.cols["checksum"] = "native-n1";
  tables_["schema_migrations"].push_back(mig);
  return save_snapshot();
}

std::optional<std::size_t> NativeCatalog::table_count(const std::string& table) const {
  auto it = tables_.find(table);
  if (it == tables_.end()) return std::nullopt;
  return it->second.size();
}

std::string NativeCatalog::trim_sql(std::string_view sql) {
  auto s = trim(sql);
  while (!s.empty() && s.back() == ';') {
    s.pop_back();
    s = trim(s);
  }
  return s;
}

std::vector<std::string> NativeCatalog::split_csv(std::string_view s) {
  std::vector<std::string> out;
  std::string cur;
  for (char c : s) {
    if (c == '|') {
      out.push_back(cur);
      cur.clear();
      continue;
    }
    cur.push_back(c);
  }
  out.push_back(cur);
  return out;
}

std::string NativeCatalog::unquote_literal(std::string_view lit) {
  auto s = trim(lit);
  if (s.size() >= 2 && s.front() == '\'' && s.back() == '\'') {
    return s.substr(1, s.size() - 2);
  }
  if (s.size() >= 3 && (s.rfind("x'", 0) == 0 || s.rfind("X'", 0) == 0) && s.back() == '\'') {
    return s.substr(2, s.size() - 3);
  }
  return s;
}

NativeExecResult NativeCatalog::exec(std::string_view sql, const std::vector<std::string>& params) {
  auto q = trim_sql(sql);
  auto lq = lower(q);
  if (lq.rfind("select", 0) == 0) return exec_select(q);
  if (lq.rfind("insert", 0) == 0) return exec_insert(q, params);
  if (lq.rfind("delete", 0) == 0) return exec_delete(q, params);
  return {};
}

NativeExecResult NativeCatalog::exec_select(std::string_view sql) {
  NativeExecResult result;
  auto q = trim_sql(sql);
  auto lq = lower(q);

  if (lq.find("select 1") == 0) {
    NativeRow r;
    std::string alias = "ok";
    auto as_pos = lq.find(" as ");
    if (as_pos != std::string::npos) alias = trim(q.substr(as_pos + 4));
    r.cols[alias] = "1";
    result.rows.push_back(r);
    return result;
  }

  auto from_pos = lq.find(" from ");
  if (from_pos == std::string::npos) return result;
  std::string table = trim(q.substr(from_pos + 6));
  auto sp = table.find(' ');
  if (sp != std::string::npos) table = table.substr(0, sp);

  bool count_star = lq.find("count(*)") != std::string::npos;
  std::optional<std::string> where_col;
  std::optional<std::string> where_val;
  auto where_pos = lq.find(" where ");
  if (where_pos != std::string::npos) {
    auto clause = trim(q.substr(where_pos + 7));
    auto eq = clause.find('=');
    if (eq != std::string::npos) {
      where_col = trim(clause.substr(0, eq));
      where_val = unquote_literal(trim(clause.substr(eq + 1)));
    }
  }

  const auto& rows = tables_[table];
  if (count_star) {
    NativeRow r;
    auto sel = trim(q.substr(7, from_pos - 7));
    auto as_pos = lower(sel).find(" as ");
    std::string key = as_pos == std::string::npos ? "count(*)" : trim(sel.substr(as_pos + 4));
    r.cols[key] = std::to_string(rows.size());
    result.rows.push_back(r);
    return result;
  }

  std::string col = "name";
  auto sel_part = trim(q.substr(7, from_pos - 7));
  if (sel_part != "*") {
    auto as_pos = lower(sel_part).find(" as ");
    col = as_pos == std::string::npos ? lower(trim(sel_part)) : lower(trim(sel_part.substr(as_pos + 4)));
  }

  for (const auto& row : rows) {
    if (where_col && where_val) {
      auto it = row.cols.find(*where_col);
      if (it == row.cols.end() || it->second != *where_val) continue;
    }
    NativeRow out;
    for (const auto& [k, v] : row.cols) {
      if (sel_part == "*" || lower(k) == col) out.cols[k] = v;
    }
    if (!out.cols.empty()) result.rows.push_back(out);
  }
  return result;
}


NativeExecResult NativeCatalog::exec_delete(std::string_view sql, const std::vector<std::string>& params) {
  NativeExecResult result;
  auto q = trim_sql(sql);
  auto lq = lower(q);
  auto from_pos = lq.find(" from ");
  if (from_pos == std::string::npos) return result;
  std::string table = trim(q.substr(from_pos + 6));
  auto sp = table.find(' ');
  if (sp != std::string::npos) table = table.substr(0, sp);

  std::optional<std::string> where_col;
  std::optional<std::string> where_val;
  auto where_pos = lq.find(" where ");
  if (where_pos != std::string::npos) {
    auto clause = trim(q.substr(where_pos + 7));
    auto eq = clause.find('=');
    if (eq != std::string::npos) {
      where_col = trim(clause.substr(0, eq));
      auto rhs = trim(clause.substr(eq + 1));
      if (rhs == "?") {
        if (params.empty()) return result;
        where_val = params[0];
      } else {
        where_val = unquote_literal(rhs);
      }
    }
  }

  auto& rows = tables_[table];
  std::vector<NativeRow> kept;
  std::size_t removed = 0;
  for (const auto& row : rows) {
    bool match = true;
    if (where_col && where_val) {
      auto it = row.cols.find(*where_col);
      match = it != row.cols.end() && it->second == *where_val;
    }
    if (match) {
      removed++;
      continue;
    }
    kept.push_back(row);
  }
  rows = std::move(kept);
  if (!save_snapshot()) return result;
  result.affected = removed;
  return result;
}

NativeExecResult NativeCatalog::exec_insert(std::string_view sql, const std::vector<std::string>& params) {
  NativeExecResult result;
  auto q = trim_sql(sql);
  auto lq = lower(q);
  auto into_pos = lq.find("insert into ");
  if (into_pos == std::string::npos) return result;
  auto rest = q.substr(into_pos + 12);
  auto col_open = rest.find('(');
  if (col_open == std::string::npos) return result;
  std::string table = trim(rest.substr(0, col_open));
  std::size_t col_close = col_open + 1;
  int depth = 1;
  while (col_close < rest.size() && depth > 0) {
    if (rest[col_close] == '(') depth++;
    else if (rest[col_close] == ')') depth--;
    col_close++;
  }
  if (depth != 0) return result;
  auto cols_part = trim(rest.substr(col_open + 1, col_close - col_open - 2));
  auto vals_kw = lower(rest).find(" values ", col_close);
  if (vals_kw == std::string::npos) return result;
  auto val_open = rest.find('(', vals_kw);
  if (val_open == std::string::npos) return result;
  std::size_t val_close = val_open + 1;
  depth = 1;
  while (val_close < rest.size() && depth > 0) {
    if (rest[val_close] == '(') depth++;
    else if (rest[val_close] == ')') depth--;
    val_close++;
  }
  if (depth != 0) return result;
  std::string vals_part = trim(rest.substr(val_open + 1, val_close - val_open - 2));

  auto col_names = split_top_level_commas(cols_part);
  auto raw_vals = split_top_level_commas(vals_part);
  std::size_t param_i = 0;
  NativeRow row;
  for (std::size_t i = 0; i < col_names.size(); ++i) {
    std::string val;
    if (i < raw_vals.size()) {
      auto rv = trim(raw_vals[i]);
      if (rv == "?") {
        if (param_i >= params.size()) return result;
        val = params[param_i++];
      } else {
        val = unquote_literal(rv);
      }
    }
    row.cols[col_names[i]] = val;
  }
  tables_[table].push_back(row);
  if (!save_snapshot()) return result;
  result.affected = 1;
  return result;
}

}  // namespace lidb

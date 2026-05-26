#include <cctype>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>
#include "lidb/embedded.hpp"
static void usage() {
  std::cerr << "lidb_embed open|migrate|exec|exec-json <data-dir> [sql]\n"
            << "  exec-json reads params JSON array from stdin\n";
}
static std::vector<std::string> read_params_json(std::istream& in) {
  std::ostringstream buf; buf << in.rdbuf();
  const std::string raw = buf.str();
  std::vector<std::string> out; std::string cur; bool in_str = false;
  for (std::size_t i = 0; i < raw.size(); ++i) {
    char c = raw[i];
    if (!in_str) { if (c == '"') { in_str = true; cur.clear(); } continue; }
    if (c == '\\' && i + 1 < raw.size()) { cur.push_back(raw[++i]); continue; }
    if (c == '"') { out.push_back(cur); in_str = false; continue; }
    cur.push_back(c);
  }
  return out;
}
int main(int argc, char** argv) {
  if (argc < 3) { usage(); return 2; }
  const std::string cmd = argv[1];
  const std::filesystem::path dir = argv[2];
  if (cmd == "open") {
    lidb::EmbeddedDatabase db({.data_dir = dir});
    if (!db.open()) return 1;
    std::cout << "open ok wal_lsn=" << db.status().wal_lsn
              << " catalog=" << db.status().catalog_path << " backend=" << db.status().backend << "\n";
    return 0;
  }
  if (cmd == "migrate") {
    lidb::EmbeddedDatabase db({.data_dir = dir});
    if (!db.open() || !db.migrate()) { std::cerr << "migrate failed\n"; return 1; }
    std::cout << "migrate ok\n"; return 0;
  }
  if ((cmd == "exec" || cmd == "exec-json") && argc >= 4) {
    lidb::EmbeddedDatabase db({.data_dir = dir});
    if (!db.open()) return 1;
    std::vector<std::string> params;
    if (cmd == "exec-json") params = read_params_json(std::cin);
    const auto result = db.exec_parameterized(argv[3], params);
    const std::string sql_l = argv[3];
    std::string sql_lower = sql_l;
    for (auto& c : sql_lower) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    const bool is_select = sql_lower.rfind("select", 0) == 0;
    const bool is_delete = sql_lower.rfind("delete", 0) == 0;
    const bool is_update = sql_lower.rfind("update", 0) == 0;
    if (result.rows.empty() && result.affected == 0 && !is_select && !is_delete && !is_update) {
      std::cerr << "exec failed\n";
      return 1;
    }
    if (cmd == "exec-json") {
      std::cout << lidb::EmbeddedDatabase::exec_result_json(result) << "\n"; return 0;
    }
    if (result.affected > 0 && result.rows.empty()) return 0;
    if (result.rows.size() == 1 && result.rows[0].cols.size() == 1) {
      std::cout << result.rows[0].cols.begin()->second << "\n"; return 0;
    }
    for (const auto& row : result.rows) {
      bool first = true;
      for (const auto& [_, v] : row.cols) { if (!first) std::cout << ' '; first = false; std::cout << v; }
      std::cout << "\n";
    }
    return 0;
  }
  usage(); return 2;
}

#include "lidb/embedded.hpp"

#include <fstream>
#include <regex>
#include <sstream>

namespace lidb {
namespace {

std::string extract_insert_table(std::string_view sql) {
  auto lq = std::string(sql);
  auto pos = lq.find("INTO ");
  if (pos == std::string::npos) pos = lq.find("into ");
  if (pos == std::string::npos) return "unknown";
  auto rest = lq.substr(pos + 5);
  auto table = rest.substr(0, rest.find('('));
  while (!table.empty() && std::isspace(static_cast<unsigned char>(table.back()))) table.pop_back();
  return table;
}

}  // anonymous namespace

std::string EmbeddedDatabase::flatten_catalog_sql(std::string_view sql) {
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

EmbeddedDatabase::EmbeddedDatabase(EmbeddedConfig config) : config_(std::move(config)) {}

bool EmbeddedDatabase::open() {
  if (status_.open) return true;
  auto root = config_.data_dir / ".lidb";
  std::filesystem::create_directories(root / "pool");
  status_.data_dir = config_.data_dir;
  status_.catalog_path = root / "catalog.heap";
  status_.wal_path = root / "wal" / "00000001.seg";
  status_.backend = "native";
  std::filesystem::create_directories(status_.wal_path.parent_path());
  pool_.emplace(config_.pool);
  wal_.emplace(status_.wal_path);
  native_exec_.emplace(*wal_, changefeed_);
  catalog_ = std::make_unique<NativeCatalog>(status_.catalog_path);
  if (!catalog_->load_or_create()) return false;
  std::vector<std::byte> payload(8);
  status_.wal_lsn = wal_->append(WalRecordType::kNoop, payload);
  (void)pool_->pin(PageId{});
  status_.open = true;
  status_.pool_pinned = pool_->pinned_count();
  return true;
}

void EmbeddedDatabase::close() {
  if (pool_) pool_->unpin(PageId{});
  pool_.reset();
  native_exec_.reset();
  catalog_.reset();
  wal_.reset();
  status_ = {};
}

bool EmbeddedDatabase::migrate() {
  if (!status_.open || !catalog_) return false;
  { std::ofstream m(status_.data_dir / ".lidb" / "migration_intent.txt"); m << "smoke_backend=native\n"; }
  if (catalog_->table_count("schema_migrations").value_or(0) > 0) return true;
  return catalog_->apply_bootstrap_schema();
}

std::string EmbeddedDatabase::exec_result_json(const NativeExecResult& result) {
  std::ostringstream out;
  out << "{\"rows\":[";
  bool first_row = true;
  for (const auto& row : result.rows) {
    if (!first_row) out << ',';
    first_row = false;
    out << '{';
    bool first_col = true;
    for (const auto& [k, v] : row.cols) {
      if (!first_col) out << ',';
      first_col = false;
      out << '"' << k << "\":\"" << v << '"';
    }
    out << '}';
  }
  out << "],\"affected\":" << result.affected << '}';
  return out.str();
}

NativeExecResult EmbeddedDatabase::exec_parameterized(std::string_view sql,
                                                      const std::vector<std::string>& params) {
  if (!status_.open || !catalog_ || !native_exec_) return {};
  const auto flat = flatten_catalog_sql(sql);
  auto result = catalog_->exec(flat, params);
  if (result.affected > 0) status_.wal_lsn = native_exec_->insert(extract_insert_table(flat), {});
  return result;
}

std::optional<std::string> EmbeddedDatabase::exec_sql(std::string_view sql) {
  auto res = exec_parameterized(sql, {});
  if (res.rows.empty() && res.affected == 0) {
    const auto flat = flatten_catalog_sql(sql);
    if (flat.find("INSERT") == 0 || flat.find("insert") == 0) return std::optional<std::string>{""};
    return std::nullopt;
  }
  if (res.rows.size() == 1 && res.rows[0].cols.size() == 1) return res.rows[0].cols.begin()->second;
  std::ostringstream lines;
  for (const auto& row : res.rows) {
    bool first = true;
    for (const auto& [_, v] : row.cols) {
      if (!first) lines << ' ';
      first = false;
      lines << v;
    }
    lines << '\n';
  }
  auto s = lines.str();
  if (!s.empty() && s.back() == '\n') s.pop_back();
  return s;
}

WalWriter* EmbeddedDatabase::wal_writer() { return wal_ ? &*wal_ : nullptr; }
Changefeed* EmbeddedDatabase::changefeed_hub() { return status_.open ? &changefeed_ : nullptr; }
NativeExecutor* EmbeddedDatabase::native_executor() { return native_exec_ ? &*native_exec_ : nullptr; }

}  // namespace lidb

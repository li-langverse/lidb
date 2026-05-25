#include "lidb/embedded.hpp"
#include <array>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <sstream>
namespace lidb {
namespace {
std::filesystem::path repo_root() {
  auto cwd = std::filesystem::current_path();
  if (std::filesystem::exists(cwd / "migrations" / "001_registry.sql")) return cwd;
  if (std::filesystem::exists(cwd.parent_path() / "migrations" / "001_registry.sql")) return cwd.parent_path();
  return cwd;
}
int run_cmd(const std::string& c) { return std::system(c.c_str()); }
std::string q(std::string_view s) {
  std::string o = "'";
  for (char c : s) { if (c == '\'') o += "'\\''"; else o.push_back(c); }
  return o + "'";
}
bool nonempty(const std::filesystem::path& p) { return std::filesystem::exists(p) && std::filesystem::file_size(p) > 0; }
}
EmbeddedDatabase::EmbeddedDatabase(EmbeddedConfig config) : config_(std::move(config)) {}
bool EmbeddedDatabase::open() {
  if (status_.open) return true;
  auto root = config_.data_dir / ".lidb";
  std::filesystem::create_directories(root / "pool");
  status_.data_dir = config_.data_dir;
  status_.catalog_path = root / "catalog.db";
  status_.wal_path = root / "wal" / "00000001.seg";
  std::filesystem::create_directories(status_.wal_path.parent_path());
  pool_.emplace(config_.pool);
  wal_.emplace(status_.wal_path);
  std::vector<std::byte> payload(8);
  status_.wal_lsn = wal_->append(WalRecordType::kNoop, payload);
  (void)pool_->pin(PageId{});
  status_.open = true;
  status_.pool_pinned = pool_->pinned_count();
  return true;
}
void EmbeddedDatabase::close() { if (pool_) pool_->unpin(PageId{}); pool_.reset(); wal_.reset(); status_ = {}; }
bool EmbeddedDatabase::migrate() {
  if (!status_.open) return false;
  auto repo = repo_root();
  auto emb = repo / "migrations" / "001_registry_embedded.sql";
  { std::ofstream m(status_.data_dir / ".lidb" / "migration_intent.txt"); m << "smoke_backend=sqlite3\n"; }
  if (!std::filesystem::exists(emb)) return false;
  std::string cmd = "sqlite3 " + q(status_.catalog_path.string()) + " < " + q(emb.string()) +
    " && sqlite3 " + q(status_.catalog_path.string()) +
    " \"INSERT OR REPLACE INTO schema_migrations(version,checksum) VALUES ('001_registry','smoke');\"";
  return run_cmd(cmd) == 0 && nonempty(status_.catalog_path);
}
std::optional<std::string> EmbeddedDatabase::exec_sql(std::string_view sql) {
  if (!status_.open || !nonempty(status_.catalog_path)) return std::nullopt;
  std::string cmd = "sqlite3 -batch " + q(status_.catalog_path.string()) + " " + q(std::string(sql)) + " 2>&1";
  FILE* pipe = popen(cmd.c_str(), "r");
  if (!pipe) return std::nullopt;
  std::ostringstream out; std::array<char, 256> buf{};
  while (fgets(buf.data(), static_cast<int>(buf.size()), pipe)) out << buf.data();
  if (pclose(pipe) != 0) return std::nullopt;
  auto s = out.str();
  if (!s.empty() && s.back() == '\n') s.pop_back();
  return s;
}
}

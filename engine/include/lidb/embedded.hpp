#pragma once
#include <filesystem>
#include <optional>
#include <string>
#include <string_view>
#include "lidb/buffer_pool.hpp"
#include "lidb/wal.hpp"
namespace lidb {
struct EmbeddedConfig { std::filesystem::path data_dir; BufferPoolConfig pool{}; };
struct EmbeddedStatus { bool open{false}; std::filesystem::path data_dir; std::filesystem::path catalog_path; std::filesystem::path wal_path; std::uint64_t wal_lsn{0}; std::size_t pool_pinned{0}; };
class EmbeddedDatabase {
 public:
  explicit EmbeddedDatabase(EmbeddedConfig config = {});
  const EmbeddedStatus& status() const { return status_; }
  bool open();
  void close();
  bool migrate();
  std::optional<std::string> exec_sql(std::string_view sql);
 private:
  EmbeddedConfig config_{};
  EmbeddedStatus status_{};
  std::optional<BufferPool> pool_;
  std::optional<WalWriter> wal_;
};
}

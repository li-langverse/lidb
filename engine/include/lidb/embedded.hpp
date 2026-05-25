#pragma once

#include <filesystem>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include "lidb/buffer_pool.hpp"
#include "lidb/changefeed.hpp"
#include "lidb/heap.hpp"
#include "lidb/native_catalog.hpp"
#include "lidb/native_exec.hpp"
#include "lidb/wal.hpp"

namespace lidb {

struct EmbeddedConfig {
  std::filesystem::path data_dir;
  BufferPoolConfig pool{};
};

struct EmbeddedStatus {
  bool open{false};
  std::filesystem::path data_dir;
  std::filesystem::path catalog_path;
  std::filesystem::path wal_path;
  std::uint64_t wal_lsn{0};
  std::size_t pool_pinned{0};
  std::string backend{"native"};
};

class EmbeddedDatabase {
 public:
  explicit EmbeddedDatabase(EmbeddedConfig config = {});
  const EmbeddedStatus& status() const { return status_; }
  bool open();
  void close();
  bool migrate();
  std::optional<std::string> exec_sql(std::string_view sql);
  NativeExecResult exec_parameterized(std::string_view sql, const std::vector<std::string>& params = {});
  static std::string exec_result_json(const NativeExecResult& result);

  WalWriter* wal_writer();
  Changefeed* changefeed_hub();
  NativeExecutor* native_executor();

 private:
  static std::string flatten_catalog_sql(std::string_view sql);

  EmbeddedConfig config_{};
  EmbeddedStatus status_{};
  std::optional<BufferPool> pool_;
  std::optional<HeapStore> heap_;
  std::optional<WalWriter> wal_;
  Changefeed changefeed_;
  std::optional<NativeExecutor> native_exec_;
  std::unique_ptr<NativeCatalog> catalog_;
};

}  // namespace lidb

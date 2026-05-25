#pragma once

#include <string_view>
#include <vector>

#include "lidb/changefeed.hpp"
#include "lidb/wal.hpp"

namespace lidb {

class NativeExecutor {
 public:
  NativeExecutor(WalWriter& wal, Changefeed& changefeed);
  std::uint64_t insert(std::string_view table, const std::vector<std::byte>& row_payload = {});

 private:
  static std::vector<std::byte> encode_heap_insert(std::string_view table,
                                                   const std::vector<std::byte>& row);
  WalWriter& wal_;
  Changefeed& changefeed_;
};

}  // namespace lidb

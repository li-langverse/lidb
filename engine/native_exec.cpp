#include "lidb/native_exec.hpp"

namespace lidb {
namespace {

void append_u32(std::vector<std::byte>& out, std::uint32_t v) {
  auto b = reinterpret_cast<const std::byte*>(&v);
  out.insert(out.end(), b, b + sizeof(v));
}

void append_bytes(std::vector<std::byte>& out, std::string_view s) {
  append_u32(out, static_cast<std::uint32_t>(s.size()));
  out.insert(out.end(), reinterpret_cast<const std::byte*>(s.data()),
             reinterpret_cast<const std::byte*>(s.data() + s.size()));
}

}  // namespace

NativeExecutor::NativeExecutor(WalWriter& wal, Changefeed& changefeed) : wal_(wal), changefeed_(changefeed) {}

std::vector<std::byte> NativeExecutor::encode_heap_insert(std::string_view table,
                                                          const std::vector<std::byte>& row) {
  std::vector<std::byte> payload;
  append_bytes(payload, table);
  append_u32(payload, static_cast<std::uint32_t>(row.size()));
  if (!row.empty()) payload.insert(payload.end(), row.begin(), row.end());
  return payload;
}

std::uint64_t NativeExecutor::insert(std::string_view table, const std::vector<std::byte>& row_payload) {
  auto payload = encode_heap_insert(table, row_payload);
  const std::uint64_t lsn = wal_.append(WalRecordType::kHeapInsert, payload);
  changefeed_.on_wal_append(lsn, ChangefeedOp::kInsert, table, row_payload);
  return lsn;
}

}  // namespace lidb

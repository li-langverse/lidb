#include "lidb/wal.hpp"
#include <stdexcept>
namespace lidb {
WalWriter::WalWriter(std::filesystem::path segment_path) : path_(std::move(segment_path)) {
  stream_.open(path_, std::ios::binary | std::ios::app);
  if (!stream_.is_open()) throw std::runtime_error("failed to open WAL segment");
}
std::uint64_t WalWriter::append(WalRecordType type, const std::vector<std::byte>& payload) {
  WalRecordHeader header{};
  header.type = type;
  header.length = static_cast<std::uint32_t>(payload.size());
  header.lsn = next_lsn_++;
  stream_.write(reinterpret_cast<const char*>(&header), sizeof(header));
  if (!payload.empty()) stream_.write(reinterpret_cast<const char*>(payload.data()), static_cast<std::streamsize>(payload.size()));
  stream_.flush();
  return header.lsn;
}
}

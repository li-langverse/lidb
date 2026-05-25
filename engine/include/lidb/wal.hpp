#pragma once
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <vector>
namespace lidb {
enum class WalRecordType : std::uint8_t { kNoop = 0, kHeapInsert = 1, kHeapUpdate = 2, kCheckpoint = 3 };
struct WalRecordHeader { std::uint32_t magic{0x4C494457}; std::uint32_t length{0}; WalRecordType type{WalRecordType::kNoop}; std::uint64_t lsn{0}; };
class WalWriter {
 public:
  explicit WalWriter(std::filesystem::path segment_path);
  std::uint64_t append(WalRecordType type, const std::vector<std::byte>& payload);
 private:
  std::filesystem::path path_;
  std::fstream stream_;
  std::uint64_t next_lsn_{1};
};
}

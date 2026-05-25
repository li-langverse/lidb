#pragma once

#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <vector>

#include "lidb/buffer_pool.hpp"

namespace lidb {

inline constexpr std::uint32_t kHeapPageMagic = 0x4C494448;

struct HeapPageHeader {
  std::uint32_t magic{kHeapPageMagic};
  std::uint32_t page_no{0};
  std::uint32_t used_bytes{sizeof(HeapPageHeader)};
  std::uint32_t row_slots{0};
};

class HeapStore {
 public:
  explicit HeapStore(std::filesystem::path heap_dir, std::size_t page_size = kDefaultPageSize);
  PageId allocate_page();
  bool write_page(PageId id, const std::byte* data, std::size_t nbytes);
  std::vector<std::byte> read_page(PageId id) const;

 private:
  std::filesystem::path heap_dir_;
  std::size_t page_size_;
  std::uint32_t next_page_no_{0};
  std::filesystem::path page_path(PageId id) const;
};

}  // namespace lidb

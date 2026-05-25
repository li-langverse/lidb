#pragma once
#include <cstddef>
#include <cstdint>
#include <memory>
#include <vector>
namespace lidb {
inline constexpr std::size_t kDefaultPageSize = 8192;
struct PageId { std::uint32_t file_id{0}; std::uint32_t page_no{0}; };
struct BufferPoolConfig { std::size_t page_size{kDefaultPageSize}; std::size_t capacity_pages{64}; };
class BufferPool {
 public:
  explicit BufferPool(BufferPoolConfig config = {});
  std::byte* pin(PageId id);
  void unpin(PageId id);
  std::size_t pinned_count() const { return pinned_.size(); }
 private:
  BufferPoolConfig config_;
  std::vector<std::unique_ptr<std::byte[]>> store_;
  std::vector<PageId> pinned_;
};
}

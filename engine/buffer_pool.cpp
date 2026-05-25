#include "lidb/buffer_pool.hpp"
#include <algorithm>
#include <cstring>
#include <stdexcept>
namespace lidb {
BufferPool::BufferPool(BufferPoolConfig config) : config_(config) {}
std::byte* BufferPool::pin(PageId id) {
  auto it = std::find_if(pinned_.begin(), pinned_.end(), [&](const PageId& p) { return p.file_id == id.file_id && p.page_no == id.page_no; });
  if (it != pinned_.end()) return store_[static_cast<std::size_t>(it - pinned_.begin())].get();
  if (pinned_.size() >= config_.capacity_pages) throw std::runtime_error("buffer pool full");
  auto page = std::make_unique<std::byte[]>(config_.page_size);
  std::memset(page.get(), 0, config_.page_size);
  auto* raw = page.get();
  store_.push_back(std::move(page));
  pinned_.push_back(id);
  return raw;
}
void BufferPool::unpin(PageId id) {
  auto it = std::find_if(pinned_.begin(), pinned_.end(), [&](const PageId& p) { return p.file_id == id.file_id && p.page_no == id.page_no; });
  if (it == pinned_.end()) return;
  auto idx = static_cast<std::size_t>(it - pinned_.begin());
  pinned_.erase(it);
  store_.erase(store_.begin() + static_cast<std::ptrdiff_t>(idx));
}
}

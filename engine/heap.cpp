#include "lidb/heap.hpp"

#include <cstring>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <stdexcept>

namespace lidb {

HeapStore::HeapStore(std::filesystem::path heap_dir, std::size_t page_size)
    : heap_dir_(std::move(heap_dir)), page_size_(page_size) {
  std::filesystem::create_directories(heap_dir_);
}

std::filesystem::path HeapStore::page_path(PageId id) const {
  std::ostringstream name;
  name << std::setw(8) << std::setfill('0') << id.page_no << ".page";
  return heap_dir_ / name.str();
}

PageId HeapStore::allocate_page() {
  PageId id{.file_id = 0, .page_no = next_page_no_++};
  std::vector<std::byte> buf(page_size_);
  auto* hdr = reinterpret_cast<HeapPageHeader*>(buf.data());
  hdr->magic = kHeapPageMagic;
  hdr->page_no = id.page_no;
  if (!write_page(id, buf.data(), buf.size())) throw std::runtime_error("heap page allocate failed");
  return id;
}

bool HeapStore::write_page(PageId id, const std::byte* data, std::size_t nbytes) {
  if (nbytes > page_size_) return false;
  std::vector<std::byte> buf(page_size_);
  std::memcpy(buf.data(), data, nbytes);
  std::ofstream out(page_path(id), std::ios::binary | std::ios::trunc);
  if (!out.is_open()) return false;
  out.write(reinterpret_cast<const char*>(buf.data()), static_cast<std::streamsize>(page_size_));
  return out.good();
}

std::vector<std::byte> HeapStore::read_page(PageId id) const {
  std::vector<std::byte> buf(page_size_);
  if (!std::filesystem::exists(page_path(id))) return {};
  std::ifstream in(page_path(id), std::ios::binary);
  if (!in.is_open()) return {};
  in.read(reinterpret_cast<char*>(buf.data()), static_cast<std::streamsize>(page_size_));
  return buf;
}

}  // namespace lidb

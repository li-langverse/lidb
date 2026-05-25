#include "lidb/changefeed_c.h"

#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#include <atomic>
#include <cstring>
#include <filesystem>
#include <memory>
#include <string>

#include "lidb/changefeed.hpp"
#include "lidb/embedded.hpp"
#include "lidb/native_exec.hpp"

struct lidb_changefeed {
  std::unique_ptr<lidb::EmbeddedDatabase> db;
  std::atomic<bool> serving{false};
};

lidb_changefeed* lidb_changefeed_open(const char* data_dir) {
  if (data_dir == nullptr) return nullptr;
  auto handle = std::make_unique<lidb_changefeed>();
  handle->db = std::make_unique<lidb::EmbeddedDatabase>(
      lidb::EmbeddedConfig{.data_dir = std::filesystem::path(data_dir)});
  if (!handle->db->open()) return nullptr;
  if (handle->db->wal_writer() == nullptr || handle->db->changefeed_hub() == nullptr) return nullptr;
  if (handle->db->native_executor() == nullptr) return nullptr;
  return handle.release();
}

void lidb_changefeed_close(lidb_changefeed* handle) {
  if (handle == nullptr) return;
  handle->serving.store(false);
  if (handle->db) handle->db->close();
  delete handle;
}

uint64_t lidb_changefeed_subscribe(lidb_changefeed* handle, const char* table) {
  if (handle == nullptr || table == nullptr || handle->db == nullptr) return 0;
  auto* hub = handle->db->changefeed_hub();
  if (hub == nullptr) return 0;
  return hub->subscribe(table, [](const lidb::ChangefeedEvent&) {});
}

void lidb_changefeed_unsubscribe(lidb_changefeed* handle, uint64_t subscription_id) {
  if (handle == nullptr || subscription_id == 0 || handle->db == nullptr) return;
  auto* hub = handle->db->changefeed_hub();
  if (hub) hub->unsubscribe(subscription_id);
}

uint64_t lidb_changefeed_native_insert(lidb_changefeed* handle, const char* table) {
  if (handle == nullptr || table == nullptr || handle->db == nullptr) return 0;
  auto* exec = handle->db->native_executor();
  if (exec == nullptr) return 0;
  return exec->insert(table);
}

int lidb_changefeed_poll(lidb_changefeed* handle, char* buf, size_t cap, size_t* out_len) {
  if (handle == nullptr || buf == nullptr || cap == 0 || handle->db == nullptr) return -1;
  auto* hub = handle->db->changefeed_hub();
  if (hub == nullptr) return -1;
  std::string line;
  if (!hub->poll_json_line(line)) {
    if (out_len) *out_len = 0;
    return 0;
  }
  if (line.size() >= cap) return -1;
  std::memcpy(buf, line.data(), line.size());
  buf[line.size()] = '\0';
  if (out_len) *out_len = line.size();
  return 1;
}

int lidb_changefeed_serve_unix(lidb_changefeed* handle, const char* socket_path) {
  if (handle == nullptr || socket_path == nullptr || handle->db == nullptr) return -1;
  auto* hub = handle->db->changefeed_hub();
  if (hub == nullptr) return -1;

  std::filesystem::path path(socket_path);
  std::error_code ec;
  std::filesystem::remove(path, ec);

  int server = ::socket(AF_UNIX, SOCK_STREAM, 0);
  if (server < 0) return -1;

  sockaddr_un addr{};
  addr.sun_family = AF_UNIX;
  if (std::strlen(socket_path) >= sizeof(addr.sun_path)) {
    ::close(server);
    return -1;
  }
  std::strncpy(addr.sun_path, socket_path, sizeof(addr.sun_path) - 1);
  if (::bind(server, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0) {
    ::close(server);
    return -1;
  }
  if (::listen(server, 8) < 0) {
    ::close(server);
    return -1;
  }

  handle->serving.store(true);
  while (handle->serving.load()) {
    int client = ::accept(server, nullptr, nullptr);
    if (client < 0) {
      if (!handle->serving.load()) break;
      continue;
    }
    hub->attach_unix_client(client);
  }

  ::close(server);
  std::filesystem::remove(path, ec);
  return 0;
}

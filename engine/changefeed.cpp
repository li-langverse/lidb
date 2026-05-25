#include "lidb/changefeed.hpp"

#include <unistd.h>

#include <algorithm>
#include <sstream>
#include <unordered_set>

namespace lidb {
namespace {

const char* op_name(ChangefeedOp op) {
  switch (op) {
    case ChangefeedOp::kInsert:
      return "insert";
    case ChangefeedOp::kUpdate:
      return "update";
  }
  return "unknown";
}

}  // namespace

Changefeed::SubscriptionId Changefeed::subscribe(std::string_view table, Callback callback) {
  std::lock_guard lock(mutex_);
  SubscriptionId id = next_id_++;
  subscriptions_.push_back(Subscription{.id = id, .table = std::string(table), .callback = std::move(callback)});
  return id;
}

void Changefeed::unsubscribe(SubscriptionId id) {
  std::lock_guard lock(mutex_);
  subscriptions_.erase(
      std::remove_if(subscriptions_.begin(), subscriptions_.end(),
                     [id](const Subscription& s) { return s.id == id; }),
      subscriptions_.end());
}

void Changefeed::on_wal_append(std::uint64_t lsn, ChangefeedOp op, std::string_view table,
                               const std::vector<std::byte>& payload) {
  publish(ChangefeedEvent{.lsn = lsn, .table = std::string(table), .op = op, .payload = payload});
}

bool Changefeed::attach_unix_client(int client_fd) {
  if (client_fd < 0) return false;
  std::lock_guard lock(mutex_);
  unix_clients_.push_back(client_fd);
  return true;
}

void Changefeed::detach_unix_client(int client_fd) {
  std::lock_guard lock(mutex_);
  unix_clients_.erase(
      std::remove_if(unix_clients_.begin(), unix_clients_.end(),
                     [client_fd](int fd) { return fd == client_fd; }),
      unix_clients_.end());
}

bool Changefeed::poll_json_line(std::string& out) {
  std::lock_guard lock(mutex_);
  if (poll_queue_.empty()) return false;
  out = std::move(poll_queue_.front());
  poll_queue_.pop_front();
  return true;
}

void Changefeed::publish(const ChangefeedEvent& event) {
  std::vector<Callback> callbacks;
  std::string line;
  {
    std::lock_guard lock(mutex_);
    for (const auto& sub : subscriptions_) {
      if (sub.table == event.table || sub.table == "*") callbacks.push_back(sub.callback);
    }
    line = event_to_json(event);
    poll_queue_.push_back(line);
  }
  for (const auto& cb : callbacks) cb(event);
  fanout_json(line);
}

void Changefeed::fanout_json(const std::string& line) {
  std::string framed = line;
  framed.push_back('\n');
  std::vector<int> clients;
  {
    std::lock_guard lock(mutex_);
    clients = unix_clients_;
  }
  std::unordered_set<int> dead;
  for (int fd : clients) {
    ssize_t n = ::write(fd, framed.data(), framed.size());
    if (n < 0 || static_cast<std::size_t>(n) != framed.size()) dead.insert(fd);
  }
  if (!dead.empty()) {
    std::lock_guard lock(mutex_);
    unix_clients_.erase(std::remove_if(unix_clients_.begin(), unix_clients_.end(),
                                       [&dead](int fd) { return dead.count(fd) != 0; }),
                        unix_clients_.end());
  }
}

std::string Changefeed::event_to_json(const ChangefeedEvent& event) {
  std::ostringstream os;
  os << "{\"lsn\":" << event.lsn << ",\"table\":\"" << event.table << "\",\"op\":\"" << op_name(event.op)
     << "\",\"payload_bytes\":" << event.payload.size() << "}";
  return os.str();
}

}  // namespace lidb

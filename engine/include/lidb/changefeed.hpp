#pragma once

#include <cstdint>
#include <deque>
#include <functional>
#include <mutex>
#include <string>
#include <string_view>
#include <vector>

namespace lidb {

enum class ChangefeedOp : std::uint8_t { kInsert = 1, kUpdate = 2 };

struct ChangefeedEvent {
  std::uint64_t lsn{0};
  std::string table;
  ChangefeedOp op{ChangefeedOp::kInsert};
  std::vector<std::byte> payload;
};

class Changefeed {
 public:
  using Callback = std::function<void(const ChangefeedEvent&)>;
  using SubscriptionId = std::uint64_t;

  SubscriptionId subscribe(std::string_view table, Callback callback);
  void unsubscribe(SubscriptionId id);
  void on_wal_append(std::uint64_t lsn, ChangefeedOp op, std::string_view table,
                     const std::vector<std::byte>& payload);
  bool poll_json_line(std::string& out);
  bool attach_unix_client(int client_fd);
  void detach_unix_client(int client_fd);

 private:
  struct Subscription {
    SubscriptionId id{0};
    std::string table;
    Callback callback;
  };

  void publish(const ChangefeedEvent& event);
  static std::string event_to_json(const ChangefeedEvent& event);
  void fanout_json(const std::string& line);

  std::mutex mutex_;
  std::vector<Subscription> subscriptions_;
  std::uint64_t next_id_{1};
  std::deque<std::string> poll_queue_;
  std::vector<int> unix_clients_;
};

}  // namespace lidb

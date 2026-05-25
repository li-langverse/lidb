#include <cassert>
#include <filesystem>
#include <iostream>
#include <string>
#include <vector>

#include "lidb/changefeed_c.h"
#include "lidb/changefeed.hpp"
#include "lidb/embedded.hpp"
#include "lidb/native_exec.hpp"

int main() {
  auto dir = std::filesystem::temp_directory_path() / "lidb-cf-smoke";
  std::error_code ec;
  std::filesystem::remove_all(dir, ec);
  std::filesystem::create_directories(dir);

  lidb::EmbeddedDatabase db({.data_dir = dir});
  if (!db.open()) {
    std::cerr << "open failed\n";
    return 1;
  }

  std::vector<std::string> captured;
  const auto sub = db.changefeed_hub()->subscribe(
      "packages", [&](const lidb::ChangefeedEvent& ev) { captured.push_back(ev.table); });

  auto* exec = db.native_executor();
  assert(exec != nullptr);
  const std::uint64_t lsn = exec->insert("packages");
  assert(lsn > 0);
  assert(captured.size() == 1 && captured[0] == "packages");

  std::string line;
  assert(db.changefeed_hub()->poll_json_line(line));
  assert(line.find("\"table\":\"packages\"") != std::string::npos);
  assert(line.find("\"op\":\"insert\"") != std::string::npos);

  db.changefeed_hub()->unsubscribe(sub);
  db.close();

  auto* handle = lidb_changefeed_open(dir.string().c_str());
  if (handle == nullptr) {
    std::cerr << "C open failed\n";
    return 1;
  }
  (void)lidb_changefeed_subscribe(handle, "*");
  const std::uint64_t lsn2 = lidb_changefeed_native_insert(handle, "agent_runs");
  if (lsn2 == 0) {
    std::cerr << "native_insert failed\n";
    lidb_changefeed_close(handle);
    return 1;
  }

  char buf[512];
  size_t n = 0;
  const int polled = lidb_changefeed_poll(handle, buf, sizeof(buf), &n);
  if (polled != 1) {
    std::cerr << "poll expected 1 got " << polled << "\n";
    lidb_changefeed_close(handle);
    return 1;
  }
  std::string polled_line(buf, n);
  if (polled_line.find("agent_runs") == std::string::npos) {
    std::cerr << "unexpected poll payload: " << polled_line << "\n";
    lidb_changefeed_close(handle);
    return 1;
  }

  lidb_changefeed_close(handle);
  std::cout << "changefeed_smoke ok lsn=" << lsn << " c_lsn=" << lsn2 << "\n";
  return 0;
}

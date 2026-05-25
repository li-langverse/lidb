#include <iostream>
#include <string>
#include "lidb/embedded.hpp"
static void usage() {
  std::cerr << "lidb_embed open|migrate|exec <data-dir> [sql]\n";
}
int main(int argc, char** argv) {
  if (argc < 3) { usage(); return 2; }
  std::string cmd = argv[1];
  std::filesystem::path dir = argv[2];
  if (cmd == "open") {
    lidb::EmbeddedDatabase db({.data_dir = dir});
    if (!db.open()) return 1;
    std::cout << "open ok wal_lsn=" << db.status().wal_lsn << " catalog=" << db.status().catalog_path << "\n";
    return 0;
  }
  if (cmd == "migrate") {
    lidb::EmbeddedDatabase db({.data_dir = dir});
    if (!db.open() || !db.migrate()) { std::cerr << "migrate failed\n"; return 1; }
    std::cout << "migrate ok\n"; return 0;
  }
  if (cmd == "exec" && argc >= 4) {
    lidb::EmbeddedDatabase db({.data_dir = dir});
    if (!db.open()) return 1;
    auto out = db.exec_sql(argv[3]);
    if (!out) { std::cerr << "exec failed\n"; return 1; }
    if (!out->empty()) std::cout << *out << "\n";
    return 0;
  }
  usage(); return 2;
}

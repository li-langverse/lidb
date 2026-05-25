// PH-DB-1 placeholder — real heap/WAL in PH-DB-2.
// Build wiring: CMakeLists.txt (TODO) + lic native interop.

namespace lidb {
namespace smoke {

// TODO PH-DB-2: allocate 8 KiB page, write WAL record header, fsync stub.
int storage_placeholder() { return 0; }

}  // namespace smoke
}  // namespace lidb

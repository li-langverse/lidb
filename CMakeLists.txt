# PH-DB-N1: native heap + WAL (no sqlite smoke path).
cmake_minimum_required(VERSION 3.20)
project(lidb LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
add_library(lidb_engine
  engine/buffer_pool.cpp engine/wal.cpp engine/heap.cpp engine/changefeed.cpp
  engine/native_catalog.cpp engine/native_exec.cpp engine/embedded.cpp)
target_include_directories(lidb_engine PUBLIC engine/include)
target_compile_features(lidb_engine PUBLIC cxx_std_20)
add_executable(lidb_embed engine/cli/embed_main.cpp)
target_link_libraries(lidb_embed PRIVATE lidb_engine)
add_library(lidb_storage_smoke STATIC src/storage_smoke.cpp)
target_compile_features(lidb_storage_smoke PUBLIC cxx_std_20)

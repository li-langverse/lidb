# PH-DB: native heap + WAL + changefeed C API + Li SQL (no sqlite).
cmake_minimum_required(VERSION 3.20)
project(lidb LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(lidb_sql
  sql/parser/lexer.cpp
  sql/parser/registry_parse.cpp
)
target_include_directories(lidb_sql PUBLIC sql/include)
target_compile_features(lidb_sql PUBLIC cxx_std_20)

add_library(lidb_engine
  engine/buffer_pool.cpp
  engine/wal.cpp
  engine/heap.cpp
  engine/changefeed.cpp
  engine/native_catalog.cpp
  engine/native_exec.cpp
  engine/embedded.cpp
)
target_include_directories(lidb_engine PUBLIC engine/include)
target_compile_features(lidb_engine PUBLIC cxx_std_20)
target_link_libraries(lidb_engine PUBLIC lidb_sql)

add_library(lidb_changefeed_c SHARED engine/changefeed_c.cpp)
target_link_libraries(lidb_changefeed_c PUBLIC lidb_engine)
target_include_directories(lidb_changefeed_c PUBLIC engine/include)
set_target_properties(lidb_changefeed_c PROPERTIES OUTPUT_NAME lidb_changefeed)

add_executable(lidb_embed engine/cli/embed_main.cpp)
target_link_libraries(lidb_embed PRIVATE lidb_engine)

add_executable(lidb_changefeed_smoke engine/tests/changefeed_smoke.cpp)
target_link_libraries(lidb_changefeed_smoke PRIVATE lidb_engine lidb_changefeed_c)

add_library(lidb_storage_smoke STATIC src/storage_smoke.cpp)
target_compile_features(lidb_storage_smoke PUBLIC cxx_std_20)

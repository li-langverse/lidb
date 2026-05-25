# PH-DB-1 scaffold — full engine target in PH-DB-2.
cmake_minimum_required(VERSION 3.20)
project(lidb LANGUAGES CXX)

add_library(lidb_storage_smoke STATIC src/storage_smoke.cpp)
target_compile_features(lidb_storage_smoke PUBLIC cxx_std_20)

# TODO PH-DB-2: lidb_core (WAL + heap), lidb_embedded, install rules

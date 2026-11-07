# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(stockfish_chess_engine VERSION 0.0.1 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
if(ANDROID)
  set(IS_MOBILE_TARGET ON)
  add_definitions(-DIS_MOBILE_TARGET=1)
endif()

file(GLOB_RECURSE cppPaths "Stockfish/src/*.cpp")
set(NNUE_NAME_BIG nn-1111cefa1111.nnue)
set(NNUE_NAME_SMALL nn-37f18f62d772.nnue)

add_library(stockfish_chess_engine SHARED
  "stockfish_chess_engine.cpp"
  "fixes/stream_fix.cpp"
  "fixes/small_fixes.cpp"
  ${cppPaths}
)

set_target_properties(stockfish_chess_engine PROPERTIES
  PUBLIC_HEADER stockfish_chess_engine.h
  OUTPUT_NAME "stockfish_chess_engine"
)

target_compile_options(stockfish_chess_engine PRIVATE -fPIC)

if(MSVC)
    add_definitions(/FI"fixes/fixes.h")
else()
    add_definitions(-include "fixes/fixes.h")
endif()

target_compile_definitions(stockfish_chess_engine PUBLIC DART_SHARED_LIB)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(stockfish_chess_engine PRIVATE "-Wl,-z,max-page-size=16384")
endif()

target_include_directories(stockfish_chess_engine
  PUBLIC
  "./"
)

# kang-chess patch: the upstream script re-downloaded both nets (~78 MB) on
# every CMake configure. Nets are named after the first 12 hex chars of their
# SHA-256, so an existing file is reused when its hash matches its name, and
# downloads go to a .part file so an interrupted build can't leave a bad net.
function(stockfish_fetch_net name dir)
  set(path "${dir}/${name}")
  string(REGEX MATCH "^nn-([0-9a-f]+)\\.nnue$" _ "${name}")
  set(expected "${CMAKE_MATCH_1}")
  if (EXISTS "${path}")
    file(SHA256 "${path}" hash)
    string(SUBSTRING "${hash}" 0 12 hash)
    if (hash STREQUAL expected)
      return()
    endif ()
  endif ()
  message(STATUS "Downloading Stockfish net ${name}")
  file(DOWNLOAD https://tests.stockfishchess.org/api/nn/${name} "${path}.part"
    STATUS status SHOW_PROGRESS)
  list(GET status 0 code)
  file(SHA256 "${path}.part" hash)
  string(SUBSTRING "${hash}" 0 12 hash)
  if (NOT code EQUAL 0 OR NOT hash STREQUAL expected)
    file(REMOVE "${path}.part")
    message(FATAL_ERROR "Failed to download Stockfish net ${name}: ${status}")
  endif ()
  file(RENAME "${path}.part" "${path}")
endfunction()

if (MSVC)
    stockfish_fetch_net(${NNUE_NAME_BIG} ${CMAKE_BINARY_DIR}/runner/Debug)
    stockfish_fetch_net(${NNUE_NAME_SMALL} ${CMAKE_BINARY_DIR}/runner/Debug)
    file(COPY ${CMAKE_BINARY_DIR}/runner/Debug/${NNUE_NAME_BIG} DESTINATION ${CMAKE_BINARY_DIR}/runner/Release)
    file(COPY ${CMAKE_BINARY_DIR}/runner/Debug/${NNUE_NAME_SMALL} DESTINATION ${CMAKE_BINARY_DIR}/runner/Release)
else ()
    if (NOT DEFINED IS_MOBILE_TARGET)
      stockfish_fetch_net(${NNUE_NAME_BIG} ${CMAKE_BINARY_DIR})
    endif ()
    stockfish_fetch_net(${NNUE_NAME_SMALL} ${CMAKE_BINARY_DIR})
endif ()

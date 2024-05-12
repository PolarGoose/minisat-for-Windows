cmake_minimum_required(VERSION 3.28)

project(minisat)

set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

find_package(ZLIB REQUIRED)

add_library(minisat_lib STATIC
  minisat/utils/Options.cc
  minisat/utils/System.cc
  minisat/core/Solver.cc
  minisat/simp/SimpSolver.cc)
target_link_libraries(minisat_lib ZLIB::ZLIB)
target_include_directories(minisat_lib PUBLIC ${CMAKE_SOURCE_DIR})

add_executable(minisat_core minisat/core/Main.cc)
target_link_libraries(minisat_core minisat_lib)

add_executable(minisat minisat/simp/Main.cc)
target_link_libraries(minisat minisat_lib)

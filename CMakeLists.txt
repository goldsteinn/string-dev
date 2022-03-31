cmake_minimum_required(VERSION 3.1.3)
project(Project_Template C CXX ASM)

set(LANG "C" CACHE STRING "Set Language (CXX or C")
set_property(CACHE LANG
  PROPERTY STRINGS "C" "CXX")


set(cxx_lang "CXX" "C++" "CPP" "CC" "cxx" "c++" "cpp" "cc")
set(c_lang "C" "c")


list(FIND cxx_lang ${LANG} cxx_lang)
list(FIND c_lang ${LANG} c_lang)
if(${cxx_lang} GREATER -1)
  set(LANG "CXX")
  set(STD "c++11")
  set(LANG_FLAGS "-fno-exceptions" "-Wno-noexcept-type" "-fno-rtti")
elseif(${c_lang} GREATER -1)
  set(LANG "C")
  set(STD "c11")
  set(LANG_FLAGS "")
else()
  message(FATAL_ERROR "Invalid language selection: ${LANG}")
endif()

set(CMAKE_EXPORT_COMPILE_COMMANDS on)

#set(CMAKE_C_COMPILER "/usr/bin/gcc")
#set(CMAKE_CXX_COMPILER "/usr/bin/g++")

set(SRC_DIR "src")
set(FULL_SRC_DIR "${CMAKE_SOURCE_DIR}/${SRC_DIR}")

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D__FILENAME__='\"$(subst ${FULL_SRC_DIR}/,,$(abspath $<))\"'")

set(attrs "pure" "const" "noreturn" "format" "cold" "malloc")
set(wattrs)
foreach(attr ${attrs})
  list(APPEND wattrs "-Wsuggest-attribute=${attr}")
endforeach()


add_compile_options(-D_GNU_SOURCE -O2 -Wwrite-strings -Wcast-qual -Wclobbered -Wdangling-else -Woverlength-strings -Wdisabled-optimization -Wstrict-aliasing -Wstrict-overflow  -Werror -Wall -Wextra -Wno-unused-function -Wno-variadic-macros -march=native -mtune=native -std=${STD} ${LANG_FLAGS})

set(link_libraries  "")
list(APPEND link_libraries "-ldl")

set(test_and_bench_libraries ${link_libraries})
list(APPEND test_and_bench_libraries "-lpthread")

set(EXE_SRC ${SRC_DIR}/driver.c)
set(EXE "driver")

include_directories("${CMAKE_CURRENT_SOURCE_DIR}/${SRC_DIR}")
file(GLOB_RECURSE C_SOURCES "${CMAKE_SOURCE_DIR}/${SRC_DIR}/*.c")
set_source_files_properties(${C_SOURCES} PROPERTIES LANGUAGE ${LANG})

set(ALL_C_SOURCES ${C_SOURCES})
list(REMOVE_ITEM C_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/${EXE_SRC}")

file(GLOB_RECURSE ASM_SOURCES "${CMAKE_SOURCE_DIR}/${SRC_DIR}/*.S")
list(FILTER ASM_SOURCES EXCLUDE REGEX ".*/core/.*\.S$")


# Setup test executable
list(FILTER C_SOURCES EXCLUDE REGEX ".*/test/.*$")
list(FILTER C_SOURCES EXCLUDE REGEX ".*\.test\.c$")

set(TEST_EXE_SRC "${SRC_DIR}/test/test-driver.c")
set(TEST_EXE "test-driver")
file(GLOB_RECURSE TEST_SOURCES "${CMAKE_SOURCE_DIR}/${SRC_DIR}/*.test.c")
file(GLOB_RECURSE TEST_UTIL_SOURCES "${CMAKE_SOURCE_DIR}/${SRC_DIR}/test/*.c")
set(TEST_C_SOURCES ${TEST_SOURCES} ${TEST_UTIL_SOURCES})
list(REMOVE_ITEM TEST_C_SOURCES ${TEST_EXE_SRC})


# Setup bench executable
list(FILTER C_SOURCES EXCLUDE REGEX ".*/bench/.*$")
list(FILTER C_SOURCES EXCLUDE REGEX ".*\.bench\.c$")

set(BENCH_EXE_SRC "${SRC_DIR}/bench/bench-driver.c")
set(BENCH_EXE "bench-driver")
file(GLOB_RECURSE BENCH_SOURCES "${CMAKE_SOURCE_DIR}/${SRC_DIR}/*.bench.c")
file(GLOB_RECURSE BENCH_UTIL_SOURCES "${CMAKE_SOURCE_DIR}/${SRC_DIR}/bench/*.c")
set(BENCH_C_SOURCES ${BENCH_SOURCES} ${BENCH_UTIL_SOURCES})
list(REMOVE_ITEM BENCH_C_SOURCES ${BENCH_EXE_SRC})



find_program(CLANG_TIDY_EXE clang-tidy NAMES clang-tidy-13 clang-tidy-12 clang-tidy-10 clang-tidy-9 clang-tidy-8)
# We don't get cache with this method which slows down check.
add_custom_target(
  static-analysis
  COMMAND ${CLANG_TIDY_EXE}
  ${ALL_C_SOURCES}
  -p=${CMAKE_CURRENT_BINARY_DIR}
#  -checks=*,-*insecureAPI.strcpy,-*insecureAPI.DeprecatedOrUnsafeBufferHandling
  )

add_executable(driver ${EXE_SRC} ${C_SOURCES} ${ASM_SOURCES})
target_link_libraries(driver ${link_libraries})
set_target_properties(driver PROPERTIES LINKER_LANGUAGE ${LANG})

add_executable(tests ${TEST_EXE_SRC} ${TEST_C_SOURCES} ${C_SOURCES} ${ASM_SOURCES})
target_link_libraries(tests ${test_and_bench_libraries})
set_target_properties(tests PROPERTIES EXCLUDE_FROM_ALL TRUE)
set_target_properties(tests PROPERTIES LINKER_LANGUAGE ${LANG})

add_executable(bench ${BENCH_EXE_SRC} ${BENCH_C_SOURCES} ${C_SOURCES} ${ASM_SOURCES})
target_link_libraries(bench ${test_and_bench_libraries})
set_target_properties(bench PROPERTIES EXCLUDE_FROM_ALL TRUE)
set_target_properties(bench PROPERTIES LINKER_LANGUAGE ${LANG})

add_custom_target(full)
add_dependencies(full driver tests bench)

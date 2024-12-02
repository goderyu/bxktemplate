cmake_minimum_required(VERSION 3.20)
project(bxktemplate VERSION 0.1.0 LANGUAGES C CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(helper)
bxk_init_dir()
bxk_add_global_definations()
bxk_fix_default_compiler_settings()

option(BUILD_SHARED_LIBS "Build package with shared libraries." ON)
option(BXK_BUILD_DOCS "Build documentation using Doxygen." OFF)

if(BXK_BUILD_DOCS)
  set(CMAKE_INSTALL_DOCDIR doc)
  set(BXK_DOC_STYLE_DIR ${BXK_DOC_DIR}/doxygen-awesome-css)
  add_subdirectory(doc)
endif()

add_subdirectory(src)

option(BXK_BUILD_TESTS "Build the tests" OFF)
if(BXK_BUILD_TESTS)
  enable_testing()
  include(GoogleTest)
  add_subdirectory(tests)
endif()

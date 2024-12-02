
include(GNUInstallDirs)

# 设置常用目录路径变量
macro(bxk_init_dir)
  set(BXK_ROOT_DIR ${CMAKE_CURRENT_SOURCE_DIR})
  set(BXK_BUILD_DIR ${BXK_ROOT_DIR}/build)
  set(BXK_MODULE_DIR ${BXK_ROOT_DIR}/cmake)
  set(BXK_DOC_DIR ${BXK_ROOT_DIR}/doc)
  set(BXK_TOOLS_DIR ${BXK_ROOT_DIR}/tools)
  set(BXK_INC_DIR ${BXK_ROOT_DIR}/include)
  set(BXK_SRC_DIR ${BXK_ROOT_DIR}/src)
  set(BXK_TESTS_DIR ${BXK_ROOT_DIR}/tests)
  set(BXK_THIRDPARTY_DIR ${BXK_ROOT_DIR}/thirdparty)
endmacro()


# Tweaks CMake's default compiler/linker settings to suit bxk's needs.
#
# This must be a macro(), as inside a function string() can only
# update variables in the function scope.
macro(bxk_fix_default_compiler_settings)
  if (CMAKE_CXX_COMPILER_ID MATCHES "MSVC|Clang")
    # For MSVC and Clang, CMake sets certain flags to defaults we want to
    # override.
    # This replacement code is taken from sample in the CMake Wiki at
    # https://gitlab.kitware.com/cmake/community/wikis/FAQ#dynamic-replace.
    foreach (flag_var
             CMAKE_C_FLAGS CMAKE_C_FLAGS_DEBUG CMAKE_C_FLAGS_RELEASE
             CMAKE_C_FLAGS_MINSIZEREL CMAKE_C_FLAGS_RELWITHDEBINFO
             CMAKE_CXX_FLAGS CMAKE_CXX_FLAGS_DEBUG CMAKE_CXX_FLAGS_RELEASE
             CMAKE_CXX_FLAGS_MINSIZEREL CMAKE_CXX_FLAGS_RELWITHDEBINFO)
      if (NOT BUILD_SHARED_LIBS)
        # When bxk is built as a shared library, it should also use
        # shared runtime libraries.  Otherwise, it may end up with multiple
        # copies of runtime library data in different modules, resulting in
        # hard-to-find crashes. When it is built as a static library, it is
        # preferable to use CRT as static libraries, as we don't have to rely
        # on CRT DLLs being available. CMake always defaults to using shared
        # CRT libraries, so we override that default here.
        string(REPLACE "/MD" "-MT" ${flag_var} "${${flag_var}}")
        string(REPLACE "-MD" "-MT" ${flag_var} "${${flag_var}}")

        # When using Ninja with Clang, static builds pass -D_DLL on Windows.
        # This is incorrect and should not happen, so we fix that here.
        string(REPLACE "-D_DLL" "" ${flag_var} "${${flag_var}}")
      endif()

      # We prefer more strict warning checking for building bxk.
      # Replaces /W3 with /W4 in defaults.
      string(REPLACE "/W3" "/W4" ${flag_var} "${${flag_var}}")

      # Prevent D9025 warning for targets that have exception handling
      # turned off (/EHs-c- flag). Where required, exceptions are explicitly
      # re-enabled using the cxx_exception_flags variable.
      string(REPLACE "/EHsc" "" ${flag_var} "${${flag_var}}")
    endforeach()
  endif()
endmacro()

function(bxk_join_paths joined_path first_path_segment)
  set(temp_path "${first_path_segment}")
  foreach(current_segment IN LISTS ARGN)
    if(NOT ("${current_segment}" STREQUAL ""))
      if(IS_ABSOLUTE "${current_segment}")
        set(temp_path "${current_segment}")
      else()
        set(temp_path "${temp_path}/${current_segment}")
      endif()
    endif()
  endforeach()
  set(${joined_path} "${temp_path}" PARENT_SCOPE)
endfunction()

macro(bxk_add_global_definations)
  if (CMAKE_SYSTEM_NAME MATCHES "Windows")
    add_definitions(-DOS_WIN=1)
    add_definitions(-DOS_LINUX=0)
    add_definitions(-DOS_MAC=0)
    set(OS_WIN ON)
    set(OS_LINUX OFF)
    set(OS_MAC OFF)
  elseif(CMAKE_SYSTEM_NAME MATCHES "Linux")
    add_definitions(-DOS_WIN=0)
    add_definitions(-DOS_LINUX=1)
    add_definitions(-DOS_MAC=0)
    set(OS_WIN OFF)
    set(OS_LINUX ON)
    set(OS_MAC OFF)
  elseif(CMAKE_SYSTEM_NAME MATCHES "Darwin")
    add_definitions(-DOS_WIN=0)
    add_definitions(-DOS_LINUX=0)
    add_definitions(-DOS_MAC=1)
    set(OS_WIN OFF)
    set(OS_LINUX OFF)
    set(OS_MAC ON)
  endif()
endmacro()


macro(bxk_add_module
  name
  version
)
  cmake_minimum_required(VERSION 3.13)
  project(${name} VERSION ${version} LANGUAGES C CXX)
  string(TOUPPER "${name}" UPPER_NAME)
  if(BUILD_SHARED_LIBS)
    add_library(${name} SHARED "")
    target_compile_definitions(${name} PRIVATE ${UPPER_NAME}_LIB_EXPORT INTERFACE ${UPPER_NAME}_SHARED)
  else()
    add_library(${name} STATIC "")
  endif()
  set(module_header ${name}-header-only)
  add_library(${module_header} INTERFACE)
  add_library(bxk::${module_header} ALIAS ${module_header})
  target_compile_definitions(${module_header} INTERFACE ${UPPER_NAME}_HEADER_ONLY=1)
  target_include_directories(
    ${module_header}
    INTERFACE
     $<BUILD_INTERFACE:${BXK_INC_DIR}>
     $<INSTALL_INTERFACE:include>
  )
  target_include_directories(
    ${name}
     PUBLIC
      $<BUILD_INTERFACE:${BXK_INC_DIR}>
      $<INSTALL_INTERFACE:include>
     PRIVATE
      .
  )
  set(MODULE_UPPER_NAME ${UPPER_NAME})
  set(MODULE_NAME ${name})
  configure_file(
    ${BXK_TOOLS_DIR}/template/module_version.h.in
    ${BXK_INC_DIR}/${name}/version.h
    @ONLY
  )
  configure_file(
    ${BXK_TOOLS_DIR}/template/module.h.in
    ${BXK_INC_DIR}/${name}/${name}.h
    @ONLY
  )

  configure_file(
    ${BXK_TOOLS_DIR}/template/module.cc.in
    ${BXK_SRC_DIR}/${name}/${name}.cc
    @ONLY
  )

  set_target_properties(
    ${name}
    PROPERTIES
      CXX_STANDARD 20
      CXX_EXTENSIONS OFF
      CXX_STANDARD_REQUIRED ON
      POSITION_INDEPENDENT_CODE 1
  )
  # TODO: 添加一个开发等级的日志，记录添加了什么模块，定义的导出宏为何等信息
  # message()
  # 获取目标的编译定义
  get_target_property(target_definitions ${name} COMPILE_DEFINITIONS)
  # 将编译定义保存到一个变量中
  set(target_definitions_list ${target_definitions})
  # 打印编译定义
  message("Target Definitions: ${target_definitions_list}")

endmacro()

macro(bxk_install_module
  name
)
  string(TOUPPER "${name}" UPPER_NAME)
  include(CMakePackageConfigHelpers)
  set(${UPPER_NAME}_CMAKE_DIR ${CMAKE_INSTALL_LIBDIR}/cmake/${name})
  set(version_config ${BXK_BUILD_DIR}/${name}/bxk${name}-config-version.cmake)
  set(project_config ${BXK_BUILD_DIR}/${name}/bxk${name}-config.cmake)
  # set(package_config ${BXK_CMAKE_DIR}/${name}/bxk-${name}.pc)
  set(targets_export_name bxk-${name}-targets)
  set(${UPPER_NAME}_LIB_DIR ${CMAKE_INSTALL_LIBDIR})

  # set_verbose(${UPPER_NAME}_PKGCONFIG_DIR ${CMAKE_INSTALL_LIBDIR}/pkgconfig CACHE STRING
  #             "Installation directory for pkgconfig (.pc) files, a relative "
  #             "path that will be joined with ${CMAKE_INSTALL_PREFIX} or an "
  #             "absolute path.")
  write_basic_package_version_file(
    ${version_config}
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY AnyNewerVersion
  )
  configure_package_config_file(
    ${BXK_TOOLS_DIR}/template/bxktemplate-config.cmake.in
    ${project_config}
    INSTALL_DESTINATION ${${UPPER_NAME}_CMAKE_DIR})
  # bxk_join_paths(libdir_for_pc_file "\${exec_prefix}" "${${UPPER_NAME}_LIB_DIR}")
  set(module_install_targets ${name} ${name}-header-only)
  set(lib_component "lib${name}${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH}")
  set(lib_component_dev "lib${name}${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH}-dev")
  install(
    TARGETS ${module_install_targets}
    EXPORT ${targets_export_name}
    LIBRARY DESTINATION lib COMPONENT ${lib_component}
    ARCHIVE DESTINATION lib COMPONENT ${lib_component_dev}
    RUNTIME DESTINATION bin COMPONENT ${lib_component}
    FRAMEWORK DESTINATION lib COMPONENT ${lib_component}
    INCLUDES DESTINATION include
    PUBLIC_HEADER DESTINATION include/${name}
    # SYMLINK NO
  )
  install(
    DIRECTORY ${BXK_INCLUDE_DIR}/${name} DESTINATION include
  )
  export(TARGETS ${module_install_targets} NAMESPACE bxk::
         FILE ${BXK_BUILD_DIR}/${targets_export_name}.cmake)
  install(
    FILES ${project_config} ${version_config}
    DESTINATION ${${UPPER_NAME}_CMAKE_DIR}
  )
  install(
    EXPORT ${targets_export_name}
    DESTINATION ${${UPPER_NAME}_CMAKE_DIR}
    NAMESPACE bxk::
  )
endmacro()

function(bxk_install_libs
  libs
)
  foreach(_lib ${libs})
    get_filename_component(_real_lib ${_lib} REALPATH)
    message(status "ready install: " ${_real_lib})
    install(FILES ${_real_lib} DESTINATION bin)
  endforeach()
endfunction()

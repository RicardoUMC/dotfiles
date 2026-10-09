cmake_minimum_required(VERSION 3.21)
project(tokyo-diagnostics VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 6.2 REQUIRED COMPONENTS Core Gui Qml Quick WaylandClient WaylandClientPrivate)
find_package(PkgConfig REQUIRED)
pkg_check_modules(WAYLAND_SERVER REQUIRED IMPORTED_TARGET wayland-server)
pkg_check_modules(WAYLAND_PROTOCOLS REQUIRED wayland-protocols)
pkg_get_variable(WAYLAND_PROTOCOLS_DATADIR wayland-protocols pkgdatadir)

find_program(WAYLAND_SCANNER_EXECUTABLE NAMES wayland-scanner)
if(NOT WAYLAND_SCANNER_EXECUTABLE)
    message(FATAL_ERROR "wayland-scanner is required to generate the xdg-shell server protocol")
endif()
if(NOT WAYLAND_PROTOCOLS_DATADIR)
    message(FATAL_ERROR "wayland-protocols pkgdatadir is required to locate stable xdg-shell.xml")
endif()

set(TOKYO_XDG_SHELL_XML
    "${WAYLAND_PROTOCOLS_DATADIR}/stable/xdg-shell/xdg-shell.xml"
)
if(NOT EXISTS "${TOKYO_XDG_SHELL_XML}")
    message(FATAL_ERROR "stable xdg-shell protocol XML was not found: ${TOKYO_XDG_SHELL_XML}")
endif()

set(TOKYO_WAYLAND_FIXTURE_GENERATED_DIR
    "${CMAKE_CURRENT_BINARY_DIR}/waylandfixture"
)
set(TOKYO_XDG_SHELL_SERVER_HEADER
    "${TOKYO_WAYLAND_FIXTURE_GENERATED_DIR}/xdg-shell-server-protocol.h"
)
set(TOKYO_XDG_SHELL_PRIVATE_CODE
    "${TOKYO_WAYLAND_FIXTURE_GENERATED_DIR}/xdg-shell-protocol.c"
)
add_custom_command(
    OUTPUT
        "${TOKYO_XDG_SHELL_SERVER_HEADER}"
        "${TOKYO_XDG_SHELL_PRIVATE_CODE}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${TOKYO_WAYLAND_FIXTURE_GENERATED_DIR}"
    COMMAND "${WAYLAND_SCANNER_EXECUTABLE}" server-header
        "${TOKYO_XDG_SHELL_XML}" "${TOKYO_XDG_SHELL_SERVER_HEADER}"
    COMMAND "${WAYLAND_SCANNER_EXECUTABLE}" private-code
        "${TOKYO_XDG_SHELL_XML}" "${TOKYO_XDG_SHELL_PRIVATE_CODE}"
    DEPENDS "${TOKYO_XDG_SHELL_XML}"
    VERBATIM
)

qt_standard_project_setup(REQUIRES 6.2)
qt_policy(SET QTP0001 NEW)
qt_policy(SET QTP0004 NEW)

qt_add_library(tokyo-diagnostics)
qt_add_qml_module(tokyo-diagnostics
    URI Tokyo.Diagnostics
    VERSION 1.0
    OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/Tokyo/Diagnostics"
    SOURCES
        diagnosticbridge.h
        diagnosticbridge.cpp
        subsurfaceprobe.h
        subsurfaceprobe.cpp
        waylandsubsurfaceadapter.h
        waylandsubsurfaceadapter.cpp
)
target_link_libraries(tokyo-diagnostics PUBLIC
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::WaylandClient
    Qt6::WaylandClientPrivate
)

target_compile_definitions(tokyo-diagnostics PRIVATE
    TOKYO_DIAGNOSTICS_VERSION="${PROJECT_VERSION}"
)

# Build/link-only API sentinel for the future isolated compositor work. This is
# deliberately outside the Qt/QML module and has no executable entry point.
add_library(tokyo-wayland-server-api-sentinel SHARED
    waylandserversentinel.cpp
)
target_compile_features(tokyo-wayland-server-api-sentinel PRIVATE cxx_std_17)
target_link_libraries(tokyo-wayland-server-api-sentinel PRIVATE
    PkgConfig::WAYLAND_SERVER
)

# Qt-independent, build/link-only protocol fixture. This generates the stable
# xdg-shell server API and references public libwayland interfaces without
# creating a display, socket, global, or other runtime state.
add_library(tokyo-wayland-fixture-core SHARED
    waylandfixturelink.cpp
    "${TOKYO_XDG_SHELL_SERVER_HEADER}"
    "${TOKYO_XDG_SHELL_PRIVATE_CODE}"
)
set_source_files_properties(
    "${TOKYO_XDG_SHELL_SERVER_HEADER}"
    PROPERTIES HEADER_FILE_ONLY TRUE
)
target_compile_features(tokyo-wayland-fixture-core PRIVATE cxx_std_17)
target_include_directories(tokyo-wayland-fixture-core PRIVATE
    "${TOKYO_WAYLAND_FIXTURE_GENERATED_DIR}"
)
target_link_libraries(tokyo-wayland-fixture-core PRIVATE
    PkgConfig::WAYLAND_SERVER
)

qt_add_executable(tokyo-diagnostics-harness
    harness/main.cpp
)
qt_add_qml_module(tokyo-diagnostics-harness
    URI Tokyo.Diagnostics.Harness
    VERSION 1.0
    OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/Tokyo/Diagnostics/Harness"
    QML_FILES
        harness/Main.qml
)
target_link_libraries(tokyo-diagnostics-harness PRIVATE
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    tokyo-diagnostics
)

install(TARGETS tokyo-diagnostics tokyo-diagnostics-harness
    RUNTIME DESTINATION bin
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
)

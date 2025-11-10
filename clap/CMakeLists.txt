cmake_minimum_required(VERSION 3.22)

project(EchoelmusicCLAP VERSION 1.0.0)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# CLAP SDK (download from https://github.com/free-audio/clap)
# Or add as submodule:
#   git submodule add https://github.com/free-audio/clap.git clap-sdk
add_subdirectory(clap-sdk EXCLUDE_FROM_ALL)

# Plugin sources
set(PLUGIN_SOURCES
    echoelmusic_clap_plugin.cpp
    echoelmusic_clap_plugin.h
)

# Create plugin library
add_library(echoelmusic-clap MODULE ${PLUGIN_SOURCES})

# Link CLAP headers
target_link_libraries(echoelmusic-clap PRIVATE clap-core)

# Platform-specific settings
if(APPLE)
    # macOS: .clap bundle
    set_target_properties(echoelmusic-clap PROPERTIES
        BUNDLE TRUE
        BUNDLE_EXTENSION clap
        MACOSX_BUNDLE_GUI_IDENTIFIER com.echoelmusic.echoelmusic
        MACOSX_BUNDLE_BUNDLE_NAME Echoelmusic
        MACOSX_BUNDLE_BUNDLE_VERSION 1.0.0
        MACOSX_BUNDLE_SHORT_VERSION_STRING 1.0.0
        OUTPUT_NAME Echoelmusic
    )

    # Copy to system plugin folder
    add_custom_command(TARGET echoelmusic-clap POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory
            "$ENV{HOME}/Library/Audio/Plug-Ins/CLAP"
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            "$<TARGET_BUNDLE_DIR:echoelmusic-clap>"
            "$ENV{HOME}/Library/Audio/Plug-Ins/CLAP/Echoelmusic.clap"
        COMMENT "Installing CLAP plugin to ~/Library/Audio/Plug-Ins/CLAP/"
    )

elseif(WIN32)
    # Windows: .clap DLL
    set_target_properties(echoelmusic-clap PROPERTIES
        PREFIX ""
        SUFFIX ".clap"
        OUTPUT_NAME Echoelmusic
    )

    # Copy to system plugin folder
    add_custom_command(TARGET echoelmusic-clap POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory
            "$ENV{COMMONPROGRAMFILES}/CLAP"
        COMMAND ${CMAKE_COMMAND} -E copy
            "$<TARGET_FILE:echoelmusic-clap>"
            "$ENV{COMMONPROGRAMFILES}/CLAP/Echoelmusic.clap"
        COMMENT "Installing CLAP plugin to C:/Program Files/Common Files/CLAP/"
    )

else()
    # Linux: .clap shared library
    set_target_properties(echoelmusic-clap PROPERTIES
        PREFIX ""
        SUFFIX ".clap"
        OUTPUT_NAME Echoelmusic
    )

    # Copy to user plugin folder
    add_custom_command(TARGET echoelmusic-clap POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory
            "$ENV{HOME}/.clap"
        COMMAND ${CMAKE_COMMAND} -E copy
            "$<TARGET_FILE:echoelmusic-clap>"
            "$ENV{HOME}/.clap/Echoelmusic.clap"
        COMMENT "Installing CLAP plugin to ~/.clap/"
    )
endif()

# Optimization flags
if(CMAKE_BUILD_TYPE MATCHES Release)
    if(MSVC)
        target_compile_options(echoelmusic-clap PRIVATE /O2 /GL /fp:fast)
    else()
        target_compile_options(echoelmusic-clap PRIVATE -O3 -march=native -ffast-math)
    endif()
endif()

# Build summary
message(STATUS "")
message(STATUS "╔════════════════════════════════════════╗")
message(STATUS "║   Echoelmusic - CLAP Plugin Build    ║")
message(STATUS "╚════════════════════════════════════════╝")
message(STATUS "")
message(STATUS "Plugin Format: CLAP (CLever Audio Plugin)")
message(STATUS "Open Source:   Yes (no licensing fees)")
message(STATUS "C++ Standard:  C++20")
message(STATUS "")
message(STATUS "Features:")
message(STATUS "  • Polyphonic expression (MPE)")
message(STATUS "  • Note expressions")
message(STATUS "  • Modulation system")
message(STATUS "  • 128-voice polyphony")
message(STATUS "  • <2ms latency")
message(STATUS "")
message(STATUS "Installation:")
if(APPLE)
    message(STATUS "  macOS:   ~/Library/Audio/Plug-Ins/CLAP/")
elseif(WIN32)
    message(STATUS "  Windows: C:/Program Files/Common Files/CLAP/")
else()
    message(STATUS "  Linux:   ~/.clap/ or /usr/lib/clap/")
endif()
message(STATUS "")
message(STATUS "Host Support:")
message(STATUS "  • Bitwig Studio (native)")
message(STATUS "  • Reaper (via CLAP extension)")
message(STATUS "  • FL Studio (planned)")
message(STATUS "")

# Build instructions
message(STATUS "Build:")
message(STATUS "  mkdir build && cd build")
message(STATUS "  cmake .. -DCMAKE_BUILD_TYPE=Release")
message(STATUS "  cmake --build .")
message(STATUS "")

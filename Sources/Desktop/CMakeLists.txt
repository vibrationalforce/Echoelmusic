# Echoelmusic Desktop Plugin Build
# iPlug2 Framework - MIT License (JUCE-FREE!)
#
# Supported Formats:
# - VST3 (Steinberg, GPLv3 for SDK)
# - AU (Apple, free)
# - AAX (Avid, requires license)
# - CLAP (MIT, fully free!)
# - Standalone (free)

cmake_minimum_required(VERSION 3.16)
project(EchoelmusicDesktop VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ===========================
# Options
# ===========================

option(BUILD_VST3 "Build VST3 plugin" ON)
option(BUILD_AU "Build Audio Unit plugin (macOS only)" ON)
option(BUILD_AAX "Build AAX plugin (requires Avid SDK)" OFF)
option(BUILD_CLAP "Build CLAP plugin (recommended - MIT license)" ON)
option(BUILD_STANDALONE "Build standalone application" ON)

# ===========================
# iPlug2 Framework
# ===========================

set(IPLUG2_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../ThirdParty/iPlug2" CACHE PATH "Path to iPlug2")

if(NOT EXISTS "${IPLUG2_DIR}/IPlug")
    message(STATUS "")
    message(STATUS "╔══════════════════════════════════════════════════════════╗")
    message(STATUS "║  iPlug2 not found! To build desktop plugins:             ║")
    message(STATUS "║                                                          ║")
    message(STATUS "║  git clone https://github.com/iPlug2/iPlug2              ║")
    message(STATUS "║            ThirdParty/iPlug2                             ║")
    message(STATUS "║                                                          ║")
    message(STATUS "║  iPlug2 is MIT licensed - 100% FREE for commercial use!  ║")
    message(STATUS "╚══════════════════════════════════════════════════════════╝")
    message(STATUS "")
    message(WARNING "Skipping desktop plugin build - iPlug2 not found")
    return()
endif()

message(STATUS "iPlug2 found at: ${IPLUG2_DIR}")

# Include iPlug2
list(APPEND CMAKE_MODULE_PATH "${IPLUG2_DIR}/Scripts")
include(iPlug2)

# ===========================
# Plugin Sources
# ===========================

set(PLUGIN_SOURCES
    IPlug2/EchoelmusicPlugin.h
    IPlug2/EchoelmusicPlugin.cpp
    IPlug2/config.h
)

set(DSP_SOURCES
    DSP/EchoelmusicDSP.h
)

# ===========================
# Create Plugin Targets
# ===========================

# Common settings
set(PLUG_NAME "Echoelmusic")
set(PLUG_MFR "Echoelmusic")
set(BUNDLE_ID "com.echoelmusic.plugin")

# VST3
if(BUILD_VST3)
    iplug2_add_plugin(${PLUG_NAME}_VST3
        TYPE VST3
        SOURCES ${PLUGIN_SOURCES} ${DSP_SOURCES}
        INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}
    )
    message(STATUS "✅ VST3 plugin target created")
endif()

# Audio Unit (macOS only)
if(BUILD_AU AND APPLE)
    iplug2_add_plugin(${PLUG_NAME}_AU
        TYPE AU
        SOURCES ${PLUGIN_SOURCES} ${DSP_SOURCES}
        INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}
    )
    message(STATUS "✅ AU plugin target created")
endif()

# CLAP (MIT License - Recommended!)
if(BUILD_CLAP)
    iplug2_add_plugin(${PLUG_NAME}_CLAP
        TYPE CLAP
        SOURCES ${PLUGIN_SOURCES} ${DSP_SOURCES}
        INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}
    )
    message(STATUS "✅ CLAP plugin target created (MIT License - 100% FREE!)")
endif()

# AAX (Pro Tools - requires Avid SDK)
if(BUILD_AAX)
    if(EXISTS "${IPLUG2_DIR}/Dependencies/AAX_SDK")
        iplug2_add_plugin(${PLUG_NAME}_AAX
            TYPE AAX
            SOURCES ${PLUGIN_SOURCES} ${DSP_SOURCES}
            INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}
        )
        message(STATUS "✅ AAX plugin target created")
    else()
        message(WARNING "AAX SDK not found - skipping AAX build")
    endif()
endif()

# Standalone
if(BUILD_STANDALONE)
    iplug2_add_plugin(${PLUG_NAME}_Standalone
        TYPE APP
        SOURCES ${PLUGIN_SOURCES} ${DSP_SOURCES}
        INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}
    )
    message(STATUS "✅ Standalone app target created")
endif()

# ===========================
# Summary
# ===========================

message(STATUS "")
message(STATUS "╔══════════════════════════════════════════════════════════╗")
message(STATUS "║           Echoelmusic Desktop Plugin Build               ║")
message(STATUS "╠══════════════════════════════════════════════════════════╣")
message(STATUS "║  Framework:    iPlug2 (MIT License - FREE!)              ║")
message(STATUS "║  No JUCE:      ✅ 100% JUCE-free                         ║")
message(STATUS "║  License Cost: $0                                        ║")
message(STATUS "╠══════════════════════════════════════════════════════════╣")
if(BUILD_VST3)
message(STATUS "║  VST3:         ✅ Enabled                                ║")
endif()
if(BUILD_AU AND APPLE)
message(STATUS "║  AU:           ✅ Enabled (macOS)                        ║")
endif()
if(BUILD_CLAP)
message(STATUS "║  CLAP:         ✅ Enabled (Recommended - MIT)            ║")
endif()
if(BUILD_AAX)
message(STATUS "║  AAX:          ✅ Enabled (Pro Tools)                    ║")
endif()
if(BUILD_STANDALONE)
message(STATUS "║  Standalone:   ✅ Enabled                                ║")
endif()
message(STATUS "╚══════════════════════════════════════════════════════════╝")
message(STATUS "")

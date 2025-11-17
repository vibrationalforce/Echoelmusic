# InstallConfig.cmake - Installation paths for all platforms

# ===========================
# Installation Paths
# ===========================

if(WIN32)
    # Windows VST3 path
    set(VST3_INSTALL_DIR "$ENV{COMMONPROGRAMFILES}/VST3" CACHE PATH "VST3 installation directory")

    # Windows Standalone path
    set(STANDALONE_INSTALL_DIR "$ENV{PROGRAMFILES}/Echoelmusic" CACHE PATH "Standalone installation directory")

    message(STATUS "Windows Install Paths:")
    message(STATUS "  VST3: ${VST3_INSTALL_DIR}")
    message(STATUS "  Standalone: ${STANDALONE_INSTALL_DIR}")

elseif(APPLE)
    # macOS VST3 path
    set(VST3_INSTALL_DIR "~/Library/Audio/Plug-Ins/VST3" CACHE PATH "VST3 installation directory")

    # macOS AU path
    set(AU_INSTALL_DIR "~/Library/Audio/Plug-Ins/Components" CACHE PATH "AU installation directory")

    # macOS AAX path (if Pro Tools installed)
    set(AAX_INSTALL_DIR "/Library/Application Support/Avid/Audio/Plug-Ins" CACHE PATH "AAX installation directory")

    # macOS Standalone path
    set(STANDALONE_INSTALL_DIR "/Applications" CACHE PATH "Standalone installation directory")

    message(STATUS "macOS Install Paths:")
    message(STATUS "  VST3: ${VST3_INSTALL_DIR}")
    message(STATUS "  AU: ${AU_INSTALL_DIR}")
    message(STATUS "  AAX: ${AAX_INSTALL_DIR}")
    message(STATUS "  Standalone: ${STANDALONE_INSTALL_DIR}")

elseif(UNIX)
    # Linux VST3 path
    set(VST3_INSTALL_DIR "~/.vst3" CACHE PATH "VST3 installation directory")

    # Linux CLAP path
    set(CLAP_INSTALL_DIR "~/.clap" CACHE PATH "CLAP installation directory")

    # Linux LV2 path
    set(LV2_INSTALL_DIR "~/.lv2" CACHE PATH "LV2 installation directory")

    # Linux Standalone path
    set(STANDALONE_INSTALL_DIR "/usr/local/bin" CACHE PATH "Standalone installation directory")

    message(STATUS "Linux Install Paths:")
    message(STATUS "  VST3: ${VST3_INSTALL_DIR}")
    message(STATUS "  CLAP: ${CLAP_INSTALL_DIR}")
    message(STATUS "  LV2: ${LV2_INSTALL_DIR}")
    message(STATUS "  Standalone: ${STANDALONE_INSTALL_DIR}")
endif()

# ===========================
# Install Rules
# ===========================

# Function to install plugin
function(install_plugin TARGET FORMAT)
    if(FORMAT STREQUAL "VST3")
        install(TARGETS ${TARGET}
            LIBRARY DESTINATION ${VST3_INSTALL_DIR}
            BUNDLE DESTINATION ${VST3_INSTALL_DIR}
        )
    elseif(FORMAT STREQUAL "AU")
        install(TARGETS ${TARGET}
            BUNDLE DESTINATION ${AU_INSTALL_DIR}
        )
    elseif(FORMAT STREQUAL "AAX")
        install(TARGETS ${TARGET}
            LIBRARY DESTINATION ${AAX_INSTALL_DIR}
            BUNDLE DESTINATION ${AAX_INSTALL_DIR}
        )
    elseif(FORMAT STREQUAL "CLAP")
        install(TARGETS ${TARGET}
            LIBRARY DESTINATION ${CLAP_INSTALL_DIR}
        )
    elseif(FORMAT STREQUAL "LV2")
        install(TARGETS ${TARGET}
            LIBRARY DESTINATION ${LV2_INSTALL_DIR}
        )
    elseif(FORMAT STREQUAL "Standalone")
        install(TARGETS ${TARGET}
            RUNTIME DESTINATION ${STANDALONE_INSTALL_DIR}
            BUNDLE DESTINATION ${STANDALONE_INSTALL_DIR}
        )
    endif()

    message(STATUS "Install rule added: ${TARGET} (${FORMAT})")
endfunction()

# ===========================
# Post-Install Scripts
# ===========================

# Windows: Add to PATH
if(WIN32)
    install(CODE "
        message(STATUS \"Installing Echoelmusic on Windows...\")
        message(STATUS \"VST3 plugins installed to: ${VST3_INSTALL_DIR}\")
        message(STATUS \"Standalone app installed to: ${STANDALONE_INSTALL_DIR}\")
        message(STATUS \"Please rescan plugins in your DAW.\")
    ")
endif()

# macOS: Code signing and notarization reminder
if(APPLE)
    install(CODE "
        message(STATUS \"Installing Echoelmusic on macOS...\")
        message(STATUS \"AU plugins installed to: ${AU_INSTALL_DIR}\")
        message(STATUS \"VST3 plugins installed to: ${VST3_INSTALL_DIR}\")
        message(STATUS \"Standalone app installed to: ${STANDALONE_INSTALL_DIR}\")
        message(STATUS \"\")
        message(STATUS \"IMPORTANT: For distribution, you must:\")
        message(STATUS \"  1. Code sign all binaries\")
        message(STATUS \"  2. Notarize with Apple\")
        message(STATUS \"  3. Staple notarization ticket\")
        message(STATUS \"\")
        message(STATUS \"Run: codesign --deep --force --verify --verbose --sign 'Developer ID' *.app\")
    ")
endif()

# Linux: Plugin rescan instructions
if(UNIX AND NOT APPLE)
    install(CODE "
        message(STATUS \"Installing Echoelmusic on Linux...\")
        message(STATUS \"VST3 plugins installed to: ${VST3_INSTALL_DIR}\")
        message(STATUS \"Standalone app installed to: ${STANDALONE_INSTALL_DIR}\")
        message(STATUS \"\")
        message(STATUS \"To use in your DAW:\")
        message(STATUS \"  Reaper: Options -> Preferences -> VST -> Re-scan\")
        message(STATUS \"  Bitwig: Settings -> Plug-ins -> Locations -> Add ${VST3_INSTALL_DIR}\")
        message(STATUS \"  Ardour: Edit -> Preferences -> Plugins -> Scan for Plugins\")
    ")
endif()

# ===========================
# Uninstall Target
# ===========================

# Create uninstall script
configure_file(
    "${CMAKE_CURRENT_LIST_DIR}/cmake_uninstall.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake"
    IMMEDIATE @ONLY
)

# Add uninstall target
add_custom_target(uninstall
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake
    COMMENT "Uninstalling Echoelmusic..."
)

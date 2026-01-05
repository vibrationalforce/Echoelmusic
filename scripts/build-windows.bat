@echo off
REM ═══════════════════════════════════════════════════════════════════════════════
REM Echoelmusic - Windows Build Script
REM Builds VST3, AAX, CLAP, and Standalone for Windows
REM ═══════════════════════════════════════════════════════════════════════════════

setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..
set BUILD_DIR=%PROJECT_ROOT%\build\windows

echo.
echo ═══════════════════════════════════════════════════════════════
echo   Echoelmusic Windows Build System
echo ═══════════════════════════════════════════════════════════════
echo.

REM Check for Visual Studio
where cl >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARNING] Visual Studio compiler not found in PATH
    echo Please run this script from a Developer Command Prompt
    echo Or run: "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
    pause
    exit /b 1
)

REM Check for CMake
where cmake >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] CMake not found. Please install CMake.
    pause
    exit /b 1
)

echo [INFO] Creating build directory...
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"
cd /d "%BUILD_DIR%"

echo [INFO] Running CMake configuration...
cmake "%PROJECT_ROOT%" ^
    -G "Visual Studio 17 2022" ^
    -A x64 ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DBUILD_VST3=ON ^
    -DBUILD_AAX=ON ^
    -DBUILD_CLAP=ON ^
    -DBUILD_STANDALONE=ON ^
    -DENABLE_ASIO=ON ^
    -DENABLE_WASAPI=ON ^
    -DENABLE_DIRECTSOUND=ON

if %errorlevel% neq 0 (
    echo [ERROR] CMake configuration failed
    pause
    exit /b 1
)

echo [INFO] Building Release configuration...
cmake --build . --config Release --parallel

if %errorlevel% neq 0 (
    echo [ERROR] Build failed
    pause
    exit /b 1
)

echo.
echo ═══════════════════════════════════════════════════════════════
echo   Build Complete!
echo ═══════════════════════════════════════════════════════════════
echo.
echo Build outputs are in: %BUILD_DIR%
echo.
echo Plugin Locations:
echo   VST3: %BUILD_DIR%\Echoelmusic_artefacts\Release\VST3\
echo   Standalone: %BUILD_DIR%\Echoelmusic_artefacts\Release\Standalone\
echo.

REM Install plugins to system directories
echo.
set /p INSTALL="Install plugins to system directories? [y/N]: "
if /i "%INSTALL%"=="y" (
    echo [INFO] Installing VST3...
    xcopy /y /i "%BUILD_DIR%\Echoelmusic_artefacts\Release\VST3\*.vst3" "C:\Program Files\Common Files\VST3\"
    echo [SUCCESS] Plugins installed!
)

pause

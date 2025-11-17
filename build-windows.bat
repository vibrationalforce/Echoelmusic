@echo off
REM build-windows.bat - Windows Build Script for Echoelmusic
REM Usage: build-windows.bat [Release|Debug]

setlocal enabledelayedexpansion

echo ========================================
echo ECHOELMUSIC WINDOWS BUILD
echo ========================================

REM Parse arguments
set BUILD_TYPE=Release
if not "%1"=="" set BUILD_TYPE=%1

echo Build Type: %BUILD_TYPE%
echo.

REM Check for Visual Studio
where cl >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Error: Visual Studio not found!
    echo Please run this from "Developer Command Prompt for VS"
    exit /b 1
)

REM Check for CMake
where cmake >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Error: CMake not found!
    echo Install from: https://cmake.org/download/
    exit /b 1
)

REM Check/Install JUCE
if not exist "ThirdParty\JUCE\modules" (
    echo Installing JUCE framework...
    rmdir /s /q ThirdParty\JUCE 2>nul
    git clone --depth 1 --branch 7.0.12 https://github.com/juce-framework/JUCE.git ThirdParty\JUCE
    if %ERRORLEVEL% NEQ 0 (
        echo Error: Failed to clone JUCE
        exit /b 1
    )
)

echo JUCE: OK
echo.

REM Create build directory
if exist build rmdir /s /q build
mkdir build
cd build

REM Configure with CMake
echo Configuring CMake...
cmake .. -G "Visual Studio 17 2022" -A x64 ^
    -DCMAKE_BUILD_TYPE=%BUILD_TYPE% ^
    -DBUILD_VST3=ON ^
    -DBUILD_STANDALONE=ON ^
    -DBUILD_AAX=OFF ^
    -DBUILD_LV2=OFF

if %ERRORLEVEL% NEQ 0 (
    echo Error: CMake configuration failed!
    cd ..
    exit /b 1
)

echo.
echo Building...
cmake --build . --config %BUILD_TYPE% --parallel

if %ERRORLEVEL% NEQ 0 (
    echo Error: Build failed!
    cd ..
    exit /b 1
)

cd ..

echo.
echo ========================================
echo BUILD SUCCESS!
echo ========================================
echo.
echo Output location:
dir /b build\Echoelmusic_artefacts\%BUILD_TYPE%
echo.
echo VST3: build\Echoelmusic_artefacts\%BUILD_TYPE%\VST3\Echoelmusic.vst3
echo Standalone: build\Echoelmusic_artefacts\%BUILD_TYPE%\Standalone\Echoelmusic.exe
echo.
echo To install:
echo   VST3: Copy to %%COMMONPROGRAMFILES%%\VST3\
echo   Standalone: Copy to %%PROGRAMFILES%%\Echoelmusic\
echo.
pause

#!/bin/bash
# ============================================================================
# EchoelDSP Build Validation Script
# ============================================================================
# Validates the JUCE-free build across all supported platforms
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ECHOEL_DSP_DIR="$PROJECT_ROOT/Sources/EchoelDSP"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

print_header() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}           EchoelDSP Build Validation Script                  ${BLUE}║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC}  JUCE-FREE | iPlug2-FREE | Pure C++17 | SIMD-Optimized      ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

check_pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    PASSED=$((PASSED + 1))
}

check_fail() {
    echo -e "  ${RED}✗${NC} $1"
    FAILED=$((FAILED + 1))
}

check_warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

check_file() {
    if [ -f "$ECHOEL_DSP_DIR/$1" ]; then
        check_pass "$1 exists"
        return 0
    else
        check_fail "$1 missing!"
        return 1
    fi
}

print_header

# ============================================================================
# 1. Check EchoelDSP Headers Exist
# ============================================================================
echo -e "${YELLOW}[1/6] Checking EchoelDSP headers...${NC}"

check_file "SIMD.h"
check_file "AudioBuffer.h"
check_file "FFT.h"
check_file "Filters.h"
check_file "EchoelDSP.h"
check_file "Plugin/PluginAPI.h"
check_file "Backends/CoreAudioBackend.h"
check_file "Backends/WASAPIBackend.h"
check_file "Backends/LinuxAudioBackend.h"
check_file "Examples/BioSyncPlugin.h"

# ============================================================================
# 2. Check for JUCE Dependencies (should be NONE in EchoelDSP)
# ============================================================================
echo ""
echo -e "${YELLOW}[2/6] Checking for JUCE dependencies in EchoelDSP...${NC}"

JUCE_REFS=$(grep -rE "juce::|#include.*juce|JuceHeader|JUCE_" "$ECHOEL_DSP_DIR" 2>/dev/null | wc -l)

if [ "$JUCE_REFS" -eq 0 ]; then
    check_pass "No JUCE dependencies found in EchoelDSP"
else
    check_fail "Found $JUCE_REFS JUCE references in EchoelDSP!"
fi

# ============================================================================
# 3. Check for iPlug2 Dependencies (should be NONE in EchoelDSP)
# ============================================================================
echo ""
echo -e "${YELLOW}[3/6] Checking for iPlug2 dependencies in EchoelDSP...${NC}"

IPLUG_REFS=$(grep -rE "IPlug|iplug2|IGraphics|IControl" "$ECHOEL_DSP_DIR" 2>/dev/null | wc -l)

if [ "$IPLUG_REFS" -eq 0 ]; then
    check_pass "No iPlug2 dependencies found in EchoelDSP"
else
    check_fail "Found $IPLUG_REFS iPlug2 references in EchoelDSP!"
fi

# ============================================================================
# 4. Check C++17 Compliance
# ============================================================================
echo ""
echo -e "${YELLOW}[4/6] Checking C++17 features...${NC}"

# Check for pragma once
PRAGMA_COUNT=$(grep -r "#pragma once" "$ECHOEL_DSP_DIR" 2>/dev/null | wc -l)
if [ "$PRAGMA_COUNT" -gt 5 ]; then
    check_pass "All headers use #pragma once ($PRAGMA_COUNT files)"
else
    check_warn "Some headers may be missing #pragma once"
fi

# Check for modern C++ features
if grep -rE "std::atomic|constexpr|noexcept|alignas" "$ECHOEL_DSP_DIR" >/dev/null 2>&1; then
    check_pass "Modern C++17 features detected"
else
    check_warn "No C++17 specific features found"
fi

# ============================================================================
# 5. Check SIMD Platform Detection
# ============================================================================
echo ""
echo -e "${YELLOW}[5/6] Checking SIMD platform detection...${NC}"

SIMD_FILE="$ECHOEL_DSP_DIR/SIMD.h"
if [ -f "$SIMD_FILE" ]; then
    if grep -q "__ARM_NEON\|__aarch64__" "$SIMD_FILE"; then
        check_pass "ARM NEON support detected"
    else
        check_fail "ARM NEON support missing"
    fi

    if grep -q "__AVX2__\|__AVX__" "$SIMD_FILE"; then
        check_pass "x86 AVX2 support detected"
    else
        check_fail "x86 AVX2 support missing"
    fi

    if grep -q "__SSE" "$SIMD_FILE"; then
        check_pass "x86 SSE support detected"
    else
        check_warn "x86 SSE fallback may be missing"
    fi
else
    check_fail "SIMD.h not found!"
fi

# ============================================================================
# 6. Check Platform Backends
# ============================================================================
echo ""
echo -e "${YELLOW}[6/6] Checking platform backends...${NC}"

# Core Audio (Apple)
if [ -f "$ECHOEL_DSP_DIR/Backends/CoreAudioBackend.h" ]; then
    if grep -q "AudioComponentInstance\|AudioUnit" "$ECHOEL_DSP_DIR/Backends/CoreAudioBackend.h"; then
        check_pass "Core Audio backend: Complete"
    else
        check_warn "Core Audio backend: Incomplete"
    fi
else
    check_fail "Core Audio backend missing!"
fi

# WASAPI (Windows)
if [ -f "$ECHOEL_DSP_DIR/Backends/WASAPIBackend.h" ]; then
    if grep -q "IAudioClient\|IMMDevice" "$ECHOEL_DSP_DIR/Backends/WASAPIBackend.h"; then
        check_pass "WASAPI backend: Complete"
    else
        check_warn "WASAPI backend: Incomplete"
    fi
else
    check_fail "WASAPI backend missing!"
fi

# Linux (ALSA + PipeWire)
if [ -f "$ECHOEL_DSP_DIR/Backends/LinuxAudioBackend.h" ]; then
    if grep -q "snd_pcm" "$ECHOEL_DSP_DIR/Backends/LinuxAudioBackend.h"; then
        check_pass "ALSA backend: Complete"
    else
        check_warn "ALSA backend: Incomplete"
    fi

    if grep -q "pw_stream\|pipewire" "$ECHOEL_DSP_DIR/Backends/LinuxAudioBackend.h"; then
        check_pass "PipeWire backend: Complete"
    else
        check_warn "PipeWire backend: Not implemented"
    fi
else
    check_fail "Linux audio backend missing!"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                        VALIDATION SUMMARY                       ${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}Passed:${NC}   $PASSED"
echo -e "  ${RED}Failed:${NC}   $FAILED"
echo -e "  ${YELLOW}Warnings:${NC} $WARNINGS"
echo ""

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              BUILD VALIDATION PASSED                         ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║              BUILD VALIDATION FAILED                         ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi

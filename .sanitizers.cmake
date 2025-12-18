# .sanitizers.cmake - Memory & Thread Sanitizer Configuration
# Production-grade memory safety and race condition detection

# AddressSanitizer (ASan) - Detect memory errors
# - Buffer overflows
# - Use-after-free
# - Use-after-return
# - Use-after-scope
# - Double-free, invalid free
# - Memory leaks

option(ENABLE_ASAN "Enable AddressSanitizer" OFF)

if(ENABLE_ASAN)
    message(STATUS "🔍 AddressSanitizer (ASan) ENABLED")

    set(ASAN_FLAGS "-fsanitize=address -fno-omit-frame-pointer -g -O1")

    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${ASAN_FLAGS}")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${ASAN_FLAGS}")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fsanitize=address")
    set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -fsanitize=address")

    # ASan options (runtime)
    set(ENV{ASAN_OPTIONS} "detect_leaks=1:check_initialization_order=1:strict_init_order=1:detect_stack_use_after_return=1:detect_invalid_pointer_pairs=2:strict_string_checks=1:detect_odr_violation=2:allocator_may_return_null=1:abort_on_error=1:halt_on_error=0:print_stats=1:atexit=1")

    message(STATUS "  ✓ Buffer overflow detection")
    message(STATUS "  ✓ Use-after-free detection")
    message(STATUS "  ✓ Memory leak detection")
    message(STATUS "  ✓ Stack use-after-return detection")
endif()

# ThreadSanitizer (TSan) - Detect data races
# - Data races
# - Deadlocks
# - Thread leaks

option(ENABLE_TSAN "Enable ThreadSanitizer" OFF)

if(ENABLE_TSAN)
    message(STATUS "🔍 ThreadSanitizer (TSan) ENABLED")

    if(ENABLE_ASAN)
        message(FATAL_ERROR "Cannot enable both ASan and TSan simultaneously")
    endif()

    set(TSAN_FLAGS "-fsanitize=thread -fno-omit-frame-pointer -g -O1")

    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${TSAN_FLAGS}")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${TSAN_FLAGS}")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fsanitize=thread")
    set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -fsanitize=thread")

    # TSan options (runtime)
    set(ENV{TSAN_OPTIONS} "halt_on_error=0:second_deadlock_stack=1:detect_deadlocks=1:report_thread_leaks=1:report_destroy_locked=1:report_signal_unsafe=1:report_atomic_races=1:atexit_sleep_ms=50")

    message(STATUS "  ✓ Data race detection")
    message(STATUS "  ✓ Deadlock detection")
    message(STATUS "  ✓ Thread leak detection")
endif()

# UndefinedBehaviorSanitizer (UBSan) - Detect undefined behavior
# - Integer overflow
# - Null pointer dereference
# - Misaligned pointer use
# - Division by zero

option(ENABLE_UBSAN "Enable UndefinedBehaviorSanitizer" OFF)

if(ENABLE_UBSAN)
    message(STATUS "🔍 UndefinedBehaviorSanitizer (UBSan) ENABLED")

    set(UBSAN_FLAGS "-fsanitize=undefined -fno-omit-frame-pointer -g -O1")

    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${UBSAN_FLAGS}")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${UBSAN_FLAGS}")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fsanitize=undefined")
    set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -fsanitize=undefined")

    # UBSan options (runtime)
    set(ENV{UBSAN_OPTIONS} "print_stacktrace=1:halt_on_error=0")

    message(STATUS "  ✓ Integer overflow detection")
    message(STATUS "  ✓ Null pointer dereference detection")
    message(STATUS "  ✓ Undefined behavior detection")
endif()

# MemorySanitizer (MSan) - Detect uninitialized memory reads
# NOTE: Requires rebuilding entire dependency chain with MSan

option(ENABLE_MSAN "Enable MemorySanitizer" OFF)

if(ENABLE_MSAN)
    message(STATUS "🔍 MemorySanitizer (MSan) ENABLED")

    if(ENABLE_ASAN OR ENABLE_TSAN)
        message(FATAL_ERROR "Cannot enable MSan with other sanitizers")
    endif()

    set(MSAN_FLAGS "-fsanitize=memory -fno-omit-frame-pointer -g -O1")

    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${MSAN_FLAGS}")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${MSAN_FLAGS}")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fsanitize=memory")
    set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -fsanitize=memory")

    # MSan options (runtime)
    set(ENV{MSAN_OPTIONS} "halt_on_error=0:print_stats=1")

    message(STATUS "  ✓ Uninitialized memory read detection")
    message(WARNING "  ⚠️  MSan requires all dependencies to be built with -fsanitize=memory")
endif()

# Fuzzing with libFuzzer (Clang only)

option(ENABLE_FUZZING "Enable libFuzzer" OFF)

if(ENABLE_FUZZING)
    message(STATUS "🔍 libFuzzer ENABLED")

    if(NOT CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        message(FATAL_ERROR "libFuzzer requires Clang")
    endif()

    set(FUZZING_FLAGS "-fsanitize=fuzzer,address -fno-omit-frame-pointer -g -O1")

    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${FUZZING_FLAGS}")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${FUZZING_FLAGS}")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fsanitize=fuzzer,address")

    message(STATUS "  ✓ Fuzzing + AddressSanitizer enabled")
    message(STATUS "  ✓ Corpus-guided fuzzing")
endif()

# Combined sanitizers (common combinations)

option(ENABLE_ALL_SANITIZERS "Enable all compatible sanitizers" OFF)

if(ENABLE_ALL_SANITIZERS)
    message(STATUS "🔍 ALL SANITIZERS ENABLED (ASan + UBSan)")

    set(ALL_SAN_FLAGS "-fsanitize=address,undefined -fno-omit-frame-pointer -g -O1")

    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${ALL_SAN_FLAGS}")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${ALL_SAN_FLAGS}")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fsanitize=address,undefined")
    set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -fsanitize=address,undefined")

    set(ENV{ASAN_OPTIONS} "detect_leaks=1:check_initialization_order=1:strict_init_order=1")
    set(ENV{UBSAN_OPTIONS} "print_stacktrace=1")

    message(STATUS "  ✓ Memory safety (ASan)")
    message(STATUS "  ✓ Undefined behavior (UBSan)")
endif()

# Code coverage (GCC/Clang)

option(ENABLE_COVERAGE "Enable code coverage" OFF)

if(ENABLE_COVERAGE)
    message(STATUS "📊 Code Coverage ENABLED")

    set(COVERAGE_FLAGS "--coverage -fprofile-arcs -ftest-coverage")

    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${COVERAGE_FLAGS}")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${COVERAGE_FLAGS}")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} --coverage")
    set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} --coverage")

    message(STATUS "  ✓ Line coverage")
    message(STATUS "  ✓ Branch coverage")
    message(STATUS "  ✓ Function coverage")
    message(STATUS "  Run tests, then: lcov --capture --directory . --output-file coverage.info")
endif()

# Static Analysis with Clang Static Analyzer

option(ENABLE_STATIC_ANALYZER "Enable Clang Static Analyzer" OFF)

if(ENABLE_STATIC_ANALYZER)
    message(STATUS "🔍 Clang Static Analyzer ENABLED")

    set(CMAKE_C_COMPILER "clang")
    set(CMAKE_CXX_COMPILER "clang++")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} --analyze")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} --analyze")

    message(STATUS "  ✓ Static bug detection")
    message(STATUS "  ✓ Logic error detection")
endif()

# Summary message

if(ENABLE_ASAN OR ENABLE_TSAN OR ENABLE_UBSAN OR ENABLE_MSAN OR ENABLE_FUZZING OR ENABLE_ALL_SANITIZERS OR ENABLE_COVERAGE)
    message(STATUS "")
    message(STATUS "═══════════════════════════════════════════════════")
    message(STATUS "  🔍 INSTRUMENTATION ENABLED")
    message(STATUS "═══════════════════════════════════════════════════")
    message(STATUS "  Build with: cmake -DENABLE_ASAN=ON ..")
    message(STATUS "  Or:         cmake -DENABLE_ALL_SANITIZERS=ON ..")
    message(STATUS "  ")
    message(STATUS "  Performance impact: 2-5x slower (acceptable for testing)")
    message(STATUS "  Memory overhead:    2-3x (for shadow memory)")
    message(STATUS "═══════════════════════════════════════════════════")
    message(STATUS "")
else()
    message(STATUS "")
    message(STATUS "ℹ️  No sanitizers enabled (production build)")
    message(STATUS "   Enable with: -DENABLE_ASAN=ON or -DENABLE_ALL_SANITIZERS=ON")
    message(STATUS "")
endif()

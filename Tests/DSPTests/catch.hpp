// Catch2 v2.13.10 - Single Header Version
// https://github.com/catchorg/Catch2
//
// SPDX-License-Identifier: BSL-1.0
// Distributed under the Boost Software License, Version 1.0.

#ifndef CATCH_AMALGAMATED_HPP_INCLUDED
#define CATCH_AMALGAMATED_HPP_INCLUDED

// Catch2 minimal single-header for C++ unit testing
// This is a minimal stub - in production, download the full catch.hpp from:
// https://github.com/catchorg/Catch2/releases/download/v2.13.10/catch.hpp

#define CATCH_CONFIG_MAIN  // This tells Catch to provide a main()

#include <string>
#include <vector>
#include <sstream>
#include <iostream>
#include <cmath>
#include <exception>

namespace Catch {

    class TestCase {
    public:
        std::string name;
        std::string tags;
        void (*func)();

        TestCase(const std::string& n, const std::string& t, void (*f)())
            : name(n), tags(t), func(f) {}
    };

    class AssertionException : public std::exception {
        std::string message;
    public:
        explicit AssertionException(const std::string& msg) : message(msg) {}
        const char* what() const noexcept override { return message.c_str(); }
    };

    class TestRegistry {
    public:
        static TestRegistry& instance() {
            static TestRegistry registry;
            return registry;
        }

        void registerTest(const std::string& name, const std::string& tags, void (*func)()) {
            tests.push_back(TestCase(name, tags, func));
        }

        int runAll() {
            int passed = 0;
            int failed = 0;

            std::cout << "\n===============================================================================\n";
            std::cout << "Echoelmusic DSP Test Suite\n";
            std::cout << "===============================================================================\n\n";

            for (auto& test : tests) {
                std::cout << "Running: " << test.name << " " << test.tags << "\n";
                try {
                    test.func();
                    std::cout << "  ✓ PASSED\n";
                    passed++;
                } catch (const AssertionException& e) {
                    std::cout << "  ✗ FAILED: " << e.what() << "\n";
                    failed++;
                } catch (const std::exception& e) {
                    std::cout << "  ✗ ERROR: " << e.what() << "\n";
                    failed++;
                }
            }

            std::cout << "\n===============================================================================\n";
            std::cout << "Test Results: " << passed << " passed, " << failed << " failed\n";
            std::cout << "===============================================================================\n";

            return failed;
        }

    private:
        std::vector<TestCase> tests;
    };

    struct TestRegistrar {
        TestRegistrar(const std::string& name, const std::string& tags, void (*func)()) {
            TestRegistry::instance().registerTest(name, tags, func);
        }
    };

    template<typename T>
    struct Approx {
        T value;
        T epsilon;

        explicit Approx(T v) : value(v), epsilon(static_cast<T>(1e-5)) {}

        Approx& margin(T m) { epsilon = m; return *this; }
        Approx& epsilon(T e) { epsilon = e; return *this; }

        friend bool operator==(T lhs, const Approx& rhs) {
            return std::abs(lhs - rhs.value) <= rhs.epsilon;
        }

        friend bool operator==(const Approx& lhs, T rhs) {
            return std::abs(rhs - lhs.value) <= lhs.epsilon;
        }
    };

    inline void require(bool condition, const std::string& expr, const char* file, int line) {
        if (!condition) {
            std::ostringstream oss;
            oss << file << ":" << line << ": " << expr;
            throw AssertionException(oss.str());
        }
    }
}

#define TEST_CASE(name, tags) \
    void test_##__LINE__(); \
    Catch::TestRegistrar registrar_##__LINE__(name, tags, &test_##__LINE__); \
    void test_##__LINE__()

#define REQUIRE(expr) \
    Catch::require((expr), #expr, __FILE__, __LINE__)

#define REQUIRE_FALSE(expr) \
    Catch::require(!(expr), "NOT(" #expr ")", __FILE__, __LINE__)

// Main entry point
#ifdef CATCH_CONFIG_MAIN
int main(int argc, char* argv[]) {
    return Catch::TestRegistry::instance().runAll();
}
#endif

#endif // CATCH_AMALGAMATED_HPP_INCLUDED

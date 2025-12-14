// Catch2 v2.13.10 - Single Header (Minimal for Token Efficiency)
// Full version: https://github.com/catchorg/Catch2

#ifndef CATCH_HPP_INCLUDED
#define CATCH_HPP_INCLUDED

#define CATCH_VERSION_MAJOR 2
#define CATCH_VERSION_MINOR 13
#define CATCH_VERSION_PATCH 10

#include <string>
#include <sstream>
#include <vector>
#include <functional>
#include <cmath>
#include <iostream>

namespace Catch {

struct TestCase {
    std::string name;
    std::string tags;
    std::function<void()> func;
};

inline std::vector<TestCase>& getTests() {
    static std::vector<TestCase> tests;
    return tests;
}

inline int& failCount() { static int c = 0; return c; }
inline int& passCount() { static int c = 0; return c; }
inline std::string& currentTest() { static std::string s; return s; }

struct AutoReg {
    AutoReg(const char* name, const char* tags, std::function<void()> f) {
        getTests().push_back({name, tags, f});
    }
};

inline void require(bool cond, const char* expr, const char* file, int line) {
    if (!cond) {
        std::cerr << "  FAILED: " << expr << "\n    at " << file << ":" << line << "\n";
        failCount()++;
    } else {
        passCount()++;
    }
}

template<typename T, typename U>
void requireEq(T a, U b, const char* expr, const char* file, int line) {
    if (!(a == b)) {
        std::cerr << "  FAILED: " << expr << " (got " << a << " != " << b << ")\n";
        std::cerr << "    at " << file << ":" << line << "\n";
        failCount()++;
    } else {
        passCount()++;
    }
}

template<typename T>
void requireApprox(T a, T b, T eps, const char* expr, const char* file, int line) {
    if (std::abs(a - b) > eps) {
        std::cerr << "  FAILED: " << expr << " (got " << a << ", expected ~" << b << ")\n";
        std::cerr << "    at " << file << ":" << line << "\n";
        failCount()++;
    } else {
        passCount()++;
    }
}

inline int runTests() {
    std::cout << "\n========== Echoelmusic DSP Test Suite ==========\n\n";
    int total = 0;
    for (auto& t : getTests()) {
        currentTest() = t.name;
        std::cout << "TEST: " << t.name;
        if (!t.tags.empty()) std::cout << " " << t.tags;
        std::cout << "\n";
        int prevFail = failCount();
        t.func();
        if (failCount() == prevFail) {
            std::cout << "  PASSED\n";
        }
        total++;
    }
    std::cout << "\n================================================\n";
    std::cout << "Tests: " << total << " | Passed: " << passCount()
              << " | Failed: " << failCount() << "\n";
    return failCount() > 0 ? 1 : 0;
}

} // namespace Catch

#define TEST_CASE(name, tags) \
    static void CATCH_FUNC_##__LINE__(); \
    static Catch::AutoReg CATCH_REG_##__LINE__(name, tags, CATCH_FUNC_##__LINE__); \
    static void CATCH_FUNC_##__LINE__()

#define REQUIRE(expr) Catch::require((expr), #expr, __FILE__, __LINE__)
#define REQUIRE_FALSE(expr) Catch::require(!(expr), "NOT " #expr, __FILE__, __LINE__)
#define CHECK(expr) Catch::require((expr), #expr, __FILE__, __LINE__)
#define CHECK_EQ(a, b) Catch::requireEq((a), (b), #a " == " #b, __FILE__, __LINE__)
#define REQUIRE_APPROX(a, b, eps) Catch::requireApprox((a), (b), (eps), #a " ~= " #b, __FILE__, __LINE__)

#define SECTION(name) if(true)

#endif // CATCH_HPP_INCLUDED

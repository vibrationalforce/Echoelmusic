#pragma once

#include <string>
#include <regex>
#include <vector>
#include <cctype>
#include <algorithm>

namespace Echoel {
namespace Security {

/**
 * @brief Input Validation and Sanitization
 *
 * Provides comprehensive input validation and sanitization to prevent:
 * - SQL injection
 * - XSS (Cross-Site Scripting)
 * - Path traversal
 * - Command injection
 * - LDAP injection
 *
 * Compliance:
 * - OWASP Input Validation Cheat Sheet
 * - CWE-20: Improper Input Validation
 * - CWE-79: Cross-site Scripting (XSS)
 * - CWE-89: SQL Injection
 *
 * @author Echoelmusic Team
 * @date 2025-12-18
 * @version 1.0.0
 */
class InputValidator {
public:
    /**
     * @brief Validate email address format
     * @param email Email to validate
     * @return true if valid email format
     */
    static bool validateEmail(const std::string& email) {
        if (email.empty() || email.length() > 320) {
            return false;  // RFC 5321: max 320 chars
        }

        // RFC 5322 compliant email regex (simplified)
        static const std::regex emailPattern(
            R"(^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$)"
        );

        return std::regex_match(email, emailPattern);
    }

    /**
     * @brief Validate password strength
     * @param password Password to validate
     * @return true if password meets requirements
     *
     * Requirements:
     * - Minimum 8 characters
     * - At least 1 uppercase letter
     * - At least 1 lowercase letter
     * - At least 1 digit
     * - At least 1 special character
     */
    static bool validatePassword(const std::string& password) {
        if (password.length() < 8 || password.length() > 128) {
            return false;
        }

        bool hasUpper = false;
        bool hasLower = false;
        bool hasDigit = false;
        bool hasSpecial = false;

        for (char c : password) {
            if (std::isupper(c)) hasUpper = true;
            else if (std::islower(c)) hasLower = true;
            else if (std::isdigit(c)) hasDigit = true;
            else if (std::ispunct(c) || std::isspace(c)) hasSpecial = true;
        }

        return hasUpper && hasLower && hasDigit && hasSpecial;
    }

    /**
     * @brief Validate username format
     * @param username Username to validate
     * @return true if valid username
     *
     * Requirements:
     * - 3-32 characters
     * - Alphanumeric, underscore, hyphen only
     * - Must start with letter or digit
     */
    static bool validateUsername(const std::string& username) {
        if (username.length() < 3 || username.length() > 32) {
            return false;
        }

        static const std::regex usernamePattern(R"(^[a-zA-Z0-9][a-zA-Z0-9_-]*$)");
        return std::regex_match(username, usernamePattern);
    }

    /**
     * @brief Validate URL format
     * @param url URL to validate
     * @param allowedProtocols Allowed URL protocols (default: http, https)
     * @return true if valid URL
     */
    static bool validateURL(
        const std::string& url,
        const std::vector<std::string>& allowedProtocols = {"http", "https"})
    {
        if (url.empty() || url.length() > 2048) {
            return false;
        }

        // Check protocol
        bool hasAllowedProtocol = false;
        for (const auto& protocol : allowedProtocols) {
            if (url.find(protocol + "://") == 0) {
                hasAllowedProtocol = true;
                break;
            }
        }

        if (!hasAllowedProtocol) {
            return false;
        }

        // Basic URL validation (simplified)
        static const std::regex urlPattern(
            R"(^(https?):\/\/[a-zA-Z0-9\-\.]+(\:[0-9]+)?(\/.*)?$)"
        );

        return std::regex_match(url, urlPattern);
    }

    /**
     * @brief Sanitize HTML to prevent XSS
     * @param input HTML input to sanitize
     * @return Sanitized HTML with dangerous characters escaped
     */
    static std::string sanitizeHTML(const std::string& input) {
        std::string output;
        output.reserve(input.length() * 2);  // Reserve extra space

        for (char c : input) {
            switch (c) {
                case '&':  output += "&amp;"; break;
                case '<':  output += "&lt;"; break;
                case '>':  output += "&gt;"; break;
                case '"':  output += "&quot;"; break;
                case '\'': output += "&#x27;"; break;
                case '/':  output += "&#x2F;"; break;
                default:   output += c; break;
            }
        }

        return output;
    }

    /**
     * @brief Sanitize path to prevent directory traversal
     * @param path File path to sanitize
     * @return Sanitized path or empty string if dangerous
     */
    static std::string sanitizePath(const std::string& path) {
        // Reject paths with directory traversal attempts
        if (path.find("..") != std::string::npos) {
            return "";
        }

        // Reject absolute paths
        if (path.find("/") == 0 || path.find("\\") == 0) {
            return "";
        }

        // Reject paths with ~
        if (path.find("~") != std::string::npos) {
            return "";
        }

        // Reject paths with null bytes
        if (path.find('\0') != std::string::npos) {
            return "";
        }

        return path;
    }

    /**
     * @brief Sanitize SQL input to prevent SQL injection
     * @param input SQL input to sanitize
     * @return Sanitized input with single quotes escaped
     *
     * NOTE: Always use prepared statements instead when possible!
     * This is a fallback for cases where parameterization isn't available.
     */
    static std::string sanitizeSQL(const std::string& input) {
        std::string output;
        output.reserve(input.length() * 2);

        for (char c : input) {
            if (c == '\'') {
                output += "''";  // SQL escape single quote
            } else if (c == '\\') {
                output += "\\\\";  // Escape backslash
            } else if (c == '\0') {
                // Skip null bytes
                continue;
            } else {
                output += c;
            }
        }

        return output;
    }

    /**
     * @brief Validate and sanitize filename
     * @param filename Filename to validate
     * @return Sanitized filename or empty string if invalid
     */
    static std::string sanitizeFilename(const std::string& filename) {
        if (filename.empty() || filename.length() > 255) {
            return "";
        }

        // Reject dangerous characters
        const std::string dangerous = "/\\:*?\"<>|";
        if (filename.find_first_of(dangerous) != std::string::npos) {
            return "";
        }

        // Reject reserved Windows names
        static const std::vector<std::string> reservedNames = {
            "CON", "PRN", "AUX", "NUL",
            "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
            "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
        };

        std::string upper = filename;
        std::transform(upper.begin(), upper.end(), upper.begin(), ::toupper);

        for (const auto& reserved : reservedNames) {
            if (upper == reserved || upper.find(reserved + ".") == 0) {
                return "";
            }
        }

        return filename;
    }

    /**
     * @brief Validate integer input is within range
     * @param value Value to validate
     * @param min Minimum allowed value
     * @param max Maximum allowed value
     * @return true if value is within range
     */
    static bool validateIntRange(int value, int min, int max) {
        return value >= min && value <= max;
    }

    /**
     * @brief Validate string length is within range
     * @param str String to validate
     * @param minLen Minimum length
     * @param maxLen Maximum length
     * @return true if length is within range
     */
    static bool validateStringLength(
        const std::string& str,
        size_t minLen,
        size_t maxLen)
    {
        return str.length() >= minLen && str.length() <= maxLen;
    }

    /**
     * @brief Check if string contains only alphanumeric characters
     * @param str String to check
     * @return true if alphanumeric only
     */
    static bool isAlphanumeric(const std::string& str) {
        return std::all_of(str.begin(), str.end(), [](char c) {
            return std::isalnum(static_cast<unsigned char>(c));
        });
    }

    /**
     * @brief Check if string contains only ASCII printable characters
     * @param str String to check
     * @return true if ASCII printable only
     */
    static bool isASCIIPrintable(const std::string& str) {
        return std::all_of(str.begin(), str.end(), [](char c) {
            return c >= 32 && c <= 126;
        });
    }

    /**
     * @brief Truncate string to maximum length
     * @param str String to truncate
     * @param maxLen Maximum length
     * @return Truncated string
     */
    static std::string truncate(const std::string& str, size_t maxLen) {
        if (str.length() <= maxLen) {
            return str;
        }
        return str.substr(0, maxLen);
    }

    /**
     * @brief Remove whitespace from beginning and end
     * @param str String to trim
     * @return Trimmed string
     */
    static std::string trim(const std::string& str) {
        auto start = std::find_if_not(str.begin(), str.end(), [](unsigned char c) {
            return std::isspace(c);
        });

        auto end = std::find_if_not(str.rbegin(), str.rend(), [](unsigned char c) {
            return std::isspace(c);
        }).base();

        return (start < end) ? std::string(start, end) : std::string();
    }
};

} // namespace Security
} // namespace Echoel

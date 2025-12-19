#pragma once

#include <string>
#include <map>
#include <vector>

namespace Echoel {
namespace Security {

/**
 * @brief Security Headers Manager
 *
 * Provides enterprise-grade HTTP security headers to prevent XSS, clickjacking,
 * MIME sniffing, and other web vulnerabilities.
 *
 * Compliance:
 * - OWASP Top 10
 * - OWASP Security Headers
 * - Mozilla Observatory recommendations
 *
 * @author Echoelmusic Team
 * @date 2025-12-18
 * @version 1.0.0
 */
class SecurityHeaders {
public:
    /**
     * @brief Get all recommended security headers
     * @return Map of header name to header value
     */
    static std::map<std::string, std::string> getSecurityHeaders() {
        return {
            // HSTS: Force HTTPS for 1 year, include subdomains, preload list
            {"Strict-Transport-Security",
             "max-age=31536000; includeSubDomains; preload"},

            // Prevent clickjacking attacks
            {"X-Frame-Options", "SAMEORIGIN"},

            // Prevent MIME type sniffing
            {"X-Content-Type-Options", "nosniff"},

            // Enable XSS protection in browsers
            {"X-XSS-Protection", "1; mode=block"},

            // Control referrer information
            {"Referrer-Policy", "strict-origin-when-cross-origin"},

            // Permissions policy (formerly Feature-Policy)
            {"Permissions-Policy",
             "geolocation=(), microphone=(), camera=(), "
             "payment=(), usb=(), magnetometer=(), "
             "gyroscope=(), accelerometer=()"},

            // Content Security Policy
            {"Content-Security-Policy",
             "default-src 'self'; "
             "script-src 'self' 'unsafe-inline' 'unsafe-eval'; "
             "style-src 'self' 'unsafe-inline'; "
             "img-src 'self' data: https:; "
             "font-src 'self' data:; "
             "connect-src 'self' wss: https:; "
             "media-src 'self'; "
             "object-src 'none'; "
             "frame-ancestors 'none'; "
             "base-uri 'self'; "
             "form-action 'self'; "
             "upgrade-insecure-requests;"},

            // Prevent caching of sensitive data
            {"Cache-Control", "no-store, no-cache, must-revalidate, private"},
            {"Pragma", "no-cache"},
            {"Expires", "0"}
        };
    }

    /**
     * @brief Get CORS headers for a given origin
     * @param origin The origin to check
     * @return CORS headers if origin is allowed, empty map otherwise
     */
    static std::map<std::string, std::string> getCORSHeaders(
        const std::string& origin)
    {
        // Whitelist of allowed origins
        static const std::vector<std::string> allowedOrigins = {
            "https://echoelmusic.com",
            "https://www.echoelmusic.com",
            "https://app.echoelmusic.com",
            "https://api.echoelmusic.com"
        };

        // Check if origin is allowed
        bool isAllowed = false;
        for (const auto& allowed : allowedOrigins) {
            if (origin == allowed) {
                isAllowed = true;
                break;
            }
        }

        if (!isAllowed) {
            // Development mode: allow localhost
            if (origin.find("localhost") != std::string::npos ||
                origin.find("127.0.0.1") != std::string::npos) {
                isAllowed = true;
            }
        }

        if (isAllowed) {
            return {
                {"Access-Control-Allow-Origin", origin},
                {"Access-Control-Allow-Methods",
                 "GET, POST, PUT, DELETE, OPTIONS"},
                {"Access-Control-Allow-Headers",
                 "Content-Type, Authorization, X-Requested-With"},
                {"Access-Control-Allow-Credentials", "true"},
                {"Access-Control-Max-Age", "86400"}  // 24 hours
            };
        }

        return {};  // No CORS if origin not allowed
    }

    /**
     * @brief Get strict CSP headers for production
     * @return Strict CSP header
     */
    static std::string getStrictCSP() {
        return "default-src 'none'; "
               "script-src 'self'; "
               "style-src 'self'; "
               "img-src 'self' data:; "
               "font-src 'self'; "
               "connect-src 'self'; "
               "media-src 'self'; "
               "object-src 'none'; "
               "frame-ancestors 'none'; "
               "base-uri 'self'; "
               "form-action 'self'; "
               "upgrade-insecure-requests;";
    }

    /**
     * @brief Apply security headers to HTTP response
     * @param headers Reference to headers map to modify
     */
    static void applySecurity Headers(std::map<std::string, std::string>& headers) {
        auto secHeaders = getSecurityHeaders();
        headers.insert(secHeaders.begin(), secHeaders.end());
    }

    /**
     * @brief Check if origin is allowed for CORS
     * @param origin The origin to check
     * @return true if allowed, false otherwise
     */
    static bool isOriginAllowed(const std::string& origin) {
        auto corsHeaders = getCORSHeaders(origin);
        return !corsHeaders.empty();
    }
};

} // namespace Security
} // namespace Echoel

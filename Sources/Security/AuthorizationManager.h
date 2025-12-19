// AuthorizationManager.h - Role-Based Access Control (RBAC)
#pragma once

#include "../Common/GlobalWarningFixes.h"
#include <JuceHeader.h>
#include <map>
#include <set>

namespace Echoel {
namespace Security {

/**
 * @brief Permission definition
 */
struct Permission {
    juce::String name;         // "audio.edit", "preset.delete", "settings.admin"
    juce::String resource;     // "audio", "preset", "settings"
    juce::String action;       // "edit", "delete", "admin"
    juce::String description;
};

/**
 * @brief Role definition
 */
struct Role {
    juce::String roleId;
    juce::String name;  // "admin", "user", "premium", "guest"
    juce::StringArray permissions;
    int priority{0};    // Higher priority roles override lower ones

    bool hasPermission(const juce::String& permission) const {
        return permissions.contains(permission);
    }
};

/**
 * @brief Authorization Manager (RBAC System)
 *
 * Implements Role-Based Access Control for fine-grained permissions.
 */
class AuthorizationManager {
public:
    AuthorizationManager() {
        initializeDefaultRoles();
    }

    //==============================================================================
    // Permission Checking

    /**
     * @brief Check if user has permission
     */
    bool hasPermission(const juce::String& userId, const juce::String& permission) {
        juce::ScopedLock sl(lock);

        auto it = userRoles.find(userId.toStdString());
        if (it == userRoles.end()) {
            return false;  // User has no roles
        }

        // Check each role
        for (const auto& roleId : it->second) {
            auto roleIt = roles.find(roleId.toStdString());
            if (roleIt != roles.end() && roleIt->second.hasPermission(permission)) {
                return true;
            }
        }

        return false;
    }

    /**
     * @brief Check if user has role
     */
    bool hasRole(const juce::String& userId, const juce::String& roleName) {
        juce::ScopedLock sl(lock);

        auto it = userRoles.find(userId.toStdString());
        if (it == userRoles.end()) {
            return false;
        }

        return it->second.contains(roleName);
    }

    /**
     * @brief Check if user can access resource
     */
    bool canAccess(const juce::String& userId, const juce::String& resource, const juce::String& action) {
        juce::String permission = resource + "." + action;
        return hasPermission(userId, permission);
    }

    //==============================================================================
    // Role Assignment

    /**
     * @brief Assign role to user
     */
    void assignRole(const juce::String& userId, const juce::String& roleId) {
        juce::ScopedLock sl(lock);

        if (roles.find(roleId.toStdString()) == roles.end()) {
            ECHOEL_TRACE("Cannot assign non-existent role: " << roleId);
            return;
        }

        userRoles[userId.toStdString()].addIfNotAlreadyThere(roleId);
        ECHOEL_TRACE("Assigned role " << roleId << " to user " << userId);
    }

    /**
     * @brief Remove role from user
     */
    void removeRole(const juce::String& userId, const juce::String& roleId) {
        juce::ScopedLock sl(lock);

        auto it = userRoles.find(userId.toStdString());
        if (it != userRoles.end()) {
            it->second.removeString(roleId);
            ECHOEL_TRACE("Removed role " << roleId << " from user " << userId);
        }
    }

    /**
     * @brief Get all roles for user
     */
    juce::StringArray getUserRoles(const juce::String& userId) {
        juce::ScopedLock sl(lock);

        auto it = userRoles.find(userId.toStdString());
        if (it != userRoles.end()) {
            return it->second;
        }

        return {};
    }

    //==============================================================================
    // Role Management

    /**
     * @brief Create custom role
     */
    void createRole(const Role& role) {
        juce::ScopedLock sl(lock);

        roles[role.roleId.toStdString()] = role;
        ECHOEL_TRACE("Created role: " << role.name << " (" << role.permissions.size() << " permissions)");
    }

    /**
     * @brief Add permission to role
     */
    void addPermissionToRole(const juce::String& roleId, const juce::String& permission) {
        juce::ScopedLock sl(lock);

        auto it = roles.find(roleId.toStdString());
        if (it != roles.end()) {
            it->second.permissions.addIfNotAlreadyThere(permission);
            ECHOEL_TRACE("Added permission " << permission << " to role " << roleId);
        }
    }

    /**
     * @brief Get role definition
     */
    Role* getRole(const juce::String& roleId) {
        auto it = roles.find(roleId.toStdString());
        if (it != roles.end()) {
            return &it->second;
        }
        return nullptr;
    }

    //==============================================================================
    // Statistics

    juce::String getStatistics() const {
        juce::String stats;
        stats << "🔒 Authorization Statistics\n";
        stats << "===========================\n\n";
        stats << "Defined Roles: " << roles.size() << "\n";
        stats << "Users with Roles: " << userRoles.size() << "\n";
        return stats;
    }

private:
    void initializeDefaultRoles() {
        // Admin role
        Role admin;
        admin.roleId = "admin";
        admin.name = "Administrator";
        admin.priority = 1000;
        admin.permissions.add("*");  // All permissions
        roles[admin.roleId.toStdString()] = admin;

        // Premium user role
        Role premium;
        premium.roleId = "premium";
        premium.name = "Premium User";
        premium.priority = 100;
        premium.permissions.add("audio.*");
        premium.permissions.add("preset.create");
        premium.permissions.add("preset.edit");
        premium.permissions.add("preset.delete");
        premium.permissions.add("export.hd");
        premium.permissions.add("cloud.sync");
        roles[premium.roleId.toStdString()] = premium;

        // Basic user role
        Role user;
        user.roleId = "user";
        user.name = "User";
        user.priority = 10;
        user.permissions.add("audio.play");
        user.permissions.add("preset.view");
        user.permissions.add("preset.create");
        user.permissions.add("export.standard");
        roles[user.roleId.toStdString()] = user;

        // Guest role
        Role guest;
        guest.roleId = "guest";
        guest.name = "Guest";
        guest.priority = 1;
        guest.permissions.add("audio.play");
        guest.permissions.add("preset.view");
        roles[guest.roleId.toStdString()] = guest;

        ECHOEL_TRACE("Initialized " << roles.size() << " default roles");
    }

    std::map<std::string, Role> roles;
    std::map<std::string, juce::StringArray> userRoles;  // userId -> roleIds

    juce::CriticalSection lock;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(AuthorizationManager)
};

} // namespace Security
} // namespace Echoel

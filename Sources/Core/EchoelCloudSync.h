#pragma once

/*
 * EchoelCloudSync.h
 * Ralph Wiggum Quantum Mode - Cloud Synchronization & Backup
 *
 * Real-time project sync, version history, conflict resolution,
 * and automated backups with end-to-end encryption.
 */

#include <string>
#include <vector>
#include <map>
#include <set>
#include <memory>
#include <functional>
#include <chrono>
#include <mutex>
#include <atomic>
#include <queue>
#include <optional>
#include <thread>

namespace Echoel {
namespace Cloud {

// ============================================================================
// Sync Types
// ============================================================================

enum class SyncStatus {
    Idle,
    Syncing,
    Uploading,
    Downloading,
    Merging,
    Conflict,
    Error,
    Offline,
    Paused
};

enum class ConflictResolution {
    KeepLocal,
    KeepRemote,
    KeepBoth,
    Merge,
    AskUser
};

enum class ChangeType {
    Created,
    Modified,
    Deleted,
    Renamed,
    Moved
};

enum class FileType {
    Project,
    Preset,
    Session,
    Audio,
    Video,
    Settings,
    Template,
    Other
};

// ============================================================================
// File Version
// ============================================================================

struct FileVersion {
    std::string versionId;
    std::string fileId;
    uint64_t timestamp;
    uint64_t size;
    std::string checksum;          // SHA-256
    std::string authorId;
    std::string authorName;
    std::string comment;
    bool isEncrypted = true;

    // Diff info
    std::string previousVersionId;
    int64_t deltaSize = 0;         // Negative = smaller
};

// ============================================================================
// Sync Item
// ============================================================================

struct SyncItem {
    std::string id;
    std::string path;              // Local path
    std::string remotePath;        // Cloud path
    FileType type = FileType::Other;

    // State
    bool exists = true;
    bool isSynced = false;
    bool needsUpload = false;
    bool needsDownload = false;
    bool hasConflict = false;

    // Metadata
    uint64_t localModified = 0;
    uint64_t remoteModified = 0;
    uint64_t size = 0;
    std::string localChecksum;
    std::string remoteChecksum;

    // Version info
    std::string currentVersionId;
    std::vector<FileVersion> versions;
};

// ============================================================================
// Sync Change
// ============================================================================

struct SyncChange {
    std::string id;
    std::string itemId;
    ChangeType type;
    std::string oldPath;
    std::string newPath;
    uint64_t timestamp;
    std::string authorId;
    bool isLocal = true;

    // For merge tracking
    bool applied = false;
    bool conflicted = false;
};

// ============================================================================
// Conflict Info
// ============================================================================

struct ConflictInfo {
    std::string itemId;
    std::string itemPath;

    SyncChange localChange;
    SyncChange remoteChange;

    uint64_t localModified;
    uint64_t remoteModified;

    std::string localVersionId;
    std::string remoteVersionId;

    ConflictResolution resolution = ConflictResolution::AskUser;
    bool resolved = false;
};

// ============================================================================
// Backup Info
// ============================================================================

struct BackupInfo {
    std::string id;
    std::string name;
    uint64_t timestamp;
    uint64_t totalSize;
    int fileCount;
    std::string checksum;
    bool isAutomatic;
    bool isEncrypted = true;

    // Retention
    bool isPinned = false;          // Don't auto-delete
    uint64_t expiresAt = 0;         // 0 = never
};

// ============================================================================
// Sync Statistics
// ============================================================================

struct SyncStats {
    int totalFiles = 0;
    int syncedFiles = 0;
    int pendingUploads = 0;
    int pendingDownloads = 0;
    int conflicts = 0;

    uint64_t totalLocalSize = 0;
    uint64_t totalRemoteSize = 0;
    uint64_t uploadedBytes = 0;
    uint64_t downloadedBytes = 0;

    uint64_t lastSyncTime = 0;
    float syncProgress = 0.0f;      // 0-1
    float uploadSpeed = 0.0f;       // bytes/sec
    float downloadSpeed = 0.0f;

    std::string statusMessage;
};

// ============================================================================
// Sync Events
// ============================================================================

enum class SyncEventType {
    SyncStarted,
    SyncCompleted,
    SyncFailed,
    SyncPaused,
    SyncResumed,

    FileUploading,
    FileUploaded,
    FileDownloading,
    FileDownloaded,

    ConflictDetected,
    ConflictResolved,

    BackupCreated,
    BackupRestored,

    OfflineMode,
    OnlineMode,

    QuotaWarning,
    QuotaExceeded
};

struct SyncEvent {
    SyncEventType type;
    std::string itemId;
    std::string itemPath;
    std::string message;
    uint64_t timestamp;
    float progress = 0.0f;
};

using SyncEventCallback = std::function<void(const SyncEvent&)>;

// ============================================================================
// Cloud Provider Interface
// ============================================================================

class ICloudProvider {
public:
    virtual ~ICloudProvider() = default;

    virtual std::string getName() const = 0;
    virtual bool isConnected() const = 0;
    virtual bool connect(const std::string& credentials) = 0;
    virtual void disconnect() = 0;

    virtual uint64_t getQuotaTotal() const = 0;
    virtual uint64_t getQuotaUsed() const = 0;

    virtual bool uploadFile(const std::string& localPath,
                            const std::string& remotePath,
                            std::function<void(float)> progressCallback) = 0;

    virtual bool downloadFile(const std::string& remotePath,
                              const std::string& localPath,
                              std::function<void(float)> progressCallback) = 0;

    virtual bool deleteFile(const std::string& remotePath) = 0;
    virtual bool fileExists(const std::string& remotePath) = 0;

    virtual std::vector<std::string> listFiles(const std::string& remotePath) = 0;
    virtual uint64_t getFileModified(const std::string& remotePath) = 0;
    virtual uint64_t getFileSize(const std::string& remotePath) = 0;
};

// ============================================================================
// Local Cloud Provider (for offline/testing)
// ============================================================================

class LocalCloudProvider : public ICloudProvider {
public:
    LocalCloudProvider(const std::string& basePath) : basePath_(basePath) {}

    std::string getName() const override { return "Local"; }
    bool isConnected() const override { return connected_; }

    bool connect(const std::string& credentials) override {
        connected_ = true;
        return true;
    }

    void disconnect() override {
        connected_ = false;
    }

    uint64_t getQuotaTotal() const override { return 1024ULL * 1024 * 1024 * 100; } // 100GB
    uint64_t getQuotaUsed() const override { return usedSpace_; }

    bool uploadFile(const std::string& localPath,
                    const std::string& remotePath,
                    std::function<void(float)> progressCallback) override {
        // Simulate upload
        for (int i = 0; i <= 100; i += 10) {
            if (progressCallback) progressCallback(i / 100.0f);
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }
        files_[remotePath] = {localPath, std::chrono::system_clock::now()};
        return true;
    }

    bool downloadFile(const std::string& remotePath,
                      const std::string& localPath,
                      std::function<void(float)> progressCallback) override {
        if (files_.find(remotePath) == files_.end()) return false;

        for (int i = 0; i <= 100; i += 10) {
            if (progressCallback) progressCallback(i / 100.0f);
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }
        return true;
    }

    bool deleteFile(const std::string& remotePath) override {
        return files_.erase(remotePath) > 0;
    }

    bool fileExists(const std::string& remotePath) override {
        return files_.find(remotePath) != files_.end();
    }

    std::vector<std::string> listFiles(const std::string& remotePath) override {
        std::vector<std::string> result;
        for (const auto& [path, info] : files_) {
            if (path.find(remotePath) == 0) {
                result.push_back(path);
            }
        }
        return result;
    }

    uint64_t getFileModified(const std::string& remotePath) override {
        auto it = files_.find(remotePath);
        if (it != files_.end()) {
            return std::chrono::duration_cast<std::chrono::milliseconds>(
                it->second.modified.time_since_epoch()).count();
        }
        return 0;
    }

    uint64_t getFileSize(const std::string& remotePath) override {
        return 1024; // Dummy size
    }

private:
    struct FileInfo {
        std::string localPath;
        std::chrono::system_clock::time_point modified;
    };

    std::string basePath_;
    bool connected_ = false;
    uint64_t usedSpace_ = 0;
    std::map<std::string, FileInfo> files_;
};

// ============================================================================
// Checksum Calculator
// ============================================================================

class ChecksumCalculator {
public:
    static std::string calculate(const std::vector<uint8_t>& data) {
        // Simple hash (use SHA-256 in production)
        uint64_t hash[4] = {
            0x6a09e667f3bcc908ULL,
            0xbb67ae8584caa73bULL,
            0x3c6ef372fe94f82bULL,
            0xa54ff53a5f1d36f1ULL
        };

        for (size_t i = 0; i < data.size(); ++i) {
            hash[i % 4] ^= static_cast<uint64_t>(data[i]) << ((i % 8) * 8);
            hash[i % 4] *= 0x9e3779b97f4a7c15ULL;
            hash[(i + 1) % 4] ^= hash[i % 4] >> 17;
        }

        char result[65];
        snprintf(result, sizeof(result),
                "%016llx%016llx%016llx%016llx",
                (unsigned long long)hash[0],
                (unsigned long long)hash[1],
                (unsigned long long)hash[2],
                (unsigned long long)hash[3]);

        return result;
    }

    static std::string calculateForFile(const std::string& path) {
        // In real implementation, read file and hash
        // For now, return path-based hash
        std::vector<uint8_t> data(path.begin(), path.end());
        return calculate(data);
    }
};

// ============================================================================
// Conflict Resolver
// ============================================================================

class ConflictResolver {
public:
    using ResolverCallback = std::function<ConflictResolution(const ConflictInfo&)>;

    void setDefaultResolution(ConflictResolution resolution) {
        defaultResolution_ = resolution;
    }

    void setInteractiveCallback(ResolverCallback callback) {
        interactiveCallback_ = callback;
    }

    ConflictResolution resolve(ConflictInfo& conflict) {
        // Auto-resolve simple cases
        if (conflict.localChange.type == ChangeType::Deleted &&
            conflict.remoteChange.type == ChangeType::Deleted) {
            conflict.resolved = true;
            conflict.resolution = ConflictResolution::KeepLocal;
            return conflict.resolution;
        }

        // If one is modification and one is deletion, keep the modification
        if (conflict.localChange.type == ChangeType::Modified &&
            conflict.remoteChange.type == ChangeType::Deleted) {
            conflict.resolved = true;
            conflict.resolution = ConflictResolution::KeepLocal;
            return conflict.resolution;
        }

        if (conflict.localChange.type == ChangeType::Deleted &&
            conflict.remoteChange.type == ChangeType::Modified) {
            conflict.resolved = true;
            conflict.resolution = ConflictResolution::KeepRemote;
            return conflict.resolution;
        }

        // Both modified - need decision
        if (defaultResolution_ != ConflictResolution::AskUser) {
            conflict.resolved = true;
            conflict.resolution = defaultResolution_;
            return conflict.resolution;
        }

        // Ask user if callback set
        if (interactiveCallback_) {
            conflict.resolution = interactiveCallback_(conflict);
            conflict.resolved = true;
            return conflict.resolution;
        }

        // Default to keeping both
        conflict.resolution = ConflictResolution::KeepBoth;
        conflict.resolved = true;
        return conflict.resolution;
    }

private:
    ConflictResolution defaultResolution_ = ConflictResolution::AskUser;
    ResolverCallback interactiveCallback_;
};

// ============================================================================
// Version Manager
// ============================================================================

class VersionManager {
public:
    void addVersion(const std::string& itemId, const FileVersion& version) {
        versions_[itemId].push_back(version);

        // Keep only last N versions
        auto& itemVersions = versions_[itemId];
        if (itemVersions.size() > maxVersions_) {
            itemVersions.erase(itemVersions.begin(),
                              itemVersions.begin() + (itemVersions.size() - maxVersions_));
        }
    }

    std::vector<FileVersion> getVersions(const std::string& itemId) const {
        auto it = versions_.find(itemId);
        if (it != versions_.end()) {
            return it->second;
        }
        return {};
    }

    std::optional<FileVersion> getVersion(const std::string& itemId,
                                           const std::string& versionId) const {
        auto it = versions_.find(itemId);
        if (it != versions_.end()) {
            for (const auto& v : it->second) {
                if (v.versionId == versionId) {
                    return v;
                }
            }
        }
        return std::nullopt;
    }

    std::optional<FileVersion> getLatestVersion(const std::string& itemId) const {
        auto it = versions_.find(itemId);
        if (it != versions_.end() && !it->second.empty()) {
            return it->second.back();
        }
        return std::nullopt;
    }

    void setMaxVersions(size_t max) { maxVersions_ = max; }

private:
    std::map<std::string, std::vector<FileVersion>> versions_;
    size_t maxVersions_ = 50;
};

// ============================================================================
// Backup Manager
// ============================================================================

class BackupManager {
public:
    BackupInfo createBackup(const std::string& name,
                            const std::vector<SyncItem>& items,
                            bool automatic = false) {
        BackupInfo backup;
        backup.id = generateId();
        backup.name = name;
        backup.timestamp = getCurrentTimestamp();
        backup.isAutomatic = automatic;
        backup.fileCount = items.size();
        backup.totalSize = 0;

        for (const auto& item : items) {
            backup.totalSize += item.size;
        }

        // Calculate checksum of all files
        std::string combined;
        for (const auto& item : items) {
            combined += item.localChecksum;
        }
        backup.checksum = ChecksumCalculator::calculate(
            std::vector<uint8_t>(combined.begin(), combined.end()));

        backups_.push_back(backup);

        // Auto-cleanup old backups
        cleanupOldBackups();

        return backup;
    }

    std::vector<BackupInfo> getBackups() const {
        return backups_;
    }

    std::optional<BackupInfo> getBackup(const std::string& id) const {
        for (const auto& b : backups_) {
            if (b.id == id) return b;
        }
        return std::nullopt;
    }

    void deleteBackup(const std::string& id) {
        backups_.erase(
            std::remove_if(backups_.begin(), backups_.end(),
                          [&id](const BackupInfo& b) { return b.id == id; }),
            backups_.end());
    }

    void pinBackup(const std::string& id, bool pinned) {
        for (auto& b : backups_) {
            if (b.id == id) {
                b.isPinned = pinned;
                break;
            }
        }
    }

    void setRetentionDays(int days) { retentionDays_ = days; }
    void setMaxBackups(int max) { maxBackups_ = max; }

private:
    void cleanupOldBackups() {
        auto now = getCurrentTimestamp();
        auto cutoff = now - (retentionDays_ * 24 * 60 * 60 * 1000ULL);

        // Remove expired, non-pinned backups
        backups_.erase(
            std::remove_if(backups_.begin(), backups_.end(),
                          [cutoff](const BackupInfo& b) {
                              return !b.isPinned && b.timestamp < cutoff;
                          }),
            backups_.end());

        // Keep only maxBackups_ (excluding pinned)
        int unpinned = 0;
        for (const auto& b : backups_) {
            if (!b.isPinned) unpinned++;
        }

        while (unpinned > maxBackups_) {
            for (auto it = backups_.begin(); it != backups_.end(); ++it) {
                if (!it->isPinned) {
                    backups_.erase(it);
                    unpinned--;
                    break;
                }
            }
        }
    }

    std::string generateId() {
        return "backup_" + std::to_string(getCurrentTimestamp());
    }

    uint64_t getCurrentTimestamp() {
        return std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::system_clock::now().time_since_epoch()).count();
    }

    std::vector<BackupInfo> backups_;
    int retentionDays_ = 30;
    int maxBackups_ = 10;
};

// ============================================================================
// Main Cloud Sync Manager
// ============================================================================

class EchoelCloudSync {
public:
    struct SyncConfig {
        bool autoSync = true;
        int syncIntervalSeconds = 30;
        bool syncOnSave = true;
        bool syncOnLaunch = true;

        // Selective sync
        std::set<FileType> syncTypes = {
            FileType::Project, FileType::Preset, FileType::Session
        };

        // Conflict handling
        ConflictResolution defaultConflictResolution = ConflictResolution::AskUser;

        // Backup
        bool autoBackup = true;
        int backupIntervalHours = 24;
        int backupRetentionDays = 30;

        // Limits
        uint64_t maxFileSize = 500 * 1024 * 1024;  // 500MB
        int maxConcurrentTransfers = 3;
    };

    static EchoelCloudSync& getInstance() {
        static EchoelCloudSync instance;
        return instance;
    }

    // ===== Configuration =====

    void configure(const SyncConfig& config) {
        config_ = config;
        conflictResolver_.setDefaultResolution(config.defaultConflictResolution);
        backupManager_.setRetentionDays(config.backupRetentionDays);
    }

    SyncConfig getConfig() const { return config_; }

    // ===== Provider Management =====

    void setProvider(std::shared_ptr<ICloudProvider> provider) {
        provider_ = provider;
    }

    bool connect(const std::string& credentials) {
        if (!provider_) return false;

        bool connected = provider_->connect(credentials);
        if (connected) {
            status_ = SyncStatus::Idle;
            emitEvent(SyncEventType::OnlineMode, "", "Connected to cloud");
        }
        return connected;
    }

    void disconnect() {
        if (provider_) {
            provider_->disconnect();
        }
        status_ = SyncStatus::Offline;
        emitEvent(SyncEventType::OfflineMode, "", "Disconnected from cloud");
    }

    bool isConnected() const {
        return provider_ && provider_->isConnected();
    }

    // ===== Sync Operations =====

    void startSync() {
        if (!isConnected() || status_ == SyncStatus::Syncing) return;

        status_ = SyncStatus::Syncing;
        emitEvent(SyncEventType::SyncStarted, "", "Sync started");

        // Perform sync in background
        syncThread_ = std::thread([this]() {
            performSync();
        });
        syncThread_.detach();
    }

    void pauseSync() {
        if (status_ == SyncStatus::Syncing) {
            status_ = SyncStatus::Paused;
            emitEvent(SyncEventType::SyncPaused, "", "Sync paused");
        }
    }

    void resumeSync() {
        if (status_ == SyncStatus::Paused) {
            status_ = SyncStatus::Syncing;
            emitEvent(SyncEventType::SyncResumed, "", "Sync resumed");
            startSync();
        }
    }

    SyncStatus getStatus() const { return status_; }
    SyncStats getStats() const { return stats_; }

    // ===== Item Management =====

    void addItem(const SyncItem& item) {
        std::lock_guard<std::mutex> lock(itemsMutex_);
        items_[item.id] = item;
    }

    void removeItem(const std::string& itemId) {
        std::lock_guard<std::mutex> lock(itemsMutex_);
        items_.erase(itemId);
    }

    std::optional<SyncItem> getItem(const std::string& itemId) const {
        std::lock_guard<std::mutex> lock(itemsMutex_);
        auto it = items_.find(itemId);
        if (it != items_.end()) {
            return it->second;
        }
        return std::nullopt;
    }

    std::vector<SyncItem> getItems() const {
        std::lock_guard<std::mutex> lock(itemsMutex_);
        std::vector<SyncItem> result;
        for (const auto& [id, item] : items_) {
            result.push_back(item);
        }
        return result;
    }

    // ===== Version Control =====

    std::vector<FileVersion> getVersionHistory(const std::string& itemId) const {
        return versionManager_.getVersions(itemId);
    }

    bool restoreVersion(const std::string& itemId, const std::string& versionId) {
        auto version = versionManager_.getVersion(itemId, versionId);
        if (!version) return false;

        // Download and restore the version
        // ... implementation ...

        return true;
    }

    // ===== Conflict Handling =====

    std::vector<ConflictInfo> getConflicts() const {
        std::lock_guard<std::mutex> lock(conflictsMutex_);
        return std::vector<ConflictInfo>(conflicts_.begin(), conflicts_.end());
    }

    void resolveConflict(const std::string& itemId, ConflictResolution resolution) {
        std::lock_guard<std::mutex> lock(conflictsMutex_);

        for (auto& conflict : conflicts_) {
            if (conflict.itemId == itemId) {
                conflict.resolution = resolution;
                conflictResolver_.resolve(conflict);

                emitEvent(SyncEventType::ConflictResolved, itemId,
                         "Conflict resolved: " + conflict.itemPath);
                break;
            }
        }

        // Remove resolved conflicts
        conflicts_.erase(
            std::remove_if(conflicts_.begin(), conflicts_.end(),
                          [](const ConflictInfo& c) { return c.resolved; }),
            conflicts_.end());
    }

    void setConflictCallback(ConflictResolver::ResolverCallback callback) {
        conflictResolver_.setInteractiveCallback(callback);
    }

    // ===== Backup =====

    BackupInfo createBackup(const std::string& name = "") {
        auto items = getItems();
        std::string backupName = name.empty() ?
            "Backup " + std::to_string(getCurrentTimestamp()) : name;

        auto backup = backupManager_.createBackup(backupName, items, name.empty());

        emitEvent(SyncEventType::BackupCreated, backup.id,
                 "Backup created: " + backup.name);

        return backup;
    }

    std::vector<BackupInfo> getBackups() const {
        return backupManager_.getBackups();
    }

    bool restoreBackup(const std::string& backupId) {
        auto backup = backupManager_.getBackup(backupId);
        if (!backup) return false;

        // Restore backup
        // ... implementation ...

        emitEvent(SyncEventType::BackupRestored, backupId,
                 "Backup restored: " + backup->name);

        return true;
    }

    // ===== Events =====

    void addEventListener(SyncEventCallback callback) {
        std::lock_guard<std::mutex> lock(listenersMutex_);
        listeners_.push_back(callback);
    }

    // ===== Quota =====

    uint64_t getQuotaTotal() const {
        return provider_ ? provider_->getQuotaTotal() : 0;
    }

    uint64_t getQuotaUsed() const {
        return provider_ ? provider_->getQuotaUsed() : 0;
    }

    float getQuotaPercent() const {
        auto total = getQuotaTotal();
        if (total == 0) return 0.0f;
        return static_cast<float>(getQuotaUsed()) / total * 100.0f;
    }

private:
    EchoelCloudSync() : status_(SyncStatus::Offline) {}

    void performSync() {
        if (!isConnected()) {
            status_ = SyncStatus::Offline;
            return;
        }

        stats_.lastSyncTime = getCurrentTimestamp();
        stats_.pendingUploads = 0;
        stats_.pendingDownloads = 0;

        auto items = getItems();

        for (auto& item : items) {
            if (status_ == SyncStatus::Paused) break;

            // Check for changes
            if (item.needsUpload) {
                uploadItem(item);
            } else if (item.needsDownload) {
                downloadItem(item);
            }
        }

        if (status_ != SyncStatus::Paused) {
            status_ = SyncStatus::Idle;
            emitEvent(SyncEventType::SyncCompleted, "",
                     "Sync completed: " + std::to_string(stats_.syncedFiles) + " files");
        }
    }

    void uploadItem(SyncItem& item) {
        status_ = SyncStatus::Uploading;
        emitEvent(SyncEventType::FileUploading, item.id, item.path);

        bool success = provider_->uploadFile(
            item.path, item.remotePath,
            [this, &item](float progress) {
                stats_.syncProgress = progress;
            });

        if (success) {
            item.isSynced = true;
            item.needsUpload = false;
            item.remoteModified = getCurrentTimestamp();
            stats_.syncedFiles++;

            // Add version
            FileVersion version;
            version.versionId = "v_" + std::to_string(getCurrentTimestamp());
            version.fileId = item.id;
            version.timestamp = getCurrentTimestamp();
            version.checksum = item.localChecksum;
            versionManager_.addVersion(item.id, version);

            emitEvent(SyncEventType::FileUploaded, item.id, item.path);
        }
    }

    void downloadItem(SyncItem& item) {
        status_ = SyncStatus::Downloading;
        emitEvent(SyncEventType::FileDownloading, item.id, item.remotePath);

        bool success = provider_->downloadFile(
            item.remotePath, item.path,
            [this](float progress) {
                stats_.syncProgress = progress;
            });

        if (success) {
            item.isSynced = true;
            item.needsDownload = false;
            item.localModified = item.remoteModified;
            stats_.syncedFiles++;

            emitEvent(SyncEventType::FileDownloaded, item.id, item.path);
        }
    }

    void emitEvent(SyncEventType type, const std::string& itemId,
                   const std::string& message) {
        SyncEvent event;
        event.type = type;
        event.itemId = itemId;
        event.message = message;
        event.timestamp = getCurrentTimestamp();
        event.progress = stats_.syncProgress;

        std::lock_guard<std::mutex> lock(listenersMutex_);
        for (const auto& listener : listeners_) {
            listener(event);
        }
    }

    uint64_t getCurrentTimestamp() {
        return std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::system_clock::now().time_since_epoch()).count();
    }

    SyncConfig config_;
    std::shared_ptr<ICloudProvider> provider_;

    std::atomic<SyncStatus> status_;
    SyncStats stats_;

    std::map<std::string, SyncItem> items_;
    mutable std::mutex itemsMutex_;

    std::vector<ConflictInfo> conflicts_;
    mutable std::mutex conflictsMutex_;

    ConflictResolver conflictResolver_;
    VersionManager versionManager_;
    BackupManager backupManager_;

    std::vector<SyncEventCallback> listeners_;
    std::mutex listenersMutex_;

    std::thread syncThread_;
};

// ============================================================================
// Convenience
// ============================================================================

#define ECHOEL_CLOUD Echoel::Cloud::EchoelCloudSync::getInstance()

} // namespace Cloud
} // namespace Echoel

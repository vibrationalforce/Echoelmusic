#pragma once

#include <JuceHeader.h>
#include <vector>
#include <map>
#include <functional>
#include <memory>

/**
 * ╔═══════════════════════════════════════════════════════════════════════════╗
 * ║           COLLABORATION HUB - Kooperations-Plattform                      ║
 * ╠═══════════════════════════════════════════════════════════════════════════╣
 * ║                                                                           ║
 * ║   ZERO-COST Kooperations-Modell                                           ║
 * ║   - Jeder behält seine eigenen Einnahmen (GEMA, Spotify, YouTube)        ║
 * ║   - Keine Platform-Fees                                                   ║
 * ║   - Fokus auf Verbindung & Zusammenarbeit                                ║
 * ║                                                                           ║
 * ║   Features:                                                               ║
 * ║   • Creator Matching (Genre, Skills, Location)                            ║
 * ║   • Project Collaboration (Real-time, Async)                              ║
 * ║   • Split Sheet Management (wer bekommt welchen %)                        ║
 * ║   • GEMA/PRO Integration (Rechteverwaltung)                               ║
 * ║   • CloudKit Sync (kostenlos via Apple)                                   ║
 * ║   • P2P File Transfer (keine Server-Kosten)                               ║
 * ║                                                                           ║
 * ╚═══════════════════════════════════════════════════════════════════════════╝
 */

namespace Echoel {

//==============================================================================
// Creator Profile
//==============================================================================

struct CreatorProfile
{
    // Identity
    juce::String uniqueId;              // UUID
    juce::String displayName;
    juce::String bio;
    juce::String location;              // City, Country
    juce::String timezone;

    // Skills & Roles
    enum class Role
    {
        Producer,
        Songwriter,
        Vocalist,
        Instrumentalist,
        MixEngineer,
        MasteringEngineer,
        Beatmaker,
        DJProducer,
        SoundDesigner,
        VideoEditor,
        VJLightingDesigner,
        ContentCreator
    };
    std::vector<Role> roles;

    // Music Style
    std::vector<juce::String> genres;   // "House", "Techno", "Pop", etc.
    std::vector<juce::String> vibes;    // "Dark", "Uplifting", "Melodic"
    std::vector<juce::String> daws;     // "Echoelmusic", "Ableton", "Logic"

    // Rights & Royalties
    struct RoyaltyInfo
    {
        juce::String proMembership;     // "GEMA", "ASCAP", "BMI", "PRS", etc.
        juce::String publisherId;       // IPI/CAE Number
        juce::String labelAffiliation;
        bool isAvailableForCollabs = true;
        bool acceptsRemixes = true;
    };
    RoyaltyInfo royalties;

    // Social/Portfolio Links (User bekommt Traffic, nicht wir)
    juce::String spotifyArtistUrl;
    juce::String soundcloudUrl;
    juce::String youtubeChannelUrl;
    juce::String instagramUrl;
    juce::String websiteUrl;

    // Stats (für Matching, nicht für uns)
    int completedCollabs = 0;
    float averageRating = 0.0f;         // 1-5 Sterne
    int responseTimeHours = 24;

    // Availability
    bool isOnline = false;
    juce::Time lastActive;
    std::vector<juce::String> availableDays;    // "Mon", "Tue", etc.
};

//==============================================================================
// Collaboration Project
//==============================================================================

struct CollabProject
{
    juce::String projectId;             // UUID
    juce::String title;
    juce::String description;

    // Project Type
    enum class ProjectType
    {
        OriginalTrack,          // Neue Produktion
        Remix,                  // Remix eines bestehenden Tracks
        Stem_Collab,            // Stems austauschen
        Topline,                // Vocals/Melodie über Beat
        Mix_Master,             // Mixing/Mastering Service
        VideoEdit,              // Music Video / Visualizer
        LivePerformance         // Live Set zusammen
    };
    ProjectType type = ProjectType::OriginalTrack;

    // Genre & Vibe
    juce::String primaryGenre;
    std::vector<juce::String> tags;

    // Participants
    struct Participant
    {
        juce::String creatorId;
        CreatorProfile::Role role;
        float ownershipPercent = 0.0f;  // % der Rechte
        bool hasAccepted = false;
        juce::Time joinedAt;
    };
    std::vector<Participant> participants;

    // Status
    enum class Status
    {
        Open,               // Sucht noch Teilnehmer
        InProgress,         // Aktiv in Arbeit
        Review,             // Zur Abnahme
        Completed,          // Fertig
        Released,           // Veröffentlicht
        Archived            // Archiviert
    };
    Status status = Status::Open;

    // Timeline
    juce::Time createdAt;
    juce::Time deadline;                // Optional
    juce::Time completedAt;

    // Files (P2P Transfer, nicht bei uns gehostet)
    struct SharedFile
    {
        juce::String filename;
        juce::String fileHash;          // SHA-256 für Verification
        int64_t fileSize;
        juce::String uploaderId;
        juce::Time uploadedAt;
        juce::String p2pMagnetLink;     // Optional: WebTorrent
    };
    std::vector<SharedFile> files;

    // Chat/Comments
    struct Message
    {
        juce::String senderId;
        juce::String content;
        juce::Time timestamp;
        bool isSystemMessage = false;
    };
    std::vector<Message> chat;
};

//==============================================================================
// Split Sheet (Rechteverwaltung)
//==============================================================================

struct SplitSheet
{
    juce::String projectId;
    juce::String trackTitle;
    juce::String isrcCode;              // International Standard Recording Code
    juce::String iswcCode;              // International Standard Musical Work Code

    // Splits
    struct Split
    {
        juce::String creatorId;
        juce::String legalName;
        juce::String proMembership;     // GEMA, ASCAP, etc.
        juce::String ipiNumber;         // IPI/CAE

        // Aufschlüsselung
        float masterOwnership = 0.0f;           // % Master-Rechte (Recording)
        float publishingOwnership = 0.0f;       // % Publishing (Komposition)
        float performanceOwnership = 0.0f;      // % Performance (GEMA-Tantiemen)

        // Rolle für Dokumentation
        juce::String contributionDescription;   // "Produced beat", "Wrote lyrics", etc.
    };
    std::vector<Split> splits;

    // Verification
    bool allPartiesAgreed = false;
    std::map<juce::String, juce::Time> signatures;  // creatorId → signedAt

    // Export
    juce::String exportToPDF();
    juce::String exportToJSON();
};

//==============================================================================
// Collaboration Hub Manager
//==============================================================================

class CollaborationHub
{
public:
    //==========================================================================
    // Singleton
    //==========================================================================

    static CollaborationHub& getInstance()
    {
        static CollaborationHub instance;
        return instance;
    }

    //==========================================================================
    // Profile Management
    //==========================================================================

    /** Create/Update own profile */
    void updateProfile(const CreatorProfile& profile)
    {
        myProfile = profile;
        syncProfileToCloud();
    }

    /** Get own profile */
    CreatorProfile& getMyProfile() { return myProfile; }

    /** Search for creators */
    std::vector<CreatorProfile> searchCreators(const SearchCriteria& criteria)
    {
        std::vector<CreatorProfile> results;

        for (const auto& [id, profile] : cachedProfiles)
        {
            if (matchesCriteria(profile, criteria))
            {
                results.push_back(profile);
            }
        }

        // Sort by relevance
        std::sort(results.begin(), results.end(),
            [&criteria](const CreatorProfile& a, const CreatorProfile& b)
            {
                return calculateRelevance(a, criteria) > calculateRelevance(b, criteria);
            });

        return results;
    }

    struct SearchCriteria
    {
        std::vector<CreatorProfile::Role> roles;
        std::vector<juce::String> genres;
        juce::String location;
        bool onlyOnline = false;
        bool onlyAvailable = true;
        float minRating = 0.0f;
    };

    //==========================================================================
    // Project Management
    //==========================================================================

    /** Create new collaboration project */
    CollabProject createProject(const juce::String& title,
                                 CollabProject::ProjectType type,
                                 const juce::String& genre)
    {
        CollabProject project;
        project.projectId = generateUUID();
        project.title = title;
        project.type = type;
        project.primaryGenre = genre;
        project.createdAt = juce::Time::getCurrentTime();
        project.status = CollabProject::Status::Open;

        // Add self as first participant
        CollabProject::Participant me;
        me.creatorId = myProfile.uniqueId;
        me.hasAccepted = true;
        me.joinedAt = juce::Time::getCurrentTime();
        project.participants.push_back(me);

        myProjects[project.projectId] = project;
        syncProjectToCloud(project);

        return project;
    }

    /** Invite creator to project */
    bool inviteToProject(const juce::String& projectId,
                         const juce::String& creatorId,
                         CreatorProfile::Role role,
                         float proposedOwnership)
    {
        auto it = myProjects.find(projectId);
        if (it == myProjects.end())
            return false;

        CollabProject::Participant participant;
        participant.creatorId = creatorId;
        participant.role = role;
        participant.ownershipPercent = proposedOwnership;
        participant.hasAccepted = false;

        it->second.participants.push_back(participant);

        // Send invitation notification
        sendInvitation(creatorId, it->second);

        return true;
    }

    /** Accept project invitation */
    bool acceptInvitation(const juce::String& projectId)
    {
        // Find invitation in pending list
        auto it = pendingInvitations.find(projectId);
        if (it == pendingInvitations.end())
            return false;

        // Add to my projects
        myProjects[projectId] = it->second;
        pendingInvitations.erase(it);

        // Notify other participants
        notifyParticipants(projectId, myProfile.displayName + " joined the project");

        return true;
    }

    /** Get my projects */
    std::vector<CollabProject> getMyProjects()
    {
        std::vector<CollabProject> projects;
        for (const auto& [id, project] : myProjects)
        {
            projects.push_back(project);
        }
        return projects;
    }

    /** Get open projects (looking for collaborators) */
    std::vector<CollabProject> discoverOpenProjects(const SearchCriteria& criteria)
    {
        // Query CloudKit for open projects matching criteria
        return queryOpenProjects(criteria);
    }

    //==========================================================================
    // Split Sheet Management
    //==========================================================================

    /** Create split sheet for project */
    SplitSheet createSplitSheet(const juce::String& projectId)
    {
        auto it = myProjects.find(projectId);
        if (it == myProjects.end())
            return {};

        SplitSheet sheet;
        sheet.projectId = projectId;
        sheet.trackTitle = it->second.title;

        // Pre-populate from participants
        for (const auto& participant : it->second.participants)
        {
            SplitSheet::Split split;
            split.creatorId = participant.creatorId;

            // Get creator info
            auto profile = getCreatorProfile(participant.creatorId);
            if (profile)
            {
                split.legalName = profile->displayName;
                split.proMembership = profile->royalties.proMembership;
            }

            split.masterOwnership = participant.ownershipPercent;
            split.publishingOwnership = participant.ownershipPercent;
            split.performanceOwnership = participant.ownershipPercent;

            sheet.splits.push_back(split);
        }

        splitSheets[projectId] = sheet;
        return sheet;
    }

    /** Update split percentages */
    bool updateSplits(const juce::String& projectId, const std::vector<SplitSheet::Split>& newSplits)
    {
        auto it = splitSheets.find(projectId);
        if (it == splitSheets.end())
            return false;

        // Verify total = 100%
        float totalMaster = 0.0f, totalPublishing = 0.0f;
        for (const auto& split : newSplits)
        {
            totalMaster += split.masterOwnership;
            totalPublishing += split.publishingOwnership;
        }

        if (std::abs(totalMaster - 100.0f) > 0.01f ||
            std::abs(totalPublishing - 100.0f) > 0.01f)
        {
            DBG("CollaborationHub: Split percentages must total 100%");
            return false;
        }

        it->second.splits = newSplits;
        it->second.allPartiesAgreed = false;  // Needs re-approval
        it->second.signatures.clear();

        // Notify all participants of change
        notifyParticipants(projectId, "Split sheet updated - please review");

        return true;
    }

    /** Sign split sheet (digital agreement) */
    bool signSplitSheet(const juce::String& projectId)
    {
        auto it = splitSheets.find(projectId);
        if (it == splitSheets.end())
            return false;

        it->second.signatures[myProfile.uniqueId] = juce::Time::getCurrentTime();

        // Check if all parties signed
        bool allSigned = true;
        auto projectIt = myProjects.find(projectId);
        if (projectIt != myProjects.end())
        {
            for (const auto& participant : projectIt->second.participants)
            {
                if (it->second.signatures.find(participant.creatorId) == it->second.signatures.end())
                {
                    allSigned = false;
                    break;
                }
            }
        }

        it->second.allPartiesAgreed = allSigned;

        if (allSigned)
        {
            notifyParticipants(projectId, "✅ All parties signed the split sheet!");
        }

        return true;
    }

    /** Export split sheet for GEMA/PRO registration */
    juce::String exportSplitSheetForPRO(const juce::String& projectId)
    {
        auto it = splitSheets.find(projectId);
        if (it == splitSheets.end())
            return {};

        // Generate standard format for PRO registration
        juce::String output;
        output << "=== SPLIT SHEET / WERKVERTEILUNG ===\n\n";
        output << "Track Title: " << it->second.trackTitle << "\n";
        output << "ISRC: " << it->second.isrcCode << "\n";
        output << "ISWC: " << it->second.iswcCode << "\n\n";
        output << "=== BETEILIGTE / PARTICIPANTS ===\n\n";

        for (const auto& split : it->second.splits)
        {
            output << "Name: " << split.legalName << "\n";
            output << "PRO: " << split.proMembership << "\n";
            output << "IPI: " << split.ipiNumber << "\n";
            output << "Master: " << juce::String(split.masterOwnership, 2) << "%\n";
            output << "Publishing: " << juce::String(split.publishingOwnership, 2) << "%\n";
            output << "Contribution: " << split.contributionDescription << "\n";
            output << "---\n";
        }

        output << "\n=== DIGITAL SIGNATURES ===\n";
        for (const auto& [creatorId, timestamp] : it->second.signatures)
        {
            output << creatorId << ": " << timestamp.toString(true, true) << "\n";
        }

        return output;
    }

    //==========================================================================
    // P2P File Sharing (Zero Server Cost)
    //==========================================================================

    /** Share file via P2P (WebTorrent compatible) */
    void shareFile(const juce::String& projectId, const juce::File& file)
    {
        auto it = myProjects.find(projectId);
        if (it == myProjects.end())
            return;

        CollabProject::SharedFile sharedFile;
        sharedFile.filename = file.getFileName();
        sharedFile.fileSize = file.getSize();
        sharedFile.uploaderId = myProfile.uniqueId;
        sharedFile.uploadedAt = juce::Time::getCurrentTime();

        // Calculate SHA-256 hash
        sharedFile.fileHash = calculateFileHash(file);

        // Generate P2P magnet link (would use WebTorrent in production)
        sharedFile.p2pMagnetLink = generateMagnetLink(file, sharedFile.fileHash);

        it->second.files.push_back(sharedFile);

        // Notify participants
        notifyParticipants(projectId, myProfile.displayName + " shared: " + sharedFile.filename);
    }

    //==========================================================================
    // Real-time Collaboration (via EchoelSync)
    //==========================================================================

    /** Start real-time session */
    void startRealtimeSession(const juce::String& projectId)
    {
        // Use EchoelSync for real-time collaboration
        // Participants can jam together with sample-accurate sync
    }

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(const CollabProject&)> onInvitationReceived;
    std::function<void(const juce::String& projectId, const juce::String& message)> onProjectMessage;
    std::function<void(const SplitSheet&)> onSplitSheetUpdated;

private:
    CollaborationHub() = default;

    //==========================================================================
    // CloudKit Sync (Zero Cost via Apple)
    //==========================================================================

    void syncProfileToCloud()
    {
        // Would use CloudKit to sync profile
        DBG("CollaborationHub: Syncing profile to CloudKit...");
    }

    void syncProjectToCloud(const CollabProject& project)
    {
        // Would use CloudKit to sync project
        DBG("CollaborationHub: Syncing project '" << project.title << "' to CloudKit...");
    }

    std::vector<CollabProject> queryOpenProjects(const SearchCriteria& criteria)
    {
        // Would query CloudKit for open projects
        return {};
    }

    //==========================================================================
    // Helpers
    //==========================================================================

    juce::String generateUUID()
    {
        return juce::Uuid().toString();
    }

    bool matchesCriteria(const CreatorProfile& profile, const SearchCriteria& criteria)
    {
        // Check roles
        if (!criteria.roles.empty())
        {
            bool hasRole = false;
            for (auto role : criteria.roles)
            {
                if (std::find(profile.roles.begin(), profile.roles.end(), role) != profile.roles.end())
                {
                    hasRole = true;
                    break;
                }
            }
            if (!hasRole) return false;
        }

        // Check genres
        if (!criteria.genres.empty())
        {
            bool hasGenre = false;
            for (const auto& genre : criteria.genres)
            {
                if (std::find(profile.genres.begin(), profile.genres.end(), genre) != profile.genres.end())
                {
                    hasGenre = true;
                    break;
                }
            }
            if (!hasGenre) return false;
        }

        // Check rating
        if (profile.averageRating < criteria.minRating)
            return false;

        // Check availability
        if (criteria.onlyAvailable && !profile.royalties.isAvailableForCollabs)
            return false;

        return true;
    }

    static float calculateRelevance(const CreatorProfile& profile, const SearchCriteria& criteria)
    {
        float score = 0.0f;

        // More matching genres = higher score
        for (const auto& genre : criteria.genres)
        {
            if (std::find(profile.genres.begin(), profile.genres.end(), genre) != profile.genres.end())
                score += 10.0f;
        }

        // Rating bonus
        score += profile.averageRating * 5.0f;

        // Completed collabs bonus
        score += std::min(50.0f, profile.completedCollabs * 2.0f);

        // Online bonus
        if (profile.isOnline)
            score += 20.0f;

        return score;
    }

    CreatorProfile* getCreatorProfile(const juce::String& creatorId)
    {
        auto it = cachedProfiles.find(creatorId);
        return it != cachedProfiles.end() ? &it->second : nullptr;
    }

    void sendInvitation(const juce::String& creatorId, const CollabProject& project)
    {
        // Would send via CloudKit push notification
        DBG("CollaborationHub: Sending invitation to " << creatorId);
    }

    void notifyParticipants(const juce::String& projectId, const juce::String& message)
    {
        // Would notify via CloudKit
        DBG("CollaborationHub: " << message);
    }

    juce::String calculateFileHash(const juce::File& file)
    {
        juce::MemoryBlock data;
        file.loadFileAsData(data);
        return juce::SHA256(data.getData(), data.getSize()).toHexString();
    }

    juce::String generateMagnetLink(const juce::File& file, const juce::String& hash)
    {
        // Would generate WebTorrent-compatible magnet link
        return "magnet:?xt=urn:sha256:" + hash + "&dn=" + juce::URL::addEscapeChars(file.getFileName(), true);
    }

    //==========================================================================
    // Data
    //==========================================================================

    CreatorProfile myProfile;
    std::map<juce::String, CreatorProfile> cachedProfiles;
    std::map<juce::String, CollabProject> myProjects;
    std::map<juce::String, CollabProject> pendingInvitations;
    std::map<juce::String, SplitSheet> splitSheets;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(CollaborationHub)
};

} // namespace Echoel

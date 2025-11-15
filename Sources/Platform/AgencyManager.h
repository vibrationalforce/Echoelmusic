#pragma once

#include <JuceHeader.h>
#include "CreatorManager.h"
#include <vector>
#include <map>

namespace Echoelmusic {

/**
 * AgencyManager - Talent Agency & Booking System
 *
 * Features:
 * - Agency Registration & Management
 * - Talent Discovery & Roster Management
 * - Booking Requests & Negotiations
 * - Commission Tracking
 * - Client Relationship Management (CRM)
 * - Contract Management
 * - Calendar & Availability Management
 * - Invoice & Payment Processing
 *
 * Use Cases:
 * - Talent agencies managing creators
 * - Booking agents for DJs/musicians
 * - Influencer marketing agencies
 * - Management companies
 * - Event promoters booking talent
 */
class AgencyManager
{
public:
    enum class AgencyType
    {
        TalentAgency,           // Full-service talent representation
        BookingAgency,          // Event/gig booking
        InfluencerAgency,       // Influencer marketing
        ManagementCompany,      // Artist management
        EventPromoter,          // Event organization & booking
        Broker                  // Freelance broker/agent
    };

    enum class BookingStatus
    {
        Inquiry,                // Initial inquiry
        Pending,                // Awaiting creator response
        Negotiating,            // Price/terms negotiation
        Accepted,               // Booking confirmed
        Contracted,             // Contract signed
        InProgress,             // Event/project in progress
        Completed,              // Successfully completed
        Cancelled,              // Booking cancelled
        Disputed                // Dispute/problem
    };

    struct Agency
    {
        juce::String id;
        juce::String name;
        AgencyType type;
        juce::String email;
        juce::String phone;
        juce::String website;
        juce::String address;

        juce::String description;
        juce::Image logo;

        // Commission structure
        float defaultCommission = 0.15f;    // 15% default
        float minCommission = 0.10f;
        float maxCommission = 0.30f;

        // Statistics
        int totalCreators = 0;
        int activeBookings = 0;
        double totalRevenue = 0.0;
        double lifetimeCommissions = 0.0;

        // Verification
        bool verified = false;
        bool backgroundChecked = false;

        // Contact person
        juce::String primaryContact;
        juce::String contactEmail;
        juce::String contactPhone;
    };

    struct BookingRequest
    {
        juce::String id;
        juce::String creatorId;
        juce::String agencyId;
        juce::String clientId;              // Company/brand requesting

        BookingStatus status;

        // Event details
        juce::String eventName;
        juce::String eventType;             // "Concert", "Brand Deal", "Sponsored Post"
        juce::Time eventDate;
        juce::String location;
        juce::String venue;

        // Financial
        double offeredRate = 0.0;
        double negotiatedRate = 0.0;
        double finalRate = 0.0;
        float agencyCommission = 0.15f;
        double agencyEarnings = 0.0;

        // Requirements
        juce::String requirements;          // Technical rider, etc.
        std::vector<juce::String> deliverables;
        juce::Time deadline;

        // Contract
        juce::String contractId;
        bool contractSigned = false;
        juce::Time contractSignedDate;

        // Communication
        std::vector<juce::String> messages;
        juce::Time lastMessage;

        // Timestamps
        juce::Time requestedDate;
        juce::Time confirmedDate;
        juce::Time completedDate;
    };

    struct Client
    {
        juce::String id;
        juce::String name;                  // Company/brand name
        juce::String industry;
        juce::String email;
        juce::String phone;
        juce::String website;

        juce::String contactPerson;
        juce::String contactEmail;

        // Budget
        double budget = 0.0;
        double totalSpent = 0.0;

        // History
        int totalBookings = 0;
        std::vector<juce::String> pastBookingIds;

        // Preferences
        std::vector<juce::String> preferredNiches;
        std::vector<juce::String> blacklistedCreators;
    };

    AgencyManager();
    ~AgencyManager();

    // ===========================
    // Agency Management
    // ===========================

    /** Register new agency */
    juce::String createAgency(const Agency& agency);

    /** Update agency info */
    void updateAgency(const juce::String& agencyId, const Agency& agency);

    /** Get agency info */
    Agency getAgency(const juce::String& agencyId) const;

    /** Delete agency */
    void deleteAgency(const juce::String& agencyId);

    /** Get all agencies */
    std::vector<Agency> getAllAgencies() const;

    /** Search agencies by type/location */
    std::vector<Agency> searchAgencies(AgencyType type, const juce::String& location = "") const;

    // ===========================
    // Roster Management
    // ===========================

    /** Add creator to agency roster */
    void addCreatorToRoster(const juce::String& agencyId, const juce::String& creatorId, float commission);

    /** Remove creator from roster */
    void removeCreatorFromRoster(const juce::String& agencyId, const juce::String& creatorId);

    /** Get all creators in agency roster */
    std::vector<juce::String> getRoster(const juce::String& agencyId) const;

    /** Check if creator is represented */
    bool isCreatorRepresented(const juce::String& creatorId) const;

    /** Get creator's agency */
    juce::String getCreatorAgency(const juce::String& creatorId) const;

    // ===========================
    // Talent Discovery
    // ===========================

    /** Discover talent based on criteria */
    std::vector<juce::String> discoverTalent(
        int minFollowers = 10000,
        const juce::String& niche = "",
        float maxCommission = 0.25f,
        bool availableOnly = true
    ) const;

    /** Recommend creators for specific job */
    std::vector<juce::String> recommendCreators(
        const juce::String& jobDescription,
        const juce::String& niche,
        double budget
    ) const;

    /** Send talent invitation */
    void sendTalentInvitation(
        const juce::String& agencyId,
        const juce::String& creatorId,
        const juce::String& message
    );

    // ===========================
    // Booking Management
    // ===========================

    /** Create booking request */
    juce::String createBooking(const BookingRequest& request);

    /** Update booking */
    void updateBooking(const juce::String& bookingId, const BookingRequest& request);

    /** Get booking details */
    BookingRequest getBooking(const juce::String& bookingId) const;

    /** Accept booking (creator/agency) */
    void acceptBooking(const juce::String& bookingId);

    /** Decline booking */
    void declineBooking(const juce::String& bookingId, const juce::String& reason);

    /** Cancel booking */
    void cancelBooking(const juce::String& bookingId, const juce::String& reason);

    /** Complete booking */
    void completeBooking(const juce::String& bookingId);

    /** Get all bookings for agency */
    std::vector<BookingRequest> getAgencyBookings(
        const juce::String& agencyId,
        BookingStatus status = BookingStatus::Pending
    ) const;

    /** Get all bookings for creator */
    std::vector<BookingRequest> getCreatorBookings(
        const juce::String& creatorId,
        BookingStatus status = BookingStatus::Pending
    ) const;

    // ===========================
    // Negotiation
    // ===========================

    /** Make counter-offer */
    void makeCounterOffer(
        const juce::String& bookingId,
        double newRate,
        const juce::String& message
    );

    /** Accept counter-offer */
    void acceptCounterOffer(const juce::String& bookingId);

    /** Send negotiation message */
    void sendMessage(
        const juce::String& bookingId,
        const juce::String& sender,
        const juce::String& message
    );

    // ===========================
    // Client Management (CRM)
    // ===========================

    /** Add client */
    juce::String addClient(const Client& client);

    /** Update client */
    void updateClient(const juce::String& clientId, const Client& client);

    /** Get client info */
    Client getClient(const juce::String& clientId) const;

    /** Get all clients for agency */
    std::vector<Client> getAgencyClients(const juce::String& agencyId) const;

    /** Add booking to client history */
    void addClientBooking(const juce::String& clientId, const juce::String& bookingId);

    // ===========================
    // Commission & Financials
    // ===========================

    /** Calculate commission for booking */
    double calculateCommission(const juce::String& bookingId) const;

    /** Get total commissions earned */
    double getTotalCommissions(const juce::String& agencyId) const;

    /** Get monthly revenue report */
    struct RevenueReport {
        double totalRevenue = 0.0;
        double totalCommissions = 0.0;
        int completedBookings = 0;
        double averageBookingValue = 0.0;
    };
    RevenueReport getRevenueReport(const juce::String& agencyId, int year, int month) const;

    // ===========================
    // Calendar & Availability
    // ===========================

    /** Check creator availability */
    bool checkAvailability(const juce::String& creatorId, juce::Time date) const;

    /** Get creator's schedule */
    std::vector<BookingRequest> getSchedule(const juce::String& creatorId) const;

    /** Block date (mark unavailable) */
    void blockDate(const juce::String& creatorId, juce::Time startDate, juce::Time endDate);

    // ===========================
    // Analytics & Reporting
    // ===========================

    /** Get agency performance metrics */
    struct AgencyMetrics {
        int totalBookings = 0;
        int completedBookings = 0;
        int cancelledBookings = 0;
        float successRate = 0.0f;
        double totalRevenue = 0.0;
        double averageBookingValue = 0.0;
        juce::String topPerformingCreator;
        juce::String topClient;
    };
    AgencyMetrics getAgencyMetrics(const juce::String& agencyId) const;

    /** Get creator performance under agency */
    struct CreatorPerformance {
        juce::String creatorId;
        int totalBookings = 0;
        double totalEarnings = 0.0;
        double averageRating = 0.0;
        int completedOnTime = 0;
    };
    CreatorPerformance getCreatorPerformance(const juce::String& agencyId, const juce::String& creatorId) const;

    // ===========================
    // Verification & Trust
    // ===========================

    /** Verify agency */
    void verifyAgency(const juce::String& agencyId, bool verified);

    /** Get agency trust score */
    int getAgencyTrustScore(const juce::String& agencyId) const;

    // ===========================
    // Callbacks
    // ===========================

    std::function<void(const juce::String& agencyId)> onAgencyCreated;
    std::function<void(const juce::String& bookingId, BookingStatus status)> onBookingStatusChanged;
    std::function<void(const juce::String& agencyId, const juce::String& creatorId)> onCreatorAdded;
    std::function<void(const juce::String& bookingId, const juce::String& message)> onNewMessage;

private:
    std::map<juce::String, Agency> m_agencies;
    std::map<juce::String, BookingRequest> m_bookings;
    std::map<juce::String, Client> m_clients;

    // Agency → Creators mapping
    std::map<juce::String, std::vector<juce::String>> m_agencyRosters;

    // Creator → Agency mapping
    std::map<juce::String, juce::String> m_creatorAgencies;

    juce::CriticalSection m_lock;

    juce::String generateAgencyId() const;
    juce::String generateBookingId() const;
    juce::String generateClientId() const;

    void saveToDatabase();
    void loadFromDatabase();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(AgencyManager)
};

} // namespace Echoelmusic

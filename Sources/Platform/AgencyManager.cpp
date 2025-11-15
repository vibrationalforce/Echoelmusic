#include "AgencyManager.h"

namespace Echoelmusic {

AgencyManager::AgencyManager()
{
    loadFromDatabase();
    DBG("Agency Manager initialized");
}

AgencyManager::~AgencyManager()
{
    saveToDatabase();
}

// ===========================
// Agency Management
// ===========================

juce::String AgencyManager::createAgency(const Agency& agency)
{
    juce::ScopedLock sl(m_lock);

    juce::String agencyId = generateAgencyId();
    Agency newAgency = agency;
    newAgency.id = agencyId;

    m_agencies[agencyId] = newAgency;

    DBG("Agency created: " << newAgency.name << " (ID: " << agencyId << ")");

    if (onAgencyCreated)
        onAgencyCreated(agencyId);

    saveToDatabase();
    return agencyId;
}

void AgencyManager::updateAgency(const juce::String& agencyId, const Agency& agency)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_agencies.find(agencyId);
    if (it != m_agencies.end())
    {
        it->second = agency;
        it->second.id = agencyId;
        DBG("Agency updated: " << agencyId);
        saveToDatabase();
    }
}

AgencyManager::Agency AgencyManager::getAgency(const juce::String& agencyId) const
{
    juce::ScopedLock sl(m_lock);

    auto it = m_agencies.find(agencyId);
    if (it != m_agencies.end())
        return it->second;

    return Agency();
}

void AgencyManager::deleteAgency(const juce::String& agencyId)
{
    juce::ScopedLock sl(m_lock);
    m_agencies.erase(agencyId);
    m_agencyRosters.erase(agencyId);
    DBG("Agency deleted: " << agencyId);
    saveToDatabase();
}

std::vector<AgencyManager::Agency> AgencyManager::getAllAgencies() const
{
    juce::ScopedLock sl(m_lock);
    std::vector<Agency> agencies;
    for (const auto& pair : m_agencies)
        agencies.push_back(pair.second);
    return agencies;
}

std::vector<AgencyManager::Agency> AgencyManager::searchAgencies(
    AgencyType type,
    const juce::String& location
) const
{
    juce::ScopedLock sl(m_lock);
    std::vector<Agency> results;

    for (const auto& pair : m_agencies)
    {
        const Agency& agency = pair.second;

        if (agency.type != type && type != AgencyType::TalentAgency)
            continue;

        if (!location.isEmpty() && !agency.address.containsIgnoreCase(location))
            continue;

        results.push_back(agency);
    }

    return results;
}

// ===========================
// Roster Management
// ===========================

void AgencyManager::addCreatorToRoster(
    const juce::String& agencyId,
    const juce::String& creatorId,
    float commission
)
{
    juce::ScopedLock sl(m_lock);

    m_agencyRosters[agencyId].push_back(creatorId);
    m_creatorAgencies[creatorId] = agencyId;

    // Update agency stats
    auto it = m_agencies.find(agencyId);
    if (it != m_agencies.end())
        it->second.totalCreators++;

    DBG("Creator " << creatorId << " added to agency " << agencyId);

    if (onCreatorAdded)
        onCreatorAdded(agencyId, creatorId);

    saveToDatabase();
}

void AgencyManager::removeCreatorFromRoster(
    const juce::String& agencyId,
    const juce::String& creatorId
)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_agencyRosters.find(agencyId);
    if (it != m_agencyRosters.end())
    {
        it->second.erase(
            std::remove(it->second.begin(), it->second.end(), creatorId),
            it->second.end()
        );
    }

    m_creatorAgencies.erase(creatorId);

    auto agencyIt = m_agencies.find(agencyId);
    if (agencyIt != m_agencies.end())
        agencyIt->second.totalCreators--;

    DBG("Creator " << creatorId << " removed from agency");
    saveToDatabase();
}

std::vector<juce::String> AgencyManager::getRoster(const juce::String& agencyId) const
{
    juce::ScopedLock sl(m_lock);

    auto it = m_agencyRosters.find(agencyId);
    if (it != m_agencyRosters.end())
        return it->second;

    return {};
}

bool AgencyManager::isCreatorRepresented(const juce::String& creatorId) const
{
    juce::ScopedLock sl(m_lock);
    return m_creatorAgencies.find(creatorId) != m_creatorAgencies.end();
}

juce::String AgencyManager::getCreatorAgency(const juce::String& creatorId) const
{
    juce::ScopedLock sl(m_lock);

    auto it = m_creatorAgencies.find(creatorId);
    if (it != m_creatorAgencies.end())
        return it->second;

    return "";
}

// ===========================
// Booking Management
// ===========================

juce::String AgencyManager::createBooking(const BookingRequest& request)
{
    juce::ScopedLock sl(m_lock);

    juce::String bookingId = generateBookingId();
    BookingRequest newRequest = request;
    newRequest.id = bookingId;
    newRequest.requestedDate = juce::Time::getCurrentTime();

    m_bookings[bookingId] = newRequest;

    DBG("Booking created: " << bookingId);
    DBG("  Creator: " << request.creatorId);
    DBG("  Event: " << request.eventName);
    DBG("  Offered rate: $" << request.offeredRate);

    if (onBookingStatusChanged)
        onBookingStatusChanged(bookingId, newRequest.status);

    saveToDatabase();
    return bookingId;
}

void AgencyManager::acceptBooking(const juce::String& bookingId)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_bookings.find(bookingId);
    if (it != m_bookings.end())
    {
        it->second.status = BookingStatus::Accepted;
        it->second.confirmedDate = juce::Time::getCurrentTime();

        DBG("Booking accepted: " << bookingId);

        if (onBookingStatusChanged)
            onBookingStatusChanged(bookingId, BookingStatus::Accepted);

        saveToDatabase();
    }
}

void AgencyManager::completeBooking(const juce::String& bookingId)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_bookings.find(bookingId);
    if (it != m_bookings.end())
    {
        it->second.status = BookingStatus::Completed;
        it->second.completedDate = juce::Time::getCurrentTime();

        // Calculate commission
        double commission = calculateCommission(bookingId);
        it->second.agencyEarnings = commission;

        DBG("Booking completed: " << bookingId);
        DBG("  Agency earnings: $" << commission);

        if (onBookingStatusChanged)
            onBookingStatusChanged(bookingId, BookingStatus::Completed);

        saveToDatabase();
    }
}

double AgencyManager::calculateCommission(const juce::String& bookingId) const
{
    juce::ScopedLock sl(m_lock);

    auto it = m_bookings.find(bookingId);
    if (it != m_bookings.end())
    {
        return it->second.finalRate * it->second.agencyCommission;
    }

    return 0.0;
}

// ===========================
// Client Management
// ===========================

juce::String AgencyManager::addClient(const Client& client)
{
    juce::ScopedLock sl(m_lock);

    juce::String clientId = generateClientId();
    Client newClient = client;
    newClient.id = clientId;

    m_clients[clientId] = newClient;

    DBG("Client added: " << newClient.name << " (ID: " << clientId << ")");
    saveToDatabase();

    return clientId;
}

AgencyManager::Client AgencyManager::getClient(const juce::String& clientId) const
{
    juce::ScopedLock sl(m_lock);

    auto it = m_clients.find(clientId);
    if (it != m_clients.end())
        return it->second;

    return Client();
}

// ===========================
// Analytics
// ===========================

AgencyManager::AgencyMetrics AgencyManager::getAgencyMetrics(const juce::String& agencyId) const
{
    juce::ScopedLock sl(m_lock);

    AgencyMetrics metrics;

    for (const auto& pair : m_bookings)
    {
        const BookingRequest& booking = pair.second;

        if (booking.agencyId != agencyId)
            continue;

        metrics.totalBookings++;

        if (booking.status == BookingStatus::Completed)
        {
            metrics.completedBookings++;
            metrics.totalRevenue += booking.finalRate;
        }
        else if (booking.status == BookingStatus::Cancelled)
        {
            metrics.cancelledBookings++;
        }
    }

    if (metrics.totalBookings > 0)
        metrics.successRate = (float)metrics.completedBookings / metrics.totalBookings;

    if (metrics.completedBookings > 0)
        metrics.averageBookingValue = metrics.totalRevenue / metrics.completedBookings;

    return metrics;
}

// ===========================
// Internal
// ===========================

juce::String AgencyManager::generateAgencyId() const
{
    return "agency_" + juce::Uuid().toString().substring(0, 8);
}

juce::String AgencyManager::generateBookingId() const
{
    return "booking_" + juce::Uuid().toString().substring(0, 8);
}

juce::String AgencyManager::generateClientId() const
{
    return "client_" + juce::Uuid().toString().substring(0, 8);
}

void AgencyManager::saveToDatabase()
{
    DBG("Saving agency database...");
}

void AgencyManager::loadFromDatabase()
{
    DBG("Loading agency database...");
}

} // namespace Echoelmusic

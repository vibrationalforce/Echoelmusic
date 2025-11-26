#include "SessionManager.h"

//==============================================================================
SessionManager::SessionManager()
    : autoSaveTimer(*this)
{
    projectInfo.createdTime = juce::Time::getCurrentTime();
    projectInfo.lastModifiedTime = juce::Time::getCurrentTime();
}

SessionManager::~SessionManager()
{
    autoSaveTimer.stopTimer();
}

//==============================================================================
bool SessionManager::saveSession(const juce::File& file)
{
    // Create session XML
    auto xml = createSessionXML();

    if (xml == nullptr)
        return false;

    // Write to file
    if (!xml->writeTo(file))
        return false;

    // Update state
    currentSessionFile = file;
    isDirty = false;
    projectInfo.lastModifiedTime = juce::Time::getCurrentTime();

    return true;
}

bool SessionManager::loadSession(const juce::File& file)
{
    if (!file.existsAsFile())
        return false;

    // Parse XML
    auto xml = juce::parseXML(file);

    if (xml == nullptr)
        return false;

    // Restore from XML
    if (!restoreFromXML(*xml))
        return false;

    // Update state
    currentSessionFile = file;
    isDirty = false;

    return true;
}

void SessionManager::newSession()
{
    // Reset project info
    projectInfo = ProjectInfo();
    projectInfo.createdTime = juce::Time::getCurrentTime();
    projectInfo.lastModifiedTime = juce::Time::getCurrentTime();

    // Clear session state
    sessionState = nullptr;

    // Clear current file
    currentSessionFile = juce::File();
    isDirty = false;
}

//==============================================================================
void SessionManager::setAutoSave(int intervalMinutes)
{
    autoSaveIntervalMinutes = intervalMinutes;

    if (intervalMinutes > 0)
    {
        autoSaveTimer.startTimer(intervalMinutes * 60 * 1000);  // Convert to ms
    }
    else
    {
        autoSaveTimer.stopTimer();
    }
}

void SessionManager::triggerAutoSave()
{
    if (!isDirty || !currentSessionFile.exists())
        return;

    // Create auto-save file (same directory, with .autosave extension)
    juce::File autoSaveFile = currentSessionFile.withFileExtension(".autosave.echoelmusic");

    saveSession(autoSaveFile);
}

//==============================================================================
void SessionManager::setProjectInfo(const ProjectInfo& info)
{
    projectInfo = info;
    projectInfo.lastModifiedTime = juce::Time::getCurrentTime();
    markAsDirty();
}

void SessionManager::setSessionState(std::unique_ptr<juce::XmlElement> state)
{
    sessionState = std::move(state);
    markAsDirty();
}

//==============================================================================
std::unique_ptr<juce::XmlElement> SessionManager::createSessionXML()
{
    auto xml = std::make_unique<juce::XmlElement>("EoelSession");
    xml->setAttribute("version", "1.0");

    // Project Info
    auto projectInfoXml = createProjectInfoXML();
    if (projectInfoXml != nullptr)
        xml->addChildElement(projectInfoXml.release());

    // Session State (tracks, effects, etc.)
    if (sessionState != nullptr)
    {
        xml->addChildElement(new juce::XmlElement(*sessionState));
    }

    return xml;
}

bool SessionManager::restoreFromXML(const juce::XmlElement& xml)
{
    if (xml.getTagName() != "EoelSession")
        return false;

    // Check version
    juce::String version = xml.getStringAttribute("version", "1.0");

    // Restore project info
    auto* projectInfoXml = xml.getChildByName("ProjectInfo");
    if (projectInfoXml != nullptr)
    {
        if (!restoreProjectInfoFromXML(*projectInfoXml))
            return false;
    }

    // Restore session state
    auto* stateXml = xml.getChildByName("SessionState");
    if (stateXml != nullptr)
    {
        sessionState = std::make_unique<juce::XmlElement>(*stateXml);
    }

    return true;
}

//==============================================================================
std::unique_ptr<juce::XmlElement> SessionManager::createProjectInfoXML()
{
    auto xml = std::make_unique<juce::XmlElement>("ProjectInfo");

    xml->setAttribute("title", projectInfo.title);
    xml->setAttribute("artist", projectInfo.artist);
    xml->setAttribute("description", projectInfo.description);

    xml->setAttribute("tempo", projectInfo.tempo);
    xml->setAttribute("timeSignatureNumerator", projectInfo.timeSignatureNumerator);
    xml->setAttribute("timeSignatureDenominator", projectInfo.timeSignatureDenominator);

    xml->setAttribute("sampleRate", projectInfo.sampleRate);
    xml->setAttribute("blockSize", projectInfo.blockSize);

    xml->setAttribute("createdTime", projectInfo.createdTime.toISO8601(true));
    xml->setAttribute("lastModifiedTime", projectInfo.lastModifiedTime.toISO8601(true));

    return xml;
}

bool SessionManager::restoreProjectInfoFromXML(const juce::XmlElement& xml)
{
    if (xml.getTagName() != "ProjectInfo")
        return false;

    projectInfo.title = xml.getStringAttribute("title", "Untitled");
    projectInfo.artist = xml.getStringAttribute("artist");
    projectInfo.description = xml.getStringAttribute("description");

    projectInfo.tempo = xml.getDoubleAttribute("tempo", 120.0);
    projectInfo.timeSignatureNumerator = xml.getIntAttribute("timeSignatureNumerator", 4);
    projectInfo.timeSignatureDenominator = xml.getIntAttribute("timeSignatureDenominator", 4);

    projectInfo.sampleRate = xml.getDoubleAttribute("sampleRate", 48000.0);
    projectInfo.blockSize = xml.getIntAttribute("blockSize", 512);

    // Parse timestamps
    juce::String createdTimeStr = xml.getStringAttribute("createdTime");
    if (createdTimeStr.isNotEmpty())
        projectInfo.createdTime = juce::Time::fromISO8601(createdTimeStr);

    juce::String modifiedTimeStr = xml.getStringAttribute("lastModifiedTime");
    if (modifiedTimeStr.isNotEmpty())
        projectInfo.lastModifiedTime = juce::Time::fromISO8601(modifiedTimeStr);

    return true;
}

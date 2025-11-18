#include "SyphonManager.h"

#if JUCE_MAC

// Syphon Framework (Objective-C++)
// Download from: https://github.com/Syphon/Syphon-Framework
// Add Syphon.framework to project
// #import <Syphon/Syphon.h>

//==============================================================================
// Syphon Implementation (Objective-C++)
//==============================================================================

struct SyphonManager::SyphonImpl
{
    // SyphonServer* server = nil;
    // SyphonClient* client = nil;
    // SyphonServerDirectory* directory = nil;

    juce::Array<SyphonServer> availableServers;
    bool isInitialized = false;

    SyphonImpl()
    {
        DBG("Syphon: Initialized (placeholder mode)");
        DBG("Syphon: To enable full Syphon support:");
        DBG("  1. Download Syphon Framework from https://github.com/Syphon/Syphon-Framework");
        DBG("  2. Add Syphon.framework to project");
        DBG("  3. Enable Objective-C++ compilation (.mm file)");
        DBG("  4. Rebuild project");
    }

    ~SyphonImpl()
    {
        cleanup();
    }

    void startDiscovery()
    {
        /*
        // Real Syphon discovery:
        directory = [SyphonServerDirectory sharedDirectory];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(serversDidChange:)
                                                     name:SyphonServerAnnounceNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(serversDidChange:)
                                                     name:SyphonServerRetireNotification
                                                   object:nil];

        NSArray* servers = [directory servers];
        // Parse servers array...
        */

        DBG("Syphon: Started discovery");

        // Simulate discovering servers
        availableServers.clear();
        availableServers.add({"Resolume Output", "Resolume", "UUID-1", true});
        availableServers.add({"VDMX Main Output", "VDMX", "UUID-2", true});
        availableServers.add({"TouchDesigner", "TouchDesigner", "UUID-3", true});
    }

    void stopDiscovery()
    {
        /*
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        directory = nil;
        */

        DBG("Syphon: Stopped discovery");
    }

    bool createServer(const juce::String& name)
    {
        /*
        // Real Syphon server creation:
        NSDictionary* options = @{};
        NSString* serverName = [NSString stringWithUTF8String:name.toRawUTF8()];

        server = [[SyphonServer alloc] initWithName:serverName
                                            context:CGLGetCurrentContext()
                                            options:options];

        if (!server)
        {
            DBG("Syphon: Failed to create server");
            return false;
        }

        DBG("Syphon: Server created - " << name);
        return true;
        */

        DBG("Syphon: Created server '" << name << "' (placeholder)");
        return true;
    }

    bool publishTexture(unsigned int textureID, int width, int height)
    {
        /*
        // Real Syphon texture publish:
        NSRect textureRegion = NSMakeRect(0, 0, width, height);
        NSSize imageSize = NSMakeSize(width, height);

        [server publishFrameTexture:textureID
                      textureTarget:GL_TEXTURE_2D
                        imageRegion:textureRegion
                  textureDimensions:imageSize
                            flipped:NO];

        return true;
        */

        // Placeholder
        return true;
    }

    bool connectToServer(const SyphonServer& serverInfo)
    {
        /*
        // Real Syphon client connection:
        NSDictionary* description = @{
            SyphonServerDescriptionUUIDKey: [NSString stringWithUTF8String:serverInfo.uuid.toRawUTF8()],
            SyphonServerDescriptionNameKey: [NSString stringWithUTF8String:serverInfo.name.toRawUTF8()],
            SyphonServerDescriptionAppNameKey: [NSString stringWithUTF8String:serverInfo.appName.toRawUTF8()]
        };

        client = [[SyphonClient alloc] initWithServerDescription:description
                                                         options:nil
                                                 newFrameHandler:^(SyphonClient *client) {
            // New frame available
        }];

        if (!client)
        {
            DBG("Syphon: Failed to connect to server");
            return false;
        }

        DBG("Syphon: Connected to " << serverInfo.name);
        return true;
        */

        DBG("Syphon: Connected to server '" << serverInfo.name << "' (placeholder)");
        return true;
    }

    unsigned int receiveTexture(int& width, int& height)
    {
        /*
        // Real Syphon texture receive:
        SyphonImage* image = [client newFrameImage];

        if (image)
        {
            width = [image textureSize].width;
            height = [image textureSize].height;
            return [image textureName];
        }

        return 0;
        */

        // Placeholder: no texture
        width = 0;
        height = 0;
        return 0;
    }

    void cleanup()
    {
        /*
        if (server)
        {
            [server stop];
            server = nil;
        }

        if (client)
        {
            [client stop];
            client = nil;
        }

        directory = nil;
        */

        DBG("Syphon: Cleaned up");
    }
};

//==============================================================================
// Constructor / Destructor
//==============================================================================

SyphonManager::SyphonManager()
{
    impl = std::make_unique<SyphonImpl>();
}

SyphonManager::~SyphonManager()
{
    closeServer();
    disconnectServer();
}

//==============================================================================
// Initialization
//==============================================================================

bool SyphonManager::isAvailable() const
{
    // Syphon is always available on macOS
    return true;
}

//==============================================================================
// Server Discovery
//==============================================================================

void SyphonManager::startDiscovery()
{
    impl->startDiscovery();
}

void SyphonManager::stopDiscovery()
{
    impl->stopDiscovery();
}

juce::Array<SyphonManager::SyphonServer> SyphonManager::getAvailableServers() const
{
    return impl->availableServers;
}

//==============================================================================
// Sender (Output)
//==============================================================================

bool SyphonManager::createServer(const juce::String& name)
{
    bool success = impl->createServer(name);
    publishing = success;
    return success;
}

bool SyphonManager::publishTexture(unsigned int textureID, int width, int height)
{
    if (!publishing)
        return false;

    bool published = impl->publishTexture(textureID, width, height);

    if (published)
    {
        currentStats.framesSent++;
    }

    return published;
}

bool SyphonManager::publishMetalTexture(void* metalTexture, int width, int height)
{
    // TODO: Implement Metal texture publishing (requires Metal-specific code)
    return false;
}

bool SyphonManager::publishImage(const juce::Image& image)
{
    if (!publishing)
        return false;

    // Upload image to OpenGL texture, then publish
    // TODO: Implement image upload to GPU

    currentStats.framesSent++;
    return true;
}

void SyphonManager::closeServer()
{
    publishing = false;
    DBG("Syphon: Server closed");
}

bool SyphonManager::isPublishing() const
{
    return publishing;
}

//==============================================================================
// Receiver (Input)
//==============================================================================

bool SyphonManager::connectToServer(const SyphonServer& server)
{
    bool success = impl->connectToServer(server);
    receiving = success;
    currentStats.isConnected = success;
    return success;
}

void SyphonManager::disconnectServer()
{
    receiving = false;
    currentStats.isConnected = false;
    DBG("Syphon: Disconnected");
}

unsigned int SyphonManager::receiveTexture(int& width, int& height)
{
    if (!receiving)
        return 0;

    unsigned int texture = impl->receiveTexture(width, height);

    if (texture != 0)
    {
        currentStats.framesReceived++;
    }

    return texture;
}

bool SyphonManager::receiveImage(juce::Image& image)
{
    if (!receiving)
        return false;

    int width, height;
    unsigned int texture = receiveTexture(width, height);

    if (texture == 0)
        return false;

    // Download texture from GPU to CPU image
    // TODO: Implement GPU -> CPU download

    image = juce::Image(juce::Image::ARGB, width, height, true);
    return true;
}

bool SyphonManager::isReceiving() const
{
    return receiving;
}

bool SyphonManager::hasNewFrame() const
{
    // TODO: Check if new frame is available
    return false;
}

//==============================================================================
// Stats
//==============================================================================

SyphonManager::Stats SyphonManager::getStats() const
{
    return currentStats;
}

#endif // JUCE_MAC

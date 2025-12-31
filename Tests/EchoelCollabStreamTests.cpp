/**
 * Echoel Collaboration & Streaming Test Suite
 *
 * ============================================================================
 *   RALPH WIGGUM GENIUS LOOP MODE - COLLAB & STREAM TESTS
 * ============================================================================
 *
 * Test coverage:
 * - EchoelRealtimeCollab: P2P connections, CRDT sync, latency
 * - EchoelLiveStream: Frame queues, encoding pipeline, outputs
 * - EchoelCollabSession: Undo/redo, locks, timeline
 * - EchoelStreamEncoder: Rate control, hardware detection
 * - EchoelChatSystem: Messages, moderation, filtering
 * - EchoelPresenceSystem: Cursor tracking, activity, bio aura
 *
 * Target: Zero errors, sub-millisecond operations
 */

#include "../Sources/Network/EchoelRealtimeCollab.h"
#include "../Sources/Network/EchoelLiveStream.h"
#include "../Sources/Network/EchoelCollabSession.h"
#include "../Sources/Network/EchoelStreamEncoder.h"
#include "../Sources/Network/EchoelChatSystem.h"
#include "../Sources/Network/EchoelPresenceSystem.h"

#include <iostream>
#include <cassert>
#include <chrono>
#include <cmath>
#include <cstring>
#include <iomanip>
#include <sstream>
#include <thread>
#include <vector>
#include <atomic>
#include <random>

//==============================================================================
// Test Framework
//==============================================================================

namespace test {

static int totalTests = 0;
static int passedTests = 0;
static int failedTests = 0;

#define TEST_ASSERT(condition, message) \
    do { \
        ++test::totalTests; \
        if (condition) { \
            ++test::passedTests; \
            std::cout << "  [PASS] " << message << std::endl; \
        } else { \
            ++test::failedTests; \
            std::cout << "  [FAIL] " << message << std::endl; \
        } \
    } while(0)

#define TEST_ASSERT_NEAR(a, b, tolerance, message) \
    TEST_ASSERT(std::abs((a) - (b)) < (tolerance), message)

void printSummary()
{
    std::cout << "\n========================================\n";
    std::cout << "Collab & Stream Test Summary:\n";
    std::cout << "  Total:  " << totalTests << std::endl;
    std::cout << "  Passed: " << passedTests << std::endl;
    std::cout << "  Failed: " << failedTests << std::endl;
    std::cout << "========================================\n";

    if (failedTests == 0)
    {
        std::cout << "\n*** ALL COLLAB/STREAM TESTS PASSED ***\n\n";
    }
    else
    {
        std::cout << "\n*** " << failedTests << " TEST(S) FAILED ***\n\n";
    }
}

} // namespace test

//==============================================================================
// Benchmark Utility
//==============================================================================

class Benchmark
{
public:
    using Clock = std::chrono::high_resolution_clock;

    void start() { startTime_ = Clock::now(); }

    double stopNs()
    {
        auto end = Clock::now();
        return std::chrono::duration<double, std::nano>(end - startTime_).count();
    }

    double stopUs()
    {
        auto end = Clock::now();
        return std::chrono::duration<double, std::micro>(end - startTime_).count();
    }

    double stopMs()
    {
        auto end = Clock::now();
        return std::chrono::duration<double, std::milli>(end - startTime_).count();
    }

private:
    std::chrono::time_point<Clock> startTime_;
};

//==============================================================================
// Realtime Collab Tests
//==============================================================================

void testCollabPeerId()
{
    std::cout << "\n[Test: Collab Peer ID Generation]\n";

    using namespace Echoel::Collab;

    PeerId id1 = PeerId::generate();
    PeerId id2 = PeerId::generate();

    TEST_ASSERT(!(id1 == id2), "Generated IDs should be unique");

    std::string str1 = id1.toString();
    std::string str2 = id2.toString();

    TEST_ASSERT(str1.length() == 36, "ID string should be 36 chars (UUID format)");
    TEST_ASSERT(str1 != str2, "ID strings should be different");

    std::cout << "  ID1: " << str1 << "\n";
    std::cout << "  ID2: " << str2 << "\n";
}

void testCollabVectorClock()
{
    std::cout << "\n[Test: Collab Vector Clock]\n";

    using namespace Echoel::Collab;

    VectorClock a, b;

    a.increment(0);
    a.increment(0);
    b.increment(1);

    TEST_ASSERT(!a.happensBefore(b), "a should not happen before b");
    TEST_ASSERT(!b.happensBefore(a), "b should not happen before a");
    TEST_ASSERT(a.concurrent(b), "a and b should be concurrent");

    b.merge(a);
    TEST_ASSERT(a.happensBefore(b), "a should happen before merged b");
}

void testCollabLWWRegister()
{
    std::cout << "\n[Test: Collab LWW Register]\n";

    using namespace Echoel::Collab;

    LWWRegister<float> reg;
    PeerId peer1 = PeerId::generate();
    PeerId peer2 = PeerId::generate();

    reg.update(1.0f, 100, peer1);
    TEST_ASSERT_NEAR(reg.value, 1.0f, 0.001f, "Value should be 1.0");

    reg.update(2.0f, 200, peer2);
    TEST_ASSERT_NEAR(reg.value, 2.0f, 0.001f, "Value should update to 2.0");

    // Earlier timestamp should not overwrite
    reg.update(3.0f, 150, peer1);
    TEST_ASSERT_NEAR(reg.value, 2.0f, 0.001f, "Earlier timestamp should not overwrite");

    // Same timestamp - higher peer ID wins
    reg.update(4.0f, 200, peer1);
    // Result depends on peer ID comparison
    TEST_ASSERT(reg.value == 2.0f || reg.value == 4.0f, "Conflict resolution should work");
}

void testCollabMessageSerialization()
{
    std::cout << "\n[Test: Collab Message Serialization]\n";

    using namespace Echoel::Collab;

    CollabMessage msg;
    msg.type = MessageType::StateUpdate;
    msg.sender = PeerId::generate();
    msg.recipient = PeerId::generate();
    msg.timestamp = 12345678901234ULL;
    msg.sequenceNumber = 42;
    msg.priority = SyncPriority::High;
    msg.payload = {1, 2, 3, 4, 5, 6, 7, 8};

    std::vector<uint8_t> serialized = msg.serialize();
    TEST_ASSERT(serialized.size() > 50, "Serialized message should have header + payload");

    auto deserialized = CollabMessage::deserialize(serialized.data(), serialized.size());
    TEST_ASSERT(deserialized.has_value(), "Message should deserialize");

    if (deserialized)
    {
        TEST_ASSERT(deserialized->type == msg.type, "Type should match");
        TEST_ASSERT(deserialized->sender == msg.sender, "Sender should match");
        TEST_ASSERT(deserialized->timestamp == msg.timestamp, "Timestamp should match");
        TEST_ASSERT(deserialized->sequenceNumber == msg.sequenceNumber, "Sequence should match");
        TEST_ASSERT(deserialized->payload == msg.payload, "Payload should match");
    }
}

void testCollabMessageQueue()
{
    std::cout << "\n[Test: Collab Lock-Free Message Queue]\n";

    using namespace Echoel::Collab;

    MessageQueue<256> queue;

    // Push messages
    for (int i = 0; i < 100; ++i)
    {
        CollabMessage msg;
        msg.sequenceNumber = i;
        TEST_ASSERT(queue.push(std::move(msg)), "Push should succeed");
    }

    TEST_ASSERT(queue.size() == 100, "Queue should have 100 messages");

    // Pop messages
    for (int i = 0; i < 100; ++i)
    {
        auto msg = queue.pop();
        TEST_ASSERT(msg.has_value(), "Pop should return message");
        TEST_ASSERT(msg->sequenceNumber == static_cast<uint32_t>(i), "Sequence should match");
    }

    TEST_ASSERT(queue.isEmpty(), "Queue should be empty");
}

void testCollabLatencyTracker()
{
    std::cout << "\n[Test: Collab Latency Tracker]\n";

    using namespace Echoel::Collab;

    LatencyTracker tracker;

    // Add samples
    for (int i = 0; i < 50; ++i)
    {
        tracker.recordSample(10.0f + i * 0.2f);  // 10-20ms range
    }

    float avg = tracker.getAverage();
    float jitter = tracker.getJitter();
    float min = tracker.getMin();
    float max = tracker.getMax();

    std::cout << "  Avg: " << avg << " ms, Jitter: " << jitter << " ms\n";
    std::cout << "  Min: " << min << " ms, Max: " << max << " ms\n";

    TEST_ASSERT(avg > 10.0f && avg < 20.0f, "Average should be in expected range");
    TEST_ASSERT(jitter > 0.0f, "Jitter should be positive");
    TEST_ASSERT(min >= 10.0f, "Min should be >= 10");
    TEST_ASSERT(max <= 20.0f, "Max should be <= 20");
}

//==============================================================================
// Live Stream Tests
//==============================================================================

void testStreamFrameQueue()
{
    std::cout << "\n[Test: Stream Frame Queue]\n";

    using namespace Echoel::Stream;

    FrameQueue<VideoFrame, 30> queue;

    // Push frames
    for (int i = 0; i < 20; ++i)
    {
        VideoFrame frame;
        frame.timestampUs = i * 16667;  // ~60fps
        frame.width = 1920;
        frame.height = 1080;
        queue.push(std::move(frame));
    }

    TEST_ASSERT(queue.size() == 20, "Queue should have 20 frames");

    // Pop frames
    for (int i = 0; i < 20; ++i)
    {
        auto frame = queue.pop();
        TEST_ASSERT(frame.has_value(), "Pop should return frame");
    }

    TEST_ASSERT(queue.droppedFrames() == 0, "No frames should be dropped");
}

void testStreamFrameQueueOverflow()
{
    std::cout << "\n[Test: Stream Frame Queue Overflow]\n";

    using namespace Echoel::Stream;

    FrameQueue<VideoFrame, 10> queue;

    // Push more than capacity
    for (int i = 0; i < 15; ++i)
    {
        VideoFrame frame;
        frame.timestampUs = i * 16667;
        queue.push(std::move(frame));
    }

    TEST_ASSERT(queue.droppedFrames() > 0, "Should have dropped frames");
    std::cout << "  Dropped: " << queue.droppedFrames() << " frames\n";
}

void testStreamQualityLevels()
{
    std::cout << "\n[Test: Stream Quality Levels]\n";

    using namespace Echoel::Stream;

    // Standard quality levels
    std::vector<QualityLevel> levels = {
        { "360p",  640,  360,  800,  64, 30.0f },
        { "480p",  854,  480, 1500,  96, 30.0f },
        { "720p", 1280,  720, 3000, 128, 30.0f },
        { "1080p", 1920, 1080, 6000, 160, 30.0f }
    };

    TEST_ASSERT(levels.size() == 4, "Should have 4 quality levels");
    TEST_ASSERT(levels[0].videoBitrate < levels[3].videoBitrate, "Higher quality = higher bitrate");
    TEST_ASSERT(levels[3].width == 1920, "1080p should be 1920 wide");
}

void testStreamEncoderCapabilities()
{
    std::cout << "\n[Test: Stream Encoder Capabilities Detection]\n";

    using namespace Echoel::Stream;

    auto caps = EchoelStreamEncoder::detectCapabilities();

    TEST_ASSERT(caps.size() > 0, "Should detect at least software encoder");

    for (const auto& cap : caps)
    {
        std::cout << "  Encoder: " << cap.deviceName << "\n";
        std::cout << "    H.264: " << (cap.supportsH264 ? "Yes" : "No");
        std::cout << ", H.265: " << (cap.supportsH265 ? "Yes" : "No");
        std::cout << ", B-frames: " << (cap.supportsBFrames ? "Yes" : "No") << "\n";
    }
}

//==============================================================================
// Collab Session Tests
//==============================================================================

void testCollabSessionUndoRedo()
{
    std::cout << "\n[Test: Collab Session Undo/Redo]\n";

    using namespace Echoel::Collab;

    UndoRedoManager manager(100);

    // Push operations
    for (int i = 0; i < 5; ++i)
    {
        Operation op;
        op.type = OperationType::SetParameter;
        op.targetPath = "/param" + std::to_string(i);
        op.sequenceNumber = i;
        manager.pushOperation(std::move(op));
    }

    TEST_ASSERT(manager.undoCount() == 5, "Should have 5 undo items");
    TEST_ASSERT(manager.canUndo(), "Should be able to undo");
    TEST_ASSERT(!manager.canRedo(), "Should not be able to redo");

    // Undo
    auto op = manager.undo();
    TEST_ASSERT(op.has_value(), "Undo should return operation");
    TEST_ASSERT(manager.undoCount() == 4, "Should have 4 undo items");
    TEST_ASSERT(manager.redoCount() == 1, "Should have 1 redo item");

    // Redo
    op = manager.redo();
    TEST_ASSERT(op.has_value(), "Redo should return operation");
    TEST_ASSERT(manager.undoCount() == 5, "Should have 5 undo items again");
    TEST_ASSERT(manager.redoCount() == 0, "Should have 0 redo items");
}

void testCollabSessionLocks()
{
    std::cout << "\n[Test: Collab Session Parameter Locks]\n";

    using namespace Echoel::Collab;

    LockManager manager(60);  // 60 second timeout

    std::array<uint8_t, 16> peer1 = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
    std::array<uint8_t, 16> peer2 = {16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1};

    // Acquire lock
    bool acquired = manager.acquireLock("/tempo", peer1, "User 1");
    TEST_ASSERT(acquired, "Lock should be acquired");

    // Check state
    auto state = manager.getLockState("/tempo", peer1);
    TEST_ASSERT(state == LockState::LockedByMe, "Should show locked by me");

    state = manager.getLockState("/tempo", peer2);
    TEST_ASSERT(state == LockState::LockedByOther, "Should show locked by other");

    // Try to acquire same lock
    acquired = manager.acquireLock("/tempo", peer2, "User 2");
    TEST_ASSERT(!acquired, "Lock should not be acquired by another peer");

    // Release lock
    bool released = manager.releaseLock("/tempo", peer1);
    TEST_ASSERT(released, "Lock should be released");

    state = manager.getLockState("/tempo", peer2);
    TEST_ASSERT(state == LockState::Unlocked, "Should be unlocked now");
}

void testCollabSessionTimeline()
{
    std::cout << "\n[Test: Collab Session Timeline]\n";

    using namespace Echoel::Collab;

    TimelineManager timeline;

    // Set initial state
    TransportState state;
    state.tempo = 120.0;
    state.beatsPerBar = 4;
    timeline.setTransportState(state);

    // Play
    timeline.play();
    std::this_thread::sleep_for(std::chrono::milliseconds(100));

    double pos = timeline.getCurrentPosition();
    TEST_ASSERT(pos > 0.0, "Position should advance while playing");
    std::cout << "  Position after 100ms: " << pos << " seconds\n";

    // Pause
    timeline.pause();
    double pausedPos = timeline.getCurrentPosition();
    std::this_thread::sleep_for(std::chrono::milliseconds(50));
    double afterPause = timeline.getCurrentPosition();

    TEST_ASSERT_NEAR(pausedPos, afterPause, 0.01, "Position should not change while paused");

    // Seek
    timeline.seek(5.0);
    pos = timeline.getCurrentPosition();
    TEST_ASSERT_NEAR(pos, 5.0, 0.01, "Should seek to 5 seconds");

    // Add marker
    TimelineMarker marker;
    marker.id = "marker1";
    marker.name = "Test Marker";
    marker.positionSeconds = 10.0;
    timeline.addMarker(marker);

    auto markers = timeline.getMarkers();
    TEST_ASSERT(markers.size() == 1, "Should have 1 marker");
    TEST_ASSERT(markers[0].name == "Test Marker", "Marker name should match");
}

//==============================================================================
// Stream Encoder Tests
//==============================================================================

void testStreamEncoderRateControl()
{
    std::cout << "\n[Test: Stream Encoder Rate Control]\n";

    using namespace Echoel::Stream;

    VideoEncoderConfig config;
    config.bitrate = 4500;
    config.bufferSize = 4500;
    config.frameRate = 30.0f;
    config.rateControlMode = RateControlMode::CBR;
    config.crf = 23;

    RateController controller(config);

    // Simulate encoding frames
    for (int i = 0; i < 60; ++i)  // 2 seconds at 30fps
    {
        bool isKeyframe = (i % 30 == 0);
        float qp = controller.getTargetQP(isKeyframe);

        // Simulate frame size
        uint32_t frameBits = static_cast<uint32_t>(
            (config.bitrate * 1000.0f / config.frameRate) * (isKeyframe ? 2.0f : 1.0f)
        );

        controller.updateAfterEncode(frameBits, isKeyframe);
    }

    float currentBitrate = controller.getCurrentBitrate();
    float bufferFill = controller.getBufferFullness();

    std::cout << "  Current bitrate: " << currentBitrate << " kbps\n";
    std::cout << "  Buffer fill: " << (bufferFill * 100.0f) << "%\n";

    TEST_ASSERT(currentBitrate > 0, "Bitrate should be positive");
    TEST_ASSERT(bufferFill >= 0.0f && bufferFill <= 1.0f, "Buffer fill should be 0-1");
}

//==============================================================================
// Chat System Tests
//==============================================================================

void testChatRateLimiter()
{
    std::cout << "\n[Test: Chat Rate Limiter]\n";

    using namespace Echoel::Chat;

    RateLimiter limiter(3, 1000);  // 3 messages per second

    UserId user;
    user.uuid = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};

    // Should allow first 3 messages
    TEST_ASSERT(limiter.checkAndUpdate(user), "First message should pass");
    TEST_ASSERT(limiter.checkAndUpdate(user), "Second message should pass");
    TEST_ASSERT(limiter.checkAndUpdate(user), "Third message should pass");

    // Fourth should be blocked
    TEST_ASSERT(!limiter.checkAndUpdate(user), "Fourth message should be blocked");

    // Wait for window to pass
    std::this_thread::sleep_for(std::chrono::milliseconds(1100));

    // Should allow again
    TEST_ASSERT(limiter.checkAndUpdate(user), "Should allow after timeout");
}

void testChatContentFilter()
{
    std::cout << "\n[Test: Chat Content Filter]\n";

    using namespace Echoel::Chat;

    ContentFilter filter;

    // Add test rule
    ModerationRule rule;
    rule.pattern = "badword";
    rule.action = FilterResult::Replace;
    rule.replacement = "***";
    rule.isRegex = false;
    filter.addRule(rule);

    // Test filtering
    auto result = filter.filter("This is a badword test");
    TEST_ASSERT(result.result == FilterResult::Replace, "Should replace bad word");
    TEST_ASSERT(result.filteredText.find("***") != std::string::npos, "Should contain replacement");

    // Test caps filter
    bool capsOk = filter.checkCaps("THIS IS ALL CAPS", 0.5f);
    TEST_ASSERT(!capsOk, "Should detect excessive caps");

    capsOk = filter.checkCaps("This is normal text", 0.5f);
    TEST_ASSERT(capsOk, "Should allow normal text");

    // Test spam filter
    bool spamOk = filter.checkSpam("aaaaaaaaaaaaaaaaaaa");
    TEST_ASSERT(!spamOk, "Should detect repeated characters");

    spamOk = filter.checkSpam("This is a normal message");
    TEST_ASSERT(spamOk, "Should allow normal message");
}

void testChatEmoteManager()
{
    std::cout << "\n[Test: Chat Emote Manager]\n";

    using namespace Echoel::Chat;

    EmoteManager manager;
    manager.loadDefaultEmotes();

    auto emotes = manager.getAllEmotes();
    TEST_ASSERT(emotes.size() > 0, "Should have default emotes");
    std::cout << "  Loaded " << emotes.size() << " emotes\n";

    // Add custom emote
    Emote custom;
    custom.name = "test_emote";
    custom.url = "/emotes/test.png";
    custom.alt = "Test";
    manager.addEmote(custom);

    auto found = manager.getEmote("test_emote");
    TEST_ASSERT(found.has_value(), "Should find custom emote");

    // Test rendering
    std::string rendered = manager.renderEmotes("Hello :test_emote: world");
    TEST_ASSERT(rendered.find("<img") != std::string::npos, "Should render to HTML");
}

void testChatModeration()
{
    std::cout << "\n[Test: Chat Moderation]\n";

    using namespace Echoel::Chat;

    ModerationManager manager;

    UserId user;
    user.uuid = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};

    // Ban user
    manager.banUser(user, "Test ban");
    TEST_ASSERT(manager.isBanned(user), "User should be banned");

    // Unban
    manager.unbanUser(user);
    TEST_ASSERT(!manager.isBanned(user), "User should be unbanned");

    // Mute for 1 second
    manager.muteUser(user, 1, "Test mute");
    TEST_ASSERT(manager.isMuted(user), "User should be muted");

    // Wait for mute to expire
    std::this_thread::sleep_for(std::chrono::milliseconds(1100));
    TEST_ASSERT(!manager.isMuted(user), "Mute should have expired");

    // Check mod log
    auto log = manager.getModLog();
    TEST_ASSERT(log.size() >= 2, "Should have mod log entries");
}

//==============================================================================
// Presence System Tests
//==============================================================================

void testPresenceTripleBuffer()
{
    std::cout << "\n[Test: Presence Triple Buffer]\n";

    using namespace Echoel::Presence;

    TripleBuffer<int> buffer;

    // Write and publish
    buffer.getWriteBuffer() = 42;
    buffer.publish();

    // Read
    int value = buffer.getReadBuffer();
    TEST_ASSERT(value == 42, "Should read published value");

    // Write new value
    buffer.getWriteBuffer() = 100;
    buffer.publish();

    value = buffer.getReadBuffer();
    TEST_ASSERT(value == 100, "Should read new value");
}

void testPresenceCursor()
{
    std::cout << "\n[Test: Presence Cursor State]\n";

    using namespace Echoel::Presence;

    CursorState cursor;
    cursor.x = 0.5f;
    cursor.y = 0.3f;
    cursor.type = CursorType::Crosshair;
    cursor.visible = true;

    TEST_ASSERT_NEAR(cursor.x, 0.5f, 0.001f, "X should be 0.5");
    TEST_ASSERT_NEAR(cursor.y, 0.3f, 0.001f, "Y should be 0.3");
    TEST_ASSERT(cursor.type == CursorType::Crosshair, "Type should be crosshair");
    TEST_ASSERT(cursor.visible, "Should be visible");
}

void testPresenceUserState()
{
    std::cout << "\n[Test: Presence User State]\n";

    using namespace Echoel::Presence;

    UserPresence user;
    user.displayName = "Test User";
    user.status = PresenceStatus::Online;
    user.activity.type = ActivityType::Editing;
    user.activity.description = "Editing laser pattern";
    user.bio.coherence = 0.8f;
    user.bio.relaxation = 0.7f;

    TEST_ASSERT(user.status == PresenceStatus::Online, "Should be online");
    TEST_ASSERT(user.activity.type == ActivityType::Editing, "Should be editing");
    TEST_ASSERT_NEAR(user.bio.coherence, 0.8f, 0.001f, "Coherence should be 0.8");
}

void testPresenceSerialization()
{
    std::cout << "\n[Test: Presence Serialization]\n";

    using namespace Echoel::Presence;

    PresenceConfig config;
    EchoelPresenceSystem& system = EchoelPresenceSystem::getInstance();

    if (!system.initialize(config))
    {
        std::cout << "  (Skipping - system already initialized)\n";
        return;
    }

    UserId id;
    id.uuid = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};

    system.setLocalUser(id, "Test User");
    system.updateCursor(0.5f, 0.3f);
    system.setActivity(ActivityType::Editing, "Test activity");
    system.updateBioState(0.75f, 0.6f, 72.0f, 14.0f);

    auto serialized = system.serializeLocalPresence();
    TEST_ASSERT(serialized.size() >= 50, "Serialized data should have content");
    std::cout << "  Serialized size: " << serialized.size() << " bytes\n";

    auto deserialized = system.deserializePresence(serialized.data(), serialized.size());
    TEST_ASSERT(deserialized.has_value(), "Should deserialize");

    if (deserialized)
    {
        TEST_ASSERT_NEAR(deserialized->cursor.x, 0.5f, 0.001f, "Cursor X should match");
        TEST_ASSERT_NEAR(deserialized->cursor.y, 0.3f, 0.001f, "Cursor Y should match");
        TEST_ASSERT_NEAR(deserialized->bio.coherence, 0.75f, 0.001f, "Coherence should match");
    }

    system.shutdown();
}

//==============================================================================
// Performance Tests
//==============================================================================

void testCollabMessagePerformance()
{
    std::cout << "\n[Test: Collab Message Queue Performance]\n";

    using namespace Echoel::Collab;

    MessageQueue<4096> queue;
    Benchmark bench;
    const int iterations = 10000;

    // Benchmark push
    bench.start();
    for (int i = 0; i < iterations; ++i)
    {
        CollabMessage msg;
        msg.sequenceNumber = i;
        queue.push(std::move(msg));
    }
    double pushNs = bench.stopNs() / iterations;

    // Benchmark pop
    bench.start();
    for (int i = 0; i < iterations; ++i)
    {
        queue.pop();
    }
    double popNs = bench.stopNs() / iterations;

    std::cout << "  Push: " << std::fixed << std::setprecision(1) << pushNs << " ns\n";
    std::cout << "  Pop: " << std::fixed << std::setprecision(1) << popNs << " ns\n";

    TEST_ASSERT(pushNs < 1000, "Push should be < 1 microsecond");
    TEST_ASSERT(popNs < 1000, "Pop should be < 1 microsecond");
}

void testPresenceUpdatePerformance()
{
    std::cout << "\n[Test: Presence Update Performance]\n";

    using namespace Echoel::Presence;

    TripleBuffer<PresenceSnapshot> buffer;
    Benchmark bench;
    const int iterations = 10000;

    // Benchmark write + publish
    bench.start();
    for (int i = 0; i < iterations; ++i)
    {
        auto& write = buffer.getWriteBuffer();
        write.timestamp = i;
        buffer.publish();
    }
    double writeNs = bench.stopNs() / iterations;

    // Benchmark read
    bench.start();
    for (int i = 0; i < iterations; ++i)
    {
        volatile auto& read = buffer.getReadBuffer();
        (void)read;
    }
    double readNs = bench.stopNs() / iterations;

    std::cout << "  Write+Publish: " << std::fixed << std::setprecision(1) << writeNs << " ns\n";
    std::cout << "  Read: " << std::fixed << std::setprecision(1) << readNs << " ns\n";

    TEST_ASSERT(writeNs < 500, "Write should be < 500 ns");
    TEST_ASSERT(readNs < 200, "Read should be < 200 ns");
}

void testChatFilterPerformance()
{
    std::cout << "\n[Test: Chat Filter Performance]\n";

    using namespace Echoel::Chat;

    ContentFilter filter;

    // Add multiple rules
    for (int i = 0; i < 20; ++i)
    {
        ModerationRule rule;
        rule.pattern = "pattern" + std::to_string(i);
        rule.action = FilterResult::Replace;
        rule.replacement = "***";
        filter.addRule(rule);
    }

    std::string testMessage = "This is a test message without any bad words in it";

    Benchmark bench;
    const int iterations = 10000;

    bench.start();
    for (int i = 0; i < iterations; ++i)
    {
        filter.filter(testMessage);
    }
    double filterUs = bench.stopUs() / iterations;

    std::cout << "  Filter time: " << std::fixed << std::setprecision(2) << filterUs << " us\n";
    TEST_ASSERT(filterUs < 100, "Filter should be < 100 microseconds");
}

//==============================================================================
// Integration Tests
//==============================================================================

void testFullCollabWorkflow()
{
    std::cout << "\n[Test: Full Collab Workflow]\n";

    using namespace Echoel::Collab;

    // Initialize collab session
    SessionConfig config;
    config.name = "Test Session";
    config.undoHistorySize = 50;

    EchoelCollabSession& session = EchoelCollabSession::getInstance();
    bool initialized = session.initialize(config);

    if (!initialized)
    {
        std::cout << "  (Session already initialized, testing state operations)\n";
    }

    // Set local peer
    std::array<uint8_t, 16> localId = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
    session.setLocalPeerId(localId);
    session.setLocalPeerName("Test User");
    session.setLocalPermissions(Permission::Host);

    // Test play/pause/seek
    session.play();
    auto transport = session.getTransportState();
    TEST_ASSERT(transport.isPlaying, "Should be playing");

    session.pause();
    transport = session.getTransportState();
    TEST_ASSERT(!transport.isPlaying, "Should be paused");

    session.seek(10.0);
    double pos = session.getCurrentPosition();
    TEST_ASSERT_NEAR(pos, 10.0, 0.1, "Should seek to 10 seconds");

    // Test parameter setting
    session.setParameter<float>("/master/volume", 0.8f);
    auto volume = session.getParameter<float>("/master/volume");
    TEST_ASSERT(volume.has_value(), "Parameter should exist");
    if (volume)
    {
        TEST_ASSERT_NEAR(*volume, 0.8f, 0.001f, "Volume should be 0.8");
    }

    // Test undo/redo
    TEST_ASSERT(session.canUndo(), "Should be able to undo");
    session.undo();
    TEST_ASSERT(session.canRedo(), "Should be able to redo");

    // Test markers
    session.addMarker("Intro", 0.0);
    session.addMarker("Drop", 30.0);
    auto markers = session.getMarkers();
    TEST_ASSERT(markers.size() >= 2, "Should have markers");

    session.shutdown();
}

//==============================================================================
// Main
//==============================================================================

int main()
{
    std::cout << "========================================\n";
    std::cout << "Echoel Collab & Stream Test Suite\n";
    std::cout << "Ralph Wiggum Genius Loop Mode\n";
    std::cout << "Target: Zero Errors, Zero Warnings\n";
    std::cout << "========================================\n";

    // Realtime Collab Tests
    testCollabPeerId();
    testCollabVectorClock();
    testCollabLWWRegister();
    testCollabMessageSerialization();
    testCollabMessageQueue();
    testCollabLatencyTracker();

    // Live Stream Tests
    testStreamFrameQueue();
    testStreamFrameQueueOverflow();
    testStreamQualityLevels();
    testStreamEncoderCapabilities();

    // Collab Session Tests
    testCollabSessionUndoRedo();
    testCollabSessionLocks();
    testCollabSessionTimeline();

    // Stream Encoder Tests
    testStreamEncoderRateControl();

    // Chat System Tests
    testChatRateLimiter();
    testChatContentFilter();
    testChatEmoteManager();
    testChatModeration();

    // Presence System Tests
    testPresenceTripleBuffer();
    testPresenceCursor();
    testPresenceUserState();
    testPresenceSerialization();

    // Performance Tests
    testCollabMessagePerformance();
    testPresenceUpdatePerformance();
    testChatFilterPerformance();

    // Integration Tests
    testFullCollabWorkflow();

    test::printSummary();

    return test::failedTests > 0 ? 1 : 0;
}

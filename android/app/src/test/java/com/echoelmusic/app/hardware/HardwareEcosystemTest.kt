package com.echoelmusic.app.hardware

import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for HardwareEcosystem
 * Tests device registries, capabilities, and session management
 */
class HardwareEcosystemTest {

    // MARK: - Ecosystem Status Tests

    @Test
    fun testAllEcosystemStatuses() {
        val statuses = EcosystemStatus.values()
        assertEquals(5, statuses.size)

        assertTrue(statuses.contains(EcosystemStatus.INITIALIZING))
        assertTrue(statuses.contains(EcosystemStatus.READY))
        assertTrue(statuses.contains(EcosystemStatus.SCANNING))
        assertTrue(statuses.contains(EcosystemStatus.CONNECTED))
        assertTrue(statuses.contains(EcosystemStatus.ERROR))
    }

    @Test
    fun testEcosystemStatusDisplayNames() {
        assertEquals("Initializing", EcosystemStatus.INITIALIZING.displayName)
        assertEquals("Ready", EcosystemStatus.READY.displayName)
        assertEquals("Scanning", EcosystemStatus.SCANNING.displayName)
        assertEquals("Connected", EcosystemStatus.CONNECTED.displayName)
        assertEquals("Error", EcosystemStatus.ERROR.displayName)
    }

    // MARK: - Device Type Tests

    @Test
    fun testAllDeviceTypes() {
        val types = DeviceType.values()
        assertTrue("Should have 30+ device types", types.size >= 30)
    }

    @Test
    fun testMobileDeviceTypes() {
        assertTrue(DeviceType.values().contains(DeviceType.ANDROID_PHONE))
        assertTrue(DeviceType.values().contains(DeviceType.ANDROID_TABLET))
        assertTrue(DeviceType.values().contains(DeviceType.IPHONE))
        assertTrue(DeviceType.values().contains(DeviceType.IPAD))
    }

    @Test
    fun testAudioDeviceTypes() {
        assertTrue(DeviceType.values().contains(DeviceType.AUDIO_INTERFACE))
        assertTrue(DeviceType.values().contains(DeviceType.MIDI_CONTROLLER))
        assertTrue(DeviceType.values().contains(DeviceType.SYNTHESIZER))
        assertTrue(DeviceType.values().contains(DeviceType.DRUM_MACHINE))
    }

    @Test
    fun testVideoLightingDeviceTypes() {
        assertTrue(DeviceType.values().contains(DeviceType.VIDEO_SWITCHER))
        assertTrue(DeviceType.values().contains(DeviceType.CAMERA))
        assertTrue(DeviceType.values().contains(DeviceType.DMX_CONTROLLER))
        assertTrue(DeviceType.values().contains(DeviceType.LIGHT_FIXTURE))
        assertTrue(DeviceType.values().contains(DeviceType.LED_STRIP))
        assertTrue(DeviceType.values().contains(DeviceType.LASER))
    }

    @Test
    fun testVRARDeviceTypes() {
        assertTrue(DeviceType.values().contains(DeviceType.META_QUEST))
        assertTrue(DeviceType.values().contains(DeviceType.PICO))
        assertTrue(DeviceType.values().contains(DeviceType.HTC_VIVE))
        assertTrue(DeviceType.values().contains(DeviceType.VISION_PRO))
    }

    @Test
    fun testWearableDeviceTypes() {
        assertTrue(DeviceType.values().contains(DeviceType.WEAR_OS))
        assertTrue(DeviceType.values().contains(DeviceType.APPLE_WATCH))
        assertTrue(DeviceType.values().contains(DeviceType.GALAXY_WATCH))
        assertTrue(DeviceType.values().contains(DeviceType.FITBIT))
        assertTrue(DeviceType.values().contains(DeviceType.GARMIN))
    }

    // MARK: - Device Platform Tests

    @Test
    fun testAllPlatforms() {
        val platforms = DevicePlatform.values()
        assertTrue("Should have 12 platforms", platforms.size >= 12)
    }

    @Test
    fun testPlatformDisplayNames() {
        assertEquals("Android", DevicePlatform.ANDROID.displayName)
        assertEquals("iOS", DevicePlatform.IOS.displayName)
        assertEquals("macOS", DevicePlatform.MACOS.displayName)
        assertEquals("Windows", DevicePlatform.WINDOWS.displayName)
        assertEquals("Linux", DevicePlatform.LINUX.displayName)
        assertEquals("visionOS", DevicePlatform.VISION_OS.displayName)
    }

    // MARK: - Connection Type Tests

    @Test
    fun testAllConnectionTypes() {
        val types = ConnectionType.values()
        assertTrue("Should have 14 connection types", types.size >= 14)
    }

    @Test
    fun testConnectionTypeDisplayNames() {
        assertEquals("USB", ConnectionType.USB.displayName)
        assertEquals("USB-C", ConnectionType.USB_C.displayName)
        assertEquals("Bluetooth", ConnectionType.BLUETOOTH.displayName)
        assertEquals("Wi-Fi", ConnectionType.WIFI.displayName)
        assertEquals("Art-Net", ConnectionType.ART_NET.displayName)
        assertEquals("NDI", ConnectionType.NDI.displayName)
    }

    // MARK: - Device Capability Tests

    @Test
    fun testAllCapabilities() {
        val capabilities = DeviceCapability.values()
        assertTrue("Should have 25+ capabilities", capabilities.size >= 25)
    }

    @Test
    fun testAudioCapabilities() {
        assertTrue(DeviceCapability.values().contains(DeviceCapability.AUDIO_INPUT))
        assertTrue(DeviceCapability.values().contains(DeviceCapability.AUDIO_OUTPUT))
        assertTrue(DeviceCapability.values().contains(DeviceCapability.MIDI_IN))
        assertTrue(DeviceCapability.values().contains(DeviceCapability.MIDI_OUT))
        assertTrue(DeviceCapability.values().contains(DeviceCapability.LOW_LATENCY))
        assertTrue(DeviceCapability.values().contains(DeviceCapability.MULTI_CHANNEL))
    }

    @Test
    fun testBioCapabilities() {
        assertTrue(DeviceCapability.values().contains(DeviceCapability.HEART_RATE))
        assertTrue(DeviceCapability.values().contains(DeviceCapability.HRV))
        assertTrue(DeviceCapability.values().contains(DeviceCapability.SPO2))
        assertTrue(DeviceCapability.values().contains(DeviceCapability.BREATHING))
    }

    @Test
    fun testSpatialCapabilities() {
        assertTrue(DeviceCapability.values().contains(DeviceCapability.SPATIAL_AUDIO))
        assertTrue(DeviceCapability.values().contains(DeviceCapability.HEAD_TRACKING))
        assertTrue(DeviceCapability.values().contains(DeviceCapability.HAND_TRACKING))
        assertTrue(DeviceCapability.values().contains(DeviceCapability.EYE_TRACKING))
    }

    // MARK: - Audio Interface Registry Tests

    @Test
    fun testAudioInterfaceRegistryCount() {
        val registry = AudioInterfaceRegistry()
        assertTrue("Should have 15+ audio interfaces", registry.devices.size >= 15)
    }

    @Test
    fun testAudioInterfaceManufacturers() {
        val registry = AudioInterfaceRegistry()
        val manufacturers = registry.devices.map { it.manufacturer }.toSet()

        assertTrue(manufacturers.contains("universal_audio"))
        assertTrue(manufacturers.contains("focusrite"))
        assertTrue(manufacturers.contains("rme"))
        assertTrue(manufacturers.contains("motu"))
        assertTrue(manufacturers.contains("apogee"))
        assertTrue(manufacturers.contains("presonus"))
        assertTrue(manufacturers.contains("ssl"))
        assertTrue(manufacturers.contains("audient"))
    }

    @Test
    fun testGetByManufacturerAudio() {
        val registry = AudioInterfaceRegistry()

        val focusrite = registry.getByManufacturer("focusrite")
        assertTrue("Should have 4+ Focusrite devices", focusrite.size >= 4)

        val rme = registry.getByManufacturer("rme")
        assertTrue("Should have 3+ RME devices", rme.size >= 3)
    }

    @Test
    fun testAudioInterfaceCapabilities() {
        val registry = AudioInterfaceRegistry()
        val apolloTwin = registry.devices.find { it.name.contains("Apollo Twin") }

        assertNotNull(apolloTwin)
        assertTrue(apolloTwin!!.capabilities.contains(DeviceCapability.AUDIO_INPUT))
        assertTrue(apolloTwin.capabilities.contains(DeviceCapability.AUDIO_OUTPUT))
        assertTrue(apolloTwin.capabilities.contains(DeviceCapability.LOW_LATENCY))
    }

    // MARK: - MIDI Controller Registry Tests

    @Test
    fun testMIDIControllerRegistryCount() {
        val registry = MIDIControllerRegistry()
        assertTrue("Should have 15+ MIDI controllers", registry.devices.size >= 15)
    }

    @Test
    fun testMIDIControllerManufacturers() {
        val registry = MIDIControllerRegistry()
        val manufacturers = registry.devices.map { it.manufacturer }.toSet()

        assertTrue(manufacturers.contains("ableton"))
        assertTrue(manufacturers.contains("native_instruments"))
        assertTrue(manufacturers.contains("akai"))
        assertTrue(manufacturers.contains("novation"))
        assertTrue(manufacturers.contains("arturia"))
        assertTrue(manufacturers.contains("roland"))
        assertTrue(manufacturers.contains("korg"))
    }

    @Test
    fun testPush3Capabilities() {
        val registry = MIDIControllerRegistry()
        val push3 = registry.devices.find { it.name.contains("Push 3") }

        assertNotNull(push3)
        assertTrue(push3!!.capabilities.contains(DeviceCapability.MIDI_IN))
        assertTrue(push3.capabilities.contains(DeviceCapability.MIDI_OUT))
        assertTrue(push3.capabilities.contains(DeviceCapability.PADS))
        assertTrue(push3.capabilities.contains(DeviceCapability.ENCODERS))
        assertTrue(push3.capabilities.contains(DeviceCapability.DISPLAY))
    }

    // MARK: - Lighting Hardware Registry Tests

    @Test
    fun testLightingRegistryCount() {
        val registry = LightingHardwareRegistry()
        assertTrue("Should have 10+ lighting devices", registry.devices.size >= 10)
    }

    @Test
    fun testDMXDevices() {
        val registry = LightingHardwareRegistry()
        val dmxDevices = registry.devices.filter {
            it.capabilities.contains(DeviceCapability.DMX_OUTPUT)
        }

        assertTrue("Should have 5+ DMX devices", dmxDevices.size >= 5)
    }

    @Test
    fun testArtNetDevices() {
        val registry = LightingHardwareRegistry()
        val artNetDevices = registry.devices.filter {
            it.capabilities.contains(DeviceCapability.ART_NET)
        }

        assertTrue("Should have 3+ Art-Net devices", artNetDevices.size >= 3)
    }

    // MARK: - Video Hardware Registry Tests

    @Test
    fun testVideoRegistryCount() {
        val registry = VideoHardwareRegistry()
        assertTrue("Should have 8+ video devices", registry.devices.size >= 8)
    }

    @Test
    fun testBlackmagicDevices() {
        val registry = VideoHardwareRegistry()
        val blackmagic = registry.devices.filter { it.manufacturer == "blackmagic" }

        assertTrue("Should have 4+ Blackmagic devices", blackmagic.size >= 4)
    }

    @Test
    fun testNDICapableDevices() {
        val registry = VideoHardwareRegistry()
        val ndiDevices = registry.devices.filter {
            it.capabilities.contains(DeviceCapability.NDI)
        }

        assertTrue("Should have 2+ NDI devices", ndiDevices.size >= 2)
    }

    // MARK: - Wearable Registry Tests

    @Test
    fun testWearableRegistryCount() {
        val registry = WearableDeviceRegistry()
        assertTrue("Should have 10+ wearable devices", registry.devices.size >= 10)
    }

    @Test
    fun testWearableHRVCapability() {
        val registry = WearableDeviceRegistry()
        val hrvDevices = registry.devices.filter {
            it.capabilities.contains(DeviceCapability.HRV)
        }

        assertTrue("Should have 8+ HRV capable devices", hrvDevices.size >= 8)
    }

    @Test
    fun testWearableManufacturers() {
        val registry = WearableDeviceRegistry()
        val manufacturers = registry.devices.map { it.manufacturer }.toSet()

        assertTrue(manufacturers.contains("samsung"))
        assertTrue(manufacturers.contains("google"))
        assertTrue(manufacturers.contains("fitbit"))
        assertTrue(manufacturers.contains("garmin"))
        assertTrue(manufacturers.contains("polar"))
        assertTrue(manufacturers.contains("whoop"))
        assertTrue(manufacturers.contains("oura"))
    }

    // MARK: - VR/AR Registry Tests

    @Test
    fun testVRARRegistryCount() {
        val registry = VRARDeviceRegistry()
        assertTrue("Should have 7+ VR/AR devices", registry.devices.size >= 7)
    }

    @Test
    fun testMetaQuestCapabilities() {
        val registry = VRARDeviceRegistry()
        val quest3 = registry.devices.find { it.name.contains("Quest 3") }

        assertNotNull(quest3)
        assertTrue(quest3!!.capabilities.contains(DeviceCapability.SPATIAL_AUDIO))
        assertTrue(quest3.capabilities.contains(DeviceCapability.HEAD_TRACKING))
        assertTrue(quest3.capabilities.contains(DeviceCapability.HAND_TRACKING))
        assertTrue(quest3.capabilities.contains(DeviceCapability.EYE_TRACKING))
    }

    // MARK: - Connected Device Tests

    @Test
    fun testConnectedDeviceCreation() {
        val device = ConnectedDevice(
            name = "Test Device",
            type = DeviceType.AUDIO_INTERFACE,
            platform = DevicePlatform.ANDROID,
            connectionType = ConnectionType.USB,
            capabilities = setOf(DeviceCapability.AUDIO_INPUT, DeviceCapability.AUDIO_OUTPUT),
            isActive = true,
            latencyMs = 5.0
        )

        assertEquals("Test Device", device.name)
        assertEquals(DeviceType.AUDIO_INTERFACE, device.type)
        assertEquals(DevicePlatform.ANDROID, device.platform)
        assertEquals(ConnectionType.USB, device.connectionType)
        assertEquals(2, device.capabilities.size)
        assertTrue(device.isActive)
        assertEquals(5.0, device.latencyMs, 0.01)
    }

    @Test
    fun testConnectedDeviceDefaultId() {
        val device = ConnectedDevice(
            name = "Test",
            type = DeviceType.MIDI_CONTROLLER,
            platform = DevicePlatform.ANDROID,
            connectionType = ConnectionType.USB,
            capabilities = setOf(DeviceCapability.MIDI_IN)
        )

        assertNotNull(device.id)
        assertTrue(device.id.isNotEmpty())
    }

    // MARK: - Multi-Device Session Tests

    @Test
    fun testMultiDeviceSessionCreation() {
        val devices = listOf(
            ConnectedDevice(
                name = "Interface",
                type = DeviceType.AUDIO_INTERFACE,
                platform = DevicePlatform.ANDROID,
                connectionType = ConnectionType.USB,
                capabilities = setOf(DeviceCapability.AUDIO_OUTPUT)
            ),
            ConnectedDevice(
                name = "Controller",
                type = DeviceType.MIDI_CONTROLLER,
                platform = DevicePlatform.ANDROID,
                connectionType = ConnectionType.USB,
                capabilities = setOf(DeviceCapability.MIDI_IN)
            )
        )

        val session = MultiDeviceSession(
            id = "test-session",
            name = "Studio Session",
            devices = devices,
            isActive = true
        )

        assertEquals("test-session", session.id)
        assertEquals("Studio Session", session.name)
        assertEquals(2, session.devices.size)
        assertTrue(session.isActive)
        assertTrue(session.createdAt > 0)
    }

    // MARK: - Supported Device Tests

    @Test
    fun testSupportedDeviceCreation() {
        val device = SupportedDevice(
            name = "Test Interface",
            manufacturer = "test_mfg",
            capabilities = setOf(DeviceCapability.AUDIO_INPUT, DeviceCapability.LOW_LATENCY)
        )

        assertEquals("Test Interface", device.name)
        assertEquals("test_mfg", device.manufacturer)
        assertEquals(2, device.capabilities.size)
    }

    // MARK: - Performance Tests

    @Test
    fun testRegistryLookupPerformance() {
        val startTime = System.nanoTime()

        repeat(10000) {
            AudioInterfaceRegistry().devices
            MIDIControllerRegistry().devices
            LightingHardwareRegistry().devices
        }

        val elapsed = (System.nanoTime() - startTime) / 1_000_000.0
        assertTrue("Registry lookup should be fast: ${elapsed}ms", elapsed < 500)
    }

    @Test
    fun testDeviceFilterPerformance() {
        val registry = AudioInterfaceRegistry()
        val startTime = System.nanoTime()

        repeat(10000) {
            registry.getByManufacturer("focusrite")
        }

        val elapsed = (System.nanoTime() - startTime) / 1_000_000.0
        assertTrue("Filter should be fast: ${elapsed}ms", elapsed < 100)
    }
}

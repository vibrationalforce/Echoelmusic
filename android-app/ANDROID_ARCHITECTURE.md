# 🤖 ECHOELMUSIC ANDROID APP - ARCHITECTURE

**Platform:** Android 8.0+ (API 26+)
**Language:** Kotlin
**UI Framework:** Jetpack Compose
**Architecture:** MVVM + Clean Architecture

---

## 📱 PROJECT STRUCTURE

```
android-app/
├── app/
│   ├── src/main/
│   │   ├── kotlin/com/echoelmusic/
│   │   │   ├── EchoelmusicApp.kt
│   │   │   ├── ui/
│   │   │   │   ├── theme/
│   │   │   │   ├── screens/
│   │   │   │   │   ├── timeline/
│   │   │   │   │   ├── mixer/
│   │   │   │   │   ├── video/
│   │   │   │   │   └── export/
│   │   │   │   └── components/
│   │   │   ├── domain/
│   │   │   │   ├── models/
│   │   │   │   ├── usecases/
│   │   │   │   └── repository/
│   │   │   ├── data/
│   │   │   │   ├── audio/
│   │   │   │   │   ├── AudioEngine.kt
│   │   │   │   │   ├── AudioRenderer.kt
│   │   │   │   │   └── PluginHost.kt
│   │   │   │   ├── video/
│   │   │   │   │   ├── VideoEngine.kt
│   │   │   │   │   └── VideoCompositor.kt
│   │   │   │   ├── ai/
│   │   │   │   │   ├── PatternRecognition.kt
│   │   │   │   │   ├── CompositionTools.kt
│   │   │   │   │   └── AutoMastering.kt
│   │   │   │   ├── biofeedback/
│   │   │   │   │   ├── BioReactiveEngine.kt
│   │   │   │   │   ├── CameraHRV.kt
│   │   │   │   │   └── WearablesManager.kt
│   │   │   │   └── export/
│   │   │   │       └── SocialMediaExporter.kt
│   │   │   └── devices/
│   │   │       ├── DeviceOrchestrator.kt
│   │   │       ├── WearOSCompanion.kt
│   │   │       ├── AndroidTVRemote.kt
│   │   │       └── AndroidAutoIntegration.kt
│   │   └── res/
│   │       ├── layout/
│   │       ├── values/
│   │       └── drawable/
│   └── build.gradle.kts
├── wear/
│   └── src/main/kotlin/com/echoelmusic/wear/
│       └── EchoelmusicWearApp.kt
├── tv/
│   └── src/main/kotlin/com/echoelmusic/tv/
│       └── EchoelmusicTVApp.kt
└── automotive/
    └── src/main/kotlin/com/echoelmusic/auto/
        └── EchoelmusicAutoApp.kt
```

---

## 🎯 CORE FEATURES

### Audio Engine
- **Oboe Library** - Low-latency audio (AAudio/OpenSL ES)
- **Sample-accurate timing** - 48kHz, 256-sample buffer
- **MIDI 2.0 Support** - Via AMidi API
- **Plugin Host** - VST3, CLAP via native code

### Video Engine
- **MediaCodec API** - Hardware-accelerated encoding/decoding
- **OpenGL ES 3.0** - GPU-accelerated effects
- **ExoPlayer** - Professional video playback
- **CameraX** - Modern camera API for HRV detection

### AI/ML
- **TensorFlow Lite** - On-device AI inference
- **ONNX Runtime** - Cross-platform ML models
- **ML Kit** - Google's ML services

### Biofeedback
- **Camera2 API** - PPG-based heart rate detection
- **Health Connect** - Universal health data API
- **Wear OS Sync** - Real-time biometric streaming
- **Bluetooth LE** - Direct wearable connection

---

## 🔗 ANDROID ECOSYSTEM INTEGRATION

### 1. Wear OS (Smartwatches)
**Supported Devices:**
- Samsung Galaxy Watch 4/5/6
- Google Pixel Watch
- Fossil Gen 6
- TicWatch Pro 3/4/5
- Montblanc Summit 3

**Features:**
- Transport control (Play/Stop/Record)
- Heart rate monitoring (Health Services API)
- Tap tempo
- Track arming
- Effects control

### 2. Android TV
**Supported Devices:**
- Google Chromecast with Google TV
- Nvidia Shield TV
- Sony Bravia
- Samsung Smart TVs (Android TV)

**Features:**
- Large-screen mixing interface
- Remote control navigation
- Voice commands (Google Assistant)
- 4K video preview

### 3. Android Auto
**Use Cases:**
- Voice recording while driving
- Audio playback
- Hands-free control
- Smart Assistant integration

### 4. Tablets & Foldables
- **Samsung Galaxy Tab S9/S9+/S9 Ultra**
- **Google Pixel Tablet**
- **Samsung Galaxy Z Fold 5**
- Multi-window support
- S Pen integration (Samsung)
- Desktop mode (Samsung DeX)

---

## 🎨 UI/UX (Jetpack Compose)

### Material Design 3
```kotlin
@Composable
fun EchoelmusicTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context)
            else dynamicLightColorScheme(context)
        }
        darkTheme -> EchoelDarkColors
        else -> EchoelLightColors
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = EchoelTypography,
        content = content
    )
}
```

### Adaptive Layouts
- **Phone:** Single-pane vertical layout
- **Tablet:** Multi-pane horizontal layout
- **Foldable:** Dual-screen support
- **Desktop Mode:** Window management

---

## 🔊 AUDIO ARCHITECTURE

### Oboe Low-Latency Audio
```kotlin
class AudioEngine {
    private lateinit var audioStream: AudioStream

    fun initialize() {
        audioStream = AudioStreamBuilder()
            .setDirection(Direction.Output)
            .setPerformanceMode(PerformanceMode.LowLatency)
            .setSharingMode(SharingMode.Exclusive)
            .setFormat(AudioFormat.Float)
            .setChannelCount(2)
            .setSampleRate(48000)
            .setBufferCapacityInFrames(256)
            .setCallback(AudioCallback())
            .build()
    }

    inner class AudioCallback : AudioStreamCallback {
        override fun onAudioReady(
            audioStream: AudioStream,
            audioData: FloatArray,
            numFrames: Int
        ): DataCallbackResult {
            // Render audio (mix all tracks)
            renderAudio(audioData, numFrames)
            return DataCallbackResult.Continue
        }
    }
}
```

---

## 📹 VIDEO ARCHITECTURE

### MediaCodec Hardware Encoding
```kotlin
class VideoEngine {
    private lateinit var mediaCodec: MediaCodec
    private lateinit var mediaMuxer: MediaMuxer

    fun exportVideo(
        timeline: Timeline,
        outputPath: String,
        resolution: Resolution,
        fps: Int = 60
    ) {
        // Initialize codec
        val format = MediaFormat.createVideoFormat(
            MediaFormat.MIMETYPE_VIDEO_AVC,
            resolution.width,
            resolution.height
        ).apply {
            setInteger(MediaFormat.KEY_BIT_RATE, 10_000_000)
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }

        mediaCodec = MediaCodec.createEncoderByType(
            MediaFormat.MIMETYPE_VIDEO_AVC
        )
        mediaCodec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)

        // Create input surface for OpenGL rendering
        val inputSurface = mediaCodec.createInputSurface()

        // Render frames with OpenGL ES
        renderFrames(inputSurface, timeline, resolution, fps)
    }
}
```

---

## 🤖 AI/ML ARCHITECTURE

### TensorFlow Lite Integration
```kotlin
class PatternRecognition {
    private lateinit var chordDetector: Interpreter
    private lateinit var keyDetector: Interpreter

    fun initialize(context: Context) {
        // Load TFLite models
        chordDetector = Interpreter(
            loadModelFile(context, "chord_detection.tflite")
        )
        keyDetector = Interpreter(
            loadModelFile(context, "key_detection.tflite")
        )
    }

    fun detectChord(audioBuffer: FloatArray): Chord {
        // Prepare input
        val input = Array(1) { FloatArray(2048) }
        audioBuffer.copyInto(input[0])

        // Run inference
        val output = Array(1) { FloatArray(24) } // 24 chord types
        chordDetector.run(input, output)

        // Parse output
        val chordIndex = output[0].indices.maxByOrNull { output[0][it] } ?: 0
        return Chord.fromIndex(chordIndex)
    }
}
```

---

## 💓 BIOFEEDBACK ARCHITECTURE

### Camera-Based HRV (PPG)
```kotlin
class CameraHRVDetector(private val context: Context) {
    private lateinit var camera: Camera
    private val ppgProcessor = PPGProcessor()

    fun startDetection(callback: (HeartRate) -> Unit) {
        val cameraProvider = ProcessCameraProvider.getInstance(context).get()

        val preview = Preview.Builder().build()
        val imageAnalysis = ImageAnalysis.Builder()
            .setTargetResolution(Size(64, 64))
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()

        imageAnalysis.setAnalyzer(Executors.newSingleThreadExecutor()) { image ->
            // Extract red channel intensity
            val redIntensity = extractRedChannel(image)

            // Process PPG signal
            ppgProcessor.addSample(redIntensity)

            // Detect peaks and calculate HR
            if (ppgProcessor.hasSufficientData()) {
                val hr = ppgProcessor.calculateHeartRate()
                callback(hr)
            }

            image.close()
        }

        // Enable torch for PPG
        val camera = cameraProvider.bindToLifecycle(
            lifecycleOwner,
            CameraSelector.DEFAULT_BACK_CAMERA,
            preview,
            imageAnalysis
        )

        camera.cameraControl.enableTorch(true)
    }
}
```

### Health Connect Integration
```kotlin
class HealthConnectManager(private val context: Context) {
    private val healthConnectClient = HealthConnectClient.getOrCreate(context)

    suspend fun readHeartRate(): Flow<HeartRateRecord> = flow {
        val request = ReadRecordsRequest(
            recordType = HeartRateRecord::class,
            timeRangeFilter = TimeRangeFilter.after(Instant.now().minus(1, ChronoUnit.HOURS))
        )

        val response = healthConnectClient.readRecords(request)
        response.records.forEach { record ->
            emit(record)
        }
    }

    suspend fun readHRV(): Flow<HeartRateVariabilityRmssdRecord> = flow {
        val request = ReadRecordsRequest(
            recordType = HeartRateVariabilityRmssdRecord::class,
            timeRangeFilter = TimeRangeFilter.after(Instant.now().minus(1, ChronoUnit.HOURS))
        )

        val response = healthConnectClient.readRecords(request)
        response.records.forEach { record ->
            emit(record)
        }
    }
}
```

---

## 🔗 DEVICE CONNECTIVITY

### Bluetooth LE (Wearables)
```kotlin
class WearablesManager(private val context: Context) {
    private val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
    private val bluetoothLeScanner = bluetoothAdapter.bluetoothLeScanner

    fun scanForDevices(callback: (BluetoothDevice) -> Unit) {
        val scanSettings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        val scanFilter = ScanFilter.Builder()
            .setServiceUuid(ParcelUuid(HEART_RATE_SERVICE_UUID))
            .build()

        bluetoothLeScanner.startScan(
            listOf(scanFilter),
            scanSettings,
            object : ScanCallback() {
                override fun onScanResult(callbackType: Int, result: ScanResult) {
                    callback(result.device)
                }
            }
        )
    }

    fun connectToDevice(device: BluetoothDevice): BluetoothGatt {
        return device.connectGatt(context, false, object : BluetoothGattCallback() {
            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    gatt.discoverServices()
                }
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                val heartRateService = gatt.getService(HEART_RATE_SERVICE_UUID)
                val heartRateCharacteristic = heartRateService.getCharacteristic(
                    HEART_RATE_MEASUREMENT_UUID
                )

                gatt.setCharacteristicNotification(heartRateCharacteristic, true)
            }

            override fun onCharacteristicChanged(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic
            ) {
                if (characteristic.uuid == HEART_RATE_MEASUREMENT_UUID) {
                    val heartRate = characteristic.getIntValue(
                        BluetoothGattCharacteristic.FORMAT_UINT8, 1
                    )
                    handleHeartRateUpdate(heartRate)
                }
            }
        })
    }
}
```

### Wear OS Data Layer
```kotlin
class WearOSCompanion(private val context: Context) {
    private val dataClient = Wearable.getDataClient(context)
    private val messageClient = Wearable.getMessageClient(context)

    fun sendTransportCommand(command: TransportCommand) {
        val request = PutDataMapRequest.create("/transport").apply {
            dataMap.putString("command", command.name)
            dataMap.putLong("timestamp", System.currentTimeMillis())
        }

        dataClient.putDataItem(request.asPutDataRequest())
    }

    fun listenForHeartRate(callback: (Int) -> Unit) {
        messageClient.addListener { messageEvent ->
            if (messageEvent.path == "/heartrate") {
                val heartRate = String(messageEvent.data).toInt()
                callback(heartRate)
            }
        }
    }
}
```

---

## 📦 DEPENDENCIES

### build.gradle.kts (Module)
```kotlin
dependencies {
    // Android Core
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    implementation("androidx.activity:activity-compose:1.8.2")

    // Jetpack Compose
    implementation(platform("androidx.compose:compose-bom:2024.01.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")

    // Audio
    implementation("com.google.oboe:oboe:1.8.0")
    implementation("androidx.media3:media3-exoplayer:1.2.0")

    // Video
    implementation("androidx.media3:media3-ui:1.2.0")
    implementation("androidx.camera:camera-camera2:1.3.1")
    implementation("androidx.camera:camera-lifecycle:1.3.1")

    // AI/ML
    implementation("org.tensorflow:tensorflow-lite:2.14.0")
    implementation("org.tensorflow:tensorflow-lite-gpu:2.14.0")
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.16.3")

    // Health
    implementation("androidx.health.connect:connect-client:1.1.0-alpha07")

    // Bluetooth
    implementation("androidx.bluetooth:bluetooth:1.0.0-alpha01")

    // Wear OS
    implementation("com.google.android.gms:play-services-wearable:18.1.0")

    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

    // Room Database
    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")

    // DataStore
    implementation("androidx.datastore:datastore-preferences:1.0.0")
}
```

---

## 🚀 BUILD & DEPLOYMENT

### Gradle Build
```bash
# Debug build
./gradlew assembleDebug

# Release build
./gradlew assembleRelease

# Install on device
./gradlew installDebug

# Run tests
./gradlew test
```

### App Bundles (Google Play)
```bash
# Build App Bundle
./gradlew bundleRelease

# Output: app/build/outputs/bundle/release/app-release.aab
```

### Multi-Module Build
```bash
# Build all modules (phone, wear, tv, auto)
./gradlew :app:assembleRelease \
          :wear:assembleRelease \
          :tv:assembleRelease \
          :automotive:assembleRelease
```

---

## 🎯 ANDROID-SPECIFIC FEATURES

### 1. Dynamic Shortcuts
```kotlin
val shortcutManager = getSystemService(ShortcutManager::class.java)

val recordShortcut = ShortcutInfo.Builder(context, "record")
    .setShortLabel("Record")
    .setLongLabel("Start Recording")
    .setIcon(Icon.createWithResource(context, R.drawable.ic_record))
    .setIntent(Intent(context, MainActivity::class.java).apply {
        action = ACTION_START_RECORDING
    })
    .build()

shortcutManager.dynamicShortcuts = listOf(recordShortcut)
```

### 2. App Widgets
```kotlin
class TransportWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Button(onClick = actionStartActivity<MainActivity>()) {
                    Text("Play")
                }
                Button(onClick = actionStartActivity<MainActivity>()) {
                    Text("Stop")
                }
                Button(onClick = actionStartActivity<MainActivity>()) {
                    Text("Record")
                }
            }
        }
    }
}
```

### 3. Quick Settings Tile
```kotlin
class RecordingTileService : TileService() {
    override fun onClick() {
        if (isRecording) {
            stopRecording()
        } else {
            startRecording()
        }
        qsTile.state = if (isRecording) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        qsTile.updateTile()
    }
}
```

### 4. Samsung DeX Support
```kotlin
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val displayManager = getSystemService(DisplayManager::class.java)
        val isDeXMode = displayManager.displays.size > 1

        setContent {
            if (isDeXMode) {
                DesktopLayout()
            } else {
                MobileLayout()
            }
        }
    }
}
```

---

## 📱 PLATFORM FEATURES MATRIX

| Feature | Phone | Tablet | Foldable | Wear OS | TV | Auto |
|---------|-------|--------|----------|---------|----|----- |
| **Full DAW** | ✅ | ✅ | ✅ | ⚠️ | ✅ | ❌ |
| **Video Editing** | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ |
| **AI Tools** | ✅ | ✅ | ✅ | ❌ | ✅ | ⚠️ |
| **Camera HRV** | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| **Health Connect** | ✅ | ✅ | ✅ | ✅ | ❌ | ⚠️ |
| **Transport Control** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Multi-Window** | ⚠️ | ✅ | ✅ | ❌ | ❌ | ❌ |
| **S Pen Support** | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ |

---

## ✅ READY FOR

1. ✅ Google Play Store submission
2. ✅ Samsung Galaxy Store
3. ✅ Amazon Appstore
4. ✅ Wear OS companion
5. ✅ Android TV app
6. ✅ Android Auto extension

**Status:** Architecture Complete - Ready for Implementation 🚀

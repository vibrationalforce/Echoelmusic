// Unity Integration for BLAB Visual Engine
// Integrates: Audio visualization, Biofeedback, Spatial audio, MIDI control
//
// Copyright (c) 2025 Vibrational Force
// Platform: Unity 2022.3+ (all platforms)

using System;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Events;

namespace Echoel
{
    /// <summary>
    /// Visualization modes available in BLAB
    /// </summary>
    public enum VisualizationMode
    {
        Particles,
        Cymatics,
        Waveform,
        Spectral,
        Mandala
    }

    /// <summary>
    /// Spatial audio modes
    /// </summary>
    public enum SpatialMode
    {
        Stereo,
        ThreeD,
        FourD_Orbital,
        AFA, // Algorithmic Field Array
        Binaural,
        Ambisonics
    }

    /// <summary>
    /// Biofeedback data structure
    /// </summary>
    [Serializable]
    public struct BiofeedbackData
    {
        public float heartRate;
        public float hrv;
        public float coherence;
        public float breathingRate;

        public BiofeedbackData(float hr, float hrvValue, float coh, float br)
        {
            heartRate = hr;
            hrv = hrvValue;
            coherence = coh;
            breathingRate = br;
        }
    }

    /// <summary>
    /// Audio analysis data
    /// </summary>
    [Serializable]
    public struct AudioAnalysis
    {
        public float audioLevel;
        public float frequency;
        public float[] spectrum;

        public AudioAnalysis(int spectrumSize = 32)
        {
            audioLevel = 0f;
            frequency = 440f;
            spectrum = new float[spectrumSize];
        }
    }

    /// <summary>
    /// Main BLAB Engine - Singleton
    /// Add to a GameObject in your scene to enable BLAB features
    /// </summary>
    public class EchoelEngine : MonoBehaviour
    {
        // MARK: - Singleton

        private static EchoelEngine _instance;
        public static EchoelEngine Instance
        {
            get
            {
                if (_instance == null)
                {
                    _instance = FindObjectOfType<EchoelEngine>();
                    if (_instance == null)
                    {
                        GameObject go = new GameObject("EchoelEngine");
                        _instance = go.AddComponent<EchoelEngine>();
                    }
                }
                return _instance;
            }
        }

        // MARK: - Configuration

        [Header("BLAB Configuration")]
        [SerializeField] private bool enableBiofeedback = false;
        [SerializeField] private bool enableMIDI = true;
        [SerializeField] private bool enableOSC = true;
        [SerializeField] private int oscReceivePort = 9000;

        [Header("Visualization")]
        [SerializeField] private VisualizationMode visualizationMode = VisualizationMode.Cymatics;
        [SerializeField] private RenderTexture renderTarget;

        [Header("Audio")]
        [SerializeField] private SpatialMode spatialMode = SpatialMode.Stereo;
        [SerializeField] private bool bioModulation = true;

        // MARK: - Events

        [Serializable] public class BiofeedbackEvent : UnityEvent<BiofeedbackData> { }
        [Serializable] public class AudioPeakEvent : UnityEvent<float, float> { }
        [Serializable] public class MIDINoteEvent : UnityEvent<int, int, int> { }

        public BiofeedbackEvent OnBiofeedbackUpdate = new BiofeedbackEvent();
        public AudioPeakEvent OnAudioPeak = new AudioPeakEvent();
        public MIDINoteEvent OnMIDINote = new MIDINoteEvent();

        // MARK: - State

        private IntPtr blabEngineHandle;
        private bool isRunning;

        private BiofeedbackData currentBiofeedback;
        private AudioAnalysis currentAudioAnalysis;

        private const float UpdateRate = 60f; // Hz
        private float updateTimer;

        // MARK: - Unity Lifecycle

        private void Awake()
        {
            if (_instance != null && _instance != this)
            {
                Destroy(gameObject);
                return;
            }

            _instance = this;
            DontDestroyOnLoad(gameObject);

            currentAudioAnalysis = new AudioAnalysis(32);
        }

        private void Start()
        {
            StartEngine();
        }

        private void Update()
        {
            if (!isRunning) return;

            updateTimer += Time.deltaTime;

            if (updateTimer >= 1f / UpdateRate)
            {
                UpdateEngine();
                updateTimer = 0f;
            }
        }

        private void OnDestroy()
        {
            StopEngine();
        }

        private void OnApplicationQuit()
        {
            StopEngine();
        }

        // MARK: - Engine Control

        /// <summary>
        /// Start the BLAB engine
        /// </summary>
        public void StartEngine()
        {
            if (isRunning) return;

            // Initialize native plugin
            blabEngineHandle = Blab_CreateEngine();

            if (blabEngineHandle == IntPtr.Zero)
            {
                Debug.LogError("Failed to create BLAB engine");
                return;
            }

            // Configure
            if (enableBiofeedback)
            {
                Blab_EnableBiofeedback(blabEngineHandle, true);
            }

            if (enableMIDI)
            {
                Blab_EnableMIDI(blabEngineHandle, true);
            }

            if (enableOSC)
            {
                Blab_EnableOSC(blabEngineHandle, true, oscReceivePort);
            }

            Blab_SetVisualizationMode(blabEngineHandle, (int)visualizationMode);
            Blab_SetSpatialMode(blabEngineHandle, (int)spatialMode);

            isRunning = true;

            Debug.Log("BLAB Engine started");
            Debug.Log($"  Visualization: {visualizationMode}");
            Debug.Log($"  Spatial: {spatialMode}");
        }

        /// <summary>
        /// Stop the BLAB engine
        /// </summary>
        public void StopEngine()
        {
            if (!isRunning) return;

            if (blabEngineHandle != IntPtr.Zero)
            {
                Blab_DestroyEngine(blabEngineHandle);
                blabEngineHandle = IntPtr.Zero;
            }

            isRunning = false;

            Debug.Log("BLAB Engine stopped");
        }

        private void UpdateEngine()
        {
            if (blabEngineHandle == IntPtr.Zero) return;

            // Update biofeedback
            if (enableBiofeedback)
            {
                UpdateBiofeedback();
            }

            // Update audio analysis
            UpdateAudioAnalysis();
        }

        // MARK: - Visualization

        /// <summary>
        /// Set visualization mode
        /// </summary>
        public void SetVisualizationMode(VisualizationMode mode)
        {
            visualizationMode = mode;

            if (blabEngineHandle != IntPtr.Zero)
            {
                Blab_SetVisualizationMode(blabEngineHandle, (int)mode);
            }
        }

        /// <summary>
        /// Render visualization to texture
        /// </summary>
        public void RenderToTexture(RenderTexture target)
        {
            if (blabEngineHandle == IntPtr.Zero || target == null) return;

            IntPtr nativeTexture = target.GetNativeTexturePtr();
            Blab_RenderToTexture(blabEngineHandle, nativeTexture, target.width, target.height);
        }

        // MARK: - Audio

        /// <summary>
        /// Set spatial audio mode
        /// </summary>
        public void SetSpatialMode(SpatialMode mode)
        {
            spatialMode = mode;

            if (blabEngineHandle != IntPtr.Zero)
            {
                Blab_SetSpatialMode(blabEngineHandle, (int)mode);
            }
        }

        /// <summary>
        /// Process audio buffer (call from OnAudioFilterRead)
        /// </summary>
        public void ProcessAudio(float[] data, int channels)
        {
            if (blabEngineHandle == IntPtr.Zero) return;

            Blab_ProcessAudio(blabEngineHandle, data, data.Length, channels);
        }

        // MARK: - Biofeedback

        private void UpdateBiofeedback()
        {
            float hr = 0, hrv = 0, coh = 0, br = 0;

            Blab_GetBiofeedback(blabEngineHandle, out hr, out hrv, out coh, out br);

            currentBiofeedback = new BiofeedbackData(hr, hrv, coh, br);

            OnBiofeedbackUpdate?.Invoke(currentBiofeedback);
        }

        /// <summary>
        /// Get current biofeedback data
        /// </summary>
        public BiofeedbackData GetBiofeedbackData()
        {
            return currentBiofeedback;
        }

        // MARK: - Audio Analysis

        private void UpdateAudioAnalysis()
        {
            float level = 0, freq = 0;

            Blab_GetAudioAnalysis(blabEngineHandle, out level, out freq, currentAudioAnalysis.spectrum, currentAudioAnalysis.spectrum.Length);

            currentAudioAnalysis.audioLevel = level;
            currentAudioAnalysis.frequency = freq;

            // Detect peaks
            if (level > 0.7f)
            {
                OnAudioPeak?.Invoke(freq, level);
            }
        }

        /// <summary>
        /// Get current audio analysis
        /// </summary>
        public AudioAnalysis GetAudioAnalysis()
        {
            return currentAudioAnalysis;
        }

        // MARK: - Export

        /// <summary>
        /// Export current session to video file
        /// </summary>
        public void ExportToVideo(string filePath, int width, int height, int frameRate)
        {
            if (blabEngineHandle == IntPtr.Zero) return;

            Blab_ExportToVideo(blabEngineHandle, filePath, width, height, frameRate);

            Debug.Log($"Exporting to video: {filePath} ({width}x{height} @ {frameRate}fps)");
        }

        // MARK: - Native Plugin Interface

        #if UNITY_IOS || UNITY_STANDALONE_OSX
        private const string DllName = "__Internal";
        #elif UNITY_ANDROID
        private const string DllName = "echoel";
        #else
        private const string DllName = "echoel";
        #endif

        [DllImport(DllName)]
        private static extern IntPtr Blab_CreateEngine();

        [DllImport(DllName)]
        private static extern void Blab_DestroyEngine(IntPtr handle);

        [DllImport(DllName)]
        private static extern void Blab_EnableBiofeedback(IntPtr handle, bool enabled);

        [DllImport(DllName)]
        private static extern void Blab_EnableMIDI(IntPtr handle, bool enabled);

        [DllImport(DllName)]
        private static extern void Blab_EnableOSC(IntPtr handle, bool enabled, int port);

        [DllImport(DllName)]
        private static extern void Blab_SetVisualizationMode(IntPtr handle, int mode);

        [DllImport(DllName)]
        private static extern void Blab_SetSpatialMode(IntPtr handle, int mode);

        [DllImport(DllName)]
        private static extern void Blab_RenderToTexture(IntPtr handle, IntPtr texture, int width, int height);

        [DllImport(DllName)]
        private static extern void Blab_ProcessAudio(IntPtr handle, float[] data, int length, int channels);

        [DllImport(DllName)]
        private static extern void Blab_GetBiofeedback(IntPtr handle, out float heartRate, out float hrv, out float coherence, out float breathingRate);

        [DllImport(DllName)]
        private static extern void Blab_GetAudioAnalysis(IntPtr handle, out float level, out float frequency, [Out] float[] spectrum, int spectrumLength);

        [DllImport(DllName)]
        private static extern void Blab_ExportToVideo(IntPtr handle, string filePath, int width, int height, int frameRate);
    }

    /// <summary>
    /// BLAB Visualization Component
    /// Attach to a GameObject to render BLAB visuals
    /// </summary>
    public class BlabVisualization : MonoBehaviour
    {
        [Header("Visualization Settings")]
        [SerializeField] private VisualizationMode mode = VisualizationMode.Cymatics;
        [SerializeField] private RenderTexture renderTarget;
        [SerializeField] private Renderer targetRenderer;
        [SerializeField] private string materialTextureProperty = "_MainTex";

        [Header("Particles (Particle Mode)")]
        [SerializeField, Range(10, 1000)] private int particleCount = 300;

        [Header("Color")]
        [SerializeField, Range(0f, 1f)] private float hue = 0.5f;
        [SerializeField] private bool bioReactive = true;

        private void Start()
        {
            if (renderTarget == null)
            {
                renderTarget = new RenderTexture(1920, 1080, 0, RenderTextureFormat.ARGB32);
                renderTarget.Create();
            }

            if (targetRenderer != null && !string.IsNullOrEmpty(materialTextureProperty))
            {
                targetRenderer.material.SetTexture(materialTextureProperty, renderTarget);
            }

            EchoelEngine.Instance.SetVisualizationMode(mode);
        }

        private void Update()
        {
            EchoelEngine.Instance.RenderToTexture(renderTarget);

            if (bioReactive)
            {
                BiofeedbackData bio = EchoelEngine.Instance.GetBiofeedbackData();
                hue = bio.coherence / 100f;
            }
        }

        /// <summary>
        /// Set visualization mode
        /// </summary>
        public void SetMode(VisualizationMode newMode)
        {
            mode = newMode;
            EchoelEngine.Instance.SetVisualizationMode(mode);
        }
    }

    /// <summary>
    /// BLAB Audio Filter
    /// Attach to AudioSource to apply spatial audio processing
    /// </summary>
    [RequireComponent(typeof(AudioSource))]
    public class BlabAudioFilter : MonoBehaviour
    {
        [Header("Spatial Audio")]
        [SerializeField] private SpatialMode spatialMode = SpatialMode.ThreeD;
        [SerializeField] private bool bioModulation = true;

        private void Start()
        {
            EchoelEngine.Instance.SetSpatialMode(spatialMode);
        }

        private void OnAudioFilterRead(float[] data, int channels)
        {
            EchoelEngine.Instance.ProcessAudio(data, channels);
        }

        /// <summary>
        /// Set spatial mode
        /// </summary>
        public void SetSpatialMode(SpatialMode newMode)
        {
            spatialMode = newMode;
            EchoelEngine.Instance.SetSpatialMode(spatialMode);
        }
    }

    /// <summary>
    /// BLAB Material Functions
    /// Utility functions for shaders and materials
    /// </summary>
    public static class BlabMaterialFunctions
    {
        /// <summary>
        /// Generate Chladni pattern at UV coordinate
        /// </summary>
        public static float GetCymaticsPattern(Vector2 uv, float frequency, float amplitude)
        {
            float x = uv.x * 2f - 1f;
            float y = uv.y * 2f - 1f;

            float pattern = Mathf.Sin(x * frequency) * Mathf.Sin(y * frequency);
            pattern += Mathf.Sin((x + y) * frequency * 0.7f);
            pattern *= amplitude;

            return Mathf.Clamp01((pattern + 1f) * 0.5f);
        }

        /// <summary>
        /// Get bio-reactive color based on coherence
        /// </summary>
        public static Color GetBioReactiveColor(float coherence)
        {
            // 0-50 = Red (stress)
            // 50-70 = Yellow (medium)
            // 70-100 = Green (optimal)

            if (coherence < 50f)
            {
                return Color.Lerp(Color.red, Color.yellow, coherence / 50f);
            }
            else
            {
                return Color.Lerp(Color.yellow, Color.green, (coherence - 50f) / 50f);
            }
        }
    }
}

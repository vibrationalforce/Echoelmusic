// Unreal Engine 5.6+ Plugin for BLAB Visual Engine
// Integrates: Audio visualization, Biofeedback, Spatial audio, MIDI control
//
// Copyright (c) 2025 Vibrational Force
// Platform: UE 5.6+, all supported platforms

#pragma once

#include "CoreMinimal.h"
#include "Modules/ModuleManager.h"
#include "AudioDevice.h"

/**
 * BLAB Plugin Module
 * Integrates BLAB's visual and audio engines into Unreal Engine
 */
class FBlabPluginModule : public IModuleInterface
{
public:
    /** IModuleInterface implementation */
    virtual void StartupModule() override;
    virtual void ShutdownModule() override;

private:
    /** Handle to the BLAB native library */
    void* BlabLibraryHandle;
};

/**
 * BLAB Visualization Mode
 */
UENUM(BlueprintType)
enum class EBlabVisualizationMode : uint8
{
    Particles      UMETA(DisplayName = "Particles"),
    Cymatics       UMETA(DisplayName = "Cymatics"),
    Waveform       UMETA(DisplayName = "Waveform"),
    Spectral       UMETA(DisplayName = "Spectral"),
    Mandala        UMETA(DisplayName = "Mandala")
};

/**
 * BLAB Spatial Audio Mode
 */
UENUM(BlueprintType)
enum class EBlabSpatialMode : uint8
{
    Stereo         UMETA(DisplayName = "Stereo"),
    ThreeD         UMETA(DisplayName = "3D"),
    FourD_Orbital  UMETA(DisplayName = "4D Orbital"),
    AFA            UMETA(DisplayName = "AFA (Algorithmic Field Array)"),
    Binaural       UMETA(DisplayName = "Binaural"),
    Ambisonics     UMETA(DisplayName = "Ambisonics")
};

/**
 * BLAB Biofeedback Data Structure
 */
USTRUCT(BlueprintType)
struct FBlabBiofeedbackData
{
    GENERATED_BODY()

    UPROPERTY(BlueprintReadOnly, Category = "BLAB|Biofeedback")
    float HeartRate;

    UPROPERTY(BlueprintReadOnly, Category = "BLAB|Biofeedback")
    float HRV;

    UPROPERTY(BlueprintReadOnly, Category = "BLAB|Biofeedback")
    float Coherence;

    UPROPERTY(BlueprintReadOnly, Category = "BLAB|Biofeedback")
    float BreathingRate;

    FBlabBiofeedbackData()
        : HeartRate(60.0f)
        , HRV(50.0f)
        , Coherence(50.0f)
        , BreathingRate(12.0f)
    {}
};

/**
 * BLAB Audio Analysis Data
 */
USTRUCT(BlueprintType)
struct FBlabAudioAnalysis
{
    GENERATED_BODY()

    UPROPERTY(BlueprintReadOnly, Category = "BLAB|Audio")
    float AudioLevel;

    UPROPERTY(BlueprintReadOnly, Category = "BLAB|Audio")
    float Frequency;

    UPROPERTY(BlueprintReadOnly, Category = "BLAB|Audio")
    TArray<float> Spectrum;

    FBlabAudioAnalysis()
        : AudioLevel(0.0f)
        , Frequency(440.0f)
    {
        Spectrum.SetNum(32);
    }
};

/**
 * Main BLAB Engine Actor
 * Place in your level to enable BLAB features
 */
UCLASS(Blueprintable, ClassGroup = (BLAB), meta = (BlueprintSpawnableComponent))
class BLABPLUGIN_API ABlabEngine : public AActor
{
    GENERATED_BODY()

public:
    ABlabEngine();

    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;
    virtual void Tick(float DeltaTime) override;

    // MARK: - Configuration

    /** Enable biofeedback integration (requires compatible device) */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "BLAB|Config")
    bool bEnableBiofeedback;

    /** Enable MIDI input */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "BLAB|Config")
    bool bEnableMIDI;

    /** Enable OSC communication */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "BLAB|Config")
    bool bEnableOSC;

    /** OSC receive port */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "BLAB|Config")
    int32 OSCReceivePort;

    /** Visualization mode */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "BLAB|Visualization")
    EBlabVisualizationMode VisualizationMode;

    /** Spatial audio mode */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "BLAB|Audio")
    EBlabSpatialMode SpatialMode;

    // MARK: - Blueprint Functions

    /** Start the BLAB engine */
    UFUNCTION(BlueprintCallable, Category = "BLAB")
    void StartEngine();

    /** Stop the BLAB engine */
    UFUNCTION(BlueprintCallable, Category = "BLAB")
    void StopEngine();

    /** Set visualization mode */
    UFUNCTION(BlueprintCallable, Category = "BLAB|Visualization")
    void SetVisualizationMode(EBlabVisualizationMode Mode);

    /** Set spatial audio mode */
    UFUNCTION(BlueprintCallable, Category = "BLAB|Audio")
    void SetSpatialMode(EBlabSpatialMode Mode);

    /** Get current biofeedback data */
    UFUNCTION(BlueprintCallable, BlueprintPure, Category = "BLAB|Biofeedback")
    FBlabBiofeedbackData GetBiofeedbackData() const;

    /** Get current audio analysis */
    UFUNCTION(BlueprintCallable, BlueprintPure, Category = "BLAB|Audio")
    FBlabAudioAnalysis GetAudioAnalysis() const;

    /** Export current session to video */
    UFUNCTION(BlueprintCallable, Category = "BLAB|Export")
    void ExportToVideo(const FString& FilePath, int32 Width, int32 Height, int32 FrameRate);

    // MARK: - Events

    /** Called when biofeedback data is updated */
    UPROPERTY(BlueprintAssignable, Category = "BLAB|Events")
    FOnBiofeedbackUpdate OnBiofeedbackUpdate;

    /** Called when audio peaks */
    UPROPERTY(BlueprintAssignable, Category = "BLAB|Events")
    FOnAudioPeak OnAudioPeak;

    /** Called when MIDI note received */
    UPROPERTY(BlueprintAssignable, Category = "BLAB|Events")
    FOnMIDINote OnMIDINote;

protected:
    /** Internal engine state */
    void* BlabEngineInstance;

    /** Current biofeedback data */
    FBlabBiofeedbackData CurrentBiofeedback;

    /** Current audio analysis */
    FBlabAudioAnalysis CurrentAudioAnalysis;

    /** Update rate (Hz) */
    static constexpr float UpdateRate = 60.0f;

    /** Accumulator for fixed timestep updates */
    float Accumulator;
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE_ThreeParams(FOnBiofeedbackUpdate, float, HeartRate, float, HRV, float, Coherence);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnAudioPeak, float, Frequency, float, Amplitude);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_ThreeParams(FOnMIDINote, int32, Note, int32, Velocity, int32, Channel);

/**
 * BLAB Visualization Component
 * Attach to any actor to render BLAB visuals
 */
UCLASS(ClassGroup = (BLAB), meta = (BlueprintSpawnableComponent))
class BLABPLUGIN_API UBlabVisualizationComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UBlabVisualizationComponent();

    virtual void BeginPlay() override;
    virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

    /** Render target for visualization */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "BLAB")
    UTextureRenderTarget2D* RenderTarget;

    /** Visualization mode */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "BLAB")
    EBlabVisualizationMode Mode;

    /** Particle count (for particle mode) */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "BLAB|Particles", meta = (ClampMin = "10", ClampMax = "1000"))
    int32 ParticleCount;

    /** Hue (0-1) */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "BLAB|Color", meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float Hue;

    /** Update visualization parameters from biofeedback */
    UFUNCTION(BlueprintCallable, Category = "BLAB")
    void UpdateFromBiofeedback(const FBlabBiofeedbackData& BiofeedbackData);

protected:
    void* VisualizationInstance;
};

/**
 * BLAB Material Functions Library
 * Blueprint-callable functions for shaders
 */
UCLASS()
class BLABPLUGIN_API UBlabMaterialFunctions : public UBlueprintFunctionLibrary
{
    GENERATED_BODY()

public:
    /** Generate Chladni pattern at UV coordinate */
    UFUNCTION(BlueprintCallable, Category = "BLAB|Material")
    static float GetCymaticsPattern(FVector2D UV, float Frequency, float Amplitude);

    /** Get audio spectrum value at normalized frequency (0-1) */
    UFUNCTION(BlueprintCallable, Category = "BLAB|Material")
    static float GetSpectrumValue(float NormalizedFrequency);

    /** Get bio-reactive color based on coherence */
    UFUNCTION(BlueprintCallable, Category = "BLAB|Material")
    static FLinearColor GetBioReactiveColor(float Coherence);
};

/**
 * BLAB Spatial Audio Component
 * Spatialize audio sources based on biofeedback and gestures
 */
UCLASS(ClassGroup = (BLAB), meta = (BlueprintSpawnableComponent))
class BLABPLUGIN_API UBlabSpatialAudioComponent : public UAudioComponent
{
    GENERATED_BODY()

public:
    UBlabSpatialAudioComponent();

    virtual void BeginPlay() override;
    virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

    /** Spatial mode */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "BLAB")
    EBlabSpatialMode SpatialMode;

    /** Enable biofeedback modulation */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "BLAB")
    bool bBioModulation;

    /** Apply biofeedback data to spatial parameters */
    UFUNCTION(BlueprintCallable, Category = "BLAB")
    void ApplyBiofeedback(const FBlabBiofeedbackData& BiofeedbackData);

protected:
    void* SpatialEngineInstance;
};

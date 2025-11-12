#pragma once

/**
 * Common JUCE includes for Echoelmusic
 *
 * JUCE 7.x doesn't have a single JuceHeader.h anymore,
 * so we include the specific modules we need.
 */

// Core JUCE modules
#include <juce_core/juce_core.h>
#include <juce_events/juce_events.h>
#include <juce_data_structures/juce_data_structures.h>

// Audio modules
#include <juce_audio_basics/juce_audio_basics.h>
#include <juce_audio_devices/juce_audio_devices.h>
#include <juce_audio_formats/juce_audio_formats.h>
#include <juce_audio_processors/juce_audio_processors.h>
#include <juce_audio_utils/juce_audio_utils.h>

// DSP module
#include <juce_dsp/juce_dsp.h>

// GUI modules
#include <juce_gui_basics/juce_gui_basics.h>
#include <juce_gui_extra/juce_gui_extra.h>
#include <juce_graphics/juce_graphics.h>

// MIDI
#include <juce_midi_ci/juce_midi_ci.h>

// Use JUCE namespace
using namespace juce;

/**
 * Scene Panel Component
 *
 * Editing panel for individual scene properties including
 * prompt, duration, camera motion, and style settings.
 */

import React, { useCallback } from 'react';
import type { Scene, SceneType, CameraMotion, MoodType, LightingType } from './types';

export interface ScenePanelProps {
  scene: Scene;
  onUpdate: (updates: Partial<Scene>) => void;
  onDelete: () => void;
}

const SCENE_TYPES: { value: SceneType; label: string }[] = [
  { value: 'establishing', label: 'Establishing Shot' },
  { value: 'closeup', label: 'Close-up' },
  { value: 'action', label: 'Action' },
  { value: 'dialogue', label: 'Dialogue' },
  { value: 'transition', label: 'Transition' },
  { value: 'montage', label: 'Montage' },
];

const CAMERA_MOTIONS: { value: CameraMotion; label: string }[] = [
  { value: 'static', label: 'Static' },
  { value: 'pan_left', label: 'Pan Left' },
  { value: 'pan_right', label: 'Pan Right' },
  { value: 'tilt_up', label: 'Tilt Up' },
  { value: 'tilt_down', label: 'Tilt Down' },
  { value: 'zoom_in', label: 'Zoom In' },
  { value: 'zoom_out', label: 'Zoom Out' },
  { value: 'dolly_in', label: 'Dolly In' },
  { value: 'dolly_out', label: 'Dolly Out' },
  { value: 'tracking', label: 'Tracking' },
  { value: 'orbit', label: 'Orbit' },
];

const MOODS: { value: MoodType; label: string }[] = [
  { value: 'neutral', label: 'Neutral' },
  { value: 'happy', label: 'Happy' },
  { value: 'sad', label: 'Sad' },
  { value: 'dramatic', label: 'Dramatic' },
  { value: 'mysterious', label: 'Mysterious' },
  { value: 'energetic', label: 'Energetic' },
  { value: 'peaceful', label: 'Peaceful' },
  { value: 'tense', label: 'Tense' },
];

const LIGHTING_TYPES: { value: LightingType; label: string }[] = [
  { value: 'natural', label: 'Natural' },
  { value: 'golden_hour', label: 'Golden Hour' },
  { value: 'blue_hour', label: 'Blue Hour' },
  { value: 'night', label: 'Night' },
  { value: 'studio', label: 'Studio' },
  { value: 'dramatic', label: 'Dramatic' },
  { value: 'soft', label: 'Soft' },
  { value: 'harsh', label: 'Harsh' },
];

export const ScenePanel: React.FC<ScenePanelProps> = ({
  scene,
  onUpdate,
  onDelete,
}) => {
  const handlePromptChange = useCallback((e: React.ChangeEvent<HTMLTextAreaElement>) => {
    onUpdate({ prompt: e.target.value });
  }, [onUpdate]);

  const handleNegativePromptChange = useCallback((e: React.ChangeEvent<HTMLTextAreaElement>) => {
    onUpdate({ negativePrompt: e.target.value });
  }, [onUpdate]);

  const handleDurationChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const duration = parseFloat(e.target.value);
    if (!isNaN(duration) && duration >= 1 && duration <= 60) {
      onUpdate({ duration });
    }
  }, [onUpdate]);

  const handleTypeChange = useCallback((e: React.ChangeEvent<HTMLSelectElement>) => {
    onUpdate({ type: e.target.value as SceneType });
  }, [onUpdate]);

  const handleSettingChange = useCallback((
    setting: keyof Scene['settings'],
    value: string
  ) => {
    onUpdate({
      settings: {
        ...scene.settings,
        [setting]: value,
      },
    });
  }, [scene.settings, onUpdate]);

  return (
    <div className="scene-panel">
      <div className="scene-panel__header">
        <h2>Scene {scene.order + 1}</h2>
        <button
          className="btn btn--danger btn--small"
          onClick={onDelete}
        >
          Delete
        </button>
      </div>

      <div className="scene-panel__section">
        <label className="scene-panel__label">Prompt</label>
        <textarea
          className="scene-panel__textarea"
          value={scene.prompt}
          onChange={handlePromptChange}
          placeholder="Describe what happens in this scene..."
          rows={4}
        />
      </div>

      <div className="scene-panel__section">
        <label className="scene-panel__label">Negative Prompt</label>
        <textarea
          className="scene-panel__textarea scene-panel__textarea--small"
          value={scene.negativePrompt || ''}
          onChange={handleNegativePromptChange}
          placeholder="What to avoid..."
          rows={2}
        />
      </div>

      <div className="scene-panel__row">
        <div className="scene-panel__section scene-panel__section--half">
          <label className="scene-panel__label">Duration (seconds)</label>
          <input
            type="number"
            className="scene-panel__input"
            value={scene.duration}
            onChange={handleDurationChange}
            min={1}
            max={60}
            step={0.5}
          />
        </div>

        <div className="scene-panel__section scene-panel__section--half">
          <label className="scene-panel__label">Scene Type</label>
          <select
            className="scene-panel__select"
            value={scene.type}
            onChange={handleTypeChange}
          >
            {SCENE_TYPES.map(type => (
              <option key={type.value} value={type.value}>
                {type.label}
              </option>
            ))}
          </select>
        </div>
      </div>

      <div className="scene-panel__divider" />

      <h3 className="scene-panel__subtitle">Camera & Style</h3>

      <div className="scene-panel__section">
        <label className="scene-panel__label">Camera Motion</label>
        <select
          className="scene-panel__select"
          value={scene.settings.cameraMotion}
          onChange={(e) => handleSettingChange('cameraMotion', e.target.value)}
        >
          {CAMERA_MOTIONS.map(motion => (
            <option key={motion.value} value={motion.value}>
              {motion.label}
            </option>
          ))}
        </select>
      </div>

      <div className="scene-panel__row">
        <div className="scene-panel__section scene-panel__section--half">
          <label className="scene-panel__label">Mood</label>
          <select
            className="scene-panel__select"
            value={scene.settings.mood}
            onChange={(e) => handleSettingChange('mood', e.target.value)}
          >
            {MOODS.map(mood => (
              <option key={mood.value} value={mood.value}>
                {mood.label}
              </option>
            ))}
          </select>
        </div>

        <div className="scene-panel__section scene-panel__section--half">
          <label className="scene-panel__label">Lighting</label>
          <select
            className="scene-panel__select"
            value={scene.settings.lighting}
            onChange={(e) => handleSettingChange('lighting', e.target.value)}
          >
            {LIGHTING_TYPES.map(lighting => (
              <option key={lighting.value} value={lighting.value}>
                {lighting.label}
              </option>
            ))}
          </select>
        </div>
      </div>

      <div className="scene-panel__section">
        <label className="scene-panel__label">Custom Style</label>
        <input
          type="text"
          className="scene-panel__input"
          value={scene.settings.style || ''}
          onChange={(e) => handleSettingChange('style', e.target.value)}
          placeholder="e.g., 'cinematic, anamorphic lens'"
        />
      </div>

      {scene.thumbnail && (
        <div className="scene-panel__section">
          <label className="scene-panel__label">Preview</label>
          <img
            src={scene.thumbnail}
            alt="Scene preview"
            className="scene-panel__thumbnail"
          />
        </div>
      )}
    </div>
  );
};

export default ScenePanel;

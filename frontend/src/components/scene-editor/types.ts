/**
 * Type definitions for Multi-Shot Scene Editor
 */

export type SceneType =
  | 'establishing'
  | 'closeup'
  | 'action'
  | 'dialogue'
  | 'transition'
  | 'montage';

export type TransitionType =
  | 'cut'
  | 'crossfade'
  | 'wipe'
  | 'zoom'
  | 'blur'
  | 'morph';

export type CameraMotion =
  | 'static'
  | 'pan_left'
  | 'pan_right'
  | 'tilt_up'
  | 'tilt_down'
  | 'zoom_in'
  | 'zoom_out'
  | 'dolly_in'
  | 'dolly_out'
  | 'tracking'
  | 'orbit';

export type MoodType =
  | 'neutral'
  | 'happy'
  | 'sad'
  | 'dramatic'
  | 'mysterious'
  | 'energetic'
  | 'peaceful'
  | 'tense';

export type LightingType =
  | 'natural'
  | 'golden_hour'
  | 'blue_hour'
  | 'night'
  | 'studio'
  | 'dramatic'
  | 'soft'
  | 'harsh';

export interface SceneSettings {
  cameraMotion: CameraMotion;
  mood: MoodType;
  lighting: LightingType;
  style?: string;
  colorPalette?: string[];
}

export interface Scene {
  id: string;
  prompt: string;
  negativePrompt?: string;
  duration: number;
  type: SceneType;
  order: number;
  settings: SceneSettings;
  thumbnail?: string;
  characters?: Character[];
}

export interface Character {
  id: string;
  name: string;
  referenceImageUrl?: string;
  description?: string;
  isTracked: boolean;
}

export interface Transition {
  type: TransitionType;
  duration: number;
  easing?: 'linear' | 'ease-in' | 'ease-out' | 'ease-in-out';
  direction?: 'left' | 'right' | 'up' | 'down';
}

export interface ProjectSettings {
  enableCharacterConsistency: boolean;
  targetResolution: '480p' | '720p' | '1080p' | '1440p' | '4k';
  fps: 12 | 24 | 30 | 60;
  aspectRatio?: '16:9' | '9:16' | '1:1' | '4:3';
  genre?: string;
  styleReference?: string;
}

export interface SceneProject {
  id: string;
  name?: string;
  scenes: Scene[];
  transitions: Transition[];
  settings: ProjectSettings;
  characters?: Character[];
  createdAt?: string;
  updatedAt?: string;
}

export interface GenerationProgress {
  status: 'pending' | 'generating' | 'completed' | 'failed';
  progress: number;
  currentScene: number;
  totalScenes: number;
  eta?: number;
  previewUrl?: string;
  error?: string;
}

export interface TimelineMarker {
  time: number;
  type: 'scene_start' | 'scene_end' | 'transition_start' | 'transition_end';
  sceneId?: string;
  transitionIndex?: number;
}

export interface DragState {
  isDragging: boolean;
  draggedItemId: string | null;
  dragOverItemId: string | null;
  dropPosition: 'before' | 'after' | null;
}

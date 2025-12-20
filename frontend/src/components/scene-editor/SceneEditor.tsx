/**
 * Multi-Shot Scene Editor Component
 *
 * Main component for creating and editing multi-shot videos
 * with automatic transitions and character consistency.
 */

import React, { useState, useCallback } from 'react';
import { SceneTimeline } from './SceneTimeline';
import { ScenePanel } from './ScenePanel';
import { TransitionPicker } from './TransitionPicker';
import { PreviewPlayer } from './PreviewPlayer';
import { useSceneStore } from './useSceneStore';
import type { Scene, Transition, SceneProject } from './types';

export interface SceneEditorProps {
  projectId?: string;
  onExport?: (project: SceneProject) => void;
  onGenerate?: (project: SceneProject) => Promise<void>;
}

export const SceneEditor: React.FC<SceneEditorProps> = ({
  projectId,
  onExport,
  onGenerate,
}) => {
  const {
    scenes,
    transitions,
    selectedSceneId,
    isGenerating,
    addScene,
    updateScene,
    deleteScene,
    reorderScenes,
    selectScene,
    updateTransition,
    setGenerating,
  } = useSceneStore();

  const [previewMode, setPreviewMode] = useState<'storyboard' | 'timeline'>('timeline');
  const [showTransitionPicker, setShowTransitionPicker] = useState(false);
  const [activeTransitionIndex, setActiveTransitionIndex] = useState<number | null>(null);

  const selectedScene = scenes.find(s => s.id === selectedSceneId);

  const handleAddScene = useCallback(() => {
    const newScene: Scene = {
      id: `scene-${Date.now()}`,
      prompt: '',
      duration: 4,
      type: 'action',
      order: scenes.length,
      settings: {
        cameraMotion: 'static',
        mood: 'neutral',
        lighting: 'natural',
      },
    };
    addScene(newScene);
    selectScene(newScene.id);
  }, [scenes.length, addScene, selectScene]);

  const handleSceneUpdate = useCallback((sceneId: string, updates: Partial<Scene>) => {
    updateScene(sceneId, updates);
  }, [updateScene]);

  const handleTransitionClick = useCallback((index: number) => {
    setActiveTransitionIndex(index);
    setShowTransitionPicker(true);
  }, []);

  const handleTransitionSelect = useCallback((transitionType: string) => {
    if (activeTransitionIndex !== null) {
      updateTransition(activeTransitionIndex, { type: transitionType as Transition['type'] });
    }
    setShowTransitionPicker(false);
    setActiveTransitionIndex(null);
  }, [activeTransitionIndex, updateTransition]);

  const handleGenerate = useCallback(async () => {
    if (!onGenerate) return;

    const project: SceneProject = {
      id: projectId || `project-${Date.now()}`,
      scenes,
      transitions,
      settings: {
        enableCharacterConsistency: true,
        targetResolution: '1080p',
        fps: 24,
      },
    };

    setGenerating(true);
    try {
      await onGenerate(project);
    } finally {
      setGenerating(false);
    }
  }, [projectId, scenes, transitions, onGenerate, setGenerating]);

  const totalDuration = scenes.reduce((sum, s) => sum + s.duration, 0) +
    transitions.reduce((sum, t) => sum + (t.duration || 0.5), 0);

  return (
    <div className="scene-editor">
      <header className="scene-editor__header">
        <h1>Multi-Shot Scene Editor</h1>
        <div className="scene-editor__actions">
          <button
            className="btn btn--secondary"
            onClick={() => setPreviewMode(m => m === 'timeline' ? 'storyboard' : 'timeline')}
          >
            {previewMode === 'timeline' ? 'Storyboard View' : 'Timeline View'}
          </button>
          <button
            className="btn btn--primary"
            onClick={handleGenerate}
            disabled={isGenerating || scenes.length === 0}
          >
            {isGenerating ? 'Generating...' : 'Generate Video'}
          </button>
        </div>
      </header>

      <div className="scene-editor__content">
        <aside className="scene-editor__sidebar">
          <div className="scene-editor__stats">
            <div className="stat">
              <span className="stat__value">{scenes.length}</span>
              <span className="stat__label">Scenes</span>
            </div>
            <div className="stat">
              <span className="stat__value">{totalDuration.toFixed(1)}s</span>
              <span className="stat__label">Duration</span>
            </div>
          </div>

          <button className="btn btn--add-scene" onClick={handleAddScene}>
            + Add Scene
          </button>

          <div className="scene-list">
            {scenes.map((scene, index) => (
              <div
                key={scene.id}
                className={`scene-list__item ${scene.id === selectedSceneId ? 'scene-list__item--selected' : ''}`}
                onClick={() => selectScene(scene.id)}
              >
                <span className="scene-list__number">{index + 1}</span>
                <span className="scene-list__prompt">
                  {scene.prompt || 'Untitled scene'}
                </span>
                <span className="scene-list__duration">{scene.duration}s</span>
              </div>
            ))}
          </div>
        </aside>

        <main className="scene-editor__main">
          {previewMode === 'timeline' ? (
            <SceneTimeline
              scenes={scenes}
              transitions={transitions}
              selectedSceneId={selectedSceneId}
              onSceneSelect={selectScene}
              onSceneReorder={reorderScenes}
              onTransitionClick={handleTransitionClick}
            />
          ) : (
            <div className="storyboard">
              {scenes.map((scene, index) => (
                <React.Fragment key={scene.id}>
                  <div
                    className={`storyboard__card ${scene.id === selectedSceneId ? 'storyboard__card--selected' : ''}`}
                    onClick={() => selectScene(scene.id)}
                  >
                    <div className="storyboard__preview">
                      <div className="storyboard__placeholder">Scene {index + 1}</div>
                    </div>
                    <div className="storyboard__info">
                      <p className="storyboard__prompt">{scene.prompt || 'No prompt'}</p>
                      <span className="storyboard__duration">{scene.duration}s</span>
                    </div>
                  </div>
                  {index < scenes.length - 1 && (
                    <div
                      className="storyboard__transition"
                      onClick={() => handleTransitionClick(index)}
                    >
                      <span>{transitions[index]?.type || 'crossfade'}</span>
                    </div>
                  )}
                </React.Fragment>
              ))}
            </div>
          )}
        </main>

        <aside className="scene-editor__panel">
          {selectedScene ? (
            <ScenePanel
              scene={selectedScene}
              onUpdate={(updates) => handleSceneUpdate(selectedScene.id, updates)}
              onDelete={() => deleteScene(selectedScene.id)}
            />
          ) : (
            <div className="empty-panel">
              <p>Select a scene to edit or add a new scene</p>
            </div>
          )}
        </aside>
      </div>

      <footer className="scene-editor__footer">
        <PreviewPlayer
          scenes={scenes}
          transitions={transitions}
          currentSceneId={selectedSceneId}
        />
      </footer>

      {showTransitionPicker && (
        <TransitionPicker
          currentType={activeTransitionIndex !== null ? transitions[activeTransitionIndex]?.type : undefined}
          onSelect={handleTransitionSelect}
          onClose={() => setShowTransitionPicker(false)}
        />
      )}
    </div>
  );
};

export default SceneEditor;

/**
 * Scene Editor State Management Hook
 *
 * Manages the state for multi-shot scene editing including
 * scenes, transitions, and selection state.
 */

import { useState, useCallback, useMemo } from 'react';
import type { Scene, Transition } from './types';

export interface SceneStore {
  scenes: Scene[];
  transitions: Transition[];
  selectedSceneId: string | null;
  isGenerating: boolean;
  addScene: (scene: Scene) => void;
  updateScene: (id: string, updates: Partial<Scene>) => void;
  deleteScene: (id: string) => void;
  reorderScenes: (fromIndex: number, toIndex: number) => void;
  selectScene: (id: string | null) => void;
  updateTransition: (index: number, updates: Partial<Transition>) => void;
  setGenerating: (generating: boolean) => void;
  clearAll: () => void;
}

const DEFAULT_TRANSITION: Transition = {
  type: 'crossfade',
  duration: 0.5,
  easing: 'ease-in-out',
};

export function useSceneStore(initialScenes: Scene[] = []): SceneStore {
  const [scenes, setScenes] = useState<Scene[]>(initialScenes);
  const [transitions, setTransitions] = useState<Transition[]>([]);
  const [selectedSceneId, setSelectedSceneId] = useState<string | null>(null);
  const [isGenerating, setIsGenerating] = useState(false);

  const addScene = useCallback((scene: Scene) => {
    setScenes(prev => {
      const newScenes = [...prev, { ...scene, order: prev.length }];

      // Add transition if not first scene
      if (prev.length > 0) {
        setTransitions(t => [...t, { ...DEFAULT_TRANSITION }]);
      }

      return newScenes;
    });
  }, []);

  const updateScene = useCallback((id: string, updates: Partial<Scene>) => {
    setScenes(prev =>
      prev.map(scene =>
        scene.id === id ? { ...scene, ...updates } : scene
      )
    );
  }, []);

  const deleteScene = useCallback((id: string) => {
    setScenes(prev => {
      const index = prev.findIndex(s => s.id === id);
      if (index === -1) return prev;

      const newScenes = prev.filter(s => s.id !== id);

      // Update orders
      newScenes.forEach((s, i) => {
        s.order = i;
      });

      // Remove associated transition
      setTransitions(t => {
        if (index === 0 && t.length > 0) {
          return t.slice(1);
        } else if (index > 0) {
          return [...t.slice(0, index - 1), ...t.slice(index)];
        }
        return t;
      });

      return newScenes;
    });

    // Clear selection if deleted scene was selected
    setSelectedSceneId(prev => prev === id ? null : prev);
  }, []);

  const reorderScenes = useCallback((fromIndex: number, toIndex: number) => {
    if (fromIndex === toIndex) return;

    setScenes(prev => {
      const newScenes = [...prev];
      const [removed] = newScenes.splice(fromIndex, 1);
      newScenes.splice(toIndex, 0, removed);

      // Update orders
      newScenes.forEach((s, i) => {
        s.order = i;
      });

      return newScenes;
    });

    // Also reorder transitions
    setTransitions(prev => {
      if (prev.length === 0) return prev;

      const newTransitions = [...prev];

      // This is simplified - in production, you'd handle transition reordering more carefully
      if (fromIndex < toIndex) {
        const [removed] = newTransitions.splice(Math.min(fromIndex, prev.length - 1), 1);
        newTransitions.splice(Math.min(toIndex - 1, prev.length - 1), 0, removed || DEFAULT_TRANSITION);
      } else {
        const [removed] = newTransitions.splice(Math.min(fromIndex - 1, prev.length - 1), 1);
        newTransitions.splice(Math.min(toIndex, prev.length - 1), 0, removed || DEFAULT_TRANSITION);
      }

      return newTransitions;
    });
  }, []);

  const selectScene = useCallback((id: string | null) => {
    setSelectedSceneId(id);
  }, []);

  const updateTransition = useCallback((index: number, updates: Partial<Transition>) => {
    setTransitions(prev => {
      if (index < 0 || index >= prev.length) return prev;

      const newTransitions = [...prev];
      newTransitions[index] = { ...newTransitions[index], ...updates };
      return newTransitions;
    });
  }, []);

  const setGenerating = useCallback((generating: boolean) => {
    setIsGenerating(generating);
  }, []);

  const clearAll = useCallback(() => {
    setScenes([]);
    setTransitions([]);
    setSelectedSceneId(null);
    setIsGenerating(false);
  }, []);

  return useMemo(() => ({
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
    clearAll,
  }), [
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
    clearAll,
  ]);
}

export default useSceneStore;

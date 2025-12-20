/**
 * Scene Timeline Component
 *
 * Visual timeline for arranging scenes with drag-and-drop reordering
 * and transition editing.
 */

import React, { useState, useRef, useCallback } from 'react';
import type { Scene, Transition, DragState } from './types';

export interface SceneTimelineProps {
  scenes: Scene[];
  transitions: Transition[];
  selectedSceneId: string | null;
  onSceneSelect: (id: string) => void;
  onSceneReorder: (fromIndex: number, toIndex: number) => void;
  onTransitionClick: (index: number) => void;
}

export const SceneTimeline: React.FC<SceneTimelineProps> = ({
  scenes,
  transitions,
  selectedSceneId,
  onSceneSelect,
  onSceneReorder,
  onTransitionClick,
}) => {
  const [dragState, setDragState] = useState<DragState>({
    isDragging: false,
    draggedItemId: null,
    dragOverItemId: null,
    dropPosition: null,
  });

  const timelineRef = useRef<HTMLDivElement>(null);

  const totalDuration = scenes.reduce((sum, s) => sum + s.duration, 0) +
    transitions.reduce((sum, t) => sum + (t.duration || 0.5), 0);

  const getSceneWidth = (duration: number) => {
    return `${(duration / totalDuration) * 100}%`;
  };

  const getTransitionWidth = (duration: number = 0.5) => {
    return `${(duration / totalDuration) * 100}%`;
  };

  const handleDragStart = useCallback((e: React.DragEvent, sceneId: string) => {
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('text/plain', sceneId);

    setDragState({
      isDragging: true,
      draggedItemId: sceneId,
      dragOverItemId: null,
      dropPosition: null,
    });
  }, []);

  const handleDragOver = useCallback((e: React.DragEvent, sceneId: string) => {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';

    if (sceneId === dragState.draggedItemId) return;

    const rect = (e.target as HTMLElement).getBoundingClientRect();
    const x = e.clientX - rect.left;
    const dropPosition = x < rect.width / 2 ? 'before' : 'after';

    setDragState(prev => ({
      ...prev,
      dragOverItemId: sceneId,
      dropPosition,
    }));
  }, [dragState.draggedItemId]);

  const handleDragEnd = useCallback(() => {
    setDragState({
      isDragging: false,
      draggedItemId: null,
      dragOverItemId: null,
      dropPosition: null,
    });
  }, []);

  const handleDrop = useCallback((e: React.DragEvent, targetSceneId: string) => {
    e.preventDefault();

    const draggedId = e.dataTransfer.getData('text/plain');
    if (!draggedId || draggedId === targetSceneId) {
      handleDragEnd();
      return;
    }

    const fromIndex = scenes.findIndex(s => s.id === draggedId);
    let toIndex = scenes.findIndex(s => s.id === targetSceneId);

    if (dragState.dropPosition === 'after') {
      toIndex += 1;
    }

    if (fromIndex !== -1 && toIndex !== -1 && fromIndex !== toIndex) {
      onSceneReorder(fromIndex, toIndex);
    }

    handleDragEnd();
  }, [scenes, dragState.dropPosition, onSceneReorder, handleDragEnd]);

  const getSceneTypeColor = (type: Scene['type']) => {
    const colors: Record<Scene['type'], string> = {
      establishing: '#3b82f6',
      closeup: '#8b5cf6',
      action: '#ef4444',
      dialogue: '#22c55e',
      transition: '#f59e0b',
      montage: '#ec4899',
    };
    return colors[type] || '#6b7280';
  };

  return (
    <div className="scene-timeline" ref={timelineRef}>
      <div className="scene-timeline__ruler">
        {Array.from({ length: Math.ceil(totalDuration) + 1 }, (_, i) => (
          <div key={i} className="scene-timeline__tick" style={{ left: `${(i / totalDuration) * 100}%` }}>
            <span>{i}s</span>
          </div>
        ))}
      </div>

      <div className="scene-timeline__track">
        {scenes.map((scene, index) => (
          <React.Fragment key={scene.id}>
            <div
              className={`scene-timeline__scene ${
                scene.id === selectedSceneId ? 'scene-timeline__scene--selected' : ''
              } ${
                dragState.isDragging && scene.id === dragState.draggedItemId ? 'scene-timeline__scene--dragging' : ''
              } ${
                dragState.dragOverItemId === scene.id ? `scene-timeline__scene--drop-${dragState.dropPosition}` : ''
              }`}
              style={{
                width: getSceneWidth(scene.duration),
                backgroundColor: getSceneTypeColor(scene.type),
              }}
              draggable
              onClick={() => onSceneSelect(scene.id)}
              onDragStart={(e) => handleDragStart(e, scene.id)}
              onDragOver={(e) => handleDragOver(e, scene.id)}
              onDragEnd={handleDragEnd}
              onDrop={(e) => handleDrop(e, scene.id)}
            >
              <div className="scene-timeline__scene-content">
                <span className="scene-timeline__scene-number">{index + 1}</span>
                <span className="scene-timeline__scene-type">{scene.type}</span>
                <span className="scene-timeline__scene-duration">{scene.duration}s</span>
              </div>
              <div className="scene-timeline__scene-prompt">
                {scene.prompt || 'No prompt'}
              </div>
            </div>

            {index < scenes.length - 1 && (
              <div
                className="scene-timeline__transition"
                style={{ width: getTransitionWidth(transitions[index]?.duration) }}
                onClick={() => onTransitionClick(index)}
              >
                <span className="scene-timeline__transition-type">
                  {transitions[index]?.type || 'crossfade'}
                </span>
              </div>
            )}
          </React.Fragment>
        ))}
      </div>

      <div className="scene-timeline__playhead" />
    </div>
  );
};

export default SceneTimeline;

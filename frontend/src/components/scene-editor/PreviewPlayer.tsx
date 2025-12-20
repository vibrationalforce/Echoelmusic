/**
 * Preview Player Component
 *
 * Video preview player for multi-shot scene projects
 * with playback controls and scene navigation.
 */

import React, { useState, useEffect, useCallback, useMemo } from 'react';
import type { Scene, Transition } from './types';

export interface PreviewPlayerProps {
  scenes: Scene[];
  transitions: Transition[];
  currentSceneId: string | null;
  previewUrl?: string;
  onSeek?: (time: number) => void;
}

interface TimelineMarker {
  time: number;
  sceneId: string;
  sceneIndex: number;
}

export const PreviewPlayer: React.FC<PreviewPlayerProps> = ({
  scenes,
  transitions,
  currentSceneId,
  previewUrl,
  onSeek,
}) => {
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [volume, setVolume] = useState(1);
  const [isMuted, setIsMuted] = useState(false);

  const totalDuration = useMemo(() => {
    const sceneDuration = scenes.reduce((sum, s) => sum + s.duration, 0);
    const transitionDuration = transitions.reduce((sum, t) => sum + (t.duration || 0.5), 0);
    return sceneDuration + transitionDuration;
  }, [scenes, transitions]);

  const markers = useMemo<TimelineMarker[]>(() => {
    const result: TimelineMarker[] = [];
    let time = 0;

    scenes.forEach((scene, index) => {
      result.push({
        time,
        sceneId: scene.id,
        sceneIndex: index,
      });
      time += scene.duration;
      if (index < transitions.length) {
        time += transitions[index].duration || 0.5;
      }
    });

    return result;
  }, [scenes, transitions]);

  const currentSceneIndex = useMemo(() => {
    for (let i = markers.length - 1; i >= 0; i--) {
      if (currentTime >= markers[i].time) {
        return i;
      }
    }
    return 0;
  }, [currentTime, markers]);

  useEffect(() => {
    let animationFrame: number;

    if (isPlaying && currentTime < totalDuration) {
      const startTime = performance.now();
      const startPlayTime = currentTime;

      const animate = (now: number) => {
        const elapsed = (now - startTime) / 1000;
        const newTime = startPlayTime + elapsed;

        if (newTime >= totalDuration) {
          setCurrentTime(totalDuration);
          setIsPlaying(false);
        } else {
          setCurrentTime(newTime);
          animationFrame = requestAnimationFrame(animate);
        }
      };

      animationFrame = requestAnimationFrame(animate);
    }

    return () => {
      if (animationFrame) {
        cancelAnimationFrame(animationFrame);
      }
    };
  }, [isPlaying, currentTime, totalDuration]);

  const handlePlayPause = useCallback(() => {
    if (currentTime >= totalDuration) {
      setCurrentTime(0);
    }
    setIsPlaying(!isPlaying);
  }, [isPlaying, currentTime, totalDuration]);

  const handleSeek = useCallback((e: React.MouseEvent<HTMLDivElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const percent = x / rect.width;
    const newTime = percent * totalDuration;

    setCurrentTime(Math.max(0, Math.min(newTime, totalDuration)));
    onSeek?.(newTime);
  }, [totalDuration, onSeek]);

  const handleVolumeChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const newVolume = parseFloat(e.target.value);
    setVolume(newVolume);
    if (newVolume > 0) {
      setIsMuted(false);
    }
  }, []);

  const handleMuteToggle = useCallback(() => {
    setIsMuted(!isMuted);
  }, [isMuted]);

  const handleSkipPrevious = useCallback(() => {
    const targetIndex = Math.max(0, currentSceneIndex - 1);
    setCurrentTime(markers[targetIndex]?.time || 0);
  }, [currentSceneIndex, markers]);

  const handleSkipNext = useCallback(() => {
    const targetIndex = Math.min(scenes.length - 1, currentSceneIndex + 1);
    setCurrentTime(markers[targetIndex]?.time || 0);
  }, [currentSceneIndex, scenes.length, markers]);

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    const ms = Math.floor((seconds % 1) * 10);
    return `${mins}:${secs.toString().padStart(2, '0')}.${ms}`;
  };

  const progressPercent = (currentTime / totalDuration) * 100;

  return (
    <div className="preview-player">
      <div className="preview-player__video">
        {previewUrl ? (
          <video
            src={previewUrl}
            muted={isMuted}
            style={{ opacity: volume }}
          />
        ) : (
          <div className="preview-player__placeholder">
            <div className="preview-player__scene-indicator">
              Scene {currentSceneIndex + 1} of {scenes.length}
            </div>
            <p className="preview-player__prompt">
              {scenes[currentSceneIndex]?.prompt || 'No scenes'}
            </p>
          </div>
        )}
      </div>

      <div className="preview-player__controls">
        <div className="preview-player__buttons">
          <button
            className="preview-player__btn"
            onClick={handleSkipPrevious}
            disabled={currentSceneIndex === 0}
          >
            ⏮
          </button>

          <button
            className="preview-player__btn preview-player__btn--play"
            onClick={handlePlayPause}
          >
            {isPlaying ? '⏸' : '▶'}
          </button>

          <button
            className="preview-player__btn"
            onClick={handleSkipNext}
            disabled={currentSceneIndex === scenes.length - 1}
          >
            ⏭
          </button>
        </div>

        <div className="preview-player__time">
          {formatTime(currentTime)} / {formatTime(totalDuration)}
        </div>

        <div className="preview-player__progress" onClick={handleSeek}>
          <div
            className="preview-player__progress-bar"
            style={{ width: `${progressPercent}%` }}
          />
          {markers.map((marker, index) => (
            <div
              key={marker.sceneId}
              className={`preview-player__marker ${
                index === currentSceneIndex ? 'preview-player__marker--active' : ''
              }`}
              style={{ left: `${(marker.time / totalDuration) * 100}%` }}
            />
          ))}
        </div>

        <div className="preview-player__volume">
          <button
            className="preview-player__btn preview-player__btn--mute"
            onClick={handleMuteToggle}
          >
            {isMuted || volume === 0 ? '🔇' : volume < 0.5 ? '🔉' : '🔊'}
          </button>
          <input
            type="range"
            className="preview-player__volume-slider"
            min="0"
            max="1"
            step="0.1"
            value={isMuted ? 0 : volume}
            onChange={handleVolumeChange}
          />
        </div>
      </div>
    </div>
  );
};

export default PreviewPlayer;

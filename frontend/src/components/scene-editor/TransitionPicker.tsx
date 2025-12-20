/**
 * Transition Picker Component
 *
 * Modal for selecting transition types between scenes.
 */

import React from 'react';
import type { TransitionType } from './types';

export interface TransitionPickerProps {
  currentType?: TransitionType;
  onSelect: (type: TransitionType) => void;
  onClose: () => void;
}

interface TransitionOption {
  type: TransitionType;
  name: string;
  description: string;
  icon: string;
  preview?: string;
}

const TRANSITION_OPTIONS: TransitionOption[] = [
  {
    type: 'cut',
    name: 'Cut',
    description: 'Instant cut between scenes',
    icon: '✂️',
  },
  {
    type: 'crossfade',
    name: 'Crossfade',
    description: 'Smooth blend between scenes',
    icon: '🔄',
  },
  {
    type: 'wipe',
    name: 'Wipe',
    description: 'Wipe transition with direction',
    icon: '➡️',
  },
  {
    type: 'zoom',
    name: 'Zoom',
    description: 'Zoom in/out transition',
    icon: '🔍',
  },
  {
    type: 'blur',
    name: 'Blur',
    description: 'Blur to blur transition',
    icon: '🌫️',
  },
  {
    type: 'morph',
    name: 'Morph',
    description: 'AI-powered scene morphing',
    icon: '✨',
  },
];

export const TransitionPicker: React.FC<TransitionPickerProps> = ({
  currentType,
  onSelect,
  onClose,
}) => {
  return (
    <div className="transition-picker__overlay" onClick={onClose}>
      <div className="transition-picker" onClick={(e) => e.stopPropagation()}>
        <div className="transition-picker__header">
          <h2>Choose Transition</h2>
          <button className="transition-picker__close" onClick={onClose}>
            ×
          </button>
        </div>

        <div className="transition-picker__grid">
          {TRANSITION_OPTIONS.map((option) => (
            <div
              key={option.type}
              className={`transition-picker__option ${
                option.type === currentType ? 'transition-picker__option--selected' : ''
              }`}
              onClick={() => onSelect(option.type)}
            >
              <div className="transition-picker__icon">{option.icon}</div>
              <div className="transition-picker__info">
                <h3 className="transition-picker__name">{option.name}</h3>
                <p className="transition-picker__description">{option.description}</p>
              </div>
              {option.type === currentType && (
                <div className="transition-picker__check">✓</div>
              )}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default TransitionPicker;

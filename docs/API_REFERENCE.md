# Echoelmusic Video Generation API Reference

> **World-Class AI-Powered Video Generation Platform**
>
> Version: 1.0.0 | Last Updated: December 2025

## Overview

Echoelmusic offers a state-of-the-art text-to-video generation API powered by the Wan2.2-T2V-14B model with 10 Super Genius AI Features for next-level video creation.

### Base URL

```
Production: https://api.echoelmusic.com/v1
Staging: https://staging-api.echoelmusic.com/v1
```

### Authentication

All API requests require authentication via API key:

```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
     https://api.echoelmusic.com/v1/generate
```

---

## Core Endpoints

### Generate Video

Start a video generation task.

```http
POST /generate
```

**Request Body:**

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `prompt` | string | Yes | - | Text description (1-2000 chars) |
| `negative_prompt` | string | No | "blurry, low quality" | What to avoid |
| `duration_seconds` | float | No | 4.0 | Duration (1-60 seconds) |
| `fps` | integer | No | 24 | Frames per second (12-60) |
| `resolution` | string | No | "720p" | 480p/720p/1080p/1440p/4k/8k |
| `aspect_ratio` | string | No | "16:9" | 16:9/9:16/1:1/4:3 |
| `genre` | string | No | "cinematic" | Style genre |
| `seed` | integer | No | random | Reproducibility seed |
| `guidance_scale` | float | No | 7.5 | Prompt adherence (1-20) |
| `num_inference_steps` | integer | No | 50 | Quality steps (10-150) |
| `webhook_url` | string | No | - | Callback URL |

**Example Request:**

```bash
curl -X POST https://api.echoelmusic.com/v1/generate \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "A majestic dragon soaring over misty mountains at sunrise",
    "duration_seconds": 8,
    "resolution": "1080p",
    "genre": "fantasy"
  }'
```

**Example Response:**

```json
{
  "task_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "status": "pending",
  "message": "Task queued for processing",
  "estimated_time_seconds": 120,
  "queue_position": 1
}
```

### Check Status

```http
GET /status/{task_id}
```

**Response:**

```json
{
  "task_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "status": "generating_base",
  "progress": 0.45,
  "current_step": "Denoising step 25/50",
  "elapsed_seconds": 45.2,
  "eta_seconds": 75.0,
  "preview_url": "/previews/a1b2c3d4.jpg"
}
```

### Get Result

```http
GET /result/{task_id}
```

**Response:**

```json
{
  "task_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "status": "completed",
  "video_url": "/videos/a1b2c3d4.mp4",
  "thumbnail_url": "/thumbnails/a1b2c3d4.jpg",
  "duration_seconds": 8.0,
  "resolution": "1080p",
  "file_size_mb": 45.2,
  "generation_time_seconds": 120.5,
  "metadata": {
    "prompt": "A majestic dragon...",
    "model": "wan2.2-t2v-14b",
    "seed": 42
  }
}
```

---

## Super Genius AI Features

### 1. Model Orchestrator

Intelligent model selection based on prompt complexity and resource constraints.

#### Select Optimal Model

```http
POST /genius/orchestrator/select-model
```

**Request:**

```json
{
  "prompt": "Complex cinematic scene with multiple characters...",
  "duration_seconds": 10,
  "target_resolution": "4k",
  "max_vram_gb": 24,
  "prefer_quality": true
}
```

**Response:**

```json
{
  "recommended_model": "wan2.2-t2v-14b",
  "complexity": "complex",
  "confidence": 0.92,
  "estimated_time_seconds": 180,
  "vram_required_gb": 24.0,
  "alternatives": [
    {"model": "wan2.2-t2v-7b", "vram_gb": 16.0, "speed_factor": 1.5},
    {"model": "wan2.2-t2v-1.3b", "vram_gb": 8.0, "speed_factor": 2.0}
  ]
}
```

---

### 2. Scene Orchestrator

Multi-shot video editing with automatic transitions and character consistency.

#### Create Multi-Shot Edit

```http
POST /genius/scene/edit
```

**Request:**

```json
{
  "scenes": [
    {"prompt": "Establishing shot: medieval castle at dawn", "duration": 3},
    {"prompt": "Close-up: knight preparing armor", "duration": 4},
    {"prompt": "Action: knight rides through forest", "duration": 5}
  ],
  "enable_auto_transitions": true,
  "transition_duration_seconds": 0.5,
  "enable_character_consistency": true
}
```

**Response:**

```json
{
  "task_id": "scene-123",
  "total_scenes": 3,
  "total_duration_seconds": 12,
  "transitions": [
    {"from_scene": 0, "to_scene": 1, "type": "crossfade", "duration": 0.5},
    {"from_scene": 1, "to_scene": 2, "type": "crossfade", "duration": 0.5}
  ],
  "estimated_time_seconds": 180
}
```

#### Available Transitions

```http
GET /genius/scene/transitions
```

| Type | Description |
|------|-------------|
| `cut` | Instant cut |
| `crossfade` | Smooth blend |
| `wipe` | Directional wipe |
| `zoom` | Zoom transition |
| `blur` | Blur effect |
| `morph` | AI-powered morphing |

---

### 3. Batch Inference

VRAM-aware batch processing with priority scheduling.

#### Submit Batch

```http
POST /genius/batch/submit
```

**Request:**

```json
{
  "prompts": [
    "Sunset over ocean waves",
    "City skyline at night",
    "Forest in autumn colors"
  ],
  "priority": "high",
  "enable_similarity_caching": true,
  "max_concurrent": 4,
  "vram_budget_gb": 48
}
```

**Response:**

```json
{
  "batch_id": "batch-456",
  "task_ids": ["task-1", "task-2", "task-3"],
  "total": 3,
  "estimated_time_seconds": 90,
  "queue_position": 1
}
```

---

### 4. Progressive Streaming

Real-time frame preview during generation via WebSocket.

#### Start Stream Session

```http
POST /genius/stream/start
```

**Request:**

```json
{
  "task_id": "a1b2c3d4",
  "initial_quality": "preview",
  "enable_adaptive": true
}
```

#### WebSocket Connection

```javascript
const ws = new WebSocket('wss://api.echoelmusic.com/genius/stream/ws/session-id');

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);

  switch(data.type) {
    case 'frame_available':
      displayFrame(data.frame_index, data.quality);
      updateProgress(data.progress);
      break;
    case 'complete':
      console.log(`Generation complete: ${data.total_frames} frames`);
      break;
  }
};
```

---

### 5. Lip-Sync Engine

Audio-driven lip synchronization with MPEG-4 viseme support.

#### Generate Lip Sync

```http
POST /genius/lipsync/generate
```

**Request:**

```json
{
  "task_id": "video-task-id",
  "audio_url": "https://example.com/speech.wav",
  "face_region": [100, 100, 300, 300],
  "expression": "happy",
  "intensity": 1.0
}
```

**Response:**

```json
{
  "task_id": "video-task-id",
  "keyframes_generated": 240,
  "duration_seconds": 10.0,
  "visemes_detected": 45,
  "processing_time_ms": 1250
}
```

#### Viseme Shapes

| Viseme | Description | Mouth Shape |
|--------|-------------|-------------|
| `PP` | Bilabial (P, B, M) | Lips closed |
| `FF` | Labiodental (F, V) | Lower lip touches teeth |
| `AA` | Open vowel (A) | Wide open |
| `EE` | Front vowel (E, I) | Wide smile |
| `OO` | Round vowel (O, U) | Pursed lips |

---

### 6. Video Inpainting

Object removal, replacement, and blending with flow-guided masks.

#### Inpaint Video

```http
POST /genius/inpaint/process
```

**Request:**

```json
{
  "task_id": "video-task-id",
  "mode": "remove",
  "bbox": [100, 150, 200, 250],
  "feather_radius": 10
}
```

| Mode | Description |
|------|-------------|
| `remove` | Remove object (AI fill) |
| `replace` | Replace with prompt |
| `blend` | Blend overlay |
| `background` | Replace background |
| `extend` | Extend canvas |

---

### 7. Speculative Decoder

2-3x faster decoding with draft model speculation.

#### Get Decoder Stats

```http
GET /genius/decoder/stats
```

**Response:**

```json
{
  "total_tokens": 100000,
  "accepted_tokens": 85000,
  "acceptance_rate": 0.85,
  "speedup_factor": 2.4,
  "average_draft_time_ms": 5.0,
  "average_verify_time_ms": 15.0
}
```

---

### 8. Consistency Tracker

Cross-frame character and object tracking.

#### Register Entity

```http
POST /genius/consistency/register-entity
```

**Request:**

```json
{
  "name": "Hero Character",
  "entity_type": "character",
  "reference_image_base64": "base64_encoded_image..."
}
```

#### Track in Video

```http
POST /genius/consistency/track/{task_id}
```

**Response:**

```json
{
  "task_id": "video-task-id",
  "entities_tracked": 3,
  "frames_analyzed": 100,
  "consistency_score": 0.92,
  "entity_timelines": {
    "hero": [
      {"frame": 0, "bbox": [100, 100, 200, 200], "confidence": 0.95}
    ]
  }
}
```

---

### 9. SLA Monitor

Performance metrics and SLA compliance tracking.

#### Get SLA Status

```http
GET /genius/sla/status
```

**Response:**

```json
{
  "target_level": "standard",
  "meets_sla": true,
  "uptime_percent": 99.9,
  "latency_p50_ms": 150,
  "latency_p95_ms": 450,
  "latency_p99_ms": 800,
  "error_rate_percent": 0.1,
  "current_throughput_rps": 25.5,
  "violations": []
}
```

#### SLA Levels

| Level | Uptime | p99 Latency | Error Rate |
|-------|--------|-------------|------------|
| `best_effort` | 95% | 30s | 5% |
| `standard` | 99% | 5s | 1% |
| `premium` | 99.9% | 1s | 0.1% |
| `critical` | 99.99% | 200ms | 0.01% |

---

### 10. V2V Pipeline

Video-to-video transformation suite.

#### Transform Video

```http
POST /genius/v2v/transform
```

**Request:**

```json
{
  "source_task_id": "original-video-id",
  "mode": "style_transfer",
  "strength": 0.7,
  "style_reference_url": "https://example.com/style.jpg",
  "preserve_motion": true,
  "temporal_consistency": 0.8
}
```

#### Transformation Modes

| Mode | Description | Reference Required |
|------|-------------|-------------------|
| `style_transfer` | Apply artistic style | Yes (image) |
| `motion_transfer` | Transfer motion | Yes (video) |
| `enhancement` | Improve quality | No |
| `upscale` | Increase resolution | No |
| `interpolation` | Increase frame rate | No |
| `colorization` | Add color to B&W | No |

---

## WebSocket Events

Real-time progress updates via WebSocket.

```http
WS /ws/{task_id}
```

### Event Types

```javascript
// Progress update
{
  "type": "progress",
  "progress": 0.45,
  "step": "Denoising step 25/50"
}

// Frame available (progressive streaming)
{
  "type": "frame_available",
  "frame_index": 42,
  "quality": "preview"
}

// Generation complete
{
  "type": "complete",
  "video_url": "/videos/task-id.mp4"
}

// Error
{
  "type": "error",
  "error": "VRAM exceeded"
}
```

---

## Webhooks

Receive notifications when tasks complete.

### Events

| Event | Description |
|-------|-------------|
| `task.created` | Task queued |
| `task.started` | Processing began |
| `task.progress` | Progress update |
| `task.completed` | Success |
| `task.failed` | Error |

### Payload

```json
{
  "event": "task.completed",
  "task_id": "a1b2c3d4",
  "timestamp": "2025-12-20T12:00:00Z",
  "data": {
    "video_url": "/videos/a1b2c3d4.mp4",
    "duration_seconds": 8.0
  }
}
```

### Signature Verification

```python
import hmac
import hashlib

def verify_webhook(payload, signature, secret):
    expected = hmac.new(
        secret.encode(),
        payload.encode(),
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(f"sha256={expected}", signature)
```

---

## Rate Limits

| Endpoint | Rate | Burst |
|----------|------|-------|
| `/generate` | 1 req/2s | 5 |
| `/batch` | 1 req/10s | 2 |
| Other endpoints | 10 req/s | 50 |

Rate limit headers:

```
X-RateLimit-Limit: 10
X-RateLimit-Remaining: 8
X-RateLimit-Reset: 1703059200
```

---

## Error Codes

| Code | Description |
|------|-------------|
| 400 | Bad Request - Invalid parameters |
| 401 | Unauthorized - Invalid API key |
| 403 | Forbidden - Access denied |
| 404 | Not Found - Task not found |
| 429 | Too Many Requests - Rate limited |
| 500 | Internal Server Error |
| 503 | Service Unavailable - Maintenance |

**Error Response:**

```json
{
  "error": "Validation error",
  "detail": "duration_seconds must be between 1 and 60",
  "type": "ValueError"
}
```

---

## SDKs

### Python

```python
from echoelmusic import VideoGenClient

client = VideoGenClient(api_key="YOUR_API_KEY")

# Generate video
result = await client.generate(
    prompt="A serene lake at sunset",
    duration_seconds=8,
    resolution="1080p"
)

print(f"Video URL: {result.video_url}")
```

### JavaScript/TypeScript

```typescript
import { EchoelClient } from '@echoelmusic/sdk';

const client = new EchoelClient({ apiKey: 'YOUR_API_KEY' });

const result = await client.generate({
  prompt: 'A serene lake at sunset',
  durationSeconds: 8,
  resolution: '1080p'
});

console.log(`Video URL: ${result.videoUrl}`);
```

---

## Support

- Documentation: https://docs.echoelmusic.com
- API Status: https://status.echoelmusic.com
- Support Email: api-support@echoelmusic.com
- Discord: https://discord.gg/echoelmusic

---

*Copyright 2025 Echoelmusic. All rights reserved.*

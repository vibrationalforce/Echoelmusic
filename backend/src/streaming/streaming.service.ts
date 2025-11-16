// Multi-Platform Streaming Service
// RTMP streaming to Twitch, YouTube, Facebook Live, etc.
import { PrismaClient } from '@prisma/client';
import { AppError } from '../middleware/error.middleware';
import crypto from 'crypto';

const prisma = new PrismaClient();

// Platform-specific configurations
const STREAMING_PLATFORMS = {
  TWITCH: {
    rtmpUrl: 'rtmp://live.twitch.tv/app',
    requiresKey: true,
    keyFormat: 'live_XXXXXXXXX_YYYYYYYYYYYYYYYYYYYYYY'
  },
  YOUTUBE: {
    rtmpUrl: 'rtmp://a.rtmp.youtube.com/live2',
    requiresKey: true,
    keyFormat: 'XXXX-XXXX-XXXX-XXXX'
  },
  FACEBOOK: {
    rtmpUrl: 'rtmps://live-api-s.facebook.com:443/rtmp',
    requiresKey: true,
    keyFormat: 'FB-XXXXXXXXXXXXXXXXXX'
  },
  INSTAGRAM: {
    rtmpUrl: 'rtmps://live-upload.instagram.com:443/rtmp',
    requiresKey: true,
    keyFormat: 'rtmp stream key'
  },
  TIKTOK: {
    rtmpUrl: 'rtmp://webcast.tiktok.com/live',
    requiresKey: true,
    keyFormat: 'stream key'
  }
};

export interface CreateStreamInput {
  title: string;
  description?: string;
  scheduledAt?: Date;
  destinations: Array<{
    platform: 'TWITCH' | 'YOUTUBE' | 'FACEBOOK' | 'INSTAGRAM' | 'TIKTOK' | 'CUSTOM_RTMP';
    platformKey: string;
    enabled?: boolean;
    customRtmpUrl?: string; // For CUSTOM_RTMP
  }>;
  hrvEnabled?: boolean;
}

export class StreamingService {
  /**
   * Create live stream
   */
  async createStream(
    userId: string,
    input: CreateStreamInput
  ): Promise<any> {
    // Check user subscription (streaming requires PRO+)
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new AppError('User not found', 404);
    }

    if (user.subscription === 'FREE') {
      throw new AppError('Live streaming requires Pro subscription', 403);
    }

    // Generate unique stream key
    const streamKey = this.generateStreamKey();

    // Create our RTMP ingest URL (would be your media server)
    const rtmpUrl = `${process.env.RTMP_SERVER_URL || 'rtmp://stream.echoelmusic.com:1935/live'}`;

    // Create stream
    const stream = await prisma.liveStream.create({
      data: {
        userId,
        title: input.title,
        description: input.description,
        streamKey,
        rtmpUrl,
        status: input.scheduledAt ? 'SCHEDULED' : 'LIVE',
        scheduledAt: input.scheduledAt,
        hrvEnabled: input.hrvEnabled || false
      }
    });

    // Create stream destinations
    for (const dest of input.destinations) {
      const platformConfig = STREAMING_PLATFORMS[dest.platform];
      const platformUrl = dest.platform === 'CUSTOM_RTMP'
        ? dest.customRtmpUrl
        : platformConfig?.rtmpUrl;

      if (!platformUrl) {
        console.warn(`Invalid platform: ${dest.platform}`);
        continue;
      }

      await prisma.streamDestination.create({
        data: {
          streamId: stream.id,
          platform: dest.platform,
          platformKey: dest.platformKey,
          platformUrl,
          enabled: dest.enabled !== false
        }
      });
    }

    return this.getStreamById(stream.id);
  }

  /**
   * Start streaming
   */
  async startStream(streamId: string): Promise<any> {
    const stream = await this.getStreamById(streamId);

    if (stream.status === 'LIVE') {
      throw new AppError('Stream is already live', 400);
    }

    // Update stream status
    const updatedStream = await prisma.liveStream.update({
      where: { id: streamId },
      data: {
        status: 'LIVE',
        startedAt: new Date()
      },
      include: {
        destinations: true
      }
    });

    // TODO: Start RTMP restreaming to all enabled destinations
    // This would use FFmpeg to replicate the incoming stream to multiple destinations
    // Example: ffmpeg -i rtmp://input -c copy -f flv rtmp://platform1 -f flv rtmp://platform2

    return updatedStream;
  }

  /**
   * Stop streaming
   */
  async stopStream(streamId: string): Promise<any> {
    const stream = await this.getStreamById(streamId);

    if (stream.status !== 'LIVE') {
      throw new AppError('Stream is not live', 400);
    }

    // Calculate duration
    const duration = stream.startedAt
      ? Math.floor((Date.now() - stream.startedAt.getTime()) / 1000)
      : 0;

    // Update stream status
    const updatedStream = await prisma.liveStream.update({
      where: { id: streamId },
      data: {
        status: 'ENDED',
        endedAt: new Date(),
        duration
      },
      include: {
        destinations: true
      }
    });

    // TODO: Stop FFmpeg restreaming processes

    return updatedStream;
  }

  /**
   * Update stream analytics
   */
  async updateStreamAnalytics(
    streamId: string,
    viewers: number
  ): Promise<void> {
    const stream = await prisma.liveStream.findUnique({ where: { id: streamId } });
    if (!stream) return;

    await prisma.liveStream.update({
      where: { id: streamId },
      data: {
        totalViewers: { increment: viewers },
        peakViewers: Math.max(stream.peakViewers, viewers)
      }
    });
  }

  /**
   * Get stream by ID
   */
  async getStreamById(streamId: string): Promise<any> {
    const stream = await prisma.liveStream.findUnique({
      where: { id: streamId },
      include: {
        destinations: true,
        user: {
          select: {
            id: true,
            name: true,
            username: true,
            avatar: true
          }
        }
      }
    });

    if (!stream) {
      throw new AppError('Stream not found', 404);
    }

    return stream;
  }

  /**
   * Get user's streams
   */
  async getUserStreams(userId: string): Promise<any[]> {
    return prisma.liveStream.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      include: {
        destinations: true
      }
    });
  }

  /**
   * Get live streams (for discovery)
   */
  async getLiveStreams(
    page: number = 1,
    limit: number = 20
  ): Promise<{ streams: any[]; total: number }> {
    const skip = (page - 1) * limit;

    const [streams, total] = await Promise.all([
      prisma.liveStream.findMany({
        where: { status: 'LIVE' },
        orderBy: { startedAt: 'desc' },
        skip,
        take: limit,
        include: {
          user: {
            select: {
              id: true,
              name: true,
              username: true,
              avatar: true
            }
          }
        }
      }),
      prisma.liveStream.count({ where: { status: 'LIVE' } })
    ]);

    return { streams, total };
  }

  /**
   * Add/update destination
   */
  async updateDestination(
    streamId: string,
    destinationId: string,
    enabled: boolean
  ): Promise<void> {
    await prisma.streamDestination.update({
      where: { id: destinationId },
      data: { enabled }
    });

    // TODO: Start/stop restreaming to this destination if stream is live
  }

  /**
   * Log biometric data during stream
   */
  async logBiometricData(
    streamId: string,
    hrvData: any,
    gestureData?: any
  ): Promise<void> {
    const stream = await prisma.liveStream.findUnique({ where: { id: streamId } });
    if (!stream || !stream.hrvEnabled) return;

    // Append to biometric log
    const currentLog = stream.biometricData ? JSON.parse(stream.biometricData) : [];
    currentLog.push({
      timestamp: Date.now(),
      hrv: hrvData,
      gesture: gestureData
    });

    await prisma.liveStream.update({
      where: { id: streamId },
      data: {
        biometricData: JSON.stringify(currentLog.slice(-1000)) // Keep last 1000 entries
      }
    });
  }

  /**
   * Generate unique stream key
   */
  private generateStreamKey(): string {
    return crypto.randomBytes(16).toString('hex');
  }

  /**
   * Get RTMP configuration for streaming software (OBS, etc.)
   */
  getRTMPConfig(streamId: string): {
    server: string;
    streamKey: string;
    instructions: string;
  } {
    return {
      server: process.env.RTMP_SERVER_URL || 'rtmp://stream.echoelmusic.com:1935/live',
      streamKey: streamId,
      instructions: `
1. Open your streaming software (OBS Studio, Streamlabs, etc.)
2. Settings → Stream
3. Service: Custom
4. Server: ${process.env.RTMP_SERVER_URL}
5. Stream Key: ${streamId}
6. Click "Start Streaming"

Your stream will be automatically rebroadcast to all enabled platforms!
      `.trim()
    };
  }
}

export default new StreamingService();

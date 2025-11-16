// Music Distribution Service
// Distributes music to Spotify, Apple Music, YouTube Music, etc.
import { PrismaClient } from '@prisma/client';
import { AppError } from '../middleware/error.middleware';
import axios from 'axios';

const prisma = new PrismaClient();

// Distribution Platform APIs
const PLATFORM_APIS = {
  SPOTIFY: {
    apiUrl: 'https://api.spotify.com/v1',
    submitEndpoint: '/releases',
    requiresPartner: true // Requires Spotify for Artists partnership
  },
  APPLE_MUSIC: {
    apiUrl: 'https://api.music.apple.com/v1',
    submitEndpoint: '/catalog/releases',
    requiresPartner: true // Requires Apple Music for Artists
  },
  // For MVP, we'll use a distribution aggregator like DistroKid API
  DISTROKID: {
    apiUrl: process.env.DISTROKID_API_URL || 'https://api.distrokid.com',
    apiKey: process.env.DISTROKID_API_KEY
  }
};

export interface CreateReleaseInput {
  title: string;
  artistName: string;
  genre: string;
  releaseDate: Date;
  label?: string;
  copyrightYear: number;
  copyrightHolder: string;
  albumArt?: Buffer;
  tracks: Array<{
    title: string;
    artists: string;
    audioFile: Buffer;
    trackNumber: number;
  }>;
}

export interface DistributionPlatform {
  platform: 'SPOTIFY' | 'APPLE_MUSIC' | 'YOUTUBE_MUSIC' | 'AMAZON_MUSIC' | 'TIDAL' | 'DEEZER';
  enabled: boolean;
}

export class DistributionService {
  /**
   * Create release
   */
  async createRelease(
    userId: string,
    input: CreateReleaseInput,
    audioFiles: Map<number, Buffer>,
    albumArtFile?: Buffer
  ): Promise<any> {
    // Upload album art to S3
    let albumArtUrl: string | undefined;
    if (albumArtFile) {
      // TODO: Upload to S3
      albumArtUrl = 'https://s3.amazonaws.com/...';
    }

    // Generate UPC (Universal Product Code)
    const upc = this.generateUPC();

    // Create release
    const release = await prisma.release.create({
      data: {
        userId,
        title: input.title,
        artistName: input.artistName,
        genre: input.genre,
        releaseDate: input.releaseDate,
        label: input.label,
        copyrightYear: input.copyrightYear,
        copyrightHolder: input.copyrightHolder,
        albumArt: albumArtUrl,
        upc,
        status: 'DRAFT'
      }
    });

    // Create tracks
    for (const [trackNumber, audioBuffer] of audioFiles.entries()) {
      const trackData = input.tracks.find(t => t.trackNumber === trackNumber);
      if (!trackData) continue;

      // Upload audio to S3
      // TODO: Upload to S3
      const audioUrl = `https://s3.amazonaws.com/track-${trackNumber}.wav`;

      // Generate ISRC (International Standard Recording Code)
      const isrc = this.generateISRC(userId, trackNumber);

      await prisma.track.create({
        data: {
          releaseId: release.id,
          title: trackData.title,
          artists: trackData.artists,
          audioUrl,
          trackNumber,
          isrc,
          duration: 0 // TODO: Calculate from audio file
        }
      });
    }

    return this.getReleaseById(release.id);
  }

  /**
   * Submit release to distribution platforms
   */
  async submitRelease(
    releaseId: string,
    platforms: DistributionPlatform[]
  ): Promise<any> {
    const release = await this.getReleaseById(releaseId);

    if (release.status !== 'DRAFT') {
      throw new AppError('Release already submitted', 400);
    }

    // Update release status
    await prisma.release.update({
      where: { id: releaseId },
      data: { status: 'SUBMITTED' }
    });

    // Submit to each platform
    for (const platform of platforms) {
      if (!platform.enabled) continue;

      try {
        await this.submitToPlatform(release, platform.platform);

        // Create distribution record
        await prisma.distribution.create({
          data: {
            releaseId,
            platform: platform.platform,
            status: 'SUBMITTED',
            submittedAt: new Date()
          }
        });
      } catch (error) {
        console.error(`Failed to submit to ${platform.platform}:`, error);
        // Create failed distribution record
        await prisma.distribution.create({
          data: {
            releaseId,
            platform: platform.platform,
            status: 'FAILED',
            submittedAt: new Date()
          }
        });
      }
    }

    return this.getReleaseById(releaseId);
  }

  /**
   * Submit to specific platform (via DistroKid or direct API)
   */
  private async submitToPlatform(release: any, platform: string): Promise<void> {
    // For MVP, use DistroKid API as aggregator
    const apiUrl = PLATFORM_APIS.DISTROKID.apiUrl;
    const apiKey = PLATFORM_APIS.DISTROKID.apiKey;

    if (!apiUrl || !apiKey) {
      throw new AppError('Distribution API not configured', 500);
    }

    // Prepare submission data
    const submissionData = {
      release: {
        title: release.title,
        artist: release.artistName,
        upc: release.upc,
        genre: release.genre,
        releaseDate: release.releaseDate.toISOString().split('T')[0],
        label: release.label,
        copyrightYear: release.copyrightYear,
        copyrightHolder: release.copyrightHolder,
        albumArt: release.albumArt
      },
      tracks: release.tracks.map((track: any) => ({
        title: track.title,
        artists: track.artists,
        isrc: track.isrc,
        audioUrl: track.audioUrl,
        trackNumber: track.trackNumber
      })),
      platforms: [platform]
    };

    // Submit via API
    try {
      const response = await axios.post(`${apiUrl}/releases`, submissionData, {
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json'
        }
      });

      console.log(`Submitted to ${platform}:`, response.data);
    } catch (error: any) {
      console.error(`Platform submission error:`, error.response?.data || error.message);
      throw new AppError(`Failed to submit to ${platform}`, 500);
    }
  }

  /**
   * Get release with tracks and distributions
   */
  async getReleaseById(releaseId: string): Promise<any> {
    const release = await prisma.release.findUnique({
      where: { id: releaseId },
      include: {
        tracks: {
          orderBy: { trackNumber: 'asc' }
        },
        distributions: true
      }
    });

    if (!release) {
      throw new AppError('Release not found', 404);
    }

    return release;
  }

  /**
   * Get user's releases
   */
  async getUserReleases(userId: string): Promise<any[]> {
    return prisma.release.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      include: {
        tracks: true,
        distributions: true
      }
    });
  }

  /**
   * Update distribution analytics (called by webhooks)
   */
  async updateDistributionAnalytics(
    distributionId: string,
    streams: number,
    revenue: number
  ): Promise<void> {
    await prisma.distribution.update({
      where: { id: distributionId },
      data: {
        streams: { increment: streams },
        revenue: { increment: revenue }
      }
    });
  }

  /**
   * Get analytics for release
   */
  async getReleaseAnalytics(releaseId: string): Promise<any> {
    const distributions = await prisma.distribution.findMany({
      where: { releaseId }
    });

    const totalStreams = distributions.reduce((sum, d) => sum + d.streams, 0);
    const totalRevenue = distributions.reduce((sum, d) => sum + d.revenue, 0);

    return {
      totalStreams,
      totalRevenue,
      platforms: distributions.map(d => ({
        platform: d.platform,
        streams: d.streams,
        revenue: d.revenue,
        status: d.status
      }))
    };
  }

  /**
   * Generate UPC (Universal Product Code)
   */
  private generateUPC(): string {
    // UPC is typically 12 digits
    // For demo, generate random UPC
    // In production, you'd request from a UPC provider
    const prefix = '8'; // Music prefix
    const companyCode = '12345';
    const productCode = Math.floor(Math.random() * 100000).toString().padStart(5, '0');
    const checkDigit = this.calculateUPCCheckDigit(prefix + companyCode + productCode);

    return prefix + companyCode + productCode + checkDigit;
  }

  /**
   * Calculate UPC check digit
   */
  private calculateUPCCheckDigit(code: string): string {
    let sum = 0;
    for (let i = 0; i < code.length; i++) {
      const digit = parseInt(code[i]);
      sum += (i % 2 === 0) ? digit * 3 : digit;
    }
    const checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit.toString();
  }

  /**
   * Generate ISRC (International Standard Recording Code)
   */
  private generateISRC(userId: string, trackNumber: number): string {
    // ISRC format: CC-XXX-YY-NNNNN
    // CC = Country code (US)
    // XXX = Registrant code (unique to label)
    // YY = Year
    // NNNNN = Designation code
    const countryCode = 'US';
    const registrantCode = userId.substring(0, 3).toUpperCase().padStart(3, 'X');
    const year = new Date().getFullYear().toString().substring(2);
    const designation = trackNumber.toString().padStart(5, '0');

    return `${countryCode}-${registrantCode}-${year}-${designation}`;
  }

  /**
   * Takedown release from platforms
   */
  async takedownRelease(releaseId: string): Promise<void> {
    await prisma.release.update({
      where: { id: releaseId },
      data: { status: 'TAKEDOWN' }
    });

    await prisma.distribution.updateMany({
      where: { releaseId },
      data: { status: 'TAKEDOWN' }
    });

    // TODO: Call platform APIs to remove content
  }
}

export default new DistributionService();

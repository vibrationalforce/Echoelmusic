// Distribution Controller
import { Response } from 'express';
import { asyncHandler } from '../middleware/error.middleware';
import { AuthRequest } from '../middleware/auth.middleware';
import distributionService from './distribution.service';
import multer from 'multer';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 200 * 1024 * 1024 } // 200MB
});

export class DistributionController {
  /**
   * Create release
   */
  createRelease = [
    upload.fields([
      { name: 'albumArt', maxCount: 1 },
      { name: 'tracks', maxCount: 20 }
    ]),
    asyncHandler(async (req: AuthRequest, res: Response) => {
      if (!req.userId) {
        return res.status(401).json({ error: 'Unauthorized' });
      }

      const files = req.files as { [fieldname: string]: Express.Multer.File[] };
      const {
        title,
        artistName,
        genre,
        releaseDate,
        label,
        copyrightYear,
        copyrightHolder,
        tracksMetadata // JSON string
      } = req.body;

      if (!files.tracks || files.tracks.length === 0) {
        return res.status(400).json({ error: 'At least one track is required' });
      }

      // Parse tracks metadata
      const tracks = JSON.parse(tracksMetadata);

      // Map audio files by track number
      const audioFiles = new Map<number, Buffer>();
      files.tracks.forEach((file, index) => {
        audioFiles.set(index + 1, file.buffer);
      });

      const release = await distributionService.createRelease(
        req.userId,
        {
          title,
          artistName,
          genre,
          releaseDate: new Date(releaseDate),
          label,
          copyrightYear: parseInt(copyrightYear),
          copyrightHolder,
          tracks
        },
        audioFiles,
        files.albumArt?.[0]?.buffer
      );

      res.status(201).json({
        success: true,
        message: 'Release created successfully',
        data: release
      });
    })
  ];

  /**
   * Submit release to platforms
   */
  submitRelease = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { releaseId, platforms } = req.body;

    if (!releaseId || !platforms || !Array.isArray(platforms)) {
      return res.status(400).json({ error: 'releaseId and platforms array are required' });
    }

    const release = await distributionService.submitRelease(releaseId, platforms);

    res.json({
      success: true,
      message: 'Release submitted to platforms',
      data: release
    });
  });

  /**
   * Get user's releases
   */
  getUserReleases = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const releases = await distributionService.getUserReleases(req.userId);

    res.json({
      success: true,
      data: releases
    });
  });

  /**
   * Get release by ID
   */
  getReleaseById = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { id } = req.params;

    const release = await distributionService.getReleaseById(id);

    res.json({
      success: true,
      data: release
    });
  });

  /**
   * Get release analytics
   */
  getReleaseAnalytics = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { id } = req.params;

    const analytics = await distributionService.getReleaseAnalytics(id);

    res.json({
      success: true,
      data: analytics
    });
  });

  /**
   * Takedown release
   */
  takedownRelease = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { id } = req.params;

    await distributionService.takedownRelease(id);

    res.json({
      success: true,
      message: 'Release taken down from all platforms'
    });
  });
}

export default new DistributionController();

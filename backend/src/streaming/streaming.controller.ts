// Streaming Controller
import { Response } from 'express';
import { asyncHandler } from '../middleware/error.middleware';
import { AuthRequest } from '../middleware/auth.middleware';
import streamingService from './streaming.service';

export class StreamingController {
  /**
   * Create stream
   */
  createStream = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { title, description, scheduledAt, destinations, hrvEnabled } = req.body;

    if (!title || !destinations || !Array.isArray(destinations)) {
      return res.status(400).json({ error: 'title and destinations are required' });
    }

    const stream = await streamingService.createStream(req.userId, {
      title,
      description,
      scheduledAt: scheduledAt ? new Date(scheduledAt) : undefined,
      destinations,
      hrvEnabled
    });

    res.status(201).json({
      success: true,
      message: 'Stream created successfully',
      data: stream
    });
  });

  /**
   * Start stream
   */
  startStream = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { id } = req.params;

    const stream = await streamingService.startStream(id);

    res.json({
      success: true,
      message: 'Stream started',
      data: stream
    });
  });

  /**
   * Stop stream
   */
  stopStream = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { id } = req.params;

    const stream = await streamingService.stopStream(id);

    res.json({
      success: true,
      message: 'Stream stopped',
      data: stream
    });
  });

  /**
   * Get RTMP configuration
   */
  getRTMPConfig = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { id } = req.params;

    const config = streamingService.getRTMPConfig(id);

    res.json({
      success: true,
      data: config
    });
  });

  /**
   * Get user's streams
   */
  getUserStreams = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const streams = await streamingService.getUserStreams(req.userId);

    res.json({
      success: true,
      data: streams
    });
  });

  /**
   * Get stream by ID
   */
  getStreamById = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { id } = req.params;

    const stream = await streamingService.getStreamById(id);

    res.json({
      success: true,
      data: stream
    });
  });

  /**
   * Get live streams
   */
  getLiveStreams = asyncHandler(async (req: AuthRequest, res: Response) => {
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 20;

    const result = await streamingService.getLiveStreams(page, limit);

    res.json({
      success: true,
      data: result.streams,
      pagination: {
        page,
        limit,
        total: result.total,
        totalPages: Math.ceil(result.total / limit)
      }
    });
  });

  /**
   * Update destination
   */
  updateDestination = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { streamId, destinationId, enabled } = req.body;

    await streamingService.updateDestination(streamId, destinationId, enabled);

    res.json({
      success: true,
      message: 'Destination updated'
    });
  });

  /**
   * Log biometric data
   */
  logBiometrics = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { streamId, hrvData, gestureData } = req.body;

    await streamingService.logBiometricData(streamId, hrvData, gestureData);

    res.json({
      success: true,
      message: 'Biometric data logged'
    });
  });
}

export default new StreamingController();

// Streaming Routes
import { Router } from 'express';
import streamingController from './streaming.controller';
import { authenticateToken, requireSubscription } from '../middleware/auth.middleware';

const router = Router();

/**
 * @route   POST /api/streaming/create
 * @desc    Create new stream
 * @access  Private (Pro+)
 */
router.post('/create', authenticateToken, requireSubscription('PRO'), streamingController.createStream);

/**
 * @route   POST /api/streaming/:id/start
 * @desc    Start stream
 * @access  Private
 */
router.post('/:id/start', authenticateToken, streamingController.startStream);

/**
 * @route   POST /api/streaming/:id/stop
 * @desc    Stop stream
 * @access  Private
 */
router.post('/:id/stop', authenticateToken, streamingController.stopStream);

/**
 * @route   GET /api/streaming/:id/rtmp-config
 * @desc    Get RTMP configuration for OBS/streaming software
 * @access  Private
 */
router.get('/:id/rtmp-config', authenticateToken, streamingController.getRTMPConfig);

/**
 * @route   GET /api/streaming/my-streams
 * @desc    Get user's streams
 * @access  Private
 */
router.get('/my-streams', authenticateToken, streamingController.getUserStreams);

/**
 * @route   GET /api/streaming/live
 * @desc    Get currently live streams
 * @access  Public
 */
router.get('/live', streamingController.getLiveStreams);

/**
 * @route   GET /api/streaming/:id
 * @desc    Get stream by ID
 * @access  Public
 */
router.get('/:id', streamingController.getStreamById);

/**
 * @route   PUT /api/streaming/destination
 * @desc    Update stream destination
 * @access  Private
 */
router.put('/destination', authenticateToken, streamingController.updateDestination);

/**
 * @route   POST /api/streaming/biometrics
 * @desc    Log biometric data during stream
 * @access  Private
 */
router.post('/biometrics', authenticateToken, streamingController.logBiometrics);

export default router;

// Distribution Routes
import { Router } from 'express';
import distributionController from './distribution.controller';
import { authenticateToken, requireSubscription } from '../middleware/auth.middleware';

const router = Router();

// All distribution routes require PRO subscription
router.use(authenticateToken);

/**
 * @route   POST /api/distribution/create
 * @desc    Create new release
 * @access  Private (Pro+)
 */
router.post('/create', requireSubscription('PRO'), distributionController.createRelease);

/**
 * @route   POST /api/distribution/submit
 * @desc    Submit release to platforms
 * @access  Private (Pro+)
 */
router.post('/submit', requireSubscription('PRO'), distributionController.submitRelease);

/**
 * @route   GET /api/distribution/releases
 * @desc    Get user's releases
 * @access  Private
 */
router.get('/releases', distributionController.getUserReleases);

/**
 * @route   GET /api/distribution/releases/:id
 * @desc    Get release by ID
 * @access  Private
 */
router.get('/releases/:id', distributionController.getReleaseById);

/**
 * @route   GET /api/distribution/releases/:id/analytics
 * @desc    Get release analytics
 * @access  Private
 */
router.get('/releases/:id/analytics', distributionController.getReleaseAnalytics);

/**
 * @route   DELETE /api/distribution/releases/:id
 * @desc    Takedown release from all platforms
 * @access  Private (Pro+)
 */
router.delete('/releases/:id', requireSubscription('PRO'), distributionController.takedownRelease);

export default router;

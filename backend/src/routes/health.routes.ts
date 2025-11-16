/**
 * Health check routes
 */

import { Router, Request, Response } from 'express';
import { logger } from '../utils/logger';

const router = Router();

/**
 * GET /api/v1/health
 * Basic health check endpoint
 */
router.get('/', (req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
  });
});

/**
 * GET /api/v1/health/detailed
 * Detailed health check with dependency status
 */
router.get('/detailed', async (req: Request, res: Response) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
    version: '1.0.0',
    services: {
      database: 'unknown',
      redis: 'unknown',
      ipfs: 'unknown',
      blockchain: 'unknown',
    },
  };

  try {
    // TODO: Add actual health checks for each service
    // Example:
    // const dbHealth = await checkDatabaseConnection();
    // health.services.database = dbHealth ? 'healthy' : 'unhealthy';

    res.json(health);
  } catch (error) {
    logger.error('Health check failed:', error);
    res.status(503).json({
      ...health,
      status: 'unhealthy',
    });
  }
});

/**
 * GET /api/v1/health/ready
 * Readiness probe for Kubernetes/container orchestration
 */
router.get('/ready', (req: Request, res: Response) => {
  // TODO: Check if all required services are available
  const ready = true;

  if (ready) {
    res.json({ ready: true });
  } else {
    res.status(503).json({ ready: false });
  }
});

/**
 * GET /api/v1/health/live
 * Liveness probe for Kubernetes/container orchestration
 */
router.get('/live', (req: Request, res: Response) => {
  res.json({ alive: true });
});

export default router;

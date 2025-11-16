/**
 * Session routes - Biofeedback sessions
 */

import { Router } from 'express';
const router = Router();

// TODO: Implement session routes
// POST /api/v1/sessions/start - Start new session
// POST /api/v1/sessions/:id/biometrics - Update biometric data
// POST /api/v1/sessions/:id/stop - Stop session
// GET /api/v1/sessions - List user sessions
// GET /api/v1/sessions/:id - Get session details

router.post('/start', (req, res) => {
  res.status(501).json({ message: 'Session routes not implemented yet' });
});

export default router;

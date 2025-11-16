/**
 * User routes
 */

import { Router } from 'express';
const router = Router();

// TODO: Implement user routes
// GET /api/v1/users/me - Get current user
// PUT /api/v1/users/me - Update current user
// GET /api/v1/users/:id - Get user by ID
// DELETE /api/v1/users/me - Delete current user

router.get('/me', (req, res) => {
  res.status(501).json({ message: 'User routes not implemented yet' });
});

export default router;

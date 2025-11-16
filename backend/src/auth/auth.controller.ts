// Authentication Controller
import { Request, Response, NextFunction } from 'express';
import { body, validationResult } from 'express-validator';
import authService from './auth.service';
import { asyncHandler } from '../middleware/error.middleware';
import { AuthRequest } from '../middleware/auth.middleware';

export class AuthController {
  // Validation rules
  static registerValidation = [
    body('email').isEmail().normalizeEmail(),
    body('password').isLength({ min: 8 }),
    body('name').optional().trim().isLength({ min: 1, max: 100 })
  ];

  static loginValidation = [
    body('email').isEmail().normalizeEmail(),
    body('password').notEmpty()
  ];

  // Register new user
  register = asyncHandler(async (req: Request, res: Response, next: NextFunction) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const result = await authService.register(req.body);

    res.status(201).json({
      success: true,
      message: 'User registered successfully',
      data: result
    });
  });

  // Login user
  login = asyncHandler(async (req: Request, res: Response, next: NextFunction) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const result = await authService.login(req.body);

    res.status(200).json({
      success: true,
      message: 'Login successful',
      data: result
    });
  });

  // Get current user profile
  getProfile = asyncHandler(async (req: AuthRequest, res: Response, next: NextFunction) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const user = await authService.getProfile(req.userId);

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.status(200).json({
      success: true,
      data: user
    });
  });

  // Update user profile
  updateProfile = asyncHandler(async (req: AuthRequest, res: Response, next: NextFunction) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { name } = req.body;

    const user = await authService.updateProfile(req.userId, { name });

    res.status(200).json({
      success: true,
      message: 'Profile updated successfully',
      data: user
    });
  });
}

export default new AuthController();

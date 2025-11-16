// Authentication Middleware
import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { AppError } from './error.middleware';

export interface AuthRequest extends Request {
  userId?: string;
  user?: any;
}

export const authenticateToken = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const authHeader = req.headers.authorization;
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

    if (!token) {
      throw new AppError('Access token required', 401);
    }

    const secret = process.env.JWT_SECRET;
    if (!secret) {
      throw new AppError('JWT secret not configured', 500);
    }

    const decoded = jwt.verify(token, secret) as { userId: string; email: string };
    req.userId = decoded.userId;
    req.user = decoded;

    next();
  } catch (error) {
    if (error instanceof jwt.JsonWebTokenError) {
      next(new AppError('Invalid token', 401));
    } else if (error instanceof jwt.TokenExpiredError) {
      next(new AppError('Token expired', 401));
    } else {
      next(error);
    }
  }
};

// Middleware to check subscription tier
export const requireSubscription = (tier: 'PRO' | 'STUDIO') => {
  return async (req: AuthRequest, res: Response, next: NextFunction) => {
    try {
      const { PrismaClient } = await import('@prisma/client');
      const prisma = new PrismaClient();

      const user = await prisma.user.findUnique({
        where: { id: req.userId }
      });

      if (!user) {
        throw new AppError('User not found', 404);
      }

      const tierLevels = { FREE: 0, PRO: 1, STUDIO: 2 };
      const requiredLevel = tierLevels[tier];
      const userLevel = tierLevels[user.subscription];

      if (userLevel < requiredLevel) {
        throw new AppError(`${tier} subscription required`, 403);
      }

      await prisma.$disconnect();
      next();
    } catch (error) {
      next(error);
    }
  };
};

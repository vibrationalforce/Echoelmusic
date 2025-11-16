/**
 * Global error handling middleware
 */

import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';
import * as Sentry from '@sentry/node';

export interface AppError extends Error {
  statusCode?: number;
  isOperational?: boolean;
}

export const errorHandler = (
  err: AppError,
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const statusCode = err.statusCode || 500;
  const message = err.message || 'Internal Server Error';

  // Log error
  logger.error('Error occurred:', {
    statusCode,
    message,
    stack: err.stack,
    url: req.url,
    method: req.method,
    ip: req.ip,
  });

  // Send to Sentry in production
  if (process.env.NODE_ENV === 'production' && !err.isOperational) {
    Sentry.captureException(err);
  }

  // Don't leak error details in production
  const response = {
    error: process.env.NODE_ENV === 'production' ? 'An error occurred' : message,
    ...(process.env.NODE_ENV !== 'production' && { stack: err.stack }),
  };

  res.status(statusCode).json(response);
};

export class ApiError extends Error implements AppError {
  statusCode: number;
  isOperational: boolean;

  constructor(statusCode: number, message: string, isOperational = true) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = isOperational;
    Error.captureStackTrace(this, this.constructor);
  }
}

export const notFound = (message = 'Resource not found') => {
  return new ApiError(404, message);
};

export const badRequest = (message = 'Bad request') => {
  return new ApiError(400, message);
};

export const unauthorized = (message = 'Unauthorized') => {
  return new ApiError(401, message);
};

export const forbidden = (message = 'Forbidden') => {
  return new ApiError(403, message);
};

export const conflict = (message = 'Conflict') => {
  return new ApiError(409, message);
};

export const internalError = (message = 'Internal server error') => {
  return new ApiError(500, message, false);
};

// Payment Routes
import { Router } from 'express';
import paymentController from './payment.controller';
import { authenticateToken } from '../middleware/auth.middleware';
import express from 'express';

const router = Router();

/**
 * @route   GET /api/payments/plans
 * @desc    Get available subscription plans
 * @access  Public
 */
router.get('/plans', paymentController.getPlans);

/**
 * @route   POST /api/payments/checkout
 * @desc    Create Stripe checkout session
 * @access  Private
 */
router.post('/checkout', authenticateToken, paymentController.createCheckoutSession);

/**
 * @route   POST /api/payments/portal
 * @desc    Create Stripe customer portal session
 * @access  Private
 */
router.post('/portal', authenticateToken, paymentController.createPortalSession);

/**
 * @route   POST /api/payments/webhook
 * @desc    Stripe webhook endpoint
 * @access  Public (verified by Stripe signature)
 */
router.post(
  '/webhook',
  express.raw({ type: 'application/json' }),
  paymentController.handleWebhook
);

export default router;

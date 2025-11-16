/**
 * Payment routes - Stripe integration
 */

import { Router } from 'express';
const router = Router();

// TODO: Implement payment routes
// POST /api/v1/payment/create-checkout-session - Create checkout session
// POST /api/v1/payment/webhook - Stripe webhook
// GET /api/v1/payment/subscription - Get subscription status
// POST /api/v1/payment/cancel-subscription - Cancel subscription
// GET /api/v1/payment/invoices - Get user invoices

router.post('/create-checkout-session', (req, res) => {
  res.status(501).json({ message: 'Payment routes not implemented yet' });
});

export default router;

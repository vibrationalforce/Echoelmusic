// Payment Controller
import { Request, Response, NextFunction } from 'express';
import { asyncHandler } from '../middleware/error.middleware';
import { AuthRequest } from '../middleware/auth.middleware';
import stripeService, { SUBSCRIPTION_PLANS } from './stripe.service';

export class PaymentController {
  /**
   * Get available subscription plans
   */
  getPlans = asyncHandler(async (req: Request, res: Response) => {
    const plans = Object.entries(SUBSCRIPTION_PLANS).map(([key, plan]) => ({
      id: key,
      tier: plan.tier,
      amount: plan.amount / 100, // Convert cents to euros
      currency: plan.currency,
      interval: plan.interval
    }));

    res.json({
      success: true,
      data: plans
    });
  });

  /**
   * Create checkout session
   */
  createCheckoutSession = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { planKey, successUrl, cancelUrl } = req.body;

    if (!planKey || !successUrl || !cancelUrl) {
      return res.status(400).json({
        error: 'planKey, successUrl, and cancelUrl are required'
      });
    }

    const checkoutUrl = await stripeService.createCheckoutSession(
      req.userId,
      planKey,
      successUrl,
      cancelUrl
    );

    res.json({
      success: true,
      data: { url: checkoutUrl }
    });
  });

  /**
   * Create portal session for subscription management
   */
  createPortalSession = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { returnUrl } = req.body;

    if (!returnUrl) {
      return res.status(400).json({ error: 'returnUrl is required' });
    }

    const portalUrl = await stripeService.createPortalSession(
      req.userId,
      returnUrl
    );

    res.json({
      success: true,
      data: { url: portalUrl }
    });
  });

  /**
   * Handle Stripe webhooks
   */
  handleWebhook = asyncHandler(async (req: Request, res: Response) => {
    const signature = req.headers['stripe-signature'] as string;

    if (!signature) {
      return res.status(400).json({ error: 'Missing stripe-signature header' });
    }

    await stripeService.handleWebhook(req.body, signature);

    res.json({ received: true });
  });
}

export default new PaymentController();

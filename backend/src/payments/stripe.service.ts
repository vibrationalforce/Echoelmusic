// Stripe Payment Service
import Stripe from 'stripe';
import { PrismaClient } from '@prisma/client';
import { AppError } from '../middleware/error.middleware';

const prisma = new PrismaClient();

if (!process.env.STRIPE_SECRET_KEY) {
  throw new Error('STRIPE_SECRET_KEY not configured');
}

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY, {
  apiVersion: '2023-10-16'
});

export interface SubscriptionPlan {
  tier: 'PRO' | 'STUDIO';
  priceId: string;
  amount: number;
  currency: string;
  interval: 'month' | 'year';
}

export const SUBSCRIPTION_PLANS: Record<string, SubscriptionPlan> = {
  PRO_MONTHLY: {
    tier: 'PRO',
    priceId: process.env.STRIPE_PRICE_ID_PRO || '',
    amount: 2900, // €29.00
    currency: 'eur',
    interval: 'month'
  },
  STUDIO_MONTHLY: {
    tier: 'STUDIO',
    priceId: process.env.STRIPE_PRICE_ID_STUDIO || '',
    amount: 9900, // €99.00
    currency: 'eur',
    interval: 'month'
  }
};

export class StripeService {
  /**
   * Create Stripe checkout session for subscription
   */
  async createCheckoutSession(
    userId: string,
    planKey: keyof typeof SUBSCRIPTION_PLANS,
    successUrl: string,
    cancelUrl: string
  ): Promise<string> {
    const plan = SUBSCRIPTION_PLANS[planKey];
    if (!plan) {
      throw new AppError('Invalid subscription plan', 400);
    }

    // Get or create Stripe customer
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new AppError('User not found', 404);
    }

    let customerId = user.stripeCustomerId;

    if (!customerId) {
      const customer = await stripe.customers.create({
        email: user.email,
        metadata: { userId: user.id }
      });
      customerId = customer.id;

      await prisma.user.update({
        where: { id: userId },
        data: { stripeCustomerId: customerId }
      });
    }

    // Create checkout session
    const session = await stripe.checkout.sessions.create({
      customer: customerId,
      mode: 'subscription',
      payment_method_types: ['card'],
      line_items: [
        {
          price: plan.priceId,
          quantity: 1
        }
      ],
      success_url: successUrl,
      cancel_url: cancelUrl,
      metadata: {
        userId,
        tier: plan.tier
      }
    });

    if (!session.url) {
      throw new AppError('Failed to create checkout session', 500);
    }

    return session.url;
  }

  /**
   * Create Stripe portal session for managing subscription
   */
  async createPortalSession(
    userId: string,
    returnUrl: string
  ): Promise<string> {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user || !user.stripeCustomerId) {
      throw new AppError('No active subscription found', 404);
    }

    const session = await stripe.billingPortal.sessions.create({
      customer: user.stripeCustomerId,
      return_url: returnUrl
    });

    return session.url;
  }

  /**
   * Handle Stripe webhook events
   */
  async handleWebhook(
    body: Buffer,
    signature: string
  ): Promise<void> {
    const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
    if (!webhookSecret) {
      throw new AppError('Stripe webhook secret not configured', 500);
    }

    let event: Stripe.Event;

    try {
      event = stripe.webhooks.constructEvent(body, signature, webhookSecret);
    } catch (err) {
      throw new AppError(`Webhook signature verification failed: ${err}`, 400);
    }

    switch (event.type) {
      case 'checkout.session.completed':
        await this.handleCheckoutCompleted(event.data.object as Stripe.Checkout.Session);
        break;

      case 'customer.subscription.created':
      case 'customer.subscription.updated':
        await this.handleSubscriptionUpdate(event.data.object as Stripe.Subscription);
        break;

      case 'customer.subscription.deleted':
        await this.handleSubscriptionDeleted(event.data.object as Stripe.Subscription);
        break;

      case 'invoice.payment_succeeded':
        await this.handlePaymentSucceeded(event.data.object as Stripe.Invoice);
        break;

      case 'invoice.payment_failed':
        await this.handlePaymentFailed(event.data.object as Stripe.Invoice);
        break;

      default:
        console.log(`Unhandled event type: ${event.type}`);
    }
  }

  private async handleCheckoutCompleted(session: Stripe.Checkout.Session) {
    const userId = session.metadata?.userId;
    const tier = session.metadata?.tier as 'PRO' | 'STUDIO';

    if (!userId || !tier) {
      console.error('Missing metadata in checkout session');
      return;
    }

    await prisma.user.update({
      where: { id: userId },
      data: {
        subscription: tier,
        subscriptionStatus: 'ACTIVE',
        subscriptionId: session.subscription as string,
        isTrialActive: false
      }
    });
  }

  private async handleSubscriptionUpdate(subscription: Stripe.Subscription) {
    const userId = subscription.metadata?.userId;
    if (!userId) return;

    const status = subscription.status;
    let subscriptionStatus: 'ACTIVE' | 'INACTIVE' | 'CANCELED' | 'PAST_DUE' = 'INACTIVE';

    switch (status) {
      case 'active':
      case 'trialing':
        subscriptionStatus = 'ACTIVE';
        break;
      case 'past_due':
        subscriptionStatus = 'PAST_DUE';
        break;
      case 'canceled':
      case 'unpaid':
        subscriptionStatus = 'CANCELED';
        break;
    }

    await prisma.user.update({
      where: { id: userId },
      data: {
        subscriptionStatus,
        subscriptionId: subscription.id
      }
    });
  }

  private async handleSubscriptionDeleted(subscription: Stripe.Subscription) {
    const userId = subscription.metadata?.userId;
    if (!userId) return;

    await prisma.user.update({
      where: { id: userId },
      data: {
        subscription: 'FREE',
        subscriptionStatus: 'CANCELED',
        subscriptionId: null
      }
    });
  }

  private async handlePaymentSucceeded(invoice: Stripe.Invoice) {
    const customerId = invoice.customer as string;

    const user = await prisma.user.findUnique({
      where: { stripeCustomerId: customerId }
    });

    if (!user) return;

    await prisma.payment.create({
      data: {
        userId: user.id,
        stripePaymentId: invoice.payment_intent as string,
        amount: invoice.amount_paid,
        currency: invoice.currency,
        status: 'SUCCEEDED',
        description: invoice.description || 'Subscription payment'
      }
    });
  }

  private async handlePaymentFailed(invoice: Stripe.Invoice) {
    const customerId = invoice.customer as string;

    const user = await prisma.user.findUnique({
      where: { stripeCustomerId: customerId }
    });

    if (!user) return;

    await prisma.user.update({
      where: { id: user.id },
      data: {
        subscriptionStatus: 'PAST_DUE'
      }
    });

    await prisma.payment.create({
      data: {
        userId: user.id,
        stripePaymentId: invoice.payment_intent as string || 'failed',
        amount: invoice.amount_due,
        currency: invoice.currency,
        status: 'FAILED',
        description: invoice.description || 'Failed subscription payment'
      }
    });
  }
}

export default new StripeService();

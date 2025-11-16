"""Stripe subscription management"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import stripe
from datetime import datetime

from ..database import get_db
from ..config import settings
from .. import models, schemas

# Configure Stripe
stripe.api_key = settings.STRIPE_SECRET_KEY

router = APIRouter()


@router.post("/create", response_model=schemas.SubscriptionResponse)
async def create_subscription(
    request: schemas.SubscriptionCreate,
    db: AsyncSession = Depends(get_db)
):
    """
    Create Stripe subscription

    Tiers:
    - Basic: $9/month - HD streaming, 10 hours/month storage
    - Pro: $49/month - 4K streaming, 100 hours/month, multi-platform
    - Studio: $249/month - Unlimited streaming, cloud GPU rendering, NFT minting
    """

    # Price IDs based on tier
    price_ids = {
        schemas.SubscriptionTier.BASIC: settings.STRIPE_PRICE_BASIC,
        schemas.SubscriptionTier.PRO: settings.STRIPE_PRICE_PRO,
        schemas.SubscriptionTier.STUDIO: settings.STRIPE_PRICE_STUDIO
    }

    # Get user
    user_id = int(request.user_id)
    stmt = select(models.User).where(models.User.id == user_id)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Create or get Stripe customer
    if user.stripe_customer_id:
        customer_id = user.stripe_customer_id
    else:
        customer = stripe.Customer.create(
            email=user.email,
            metadata={"user_id": str(user_id)}
        )
        customer_id = customer.id
        user.stripe_customer_id = customer_id

    # Create subscription
    subscription = stripe.Subscription.create(
        customer=customer_id,
        items=[{"price": price_ids[request.tier]}],
        payment_behavior="default_incomplete",
        expand=["latest_invoice.payment_intent"]
    )

    # Update user
    user.stripe_subscription_id = subscription.id
    user.subscription_tier = request.tier
    await db.commit()

    return schemas.SubscriptionResponse(
        subscription_id=subscription.id,
        customer_id=customer_id,
        tier=request.tier,
        status=subscription.status,
        current_period_end=datetime.fromtimestamp(subscription.current_period_end),
        cancel_at_period_end=subscription.cancel_at_period_end,
        client_secret=subscription.latest_invoice.payment_intent.client_secret
    )


@router.put("/{subscription_id}/upgrade", response_model=schemas.SubscriptionResponse)
async def upgrade_subscription(
    subscription_id: str,
    request: schemas.SubscriptionUpdate,
    db: AsyncSession = Depends(get_db)
):
    """Upgrade/downgrade subscription tier"""

    price_ids = {
        schemas.SubscriptionTier.BASIC: settings.STRIPE_PRICE_BASIC,
        schemas.SubscriptionTier.PRO: settings.STRIPE_PRICE_PRO,
        schemas.SubscriptionTier.STUDIO: settings.STRIPE_PRICE_STUDIO
    }

    # Update Stripe subscription
    subscription = stripe.Subscription.modify(
        subscription_id,
        items=[{
            "id": stripe.Subscription.retrieve(subscription_id).items.data[0].id,
            "price": price_ids[request.tier]
        }],
        proration_behavior="always_invoice"
    )

    # Update database
    stmt = select(models.User).where(models.User.stripe_subscription_id == subscription_id)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if user:
        user.subscription_tier = request.tier
        await db.commit()

    return schemas.SubscriptionResponse(
        subscription_id=subscription.id,
        customer_id=subscription.customer,
        tier=request.tier,
        status=subscription.status,
        current_period_end=datetime.fromtimestamp(subscription.current_period_end),
        cancel_at_period_end=subscription.cancel_at_period_end
    )


@router.delete("/{subscription_id}/cancel")
async def cancel_subscription(
    subscription_id: str,
    db: AsyncSession = Depends(get_db)
):
    """Cancel subscription at end of billing period"""

    subscription = stripe.Subscription.modify(
        subscription_id,
        cancel_at_period_end=True
    )

    return {
        "status": "will_cancel",
        "subscription_id": subscription_id,
        "cancel_at": datetime.fromtimestamp(subscription.current_period_end)
    }


@router.post("/webhook")
async def stripe_webhook(request: dict):
    """Handle Stripe webhooks for subscription events"""

    # Verify webhook signature
    # sig_header = request.headers.get("stripe-signature")
    # event = stripe.Webhook.construct_event(
    #     payload, sig_header, settings.STRIPE_WEBHOOK_SECRET
    # )

    event = request  # Simplified for now

    # Handle different event types
    if event["type"] == "customer.subscription.updated":
        subscription = event["data"]["object"]
        # Update database with subscription status
        pass

    elif event["type"] == "customer.subscription.deleted":
        subscription = event["data"]["object"]
        # Downgrade user to free tier
        pass

    elif event["type"] == "invoice.payment_succeeded":
        invoice = event["data"]["object"]
        # Confirm payment received
        pass

    elif event["type"] == "invoice.payment_failed":
        invoice = event["data"]["object"]
        # Handle failed payment
        pass

    return {"status": "received"}

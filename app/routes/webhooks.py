"""
Stripe Webhook Routes
Handles Stripe webhook events for subscription management
"""

import stripe
from flask import Blueprint, request, jsonify, current_app
from app.services.stripe_service import StripeService
from app.utils.logger import setup_logger

bp = Blueprint('webhooks', __name__)
logger = setup_logger(__name__)


@bp.route('/stripe', methods=['POST'])
def stripe_webhook():
    """
    Handle Stripe webhook events

    This endpoint receives and processes webhook events from Stripe,
    including subscription updates, payments, and cancellations.

    Returns:
        JSON response indicating success or failure
    """
    payload = request.data
    sig_header = request.headers.get('Stripe-Signature')

    try:
        # Verify webhook signature
        event = stripe.Webhook.construct_event(
            payload,
            sig_header,
            current_app.config['STRIPE_WEBHOOK_SECRET']
        )

    except ValueError as e:
        # Invalid payload
        logger.error(f"Invalid webhook payload: {str(e)}")
        return jsonify({'error': 'Invalid payload'}), 400

    except stripe.error.SignatureVerificationError as e:
        # Invalid signature
        logger.error(f"Invalid webhook signature: {str(e)}")
        return jsonify({'error': 'Invalid signature'}), 400

    # Handle the event
    event_type = event['type']
    event_data = event['data']['object']

    logger.info(f"Received webhook event: {event_type}")

    stripe_service = StripeService()

    try:
        # Subscription events
        if event_type == 'customer.subscription.created':
            stripe_service.handle_subscription_created(event_data)

        elif event_type == 'customer.subscription.updated':
            stripe_service.handle_subscription_updated(event_data)

        elif event_type == 'customer.subscription.deleted':
            stripe_service.handle_subscription_deleted(event_data)

        # Payment events
        elif event_type == 'payment_intent.succeeded':
            stripe_service.handle_payment_succeeded(event_data)

        elif event_type == 'payment_intent.payment_failed':
            stripe_service.handle_payment_failed(event_data)

        # Invoice events
        elif event_type == 'invoice.payment_succeeded':
            logger.info(f"Invoice payment succeeded: {event_data['id']}")

        elif event_type == 'invoice.payment_failed':
            logger.warning(f"Invoice payment failed: {event_data['id']}")
            # TODO: Send notification to user about failed payment

        # Checkout events
        elif event_type == 'checkout.session.completed':
            stripe_service.handle_checkout_completed(event_data)

        else:
            logger.info(f"Unhandled webhook event type: {event_type}")

        return jsonify({'success': True}), 200

    except Exception as e:
        logger.error(f"Error processing webhook event {event_type}: {str(e)}")
        return jsonify({'error': 'Webhook processing failed'}), 500


@bp.route('/stripe/test', methods=['GET'])
def test_webhook():
    """
    Test endpoint to verify webhook configuration

    Returns:
        JSON with webhook configuration status
    """
    webhook_secret = current_app.config.get('STRIPE_WEBHOOK_SECRET')

    return jsonify({
        'webhook_configured': bool(webhook_secret),
        'endpoint': '/api/webhooks/stripe',
        'events': [
            'customer.subscription.created',
            'customer.subscription.updated',
            'customer.subscription.deleted',
            'payment_intent.succeeded',
            'payment_intent.payment_failed',
            'invoice.payment_succeeded',
            'invoice.payment_failed',
            'checkout.session.completed'
        ]
    }), 200

"""
Subscription Routes
Handles subscription management and Stripe checkout
"""

from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models.user import User
from app.models.subscription import Subscription
from app.services.stripe_service import StripeService
from app.utils.logger import setup_logger

bp = Blueprint('subscription', __name__)
logger = setup_logger(__name__)


@bp.route('/available', methods=['GET'])
def check_stripe_available():
    """
    Check if Stripe payment processing is available

    Returns:
        JSON with availability status
    """
    from flask import current_app

    stripe_configured = bool(
        current_app.config.get('STRIPE_SECRET_KEY') and
        current_app.config.get('STRIPE_PUBLISHABLE_KEY') and
        current_app.config.get('STRIPE_PRICE_ID_PRO') and
        current_app.config.get('STRIPE_SECRET_KEY') != 'sk_test_YOUR_STRIPE_SECRET_KEY_HERE'
    )

    return jsonify({
        'available': stripe_configured,
        'message': 'Payment processing is available' if stripe_configured else 'Payment processing is not configured'
    }), 200


@bp.route('/create-checkout-session', methods=['POST'])
@jwt_required()
def create_checkout_session():
    """
    Create a Stripe Checkout session for Pro subscription

    Returns:
        JSON with checkout session URL
    """
    try:
        from flask import current_app

        # Check if Stripe is configured
        if not current_app.config.get('STRIPE_SECRET_KEY') or not current_app.config.get('STRIPE_PRICE_ID_PRO'):
            logger.error("Stripe is not configured. Missing STRIPE_SECRET_KEY or STRIPE_PRICE_ID_PRO")
            return jsonify({
                'error': 'Payment system is not configured. Please contact support.'
            }), 503

        user_id = get_jwt_identity()
        user = User.query.get(user_id)

        if not user:
            return jsonify({'error': 'User not found'}), 404

        # Check if user already has an active subscription
        if user.subscription_tier == 'pro' and user.subscription_status == 'active':
            return jsonify({'error': 'User already has an active Pro subscription'}), 400

        stripe_service = StripeService()
        session_data = stripe_service.create_checkout_session(user)

        return jsonify({
            'success': True,
            'session_id': session_data['session_id'],
            'url': session_data['url']
        }), 200

    except Exception as e:
        logger.error(f"Error creating checkout session: {str(e)}", exc_info=True)
        return jsonify({'error': f'Failed to create checkout session: {str(e)}'}), 500


@bp.route('/create-portal-session', methods=['POST'])
@jwt_required()
def create_portal_session():
    """
    Create a Stripe Customer Portal session for subscription management

    Returns:
        JSON with portal session URL
    """
    try:
        user_id = get_jwt_identity()
        user = User.query.get(user_id)

        if not user:
            return jsonify({'error': 'User not found'}), 404

        # Check if user has Pro subscription
        if user.subscription_tier != 'pro':
            return jsonify({'error': 'Portal is only available for Pro subscribers'}), 403

        if not user.stripe_customer_id:
            return jsonify({'error': 'No Stripe customer ID found. Please contact support.'}), 400

        stripe_service = StripeService()
        portal_url = stripe_service.create_portal_session(user)

        return jsonify({
            'success': True,
            'url': portal_url
        }), 200

    except Exception as e:
        logger.error(f"Error creating portal session: {str(e)}")
        return jsonify({'error': 'Failed to create portal session'}), 500


@bp.route('/status', methods=['GET'])
@jwt_required()
def get_subscription_status():
    """
    Get current user's subscription status

    Returns:
        JSON with subscription details
    """
    try:
        user_id = get_jwt_identity()
        user = User.query.get(user_id)

        if not user:
            return jsonify({'error': 'User not found'}), 404

        subscription = Subscription.query.filter_by(user_id=user.id).first()

        return jsonify({
            'tier': user.subscription_tier,
            'status': user.subscription_status,
            'subscription': subscription.to_dict() if subscription else None
        }), 200

    except Exception as e:
        logger.error(f"Error fetching subscription status: {str(e)}")
        return jsonify({'error': 'Failed to fetch subscription status'}), 500


@bp.route('/cancel', methods=['POST'])
@jwt_required()
def cancel_subscription():
    """
    Cancel user's subscription at period end

    Returns:
        JSON with cancellation confirmation
    """
    try:
        user_id = get_jwt_identity()
        user = User.query.get(user_id)

        if not user:
            return jsonify({'error': 'User not found'}), 404

        subscription = Subscription.query.filter_by(user_id=user.id).first()

        if not subscription:
            return jsonify({'error': 'No active subscription found'}), 404

        stripe_service = StripeService()
        stripe_service.cancel_subscription(subscription.stripe_subscription_id)

        return jsonify({
            'success': True,
            'message': 'Subscription will be canceled at the end of the billing period'
        }), 200

    except Exception as e:
        logger.error(f"Error canceling subscription: {str(e)}")
        return jsonify({'error': 'Failed to cancel subscription'}), 500


@bp.route('/reactivate', methods=['POST'])
@jwt_required()
def reactivate_subscription():
    """
    Reactivate a subscription that was set to cancel

    Returns:
        JSON with reactivation confirmation
    """
    try:
        user_id = get_jwt_identity()
        user = User.query.get(user_id)

        if not user:
            return jsonify({'error': 'User not found'}), 404

        subscription = Subscription.query.filter_by(user_id=user.id).first()

        if not subscription or not subscription.cancel_at_period_end:
            return jsonify({'error': 'No subscription set to cancel found'}), 404

        stripe_service = StripeService()
        stripe_service.reactivate_subscription(subscription.stripe_subscription_id)

        return jsonify({
            'success': True,
            'message': 'Subscription reactivated successfully'
        }), 200

    except Exception as e:
        logger.error(f"Error reactivating subscription: {str(e)}")
        return jsonify({'error': 'Failed to reactivate subscription'}), 500


@bp.route('/invoices', methods=['GET'])
@jwt_required()
def get_invoices():
    """
    Get user's invoice history from Stripe

    Returns:
        JSON with list of invoices
    """
    try:
        user_id = get_jwt_identity()
        user = User.query.get(user_id)

        if not user or not user.stripe_customer_id:
            return jsonify({'error': 'User or Stripe customer not found'}), 404

        import stripe
        from flask import current_app

        stripe.api_key = current_app.config['STRIPE_SECRET_KEY']

        invoices = stripe.Invoice.list(customer=user.stripe_customer_id, limit=10)

        invoice_list = [{
            'id': inv.id,
            'amount': inv.amount_paid / 100,
            'currency': inv.currency,
            'status': inv.status,
            'created': inv.created,
            'pdf_url': inv.invoice_pdf
        } for inv in invoices.data]

        return jsonify({
            'success': True,
            'invoices': invoice_list
        }), 200

    except Exception as e:
        logger.error(f"Error fetching invoices: {str(e)}")
        return jsonify({'error': 'Failed to fetch invoices'}), 500

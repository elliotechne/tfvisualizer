"""
Stripe Integration Service
Handles all Stripe payment and subscription operations
"""

import stripe
from flask import current_app, url_for
from app.models.user import User
from app.models.subscription import Subscription
from app.main import db
from app.utils.logger import setup_logger

logger = setup_logger(__name__)


class StripeService:
    """Service for managing Stripe operations"""

    def __init__(self):
        """Initialize Stripe with API key"""
        api_key = current_app.config.get('STRIPE_SECRET_KEY')
        if not api_key or api_key == 'sk_test_YOUR_STRIPE_SECRET_KEY_HERE':
            raise ValueError("Stripe API key is not configured")
        stripe.api_key = api_key

    def create_customer(self, user: User) -> str:
        """
        Create a Stripe customer for a user

        Args:
            user: User model instance

        Returns:
            Stripe customer ID
        """
        try:
            customer = stripe.Customer.create(
                email=user.email,
                name=user.name,
                metadata={
                    'user_id': str(user.id)
                }
            )

            # Update user with Stripe customer ID
            user.stripe_customer_id = customer.id
            db.session.commit()

            logger.info(f"Created Stripe customer {customer.id} for user {user.id}")
            return customer.id

        except stripe.error.StripeError as e:
            logger.error(f"Stripe customer creation failed: {str(e)}")
            raise

    def create_checkout_session(self, user: User) -> dict:
        """
        Create a Stripe Checkout session for Pro subscription

        Args:
            user: User model instance

        Returns:
            dict with session ID and URL
        """
        try:
            # Ensure user has a Stripe customer ID
            if not user.stripe_customer_id:
                self.create_customer(user)

            # Create checkout session
            session = stripe.checkout.Session.create(
                customer=user.stripe_customer_id,
                payment_method_types=['card'],
                line_items=[{
                    'price': current_app.config['STRIPE_PRICE_ID_PRO'],
                    'quantity': 1,
                }],
                mode='subscription',
                success_url=current_app.config['STRIPE_SUCCESS_URL'] + '?session_id={CHECKOUT_SESSION_ID}',
                cancel_url=current_app.config['STRIPE_CANCEL_URL'],
                metadata={
                    'user_id': str(user.id)
                },
                subscription_data={
                    'metadata': {
                        'user_id': str(user.id)
                    }
                }
            )

            logger.info(f"Created checkout session {session.id} for user {user.id}")

            return {
                'session_id': session.id,
                'url': session.url
            }

        except stripe.error.StripeError as e:
            logger.error(f"Checkout session creation failed: {str(e)}")
            raise

    def create_portal_session(self, user: User) -> str:
        """
        Create a Stripe Customer Portal session for subscription management

        Args:
            user: User model instance

        Returns:
            Portal session URL
        """
        try:
            if not user.stripe_customer_id:
                raise ValueError("User does not have a Stripe customer ID")

            session = stripe.billing_portal.Session.create(
                customer=user.stripe_customer_id,
                return_url=current_app.config.get('FRONTEND_URL', 'http://localhost') + '/dashboard'
            )

            logger.info(f"Created portal session for user {user.id}")
            return session.url

        except stripe.error.StripeError as e:
            logger.error(f"Portal session creation failed: {str(e)}")
            raise

    def cancel_subscription(self, subscription_id: str) -> bool:
        """
        Cancel a subscription at period end

        Args:
            subscription_id: Stripe subscription ID

        Returns:
            True if successful
        """
        try:
            stripe.Subscription.modify(
                subscription_id,
                cancel_at_period_end=True
            )

            # Update database
            subscription = Subscription.query.filter_by(
                stripe_subscription_id=subscription_id
            ).first()

            if subscription:
                subscription.cancel_at_period_end = True
                db.session.commit()

            logger.info(f"Subscription {subscription_id} set to cancel at period end")
            return True

        except stripe.error.StripeError as e:
            logger.error(f"Subscription cancellation failed: {str(e)}")
            raise

    def reactivate_subscription(self, subscription_id: str) -> bool:
        """
        Reactivate a subscription that was set to cancel

        Args:
            subscription_id: Stripe subscription ID

        Returns:
            True if successful
        """
        try:
            stripe.Subscription.modify(
                subscription_id,
                cancel_at_period_end=False
            )

            # Update database
            subscription = Subscription.query.filter_by(
                stripe_subscription_id=subscription_id
            ).first()

            if subscription:
                subscription.cancel_at_period_end = False
                db.session.commit()

            logger.info(f"Subscription {subscription_id} reactivated")
            return True

        except stripe.error.StripeError as e:
            logger.error(f"Subscription reactivation failed: {str(e)}")
            raise

    def handle_subscription_created(self, subscription_obj: dict) -> None:
        """
        Handle subscription.created webhook event

        Args:
            subscription_obj: Stripe subscription object
        """
        try:
            user_id = subscription_obj['metadata'].get('user_id')
            if not user_id:
                logger.error("No user_id in subscription metadata")
                return

            user = User.query.get(user_id)
            if not user:
                logger.error(f"User {user_id} not found")
                return

            # Create subscription record
            subscription = Subscription(
                user_id=user.id,
                stripe_subscription_id=subscription_obj['id'],
                stripe_price_id=subscription_obj['items']['data'][0]['price']['id'],
                status=subscription_obj['status'],
                current_period_start=subscription_obj['current_period_start'],
                current_period_end=subscription_obj['current_period_end'],
                cancel_at_period_end=subscription_obj['cancel_at_period_end']
            )

            # Update user subscription status
            user.subscription_tier = 'pro'
            user.subscription_status = 'active'

            db.session.add(subscription)
            db.session.commit()

            logger.info(f"Subscription {subscription_obj['id']} created for user {user_id}")

        except Exception as e:
            logger.error(f"Error handling subscription.created: {str(e)}")
            db.session.rollback()

    def handle_subscription_updated(self, subscription_obj: dict) -> None:
        """
        Handle subscription.updated webhook event

        Args:
            subscription_obj: Stripe subscription object
        """
        try:
            subscription = Subscription.query.filter_by(
                stripe_subscription_id=subscription_obj['id']
            ).first()

            if not subscription:
                logger.warning(f"Subscription {subscription_obj['id']} not found in database")
                return

            # Update subscription details
            subscription.status = subscription_obj['status']
            subscription.current_period_start = subscription_obj['current_period_start']
            subscription.current_period_end = subscription_obj['current_period_end']
            subscription.cancel_at_period_end = subscription_obj['cancel_at_period_end']

            # Update user status
            user = subscription.user
            if subscription_obj['status'] == 'active':
                user.subscription_status = 'active'
            elif subscription_obj['status'] in ['canceled', 'unpaid', 'past_due']:
                user.subscription_status = subscription_obj['status']
                if subscription_obj['status'] == 'canceled':
                    user.subscription_tier = 'free'

            db.session.commit()
            logger.info(f"Subscription {subscription_obj['id']} updated")

        except Exception as e:
            logger.error(f"Error handling subscription.updated: {str(e)}")
            db.session.rollback()

    def handle_subscription_deleted(self, subscription_obj: dict) -> None:
        """
        Handle subscription.deleted webhook event

        Args:
            subscription_obj: Stripe subscription object
        """
        try:
            subscription = Subscription.query.filter_by(
                stripe_subscription_id=subscription_obj['id']
            ).first()

            if not subscription:
                logger.warning(f"Subscription {subscription_obj['id']} not found")
                return

            # Update user to free tier
            user = subscription.user
            user.subscription_tier = 'free'
            user.subscription_status = 'canceled'

            # Update subscription status
            subscription.status = 'canceled'

            db.session.commit()
            logger.info(f"Subscription {subscription_obj['id']} deleted, user downgraded to free")

        except Exception as e:
            logger.error(f"Error handling subscription.deleted: {str(e)}")
            db.session.rollback()

    def handle_payment_succeeded(self, payment_intent_obj: dict) -> None:
        """
        Handle payment_intent.succeeded webhook event

        Args:
            payment_intent_obj: Stripe payment intent object
        """
        try:
            from app.models.payment import PaymentHistory

            # Extract user from metadata
            user_id = payment_intent_obj.get('metadata', {}).get('user_id')

            if user_id:
                payment = PaymentHistory(
                    user_id=user_id,
                    stripe_payment_intent_id=payment_intent_obj['id'],
                    amount=payment_intent_obj['amount'] / 100,  # Convert from cents
                    currency=payment_intent_obj['currency'],
                    status='succeeded'
                )

                db.session.add(payment)
                db.session.commit()

                logger.info(f"Payment {payment_intent_obj['id']} recorded for user {user_id}")

        except Exception as e:
            logger.error(f"Error handling payment_intent.succeeded: {str(e)}")
            db.session.rollback()

    def handle_payment_failed(self, payment_intent_obj: dict) -> None:
        """
        Handle payment_intent.payment_failed webhook event

        Args:
            payment_intent_obj: Stripe payment intent object
        """
        try:
            from app.models.payment import PaymentHistory

            user_id = payment_intent_obj.get('metadata', {}).get('user_id')

            if user_id:
                payment = PaymentHistory(
                    user_id=user_id,
                    stripe_payment_intent_id=payment_intent_obj['id'],
                    amount=payment_intent_obj['amount'] / 100,
                    currency=payment_intent_obj['currency'],
                    status='failed'
                )

                db.session.add(payment)
                db.session.commit()

                logger.warning(f"Payment {payment_intent_obj['id']} failed for user {user_id}")

                # TODO: Send email notification to user about failed payment

        except Exception as e:
            logger.error(f"Error handling payment_intent.payment_failed: {str(e)}")
            db.session.rollback()

    def handle_checkout_completed(self, session_obj: dict) -> None:
        """
        Handle checkout.session.completed webhook event

        Args:
            session_obj: Stripe checkout session object
        """
        try:
            user_id = session_obj.get('metadata', {}).get('user_id')
            if not user_id:
                logger.error("No user_id in checkout session metadata")
                return

            user = User.query.get(user_id)
            if not user:
                logger.error(f"User {user_id} not found")
                return

            # If subscription was created, update user immediately
            if session_obj.get('mode') == 'subscription' and session_obj.get('subscription'):
                # Retrieve the subscription to get its status
                subscription_id = session_obj['subscription']
                subscription = stripe.Subscription.retrieve(subscription_id)

                # Update user to Pro tier immediately
                user.subscription_tier = 'pro'

                # Set status based on subscription status
                if subscription.status == 'trialing':
                    user.subscription_status = 'trialing'
                elif subscription.status == 'active':
                    user.subscription_status = 'active'
                else:
                    user.subscription_status = subscription.status

                db.session.commit()
                logger.info(f"User {user_id} upgraded to Pro via checkout session {session_obj['id']}")

        except Exception as e:
            logger.error(f"Error handling checkout.session.completed: {str(e)}")
            db.session.rollback()

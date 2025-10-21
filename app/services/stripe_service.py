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

    def create_checkout_session(self, user: User, trial_period_days: int = None) -> dict:
        """
        Create a Stripe Checkout session for Pro subscription with optional trial

        Args:
            user: User model instance
            trial_period_days: Number of days for trial period (default from config)

        Returns:
            dict with session ID and URL
        """
        try:
            # Ensure user has a Stripe customer ID
            if not user.stripe_customer_id:
                self.create_customer(user)

            # Get trial period from config if not specified
            if trial_period_days is None:
                trial_period_days = current_app.config.get('TRIAL_PERIOD_DAYS', 14)

            # Create subscription data with trial period
            subscription_data = {
                'metadata': {
                    'user_id': str(user.id)
                },
                'trial_period_days': trial_period_days
            }

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
                subscription_data=subscription_data,
                payment_method_collection='always'  # Require payment method even for trial
            )

            logger.info(f"Created checkout session {session.id} for user {user.id} with {trial_period_days}-day trial")

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
            from datetime import datetime

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
            if subscription_obj['status'] == 'trialing':
                user.subscription_status = 'trialing'
                user.is_on_trial = True
                if subscription_obj.get('trial_end'):
                    user.trial_end_date = datetime.fromtimestamp(subscription_obj['trial_end'])
            elif subscription_obj['status'] == 'active':
                user.subscription_status = 'active'
                # Trial has ended, subscription is now active
                if user.is_on_trial:
                    user.is_on_trial = False
                    logger.info(f"Trial ended for user {user.id}, now on active subscription")
            elif subscription_obj['status'] in ['canceled', 'unpaid', 'past_due']:
                user.subscription_status = subscription_obj['status']
                if subscription_obj['status'] == 'canceled':
                    user.subscription_tier = 'free'
                    user.is_on_trial = False

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
            from datetime import datetime, timedelta

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

                # Set status and trial info based on subscription status
                if subscription.status == 'trialing':
                    user.subscription_status = 'trialing'
                    user.is_on_trial = True

                    # Calculate trial dates from Stripe subscription
                    if subscription.trial_start and subscription.trial_end:
                        user.trial_start_date = datetime.fromtimestamp(subscription.trial_start)
                        user.trial_end_date = datetime.fromtimestamp(subscription.trial_end)

                    logger.info(f"User {user_id} started trial until {user.trial_end_date}")
                elif subscription.status == 'active':
                    user.subscription_status = 'active'
                    # Clear trial flags if subscription becomes active (trial ended)
                    if user.is_on_trial and user.trial_end_date and datetime.utcnow() >= user.trial_end_date:
                        user.is_on_trial = False
                else:
                    user.subscription_status = subscription.status

                db.session.commit()
                logger.info(f"User {user_id} upgraded to Pro via checkout session {session_obj['id']}")

        except Exception as e:
            logger.error(f"Error handling checkout.session.completed: {str(e)}")
            db.session.rollback()

    def sync_user_subscription(self, user: User) -> None:
        """
        Sync user's subscription tier with Stripe
        Checks if user has an active Pro subscription and updates local database

        Args:
            user: User model instance
        """
        try:
            if not user.stripe_customer_id:
                logger.info(f"User {user.id} has no Stripe customer ID, skipping sync")
                return

            # Retrieve all subscriptions for this customer
            subscriptions = stripe.Subscription.list(
                customer=user.stripe_customer_id,
                limit=10
            )

            # Check if user has an active Pro subscription
            has_active_pro = False
            current_status = 'inactive'

            for subscription in subscriptions.data:
                # Check if subscription is active or trialing
                if subscription.status in ['active', 'trialing']:
                    has_active_pro = True
                    current_status = subscription.status
                    logger.info(f"User {user.id} has active Stripe subscription: {subscription.id} with status {subscription.status}")
                    break

            # Update user's subscription tier based on Stripe data
            if has_active_pro:
                if user.subscription_tier != 'pro':
                    logger.info(f"Updating user {user.id} from {user.subscription_tier} to pro")
                    user.subscription_tier = 'pro'

                if user.subscription_status != current_status:
                    logger.info(f"Updating user {user.id} status from {user.subscription_status} to {current_status}")
                    user.subscription_status = current_status

                db.session.commit()
            else:
                # No active subscription found, ensure user is on free tier
                if user.subscription_tier == 'pro':
                    logger.info(f"No active subscription found for user {user.id}, downgrading to free")
                    user.subscription_tier = 'free'
                    user.subscription_status = 'inactive'
                    db.session.commit()

        except Exception as e:
            logger.error(f"Error syncing subscription for user {user.id}: {str(e)}")
            db.session.rollback()

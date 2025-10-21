"""
Trial Period Utilities
Helper functions for managing trial periods and checking trial status
"""

from datetime import datetime
from app.models.user import User
from app.main import db
from app.utils.logger import setup_logger

logger = setup_logger(__name__)


def check_trial_expired(user: User) -> bool:
    """
    Check if a user's trial has expired

    Args:
        user: User model instance

    Returns:
        True if trial has expired, False otherwise
    """
    if not user.is_on_trial or not user.trial_end_date:
        return False

    return datetime.utcnow() >= user.trial_end_date


def expire_trial(user: User) -> bool:
    """
    Expire a user's trial and update their status

    Args:
        user: User model instance

    Returns:
        True if successful, False otherwise
    """
    try:
        if not user.is_on_trial:
            logger.warning(f"User {user.id} is not on trial, cannot expire")
            return False

        user.is_on_trial = False

        # If subscription is still in trialing status, it means Stripe hasn't
        # converted it to active yet, so we should check with Stripe
        if user.subscription_status == 'trialing':
            logger.info(f"Trial expired for user {user.id}, but subscription status is still 'trialing'")
            # Stripe webhook should handle the status update, but we can trigger a sync
            from app.services.stripe_service import StripeService
            try:
                stripe_service = StripeService()
                stripe_service.sync_user_subscription(user)
            except Exception as e:
                logger.error(f"Error syncing subscription for user {user.id}: {str(e)}")

        db.session.commit()
        logger.info(f"Trial expired for user {user.id}")
        return True

    except Exception as e:
        logger.error(f"Error expiring trial for user {user.id}: {str(e)}")
        db.session.rollback()
        return False


def check_and_expire_trials() -> int:
    """
    Check all users with active trials and expire those that have ended
    This function should be called periodically (e.g., daily cron job)

    Returns:
        Number of trials expired
    """
    try:
        # Find all users with active trials that have ended
        expired_users = User.query.filter(
            User.is_on_trial == True,
            User.trial_end_date <= datetime.utcnow()
        ).all()

        count = 0
        for user in expired_users:
            if expire_trial(user):
                count += 1

        if count > 0:
            logger.info(f"Expired {count} trial(s)")

        return count

    except Exception as e:
        logger.error(f"Error checking and expiring trials: {str(e)}")
        return 0


def send_trial_expiry_warning(user: User, days_remaining: int) -> bool:
    """
    Send a warning email to user about upcoming trial expiry

    Args:
        user: User model instance
        days_remaining: Number of days remaining in trial

    Returns:
        True if email sent successfully, False otherwise
    """
    try:
        # TODO: Implement email sending using Flask-Mail
        logger.info(f"Trial expiry warning for user {user.id}: {days_remaining} days remaining")

        # Example email logic (to be implemented):
        # from flask_mail import Message
        # from app.main import mail
        #
        # msg = Message(
        #     subject=f"Your TFVisualizer trial expires in {days_remaining} days",
        #     recipients=[user.email],
        #     body=f"Your 14-day trial will expire on {user.trial_end_date.strftime('%B %d, %Y')}..."
        # )
        # mail.send(msg)

        return True

    except Exception as e:
        logger.error(f"Error sending trial warning to user {user.id}: {str(e)}")
        return False


def check_and_send_trial_warnings() -> int:
    """
    Check for trials expiring soon and send warning emails
    Send warnings at 7 days, 3 days, and 1 day before expiry

    Returns:
        Number of warnings sent
    """
    try:
        now = datetime.utcnow()
        count = 0

        # Find users with active trials
        trial_users = User.query.filter(
            User.is_on_trial == True,
            User.trial_end_date > now
        ).all()

        for user in trial_users:
            days_remaining = user.days_remaining_in_trial()

            # Send warnings at specific thresholds
            if days_remaining in [7, 3, 1]:
                if send_trial_expiry_warning(user, days_remaining):
                    count += 1

        if count > 0:
            logger.info(f"Sent {count} trial expiry warning(s)")

        return count

    except Exception as e:
        logger.error(f"Error checking and sending trial warnings: {str(e)}")
        return 0

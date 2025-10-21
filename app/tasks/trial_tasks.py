"""
Background Tasks for Trial Management
Scheduled tasks to check trial expiration and send warnings
"""

from app.utils.trial_utils import check_and_expire_trials, check_and_send_trial_warnings
from app.utils.logger import setup_logger

logger = setup_logger(__name__)


def run_trial_expiration_check():
    """
    Background task to check and expire trials
    Should be run daily via cron or task scheduler
    """
    logger.info("Running trial expiration check...")
    count = check_and_expire_trials()
    logger.info(f"Trial expiration check complete. Expired {count} trial(s)")
    return count


def run_trial_warning_check():
    """
    Background task to send trial expiry warnings
    Should be run daily via cron or task scheduler
    """
    logger.info("Running trial warning check...")
    count = check_and_send_trial_warnings()
    logger.info(f"Trial warning check complete. Sent {count} warning(s)")
    return count


def run_all_trial_tasks():
    """
    Run all trial-related background tasks
    Convenience function to run both expiration and warning checks
    """
    logger.info("Running all trial tasks...")

    expired_count = run_trial_expiration_check()
    warning_count = run_trial_warning_check()

    logger.info(f"All trial tasks complete. Expired: {expired_count}, Warnings: {warning_count}")

    return {
        'expired': expired_count,
        'warnings': warning_count
    }


# Flask CLI commands for manual execution
def register_trial_commands(app):
    """
    Register trial management CLI commands with Flask app

    Usage:
        flask trial expire       # Check and expire trials
        flask trial warnings     # Send trial warnings
        flask trial all          # Run all trial tasks
    """
    import click

    @app.cli.group()
    def trial():
        """Trial management commands"""
        pass

    @trial.command()
    def expire():
        """Check and expire trials"""
        with app.app_context():
            count = run_trial_expiration_check()
            click.echo(f"Expired {count} trial(s)")

    @trial.command()
    def warnings():
        """Send trial expiry warnings"""
        with app.app_context():
            count = run_trial_warning_check()
            click.echo(f"Sent {count} warning(s)")

    @trial.command()
    def all():
        """Run all trial tasks"""
        with app.app_context():
            result = run_all_trial_tasks()
            click.echo(f"Expired: {result['expired']}, Warnings: {result['warnings']}")

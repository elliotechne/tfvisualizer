"""
Page Routes
Handles rendering of HTML pages (landing page, editor, etc.)
"""

from flask import Blueprint, render_template, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models.user import User
from app.utils.logger import setup_logger

bp = Blueprint('pages', __name__)
logger = setup_logger(__name__)


@bp.route('/')
def index():
    """
    Render landing page

    Returns:
        Rendered HTML landing page
    """
    return render_template('index.html',
                          stripe_publishable_key=current_app.config.get('STRIPE_PUBLISHABLE_KEY'))


@bp.route('/editor')
@bp.route('/editor.html')
def editor():
    """
    Render Terraform visual editor (Free tier - AWS only)
    Requires authentication and active subscription (free or pro)

    Returns:
        Rendered HTML editor page or redirect to pricing
    """
    from flask import redirect, url_for, flash
    from flask_jwt_extended import verify_jwt_in_request
    from jwt.exceptions import InvalidTokenError

    # Check if JWT token exists and is valid
    try:
        verify_jwt_in_request()
        user_id = get_jwt_identity()
    except Exception:
        # No valid token found - redirect to login
        flash('Please log in to access the editor', 'error')
        return redirect(url_for('pages.login_page'))

    # Get user from database
    user = User.query.get(user_id)
    if not user:
        flash('Please log in to access the editor', 'error')
        return redirect(url_for('pages.login_page'))

    # Check if user has an active subscription (free or pro)
    if user.subscription_status not in ['active', 'trialing']:
        flash('Please subscribe to a plan to access the editor', 'warning')
        return redirect(url_for('pages.pricing'))

    return render_template('editor.html', user=user)


@bp.route('/editor/pro')
def pro_editor():
    """
    Render Pro Terraform visual editor (Multi-cloud: AWS, GCP, Azure)
    Requires authentication and Pro subscription

    Returns:
        Rendered HTML Pro editor page or redirect
    """
    from flask import redirect, url_for, flash
    from flask_jwt_extended import verify_jwt_in_request

    # Check if JWT token exists and is valid
    try:
        verify_jwt_in_request()
        user_id = get_jwt_identity()
    except Exception:
        # No valid token found - redirect to login
        flash('Please log in to access the Pro editor', 'error')
        return redirect(url_for('pages.login_page'))

    # Get user from database
    user = User.query.get(user_id)
    if not user:
        flash('Please log in to access the Pro editor', 'error')
        return redirect(url_for('pages.login_page'))

    # Check if user has Pro subscription
    if user.subscription_tier != 'pro':
        flash('Pro subscription required to access multi-cloud editor', 'warning')
        return redirect(url_for('pages.pricing'))

    if user.subscription_status not in ['active', 'trialing']:
        flash('Please activate your Pro subscription', 'warning')
        return redirect(url_for('pages.pricing'))

    return render_template('editor_pro.html', user=user)


@bp.route('/pricing')
def pricing():
    """
    Render pricing page

    Returns:
        Rendered HTML pricing page
    """
    return render_template('pricing.html',
                          stripe_publishable_key=current_app.config.get('STRIPE_PUBLISHABLE_KEY'))


@bp.route('/dashboard')
@jwt_required(optional=True)
def dashboard():
    """
    Render user dashboard

    Returns:
        Rendered HTML dashboard page
    """
    user_id = get_jwt_identity()
    user = None

    if user_id:
        user = User.query.get(user_id)

        # Sync subscription status with Stripe if user has a Stripe customer ID
        if user and user.stripe_customer_id:
            try:
                from app.services.stripe_service import StripeService
                stripe_service = StripeService()
                stripe_service.sync_user_subscription(user)
            except Exception as e:
                logger.error(f"Error syncing subscription for user {user_id}: {str(e)}")

    return render_template('dashboard.html', user=user)


@bp.route('/login')
def login_page():
    """
    Render login page

    Returns:
        Rendered HTML login page
    """
    return render_template('login.html')


@bp.route('/register')
@bp.route('/signup')
def register_page():
    """
    Render registration page

    Returns:
        Rendered HTML registration page
    """
    return render_template('register.html')


@bp.route('/docs')
def documentation():
    """
    Render documentation page

    Returns:
        Rendered HTML documentation page
    """
    return render_template('docs.html')


@bp.route('/about')
def about():
    """
    Render about page

    Returns:
        Rendered HTML about page
    """
    return render_template('about.html')


@bp.route('/contact')
def contact():
    """
    Render contact page

    Returns:
        Rendered HTML contact page
    """
    return render_template('contact.html')


@bp.route('/terms')
def terms():
    """
    Render terms of service page

    Returns:
        Rendered HTML terms page
    """
    return render_template('terms.html')


@bp.route('/privacy')
def privacy():
    """
    Render privacy policy page

    Returns:
        Rendered HTML privacy page
    """
    return render_template('privacy.html')


@bp.route('/subscription/success')
def subscription_success():
    """
    Render subscription success page

    Returns:
        Rendered HTML success page
    """
    return render_template('subscription_success.html')


@bp.route('/subscription/cancel')
def subscription_cancel():
    """
    Render subscription cancellation page

    Returns:
        Rendered HTML cancellation page
    """
    return render_template('subscription_cancel.html')


@bp.route('/projects')
def projects_page():
    """
    Render projects management page
    Uses client-side authentication via JWT in localStorage

    Returns:
        Rendered HTML projects page
    """
    return render_template('projects.html')


@bp.route('/api/debug/tables')
def debug_tables():
    """
    Debug endpoint to check database tables

    Returns:
        JSON with table information
    """
    from app.main import db

    try:
        # Check if tables exist
        inspector = db.inspect(db.engine)
        tables = inspector.get_table_names()

        return jsonify({
            'success': True,
            'tables': tables,
            'projects_exists': 'projects' in tables,
            'users_exists': 'users' in tables
        }), 200
    except Exception as e:
        return jsonify({
            'error': str(e)
        }), 500

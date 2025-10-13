"""
Authentication Routes
Handles user registration, login, JWT token management, and OAuth
"""

from flask import Blueprint, request, jsonify, redirect, url_for, session
from flask_jwt_extended import create_access_token, create_refresh_token, jwt_required, get_jwt_identity
from app.models.user import User
from app.main import db
from app.utils.logger import setup_logger
import os
import requests
from urllib.parse import urlencode

bp = Blueprint('auth', __name__)
logger = setup_logger(__name__)


@bp.route('/register', methods=['POST'])
def register():
    """
    Register a new user

    Request Body:
        {
            "name": "John Doe",
            "email": "john@example.com",
            "password": "password123"
        }

    Returns:
        JSON with access token and user info
    """
    try:
        data = request.get_json()

        # Validate required fields
        if not data or not all(k in data for k in ('name', 'email', 'password')):
            return jsonify({'error': 'Missing required fields'}), 400

        name = data.get('name')
        email = data.get('email').lower().strip()
        password = data.get('password')

        # Check if user already exists
        if User.query.filter_by(email=email).first():
            return jsonify({'error': 'Email already registered'}), 400

        # Validate password length
        if len(password) < 8:
            return jsonify({'error': 'Password must be at least 8 characters'}), 400

        # Create new user with free tier active by default
        user = User(name=name, email=email)
        user.set_password(password)
        user.subscription_tier = 'free'
        user.subscription_status = 'active'  # Free tier is active by default

        db.session.add(user)
        db.session.commit()

        # Create access token
        access_token = create_access_token(identity=str(user.id))
        refresh_token = create_refresh_token(identity=str(user.id))

        logger.info(f"New user registered: {email}")

        # Create response with tokens in cookies
        response = jsonify({
            'success': True,
            'message': 'User registered successfully',
            'access_token': access_token,
            'refresh_token': refresh_token,
            'user': user.to_dict()
        })

        # Set JWT cookies for browser-based authentication
        from flask_jwt_extended import set_access_cookies, set_refresh_cookies
        set_access_cookies(response, access_token)
        set_refresh_cookies(response, refresh_token)

        return response, 201

    except Exception as e:
        logger.error(f"Registration error: {str(e)}")
        db.session.rollback()
        return jsonify({'error': 'Registration failed'}), 500


@bp.route('/login', methods=['POST'])
def login():
    """
    Login user

    Request Body:
        {
            "email": "john@example.com",
            "password": "password123"
        }

    Returns:
        JSON with access token and user info
    """
    try:
        data = request.get_json()

        if not data or not all(k in data for k in ('email', 'password')):
            return jsonify({'error': 'Missing email or password'}), 400

        email = data.get('email').lower().strip()
        password = data.get('password')

        # Find user
        user = User.query.filter_by(email=email).first()

        if not user or not user.check_password(password):
            return jsonify({'error': 'Invalid email or password'}), 401

        # Create access token
        access_token = create_access_token(identity=str(user.id))
        refresh_token = create_refresh_token(identity=str(user.id))

        logger.info(f"User logged in: {email}")

        # Create response with tokens in cookies
        response = jsonify({
            'success': True,
            'message': 'Login successful',
            'access_token': access_token,
            'refresh_token': refresh_token,
            'user': user.to_dict()
        })

        # Set JWT cookies for browser-based authentication
        from flask_jwt_extended import set_access_cookies, set_refresh_cookies
        set_access_cookies(response, access_token)
        set_refresh_cookies(response, refresh_token)

        return response, 200

    except Exception as e:
        logger.error(f"Login error: {str(e)}")
        return jsonify({'error': 'Login failed'}), 500


@bp.route('/me', methods=['GET'])
@jwt_required()
def get_current_user():
    """
    Get current user information

    Headers:
        Authorization: Bearer <access_token>

    Returns:
        JSON with user info
    """
    try:
        user_id = get_jwt_identity()
        user = User.query.get(user_id)

        if not user:
            return jsonify({'error': 'User not found'}), 404

        return jsonify({
            'success': True,
            'user': user.to_dict()
        }), 200

    except Exception as e:
        logger.error(f"Get user error: {str(e)}")
        return jsonify({'error': 'Failed to fetch user'}), 500


@bp.route('/refresh', methods=['POST'])
@jwt_required(refresh=True)
def refresh():
    """
    Refresh access token

    Headers:
        Authorization: Bearer <refresh_token>

    Returns:
        JSON with new access token
    """
    try:
        user_id = get_jwt_identity()
        access_token = create_access_token(identity=user_id)

        return jsonify({
            'success': True,
            'access_token': access_token
        }), 200

    except Exception as e:
        logger.error(f"Token refresh error: {str(e)}")
        return jsonify({'error': 'Token refresh failed'}), 500


@bp.route('/logout', methods=['POST'])
@jwt_required()
def logout():
    """
    Logout user (client-side should remove token and clear cookies)

    Returns:
        JSON with success message
    """
    from flask_jwt_extended import unset_jwt_cookies

    # Create response
    response = jsonify({
        'success': True,
        'message': 'Logout successful'
    })

    # Clear JWT cookies
    unset_jwt_cookies(response)

    return response, 200


@bp.route('/google/login', methods=['GET'])
def google_login():
    """
    Initiate Google OAuth flow
    """
    google_client_id = os.getenv('GOOGLE_CLIENT_ID', '').strip()
    if not google_client_id:
        return jsonify({'error': 'Google OAuth not configured'}), 500

    # Force HTTPS for redirect URI (required for OAuth)
    redirect_uri = url_for('auth.google_callback', _external=True, _scheme='https')

    # Log for debugging
    logger.info(f"Google OAuth redirect_uri: {redirect_uri}")
    logger.info(f"Google OAuth client_id: {google_client_id}")

    # Build OAuth URL with proper encoding
    params = {
        'client_id': google_client_id,
        'redirect_uri': redirect_uri,
        'response_type': 'code',
        'scope': 'openid email profile',
        'access_type': 'offline'
    }
    google_auth_url = f"https://accounts.google.com/o/oauth2/v2/auth?{urlencode(params)}"

    logger.info(f"Redirecting to: {google_auth_url}")

    return redirect(google_auth_url)


@bp.route('/google/callback', methods=['GET'])
def google_callback():
    """
    Handle Google OAuth callback
    """
    try:
        code = request.args.get('code')
        if not code:
            return redirect('/login?error=oauth_failed')

        google_client_id = os.getenv('GOOGLE_CLIENT_ID', '').strip()
        google_client_secret = os.getenv('GOOGLE_CLIENT_SECRET', '').strip()

        if not google_client_id or not google_client_secret:
            return redirect('/login?error=oauth_not_configured')

        # Exchange code for token (must match the redirect_uri sent to Google)
        redirect_uri = url_for('auth.google_callback', _external=True, _scheme='https')
        token_url = 'https://oauth2.googleapis.com/token'
        token_data = {
            'code': code,
            'client_id': google_client_id,
            'client_secret': google_client_secret,
            'redirect_uri': redirect_uri,
            'grant_type': 'authorization_code'
        }

        token_response = requests.post(token_url, data=token_data)
        token_json = token_response.json()

        logger.info(f"Google token response status: {token_response.status_code}")
        logger.info(f"Google token response: {token_json}")

        if 'error' in token_json:
            logger.error(f"Google OAuth token error: {token_json.get('error')}, description: {token_json.get('error_description')}")
            return redirect('/login?error=oauth_token_failed')

        access_token = token_json.get('access_token')

        # Get user info from Google
        user_info_url = 'https://www.googleapis.com/oauth2/v2/userinfo'
        user_info_response = requests.get(
            user_info_url,
            headers={'Authorization': f'Bearer {access_token}'}
        )
        user_info = user_info_response.json()

        email = user_info.get('email')
        name = user_info.get('name', email.split('@')[0])
        google_id = user_info.get('id')
        avatar_url = user_info.get('picture')

        if not email or not google_id:
            return redirect('/login?error=oauth_invalid_response')

        # Find or create user
        user = User.query.filter_by(email=email.lower().strip()).first()

        if not user:
            # Create new user with OAuth
            user = User(
                email=email.lower().strip(),
                name=name,
                oauth_provider='google',
                oauth_id=google_id,
                oauth_token=access_token,
                avatar_url=avatar_url,
                subscription_tier='free',
                subscription_status='active'
            )
            db.session.add(user)
            db.session.commit()
            logger.info(f"New Google OAuth user created: {email}")
        else:
            # Update existing user with OAuth info if not already set
            if not user.oauth_provider:
                user.oauth_provider = 'google'
                user.oauth_id = google_id
                user.oauth_token = access_token
                if avatar_url:
                    user.avatar_url = avatar_url
                db.session.commit()
                logger.info(f"Existing user linked to Google: {email}")

        # Create JWT tokens
        access_token_jwt = create_access_token(identity=str(user.id))
        refresh_token_jwt = create_refresh_token(identity=str(user.id))

        # Redirect to dashboard with tokens in URL (will be moved to localStorage by client)
        return redirect(f'/dashboard?access_token={access_token_jwt}&refresh_token={refresh_token_jwt}')

    except Exception as e:
        logger.error(f"Google OAuth callback error: {str(e)}")
        return redirect('/login?error=oauth_exception')

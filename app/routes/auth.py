"""
Authentication Routes
Handles user registration, login, and JWT token management
"""

from flask import Blueprint, request, jsonify
from flask_jwt_extended import create_access_token, create_refresh_token, jwt_required, get_jwt_identity
from app.models.user import User
from app.main import db
from app.utils.logger import setup_logger

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

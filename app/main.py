"""
TFVisualizer - Main Application Entry Point
A Python Flask application for visual Terraform infrastructure design with Stripe subscriptions
"""

import os
from flask import Flask, send_from_directory, jsonify
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import JWTManager
from flask_migrate import Migrate
from redis import Redis

from app.config.settings import Config
from app.middleware.error_handler import register_error_handlers
from app.utils.logger import setup_logger

# Initialize extensions
db = SQLAlchemy()
jwt = JWTManager()
migrate = Migrate()
redis_client = None

logger = setup_logger(__name__)


def create_app(config_class=Config):
    """Application factory pattern"""
    app = Flask(__name__,
                static_folder='../static',
                template_folder='../templates')

    # Load configuration
    app.config.from_object(config_class)

    # Initialize extensions
    db.init_app(app)
    jwt.init_app(app)
    migrate.init_app(app, db)

    # Setup CORS
    CORS(app, resources={
        r"/api/*": {
            "origins": app.config['CORS_ORIGINS'],
            "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
            "allow_headers": ["Content-Type", "Authorization"]
        }
    })

    # Initialize Redis
    global redis_client
    try:
        redis_client = Redis.from_url(
            app.config['REDIS_URL'],
            decode_responses=True
        )
    except Exception as e:
        logger.warning(f"Failed to initialize Redis: {e}")
        redis_client = None

    # Register error handlers
    register_error_handlers(app)

    # Add before_request handler for protected routes
    @app.before_request
    def check_protected_routes():
        """Check authentication for protected routes before processing request"""
        from flask import request, redirect, url_for
        from flask_jwt_extended import verify_jwt_in_request

        # List of routes that require authentication
        # Note: /dashboard handles its own optional auth, so it's not in this list
        protected_routes = ['/editor', '/editor.html']

        # Check if current path is protected
        if request.path in protected_routes or request.path.endswith('/editor.html'):
            try:
                verify_jwt_in_request()
            except Exception:
                # No valid JWT token - redirect to login
                return redirect(url_for('pages.login_page'))

    # Register blueprints
    from app.routes import auth, projects, terraform, subscription, webhooks, pages

    app.register_blueprint(auth.bp, url_prefix='/api/auth')
    app.register_blueprint(projects.bp, url_prefix='/api/projects')
    app.register_blueprint(terraform.bp, url_prefix='/api/terraform')
    app.register_blueprint(subscription.bp, url_prefix='/api/subscription')
    app.register_blueprint(webhooks.bp, url_prefix='/api/webhooks')
    app.register_blueprint(pages.bp)  # Landing page routes

    # Health check endpoint
    @app.route('/health')
    def health():
        """Health check for load balancers"""
        try:
            # Check database connection
            db.session.execute(db.text('SELECT 1'))

            # Check Redis connection (optional)
            redis_status = 'not_configured'
            if redis_client:
                try:
                    redis_client.ping()
                    redis_status = 'connected'
                except Exception as e:
                    logger.warning(f"Redis health check failed: {e}")
                    redis_status = 'disconnected'

            return jsonify({
                'status': 'healthy',
                'database': 'connected',
                'redis': redis_status
            }), 200
        except Exception as e:
            logger.error(f"Health check failed: {str(e)}")
            return jsonify({
                'status': 'unhealthy',
                'error': str(e)
            }), 503

    # API info endpoint
    @app.route('/api')
    def api_info():
        """API information"""
        return jsonify({
            'name': 'TFVisualizer API',
            'version': '1.0.0',
            'description': 'Visual Terraform Infrastructure Designer',
            'endpoints': {
                'auth': '/api/auth',
                'projects': '/api/projects',
                'terraform': '/api/terraform',
                'subscription': '/api/subscription',
                'webhooks': '/api/webhooks'
            }
        })

    logger.info("TFVisualizer application initialized successfully")
    return app


if __name__ == '__main__':
    app = create_app()

    # Development server
    port = int(os.environ.get('PORT', 80))
    debug = os.environ.get('FLASK_ENV') == 'development'

    logger.info(f"Starting TFVisualizer on port {port} (debug={debug})")
    app.run(host='0.0.0.0', port=port, debug=debug)

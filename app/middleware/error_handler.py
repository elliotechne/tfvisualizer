"""
Global Error Handlers
"""

from flask import jsonify
from werkzeug.exceptions import HTTPException
from app.utils.logger import setup_logger

logger = setup_logger(__name__)


def register_error_handlers(app):
    """Register global error handlers for the Flask app"""

    @app.errorhandler(404)
    def not_found(error):
        """Handle 404 Not Found errors"""
        return jsonify({
            'error': 'Not found',
            'message': str(error)
        }), 404

    @app.errorhandler(400)
    def bad_request(error):
        """Handle 400 Bad Request errors"""
        return jsonify({
            'error': 'Bad request',
            'message': str(error)
        }), 400

    @app.errorhandler(401)
    def unauthorized(error):
        """Handle 401 Unauthorized errors"""
        return jsonify({
            'error': 'Unauthorized',
            'message': 'Authentication required'
        }), 401

    @app.errorhandler(403)
    def forbidden(error):
        """Handle 403 Forbidden errors"""
        return jsonify({
            'error': 'Forbidden',
            'message': 'You do not have permission to access this resource'
        }), 403

    @app.errorhandler(500)
    def internal_server_error(error):
        """Handle 500 Internal Server Error"""
        # Log the full exception for diagnostics
        logger.exception(f"Internal server error: {str(error)}")

        # In development mode, include the error message to aid debugging
        if app.config.get('DEBUG') or app.config.get('FLASK_ENV') == 'development':
            return jsonify({
                'error': 'Internal server error',
                'message': str(error)
            }), 500

        return jsonify({
            'error': 'Internal server error',
            'message': 'An unexpected error occurred'
        }), 500

    @app.errorhandler(HTTPException)
    def handle_http_exception(error):
        """Handle all HTTP exceptions"""
        return jsonify({
            'error': error.name,
            'message': error.description
        }), error.code

    @app.errorhandler(Exception)
    def handle_exception(error):
        """Handle all uncaught exceptions"""
        logger.exception(f"Unhandled exception: {str(error)}")

        # Surface exception details in development to help debugging
        if app.config.get('DEBUG') or app.config.get('FLASK_ENV') == 'development':
            return jsonify({
                'error': 'Internal server error',
                'message': str(error)
            }), 500

        return jsonify({
            'error': 'Internal server error',
            'message': 'An unexpected error occurred'
        }), 500

"""
AI Routes
Handles AI-powered features (cost optimization, design assistant)
"""

from flask import Blueprint, request, jsonify, Response, stream_with_context
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models.user import User
from app.services.ai_service import AIService
from app.utils.logger import setup_logger
import json

bp = Blueprint('ai', __name__)
logger = setup_logger(__name__)
ai_service = AIService()


@bp.route('/available', methods=['GET'])
def check_availability():
    """
    Check if AI features are available

    Returns:
        JSON with availability status
    """
    return jsonify({
        'available': ai_service.is_available()
    }), 200


@bp.route('/cost-optimization', methods=['POST'])
@jwt_required()
def optimize_costs():
    """
    Analyze infrastructure and suggest cost optimizations (streaming)

    Request Body:
        {
            "resources": [...],
            "current_cost": 123.45
        }

    Returns:
        Streaming response with optimization recommendations
    """
    try:
        user_id = get_jwt_identity()
        user = User.query.get(user_id)

        if not user:
            return jsonify({'error': 'User not found'}), 404

        # Check if user has Pro subscription
        if user.subscription_tier != 'pro' or user.subscription_status not in ['active', 'trialing']:
            return jsonify({
                'error': 'AI features require Pro subscription',
                'upgrade_url': '/pricing'
            }), 403

        data = request.get_json()

        if not data or 'resources' not in data:
            return jsonify({'error': 'Resources required'}), 400

        resources = data.get('resources', [])
        current_cost = data.get('current_cost', 0)

        if not resources:
            return jsonify({'error': 'No resources to analyze'}), 400

        logger.info(f"Cost optimization analysis started for user {user_id}")

        # Stream the AI response
        def generate():
            try:
                for chunk in ai_service.analyze_cost_optimization(resources, current_cost):
                    if isinstance(chunk, dict):
                        # Error or metadata
                        yield f"data: {json.dumps(chunk)}\n\n"
                    else:
                        # Text chunk
                        yield f"data: {json.dumps({'chunk': chunk})}\n\n"
                yield "data: [DONE]\n\n"
            except Exception as e:
                logger.error(f"Streaming error: {str(e)}")
                yield f"data: {json.dumps({'error': str(e)})}\n\n"

        return Response(
            stream_with_context(generate()),
            mimetype='text/event-stream',
            headers={
                'Cache-Control': 'no-cache',
                'X-Accel-Buffering': 'no'
            }
        )

    except Exception as e:
        logger.error(f"Cost optimization error: {str(e)}")
        return jsonify({'error': 'Failed to analyze costs'}), 500


@bp.route('/design', methods=['POST'])
@jwt_required()
def generate_design():
    """
    Generate infrastructure design from natural language (streaming)

    Request Body:
        {
            "prompt": "Create a 3-tier web application",
            "cloud_provider": "aws"
        }

    Returns:
        Streaming response with generated design chunks
    """
    try:
        user_id = get_jwt_identity()
        user = User.query.get(user_id)

        if not user:
            return jsonify({'error': 'User not found'}), 404

        # Check if user has Pro subscription
        if user.subscription_tier != 'pro' or user.subscription_status not in ['active', 'trialing']:
            return jsonify({
                'error': 'AI features require Pro subscription',
                'upgrade_url': '/pricing'
            }), 403

        data = request.get_json()

        if not data or 'prompt' not in data:
            return jsonify({'error': 'Prompt required'}), 400

        user_prompt = data.get('prompt', '').strip()
        cloud_provider = data.get('cloud_provider', 'aws')

        if not user_prompt:
            return jsonify({'error': 'Prompt cannot be empty'}), 400

        # Validate cloud provider
        valid_providers = ['aws', 'gcp', 'azure', 'digitalocean', 'kubernetes']
        if cloud_provider not in valid_providers:
            return jsonify({
                'error': 'Invalid cloud provider',
                'valid_providers': valid_providers
            }), 400

        logger.info(f"Design generation started for user {user_id}: {user_prompt[:50]}...")

        # Stream the AI response
        def generate():
            try:
                for chunk in ai_service.generate_design(user_prompt, cloud_provider):
                    if isinstance(chunk, dict):
                        # Error or metadata
                        yield f"data: {json.dumps(chunk)}\n\n"
                    else:
                        # Text chunk
                        yield f"data: {json.dumps({'chunk': chunk})}\n\n"
                yield "data: [DONE]\n\n"
            except Exception as e:
                logger.error(f"Streaming error: {str(e)}")
                yield f"data: {json.dumps({'error': str(e)})}\n\n"

        return Response(
            stream_with_context(generate()),
            mimetype='text/event-stream',
            headers={
                'Cache-Control': 'no-cache',
                'X-Accel-Buffering': 'no'
            }
        )

    except Exception as e:
        logger.error(f"Design generation error: {str(e)}")
        return jsonify({'error': 'Failed to generate design'}), 500

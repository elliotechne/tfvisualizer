"""
Project Routes
Handles project CRUD operations
"""

from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models.user import User
from app.models.project import Project, ProjectVersion
from app.main import db
from app.utils.logger import setup_logger

bp = Blueprint('projects', __name__)
logger = setup_logger(__name__)


@bp.route('/', methods=['GET'])
@jwt_required()
def list_projects():
    """
    List all projects for current user

    Returns:
        JSON with list of projects
    """
    try:
        user_id = get_jwt_identity()
        user = User.query.get(user_id)

        if not user:
            return jsonify({'error': 'User not found'}), 404

        projects = Project.query.filter_by(user_id=user_id).all()

        return jsonify({
            'success': True,
            'projects': [p.to_dict() for p in projects]
        }), 200

    except Exception as e:
        logger.error(f"List projects error: {str(e)}")
        return jsonify({'error': 'Failed to fetch projects'}), 500


@bp.route('/', methods=['POST'])
@jwt_required()
def create_project():
    """
    Create a new project

    Request Body:
        {
            "name": "My Infrastructure",
            "description": "Production AWS setup"
        }

    Returns:
        JSON with created project
    """
    try:
        user_id = get_jwt_identity()
        user = User.query.get(user_id)

        if not user:
            return jsonify({'error': 'User not found'}), 404

        # Check project limit for free tier
        if not user.can_create_project():
            return jsonify({
                'error': 'Project limit reached',
                'message': 'Upgrade to Pro for unlimited projects'
            }), 403

        data = request.get_json()

        if not data or 'name' not in data:
            return jsonify({'error': 'Project name is required'}), 400

        project = Project(
            user_id=user_id,
            name=data.get('name'),
            description=data.get('description', ''),
            visibility=data.get('visibility', 'private')
        )

        db.session.add(project)
        db.session.commit()

        logger.info(f"Project created: {project.id} by user {user_id}")

        return jsonify({
            'success': True,
            'project': project.to_dict()
        }), 201

    except Exception as e:
        logger.error(f"Create project error: {str(e)}")
        db.session.rollback()
        return jsonify({'error': 'Failed to create project'}), 500


@bp.route('/<project_id>', methods=['GET'])
@jwt_required()
def get_project(project_id):
    """
    Get project details

    Returns:
        JSON with project details
    """
    try:
        user_id = get_jwt_identity()
        project = Project.query.get(project_id)

        if not project:
            return jsonify({'error': 'Project not found'}), 404

        # Check ownership
        if project.user_id != user_id:
            return jsonify({'error': 'Unauthorized'}), 403

        return jsonify({
            'success': True,
            'project': project.to_dict()
        }), 200

    except Exception as e:
        logger.error(f"Get project error: {str(e)}")
        return jsonify({'error': 'Failed to fetch project'}), 500


@bp.route('/<project_id>', methods=['DELETE'])
@jwt_required()
def delete_project(project_id):
    """
    Delete a project

    Returns:
        JSON with success message
    """
    try:
        user_id = get_jwt_identity()
        project = Project.query.get(project_id)

        if not project:
            return jsonify({'error': 'Project not found'}), 404

        # Check ownership
        if project.user_id != user_id:
            return jsonify({'error': 'Unauthorized'}), 403

        db.session.delete(project)
        db.session.commit()

        logger.info(f"Project deleted: {project_id}")

        return jsonify({
            'success': True,
            'message': 'Project deleted successfully'
        }), 200

    except Exception as e:
        logger.error(f"Delete project error: {str(e)}")
        db.session.rollback()
        return jsonify({'error': 'Failed to delete project'}), 500

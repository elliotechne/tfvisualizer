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


@bp.route('/<project_id>/save', methods=['POST'])
@jwt_required()
def save_project_state(project_id):
    """
    Save project state (resources, connections, positions)

    Request Body:
        {
            "resources": [...],
            "connections": [...],
            "positions": {...},
            "terraform_code": "..."
        }

    Returns:
        JSON with version information
    """
    try:
        user_id = get_jwt_identity()
        project = Project.query.get(project_id)

        if not project:
            return jsonify({'error': 'Project not found'}), 404

        # Check ownership
        if project.user_id != user_id:
            return jsonify({'error': 'Unauthorized'}), 403

        data = request.get_json()

        if not data:
            return jsonify({'error': 'No data provided'}), 400

        # Get the latest version number
        latest_version = ProjectVersion.query.filter_by(
            project_id=project_id
        ).order_by(ProjectVersion.version_number.desc()).first()

        next_version = (latest_version.version_number + 1) if latest_version else 1

        # Create new version
        version = ProjectVersion(
            project_id=project_id,
            version_number=next_version,
            resources=data.get('resources', []),
            connections=data.get('connections', []),
            positions=data.get('positions', {}),
            terraform_code=data.get('terraform_code', ''),
            created_by=user_id
        )

        db.session.add(version)
        db.session.commit()

        logger.info(f"Project state saved: {project_id} v{next_version}")

        return jsonify({
            'success': True,
            'version': version.to_dict()
        }), 201

    except Exception as e:
        logger.error(f"Save project state error: {str(e)}")
        db.session.rollback()
        return jsonify({'error': 'Failed to save project state'}), 500


@bp.route('/<project_id>/load', methods=['GET'])
@jwt_required()
def load_project_state(project_id):
    """
    Load latest project state

    Returns:
        JSON with project state (resources, connections, positions)
    """
    try:
        user_id = get_jwt_identity()
        project = Project.query.get(project_id)

        if not project:
            return jsonify({'error': 'Project not found'}), 404

        # Check ownership
        if project.user_id != user_id:
            return jsonify({'error': 'Unauthorized'}), 403

        # Get latest version
        latest_version = ProjectVersion.query.filter_by(
            project_id=project_id
        ).order_by(ProjectVersion.version_number.desc()).first()

        if not latest_version:
            return jsonify({
                'success': True,
                'state': {
                    'resources': [],
                    'connections': [],
                    'positions': {},
                    'terraform_code': ''
                }
            }), 200

        return jsonify({
            'success': True,
            'state': {
                'resources': latest_version.resources,
                'connections': latest_version.connections,
                'positions': latest_version.positions,
                'terraform_code': latest_version.terraform_code
            },
            'version': latest_version.version_number
        }), 200

    except Exception as e:
        logger.error(f"Load project state error: {str(e)}")
        return jsonify({'error': 'Failed to load project state'}), 500


@bp.route('/<project_id>/versions', methods=['GET'])
@jwt_required()
def list_versions(project_id):
    """
    List all versions of a project

    Returns:
        JSON with list of versions (metadata only, no full state)
    """
    try:
        user_id = get_jwt_identity()
        project = Project.query.get(project_id)

        if not project:
            return jsonify({'error': 'Project not found'}), 404

        # Check ownership
        if project.user_id != user_id:
            return jsonify({'error': 'Unauthorized'}), 403

        # Get all versions ordered by version number descending (newest first)
        versions = ProjectVersion.query.filter_by(
            project_id=project_id
        ).order_by(ProjectVersion.version_number.desc()).all()

        # Return minimal version info (no full state data)
        version_list = [{
            'id': v.id,
            'version_number': v.version_number,
            'created_by': v.created_by,
            'created_at': v.created_at.isoformat(),
            'resource_count': len(v.resources) if v.resources else 0
        } for v in versions]

        return jsonify({
            'success': True,
            'versions': version_list
        }), 200

    except Exception as e:
        logger.error(f"List versions error: {str(e)}")
        return jsonify({'error': 'Failed to list versions'}), 500


@bp.route('/<project_id>/versions/<int:version_number>', methods=['GET'])
@jwt_required()
def load_specific_version(project_id, version_number):
    """
    Load a specific version of a project

    Returns:
        JSON with project state from specified version
    """
    try:
        user_id = get_jwt_identity()
        project = Project.query.get(project_id)

        if not project:
            return jsonify({'error': 'Project not found'}), 404

        # Check ownership
        if project.user_id != user_id:
            return jsonify({'error': 'Unauthorized'}), 403

        # Get specific version
        version = ProjectVersion.query.filter_by(
            project_id=project_id,
            version_number=version_number
        ).first()

        if not version:
            return jsonify({'error': 'Version not found'}), 404

        return jsonify({
            'success': True,
            'state': {
                'resources': version.resources,
                'connections': version.connections,
                'positions': version.positions,
                'terraform_code': version.terraform_code
            },
            'version': version.version_number,
            'created_at': version.created_at.isoformat()
        }), 200

    except Exception as e:
        logger.error(f"Load specific version error: {str(e)}")
        return jsonify({'error': 'Failed to load version'}), 500

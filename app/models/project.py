"""
Project Model
"""

from datetime import datetime
from app.main import db
import uuid


class Project(db.Model):
    """Project model for storing Terraform infrastructure designs"""

    __tablename__ = 'projects'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)

    name = db.Column(db.String(255), nullable=False)
    description = db.Column(db.Text, nullable=True)
    visibility = db.Column(db.String(50), default='private')  # 'private', 'public', 'team'

    # Timestamps
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # Relationships
    versions = db.relationship('ProjectVersion', backref='project', lazy='dynamic', cascade='all, delete-orphan')

    def to_dict(self) -> dict:
        """Convert project to dictionary"""
        return {
            'id': self.id,
            'user_id': self.user_id,
            'name': self.name,
            'description': self.description,
            'visibility': self.visibility,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }

    def __repr__(self):
        return f'<Project {self.name}>'


class ProjectVersion(db.Model):
    """Project version model for version control"""

    __tablename__ = 'project_versions'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    project_id = db.Column(db.String(36), db.ForeignKey('projects.id', ondelete='CASCADE'), nullable=False, index=True)

    version_number = db.Column(db.Integer, nullable=False)
    resources = db.Column(db.JSON, nullable=False)  # JSONB in PostgreSQL
    connections = db.Column(db.JSON, nullable=False)
    positions = db.Column(db.JSON, nullable=False)
    terraform_code = db.Column(db.Text, nullable=True)

    created_by = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)

    def to_dict(self) -> dict:
        """Convert project version to dictionary"""
        return {
            'id': self.id,
            'project_id': self.project_id,
            'version_number': self.version_number,
            'resources': self.resources,
            'connections': self.connections,
            'positions': self.positions,
            'terraform_code': self.terraform_code,
            'created_by': self.created_by,
            'created_at': self.created_at.isoformat()
        }

    def __repr__(self):
        return f'<ProjectVersion {self.project_id} v{self.version_number}>'

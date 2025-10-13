"""
User Model
"""

from datetime import datetime
from app.main import db
from werkzeug.security import generate_password_hash, check_password_hash
import uuid


class User(db.Model):
    """User model for authentication and subscription management"""

    __tablename__ = 'users'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    email = db.Column(db.String(255), unique=True, nullable=False, index=True)
    name = db.Column(db.String(255), nullable=False)
    password_hash = db.Column(db.String(255), nullable=True)  # Nullable for OAuth users
    avatar_url = db.Column(db.Text, nullable=True)

    # OAuth fields
    oauth_provider = db.Column(db.String(50), nullable=True)  # 'google', 'github', etc.
    oauth_id = db.Column(db.String(255), nullable=True)  # Provider's user ID
    oauth_token = db.Column(db.Text, nullable=True)  # OAuth access token (encrypted in production)

    # Stripe fields
    stripe_customer_id = db.Column(db.String(255), unique=True, nullable=True)
    subscription_tier = db.Column(db.String(50), default='free')  # 'free' or 'pro'
    subscription_status = db.Column(db.String(50), default='inactive')  # 'active', 'inactive', 'canceled', etc.

    # Timestamps
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # Relationships
    projects = db.relationship('Project', backref='user', lazy='dynamic', cascade='all, delete-orphan')
    subscriptions = db.relationship('Subscription', backref='user', lazy='dynamic', cascade='all, delete-orphan')
    payments = db.relationship('PaymentHistory', backref='user', lazy='dynamic', cascade='all, delete-orphan')

    def set_password(self, password: str) -> None:
        """Hash and set user password"""
        self.password_hash = generate_password_hash(password)

    def check_password(self, password: str) -> bool:
        """Verify password against hash"""
        return check_password_hash(self.password_hash, password)

    def can_create_project(self) -> bool:
        """Check if user can create more projects based on their tier"""
        from app.config.settings import Config

        if self.subscription_tier == 'pro':
            return True  # Unlimited for Pro tier

        # Free tier has a limit
        project_count = self.projects.count()
        return project_count < Config.FREE_TIER_PROJECT_LIMIT

    def to_dict(self) -> dict:
        """Convert user to dictionary (exclude sensitive data)"""
        return {
            'id': self.id,
            'email': self.email,
            'name': self.name,
            'avatar_url': self.avatar_url,
            'subscription_tier': self.subscription_tier,
            'subscription_status': self.subscription_status,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }

    def __repr__(self):
        return f'<User {self.email}>'

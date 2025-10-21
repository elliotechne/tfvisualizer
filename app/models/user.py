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
    subscription_status = db.Column(db.String(50), default='inactive')  # 'active', 'inactive', 'canceled', 'trialing', etc.

    # Trial fields
    is_on_trial = db.Column(db.Boolean, default=False)
    trial_start_date = db.Column(db.DateTime, nullable=True)
    trial_end_date = db.Column(db.DateTime, nullable=True)

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

    def is_trial_active(self) -> bool:
        """Check if user's trial period is still active"""
        if not self.is_on_trial or not self.trial_end_date:
            return False
        return datetime.utcnow() < self.trial_end_date

    def days_remaining_in_trial(self) -> int:
        """Get number of days remaining in trial"""
        if not self.is_trial_active():
            return 0
        delta = self.trial_end_date - datetime.utcnow()
        return max(0, delta.days)

    def can_create_project(self) -> bool:
        """Check if user can create more projects based on their tier"""
        from app.config.settings import Config

        # Pro tier or active trial gets unlimited projects
        if self.subscription_tier == 'pro' or self.is_trial_active():
            return True

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
            'is_on_trial': self.is_on_trial,
            'trial_end_date': self.trial_end_date.isoformat() if self.trial_end_date else None,
            'days_remaining_in_trial': self.days_remaining_in_trial() if self.is_on_trial else 0,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }

    def __repr__(self):
        return f'<User {self.email}>'

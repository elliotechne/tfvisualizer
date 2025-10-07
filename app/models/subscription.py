"""
Subscription Model
"""

from datetime import datetime
from app.main import db
import uuid


class Subscription(db.Model):
    """Subscription model for tracking Stripe subscriptions"""

    __tablename__ = 'subscriptions'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False)

    # Stripe fields
    stripe_subscription_id = db.Column(db.String(255), unique=True, nullable=False, index=True)
    stripe_price_id = db.Column(db.String(255), nullable=False)
    status = db.Column(db.String(50), nullable=False)  # 'active', 'canceled', 'past_due', etc.

    # Subscription period
    current_period_start = db.Column(db.Integer, nullable=False)  # Unix timestamp
    current_period_end = db.Column(db.Integer, nullable=False)  # Unix timestamp
    cancel_at_period_end = db.Column(db.Boolean, default=False)

    # Timestamps
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    def to_dict(self) -> dict:
        """Convert subscription to dictionary"""
        return {
            'id': self.id,
            'user_id': self.user_id,
            'stripe_subscription_id': self.stripe_subscription_id,
            'status': self.status,
            'current_period_start': self.current_period_start,
            'current_period_end': self.current_period_end,
            'cancel_at_period_end': self.cancel_at_period_end,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }

    def __repr__(self):
        return f'<Subscription {self.stripe_subscription_id}>'

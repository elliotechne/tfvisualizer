"""
Payment History Model
"""

from datetime import datetime
from app.main import db
import uuid


class PaymentHistory(db.Model):
    """Payment history model for tracking Stripe payments"""

    __tablename__ = 'payment_history'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False)

    # Stripe payment fields
    stripe_payment_intent_id = db.Column(db.String(255), unique=True, nullable=False, index=True)
    amount = db.Column(db.Numeric(10, 2), nullable=False)  # Amount in dollars
    currency = db.Column(db.String(3), default='usd', nullable=False)
    status = db.Column(db.String(50), nullable=False)  # 'succeeded', 'failed', 'pending'

    # Timestamp
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)

    def to_dict(self) -> dict:
        """Convert payment to dictionary"""
        return {
            'id': self.id,
            'user_id': self.user_id,
            'stripe_payment_intent_id': self.stripe_payment_intent_id,
            'amount': float(self.amount),
            'currency': self.currency,
            'status': self.status,
            'created_at': self.created_at.isoformat()
        }

    def __repr__(self):
        return f'<PaymentHistory {self.stripe_payment_intent_id}>'

#!/usr/bin/env python3
"""
Database initialization script
Creates all tables defined in SQLAlchemy models
"""

import sys
import os

# Add app directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.main import create_app, db
from app.models.user import User
from app.models.project import Project, ProjectVersion
from app.models.subscription import Subscription
from app.models.payment import PaymentHistory

def init_database():
    """Initialize database tables"""
    app = create_app()

    with app.app_context():
        print("Creating database tables...")

        # Create all tables
        db.create_all()

        print("Database tables created successfully!")

        # List all tables
        from sqlalchemy import inspect
        inspector = inspect(db.engine)
        tables = inspector.get_table_names()

        print(f"\nExisting tables: {', '.join(tables)}")

        return True

if __name__ == '__main__':
    try:
        init_database()
        print("\n✓ Database initialization complete")
        sys.exit(0)
    except Exception as e:
        print(f"\n✗ Database initialization failed: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

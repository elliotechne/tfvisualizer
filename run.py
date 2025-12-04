#!/usr/bin/env python
"""
Quick start script for TFVisualizer
Runs the Flask development server
"""

import os
from app.main import create_app

if __name__ == '__main__':
    app = create_app()

    # Default to 8080 for local development to avoid requiring root for port 80
    port = int(os.environ.get('PORT', 8080))
    debug = os.environ.get('FLASK_ENV') == 'development'

    print(f"""
    ╔════════════════════════════════════════════════════╗
    ║                                                    ║
    ║         🌐  TFVisualizer Starting...              ║
    ║                                                    ║
    ║  Landing Page:  http://localhost:{port if port != 80 else ''}            ║
    ║  Editor:        http://localhost:{port if port != 80 else ''}/editor     ║
    ║  API Docs:      http://localhost:{port if port != 80 else ''}/api        ║
    ║  Health Check:  http://localhost:{port if port != 80 else ''}/health     ║
    ║                                                    ║
    ╚════════════════════════════════════════════════════╝
    """)

    app.run(host='0.0.0.0', port=port, debug=debug)

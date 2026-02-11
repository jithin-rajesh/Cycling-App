"""
Local dev server for the AI Cycling Coach API.
Run with: python3 api/dev_server.py
"""
import os
import sys
from http.server import HTTPServer

# Add parent dir so we can import the handler
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from plan import handler

# Set API keys from environment or hardcoded for dev
# (these should be in .env.local or exported in your shell)

if __name__ == "__main__":
    port = 8000
    server = HTTPServer(("0.0.0.0", port), handler)
    print(f"🚴 Coach API running at http://localhost:{port}")
    print(f"   POST http://localhost:{port}/api/plan")
    print(f"   Press Ctrl+C to stop")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        server.shutdown()

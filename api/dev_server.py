"""
Local dev server for the AI Cycling Coach API.
Run with: python3 api/dev_server.py
"""
import os
import sys
from http.server import HTTPServer, ThreadingHTTPServer

# Add parent dir so we can import the handler
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from plan import handler

env_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../.env.local")
if os.path.exists(env_path):
    print(f"Loading environment from {env_path}")
    with open(env_path, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, value = line.split("=", 1)
                # Remove quotes if present
                if value.startswith('"') and value.endswith('"'):
                    value = value[1:-1]
                elif value.startswith("'") and value.endswith("'"):
                    value = value[1:-1]
                os.environ[key] = value
else:
    print(f"Warning: .env.local not found at {env_path}")

if __name__ == "__main__":
    port = 8000
    # Use ThreadingHTTPServer to handle multiple requests (e.g. OPTIONS + POST) without blocking
    server = ThreadingHTTPServer(("0.0.0.0", port), handler)
    print(f"🚴 Coach API running at http://localhost:{port}")
    print(f"   POST http://localhost:{port}/api/plan")
    print(f"   Press Ctrl+C to stop")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        server.shutdown()

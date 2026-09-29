"""
backend-a/server.py
===================
Phase 1 — Private Network Service Platform
Backend A  |  Python standard library only  |  Port 3001

Endpoints:
  GET /            → 200 plain-text greeting
  GET /api/status  → 200 JSON  {"backend":"A","status":"ok"}
  Any other path   → 404 JSON

Headers added to every response:
  X-Backend:     A
  Cache-Control: max-age=60
"""

import http.server
import json
import os

HOST = "0.0.0.0"
PORT = 3001


class BackendAHandler(http.server.BaseHTTPRequestHandler):
    """Simple request handler for Backend A."""

    # ── silence the default request-log line; we print our own ──
    def log_message(self, format, *args):  # noqa: A002
        print(f"[Backend A] {self.address_string()} - {format % args}")

    def _send(self, status: int, content_type: str, body: str) -> None:
        """Helper that writes status, common headers, and body."""
        encoded = body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("X-Backend", "A")
        self.send_header("Cache-Control", "max-age=60")
        self.end_headers()
        self.wfile.write(encoded)

    def do_GET(self) -> None:  # noqa: N802
        """Handle GET requests."""
        if self.path == "/":
            self._send(
                200,
                "text/plain; charset=utf-8",
                "Hello from Backend A\n",
            )

        elif self.path == "/api/status":
            payload = json.dumps({"backend": "A", "status": "ok"})
            self._send(
                200,
                "application/json; charset=utf-8",
                payload,
            )

        else:
            payload = json.dumps({"error": "not found", "path": self.path})
            self._send(
                404,
                "application/json; charset=utf-8",
                payload,
            )


if __name__ == "__main__":
    server = http.server.HTTPServer((HOST, PORT), BackendAHandler)
    print(f"Backend A running on {HOST}:{PORT}")
    print("Endpoints: GET /   GET /api/status")
    print("Press Ctrl-C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nBackend A stopped.")
        server.server_close()

from http.server import BaseHTTPRequestHandler, HTTPServer
import json

HOST = "0.0.0.0"
PORT = 3002


class Handler(BaseHTTPRequestHandler):

    def get_data(self):
        if self.path == "/api/status":
            return {
                "backend": "B",
                "status": "ok",
                "server": "Backend B"
            }

        return {
            "backend": "B",
            "message": "Hello from Backend B"
        }

    def send_json(self, data, send_body=True):
        body = json.dumps(data).encode()

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("X-Backend", "B")
        self.send_header("Cache-Control", "max-age=60")
        self.end_headers()

        if send_body:
            self.wfile.write(body)

    def do_GET(self):
        self.send_json(self.get_data())

    def do_HEAD(self):
        self.send_json(self.get_data(), send_body=False)

    def log_message(self, format, *args):
        print(f"[Backend B] {self.client_address[0]} - {format % args}")


server = HTTPServer((HOST, PORT), Handler)

print(f"Backend B running on {HOST}:{PORT}")

try:
    server.serve_forever()
except KeyboardInterrupt:
    print("\nStopping Backend B...")
finally:
    server.server_close()

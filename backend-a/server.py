from http.server import BaseHTTPRequestHandler, HTTPServer
import json

HOST = "0.0.0.0"
PORT = 3001


class Handler(BaseHTTPRequestHandler):

    def get_data(self):
        if self.path == "/api/status":
            return {
                "backend": "A",
                "status": "ok",
                "server": "Backend A"
            }

        return {
            "backend": "A",
            "message": "Hello from Backend A"
        }

    def send_json(self, data, send_body=True):
        body = json.dumps(data).encode()

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("X-Backend", "A")
        self.send_header("Cache-Control", "max-age=60")
        self.end_headers()

        if send_body:
            self.wfile.write(body)

    def do_GET(self):
        self.send_json(self.get_data())

    def do_HEAD(self):
        self.send_json(self.get_data(), send_body=False)

    def log_message(self, format, *args):
        print(f"[Backend A] {self.client_address[0]} - {format % args}")


server = HTTPServer((HOST, PORT), Handler)

print(f"Backend A running on {HOST}:{PORT}")

try:
    server.serve_forever()
except KeyboardInterrupt:
    print("\nStopping Backend A...")
finally:
    server.server_close()

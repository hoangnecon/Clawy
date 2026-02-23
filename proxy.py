import sys
import json
import urllib.request
import urllib.error
from http.server import HTTPServer, BaseHTTPRequestHandler

TARGET_HOST = "localhost"
TARGET_PORT = 8045
LISTEN_PORT = 8046
INJECTED_CONTEXT_WINDOW = 128000
INJECTED_MAX_TOKENS = 8192

class ProxyHTTPRequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = f"http://{TARGET_HOST}:{TARGET_PORT}{self.path}"
        try:
            req = urllib.request.Request(url, headers=self.headers)
            with urllib.request.urlopen(req) as response:
                body = response.read()
                
                # Intercept /v1/models and inject context_window
                if self.path == "/v1/models" or self.path == "/v1/models/":
                    try:
                        data = json.loads(body)
                        if "data" in data and isinstance(data["data"], list):
                            for model in data["data"]:
                                model["context_window"] = INJECTED_CONTEXT_WINDOW
                                model["max_tokens"] = INJECTED_MAX_TOKENS
                        body = json.dumps(data).encode('utf-8')
                    except Exception as e:
                        print(f"Error parsing models JSON: {e}")

                self.send_response(response.status)
                for key, val in response.headers.items():
                    if key.lower() not in ['content-length', 'transfer-encoding', 'connection']:
                        self.send_header(key, val)
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            for key, val in e.headers.items():
                self.send_header(key, val)
            self.end_headers()
            self.wfile.write(e.read())
            
    def do_POST(self):
        url = f"http://{TARGET_HOST}:{TARGET_PORT}{self.path}"
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length)
        try:
            req = urllib.request.Request(url, data=post_data, headers=self.headers, method='POST')
            with urllib.request.urlopen(req) as response:
                body = response.read()
                self.send_response(response.status)
                for key, val in response.headers.items():
                    if key.lower() not in ['transfer-encoding', 'connection']:
                        self.send_header(key, val)
                self.end_headers()
                self.wfile.write(body)
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            for key, val in e.headers.items():
                self.send_header(key, val)
            self.end_headers()
            self.wfile.write(e.read())

if __name__ == '__main__':
    print(f"Starting OpenClaw AntiGravity Context Bridge on port {LISTEN_PORT} -> forwarding to {TARGET_HOST}:{TARGET_PORT}")
    print(f"Injecting context_window: {INJECTED_CONTEXT_WINDOW} and max_tokens: {INJECTED_MAX_TOKENS}")
    httpd = HTTPServer(('127.0.0.1', LISTEN_PORT), ProxyHTTPRequestHandler)
    httpd.serve_forever()

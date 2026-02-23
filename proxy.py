import sys
import json
import urllib.request
import urllib.error
from http.server import HTTPServer, BaseHTTPRequestHandler
import os

TARGET_HOST = "localhost"
TARGET_PORT = 8045
LISTEN_PORT = 8046
INJECTED_CONTEXT_WINDOW = 128000
INJECTED_MAX_TOKENS = 8192

def get_user_context():
    account_email = "Unknown User"
    quota_str = ""
    try:
        # Get active email
        accounts_file = os.path.expanduser("~/.antigravity_tools/accounts.json")
        if os.path.exists(accounts_file):
            with open(accounts_file, 'r') as f:
                data = json.load(f)
                curr_id = data.get("current_account_id")
                for acc in data.get("accounts", []):
                    if acc.get("id") == curr_id:
                        account_email = acc.get("email", "Unknown User")
                        break
                        
        # Get quota %
        quota_str = get_quota_for_email(account_email).replace(account_email, "")
    except Exception as e:
        print(f"Error reading Antigravity context: {e}")
        
    return f" - {account_email}{quota_str}"

def get_quota_for_email(account_email):
    quota_str = ""
    try:
        warmup_file = os.path.expanduser("~/.antigravity_tools/warmup_history.json")
        if os.path.exists(warmup_file):
            with open(warmup_file, 'r') as f:
                wdata = json.load(f)
                for key in wdata.keys():
                    if account_email in key and "gemini" in key:
                        parts = key.split(':')
                        if len(parts) >= 3:
                            quota_str = f" - {parts[2]}%"
                            break
    except Exception as e:
        print(f"Error reading Antigravity context: {e}")
        
    return f"{account_email}{quota_str}"

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
                            
                            # Inject specific Gemini model aliases
                            custom_models = ["gemini-3.1-pro", "gemini-2.5-flash", "gemini-1.5-pro", "gemini-1.5-flash"]
                            existing_ids = {m.get("id") for m in data["data"]}
                            
                            for custom_model in custom_models:
                                if custom_model not in existing_ids:
                                    data["data"].append({
                                        "id": custom_model,
                                        "object": "model",
                                        "created": 1706745600,
                                        "owned_by": "antigravity",
                                        "context_window": INJECTED_CONTEXT_WINDOW,
                                        "max_tokens": INJECTED_MAX_TOKENS
                                    })
                                    
                            # Inject an informational fake model for the user context
                            context_suffix = get_user_context()
                            info_model_name = f"== Account{context_suffix} =="
                            data["data"].append({
                                "id": info_model_name,
                                "object": "model",
                                "created": 1706745600,
                                "owned_by": "antigravity (Info Only)"
                            })
                            
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
                self.send_response(response.status)
                
                is_chunked = False
                account_email = "Unknown User"
                for key, val in response.headers.items():
                    if key.lower() == 'x-account-email':
                        account_email = val
                    if key.lower() == 'transfer-encoding' and val.lower() == 'chunked':
                        is_chunked = True
                        self.send_header(key, val)
                    elif key.lower() not in ['connection']:
                        self.send_header(key, val)
                
                # If the upstream didn't chunk but we want to simulate streaming? 
                # OpenClaw usually sets stream: true, so Antigravity replies with chunked encoding.
                if not is_chunked:
                    # Just passthrough if not SSE chunked
                    self.end_headers()
                    self.wfile.write(response.read())
                    return

                self.end_headers()
                
                # We are processing HTTP chunked transfer from Antigravity.
                # `urllib` auto-decodes the incoming chunks, so `response.readline()` gives us raw SSE events.
                # Since we passed `Transfer-Encoding: chunked` to the client, we must manually re-encode the chunks!
                while True:
                    line = response.readline()
                    if not line:
                        break
                    
                    # Inspect chunk_data for the magic SSE finish
                    # The SSE event looks like: data: {"choices":[{"delta":{},"finish_reason":"stop"}]}
                    if b'finish_reason":"stop"' in line or b'finish_reason": "stop"' in line:
                        # We must inject our own valid SSE event right BEFORE we send this chunk
                        context = get_quota_for_email(account_email)
                        footnote = f'\\n---\\n**Account:** {context}\\n'
                        injected_sse = f'data: {{"id":"chatcmpl-proxy","choices":[{{"delta":{{"content":"{footnote}"}}}}],"model":"gemini-3.1-pro"}}\n\n'.encode('utf-8')
                        
                        # Send injected HTTP chunk
                        self.wfile.write(f"{len(injected_sse):X}\r\n".encode())
                        self.wfile.write(injected_sse)
                        self.wfile.write(b"\r\n")
                    
                    # Send actual HTTP chunk
                    self.wfile.write(f"{len(line):X}\r\n".encode())
                    self.wfile.write(line)
                    self.wfile.write(b"\r\n")
                    
                # Send the final zero-length chunk to close the stream
                self.wfile.write(b"0\r\n\r\n")
                
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            for key, val in e.headers.items():
                self.send_header(key, val)
            self.end_headers()

if __name__ == '__main__':
    print(f"Starting OpenClaw AntiGravity Context Bridge on port {LISTEN_PORT} -> forwarding to {TARGET_HOST}:{TARGET_PORT}")
    print(f"Injecting context_window: {INJECTED_CONTEXT_WINDOW} and max_tokens: {INJECTED_MAX_TOKENS}")
    httpd = HTTPServer(('127.0.0.1', LISTEN_PORT), ProxyHTTPRequestHandler)
    httpd.serve_forever()

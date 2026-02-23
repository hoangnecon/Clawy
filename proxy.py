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

def get_current_account_id_and_email():
    account_id = None
    account_email = "Unknown User"
    try:
        # Get active email
        accounts_file = os.path.expanduser("~/.antigravity_tools/accounts.json")
        if os.path.exists(accounts_file):
            with open(accounts_file, 'r') as f:
                data = json.load(f)
                curr_id = data.get("current_account_id")
                if curr_id:
                    account_id = curr_id
                    for acc in data.get("accounts", []):
                        if acc.get("id") == curr_id:
                            account_email = acc.get("email", "Unknown User")
                            break
    except Exception as e:
        print(f"Error reading Antigravity accounts: {e}")
        
    return account_id, account_email

def restrict_proxy_to_current_account():
    try:
        accounts_file = os.path.expanduser("~/.antigravity_tools/accounts.json")
        if not os.path.exists(accounts_file):
            return
            
        with open(accounts_file, 'r') as f:
            data = json.load(f)
            
        curr_id = data.get("current_account_id")
        if not curr_id:
            return
            
        changed = False
        for acc in data.get("accounts", []):
            should_disable = (acc.get("id") != curr_id)
            if acc.get("proxy_disabled") != should_disable:
                acc["proxy_disabled"] = should_disable
                changed = True
                
        if changed:
            with open(accounts_file, 'w') as f:
                json.dump(data, f, indent=2)
            print(f"Isolated proxy to account: {curr_id}")
            
    except Exception as e:
        print(f"Error isolating Antigravity account: {e}")

def get_user_context():
    account_id, account_email = get_current_account_id_and_email()
    quota_str = ""
    try:
                        
        # Get quota %
        quota_str = get_quota_for_email(account_email).replace(account_email, "")
        quota_str = get_quota_for_email(account_email)
    except Exception as e:
        print(f"Error reading Antigravity context: {e}")
        
    return f" - {account_email}{quota_str}"

def get_quota_for_email(account_email, target_model=None):
    try:
        accounts_file = os.path.expanduser("~/.antigravity_tools/accounts.json")
        if not os.path.exists(accounts_file):
            return ""
            
        with open(accounts_file, 'r') as f:
            data = json.load(f)
            
        account_id = None
        for acc in data.get("accounts", []):
            if acc.get("email") == account_email:
                account_id = acc.get("id")
                break
                
        if not account_id:
            return ""
            
        detail_file = os.path.expanduser(f"~/.antigravity_tools/accounts/{account_id}.json")
        if not os.path.exists(detail_file):
            return ""
            
        with open(detail_file, 'r') as f:
            detail_data = json.load(f)
            
        percentages = {}
        for model in detail_data.get("quota", {}).get("models", []):
            name = model.get("name")
            if name:
                percentages[name] = model.get("percentage", 100)
                
        if target_model and target_model in percentages:
            percentage = percentages[target_model]
        else:
            percentage = percentages.get("gemini-3.1-pro-high", percentages.get("gemini-3-pro-high", 100))
            
        return f" - {percentage}%"
    except Exception as e:
        print(f"Error reading Antigravity quota: {e}")
        return ""

class ProxyHTTPRequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = f"http://{TARGET_HOST}:{TARGET_PORT}{self.path}"
        
        headers_dict = dict(self.headers)
        
        try:
            req = urllib.request.Request(url, headers=headers_dict)
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
                            custom_models = ["gemini-3.1-pro", "gemini-3.1-pro-high", "gemini-3.1-pro-low", "claude-opus-4-6-thinking", "claude-sonnet-4-6", "gemini-2.5-flash", "gemini-1.5-pro", "gemini-1.5-flash"]
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
        
        headers_dict = dict(self.headers)
        
        try:
            target_model_name = None
            if self.path.startswith("/v1/chat/completions") or self.path.startswith("/v1/completions"):
                # Strip old footnotes from chat history to prevent LLM hallucinations
                try:
                    payload = json.loads(post_data)
                    modified = False
                    if "model" in payload:
                        target_model_name = payload["model"]
                        
                    if "messages" in payload:
                        for msg in payload["messages"]:
                            if msg.get("role") == "assistant" and msg.get("content"):
                                content = msg["content"]
                                if "**Account:**" in content:
                                    if "\n\n---\n\n**Account:**" in content:
                                        msg["content"] = content.split("\n\n---\n\n**Account:**")[0]
                                        modified = True
                                    elif "\n---\n**Account:**" in content:
                                        msg["content"] = content.split("\n---\n**Account:**")[0]
                                        modified = True
                                    elif "---\n**Account:**" in content:
                                        msg["content"] = content.split("---\n**Account:**")[0]
                                        modified = True
                    if modified:
                        post_data = json.dumps(payload).encode('utf-8')
                        headers_dict['Content-Length'] = str(len(post_data))
                except Exception as e:
                    print(f"Error stripping history footnotes: {e}")
                    
                if "x-account-id" in headers_dict:
                    del headers_dict["x-account-id"]
                if "X-Account-Id" in headers_dict:
                    del headers_dict["X-Account-Id"]
                    
                # Enforce the selected GUI account by passing X-Account-Id to Antigravity
                account_id, _ = get_current_account_id_and_email()
                if account_id:
                    headers_dict['X-Account-Id'] = account_id
                    
            # Isolate the proxy to use specifically the current account ID
            restrict_proxy_to_current_account()

            req = urllib.request.Request(url, data=post_data, headers=headers_dict, method='POST')
            with urllib.request.urlopen(req) as response:
                self.send_response(response.status)
                
                is_chunked = False
                account_email = "Unknown User"
                
                # Iterate and extract x-account-email case-insensitively
                for key, val in response.headers.items():
                    lower_key = key.lower()
                    if lower_key == 'x-account-email':
                        account_email = val
                    if lower_key == 'transfer-encoding' and val.lower() == 'chunked':
                        is_chunked = True
                        self.send_header(key, val)
                    elif lower_key not in ['connection']:
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
                # `urllib` auto-decodes the incoming chunks.
                # Since we passed `Transfer-Encoding: chunked` to the client, we must manually re-encode the chunks!
                buffer = b""
                while True:
                    chunk = response.read(1)
                    if not chunk:
                        if buffer:
                            self.wfile.write(f"{len(buffer):X}\r\n".encode())
                            self.wfile.write(buffer)
                            self.wfile.write(b"\r\n")
                        break
                    
                    buffer += chunk
                    
                    # Yield complete SSE events separated by double newlines
                    if buffer.endswith(b"\n\n"):
                        # Inspect buffer for the magic SSE finish
                        if b'finish_reason":"stop"' in buffer or b'finish_reason": "stop"' in buffer:
                            # We must inject our own valid SSE event right BEFORE we send this chunk
                            context = get_quota_for_email(account_email, target_model=target_model_name)
                            model_display = f" ({target_model_name})" if target_model_name else ""
                            footnote = f'\\n\\n---\\n\\n**Account:** {account_email}{context}{model_display}\\n'
                            injected_sse = f'data: {{"id":"chatcmpl-proxy","choices":[{{"delta":{{"content":"{footnote}"}}}}],"model":"{target_model_name or "gemini-3.1-pro"}"}}\n\n'.encode('utf-8')
                            
                            # Send injected HTTP chunk
                            self.wfile.write(f"{len(injected_sse):X}\r\n".encode())
                            self.wfile.write(injected_sse)
                            self.wfile.write(b"\r\n")
                        
                        # Send actual HTTP chunk
                        self.wfile.write(f"{len(buffer):X}\r\n".encode())
                        self.wfile.write(buffer)
                        self.wfile.write(b"\r\n")
                        
                        # Reset buffer for next SSE event
                        buffer = b""
                        
                # Send the final zero-length chunk to close the HTTP stream
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

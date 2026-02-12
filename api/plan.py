"""
Vercel Serverless Function: /api/plan
Sensorless Cycling Coach — Kimi (Planner) + Mistral (Executor)

Streams tokens in real-time from NVIDIA NIM and Mistral APIs.
Zero external dependencies — Python stdlib only.
"""

import json
import os
import traceback
from http.server import BaseHTTPRequestHandler
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError


# ── System Prompts ────────────────────────────────────────────────────────
PLANNER_SYSTEM = (
    "You are a cycling coach. Given a rider's goal, produce a brief training plan. "
    "Include: weekly structure, intensity zones, rest days. "
    "Be specific with distances. Keep it under 150 words. No preamble."
)

EXECUTOR_SYSTEM = (
    "You are a training schedule builder. "
    "Given a cycling plan, convert it into a day-by-day schedule "
    "with distances, times, and intensity. "
    "Format as a markdown table. Keep it under 250 words. No preamble."
)


def _send_sse(wfile, payload_dict):
    """Send a single SSE event."""
    line = f"data: {json.dumps(payload_dict)}\n\n"
    wfile.write(line.encode())
    wfile.flush()


def stream_nvidia_nim(prompt: str, wfile):
    """Stream tokens from Kimi k2.5 via NVIDIA NIM, sending SSE events."""
    api_key = os.environ.get("NVIDIA_API_KEY", "")
    if not api_key:
        raise RuntimeError("NVIDIA_API_KEY environment variable is not set")
    url = "https://integrate.api.nvidia.com/v1/chat/completions"

    payload = json.dumps({
        "model": "meta/llama-3.3-70b-instruct",
        "messages": [
            {"role": "system", "content": PLANNER_SYSTEM},
            {"role": "user", "content": prompt},
        ],
        "temperature": 0.4,
        "max_tokens": 1024,
        "stream": True,
    }).encode("utf-8")

    req = Request(url, data=payload, method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {api_key}")

    full_content = ""

    try:
        with urlopen(req, timeout=180) as resp:
            buffer = ""
            while True:
                chunk = resp.read(1024)
                if not chunk:
                    break
                buffer += chunk.decode("utf-8", errors="replace")

                # Process complete SSE lines from the API
                while "\n" in buffer:
                    line, buffer = buffer.split("\n", 1)
                    line = line.strip()

                    if not line or not line.startswith("data: "):
                        continue
                    data_str = line[6:]
                    if data_str == "[DONE]":
                        break

                    try:
                        data = json.loads(data_str)
                        delta = data.get("choices", [{}])[0].get("delta", {})

                        # Kimi k2.5 streams reasoning in reasoning_content
                        # and final answer in content
                        token = delta.get("content") or ""
                        reasoning = delta.get("reasoning_content") or ""

                        text = token if token else reasoning
                        if text:
                            full_content += text
                            _send_sse(wfile, {
                                "node": "planner_token",
                                "token": text,
                            })
                    except json.JSONDecodeError:
                        continue

    except HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"NVIDIA API error {e.code}: {body}") from e
    except URLError as e:
        raise RuntimeError(f"NVIDIA connection error: {e.reason}") from e

    return full_content


def stream_mistral(prompt: str, wfile):
    """Stream tokens from Mistral Small, sending SSE events."""
    api_key = os.environ.get("MISTRAL_API_KEY", "")
    if not api_key:
        raise RuntimeError("MISTRAL_API_KEY environment variable is not set")
    url = "https://api.mistral.ai/v1/chat/completions"

    payload = json.dumps({
        "model": "mistral-small-latest",
        "messages": [
            {"role": "system", "content": EXECUTOR_SYSTEM},
            {"role": "user", "content": prompt},
        ],
        "temperature": 0.3,
        "max_tokens": 1024,
        "stream": True,
    }).encode("utf-8")

    req = Request(url, data=payload, method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {api_key}")

    full_content = ""

    try:
        with urlopen(req, timeout=180) as resp:
            buffer = ""
            while True:
                chunk = resp.read(256)
                if not chunk:
                    break
                buffer += chunk.decode("utf-8", errors="replace")

                while "\n" in buffer:
                    line, buffer = buffer.split("\n", 1)
                    line = line.strip()

                    if not line or not line.startswith("data: "):
                        continue
                    data_str = line[6:]
                    if data_str == "[DONE]":
                        break

                    try:
                        data = json.loads(data_str)
                        delta = data.get("choices", [{}])[0].get("delta", {})
                        token = delta.get("content") or ""
                        if token:
                            full_content += token
                            _send_sse(wfile, {
                                "node": "executor_token",
                                "token": token,
                            })
                    except json.JSONDecodeError:
                        continue

    except HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Mistral API error {e.code}: {body}") from e
    except URLError as e:
        raise RuntimeError(f"Mistral connection error: {e.reason}") from e

    return full_content


# ── Vercel Handler ───────────────────────────────────────────────────────
class handler(BaseHTTPRequestHandler):
    def do_POST(self):
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(content_length))
            query = body.get("query", "")

            if not query:
                self.send_response(400)
                self.send_header("Content-Type", "application/json")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(
                    json.dumps({"error": "query is required"}).encode()
                )
                return

            # Set SSE headers
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "keep-alive")
            self.send_header("X-Accel-Buffering", "no")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()

            # ── Stage 1: Planner (Kimi k2.5) — stream tokens ────────
            _send_sse(self.wfile, {
                "node": "planner_start",
                "status": "Kimi is thinking...",
            })

            try:
                plan_text = stream_nvidia_nim(query, self.wfile)
                _send_sse(self.wfile, {
                    "node": "planner_done",
                    "plan": plan_text,
                    "status": "Planner finished",
                })
            except Exception as e:
                _send_sse(self.wfile, {
                    "node": "error",
                    "status": f"Planner failed: {e}",
                })
                return

            # ── Stage 2: Executor (Mistral) — stream tokens ─────────
            _send_sse(self.wfile, {
                "node": "executor_start",
                "status": "Mistral is scheduling...",
            })

            try:
                executor_prompt = (
                    f"High-level plan:\n{plan_text}\n\n"
                    f"Original rider request: {query}"
                )
                schedule_text = stream_mistral(executor_prompt, self.wfile)
                _send_sse(self.wfile, {
                    "node": "executor_done",
                    "final_response": schedule_text,
                    "status": "Executor finished",
                })
            except Exception as e:
                _send_sse(self.wfile, {
                    "node": "error",
                    "status": f"Executor failed: {e}",
                })
                return

            # ── Done ─────────────────────────────────────────────────
            _send_sse(self.wfile, {
                "node": "done",
                "status": "Complete",
            })

        except Exception as e:
            traceback.print_exc()
            try:
                _send_sse(self.wfile, {
                    "node": "error",
                    "status": str(e),
                })
            except Exception:
                pass

    def do_OPTIONS(self):
        """Handle CORS preflight."""
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Max-Age", "86400")
        self.end_headers()

    def log_message(self, format, *args):
        print(f"[Coach] {self.client_address[0]} - {format % args}")

#!/usr/bin/env python3
"""Mayari MCP server.

Exposes Mayari backend functionality over MCP JSON-RPC so Claude Code and
other MCP clients can operate the app programmatically.
"""

from __future__ import annotations

import argparse
import json
import logging
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from logging.handlers import RotatingFileHandler
from pathlib import Path
from typing import Any, Dict
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

SERVER_NAME = "mayari-mcp"
SERVER_VERSION = "1.0.0"
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8086
BACKEND_URL = os.environ.get("MAYARI_BACKEND_URL", "http://127.0.0.1:8787")

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPT_DIR.parent
LOG_DIR = ROOT_DIR / "runs" / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)

LOGGER = logging.getLogger("mayari_mcp")
LOGGER.setLevel(logging.INFO)
_handler = RotatingFileHandler(
    LOG_DIR / "mayari_mcp_server.log",
    maxBytes=5 * 1024 * 1024,
    backupCount=3,
    encoding="utf-8",
)
_handler.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] %(message)s"))
LOGGER.addHandler(_handler)
LOGGER.addHandler(logging.StreamHandler())

MCP_TOOLS = [
    {
        "name": "health_check",
        "description": "Check whether Mayari backend is healthy.",
        "inputSchema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "mayari_status",
        "description": "Return backend status and configured backend URL.",
        "inputSchema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "mayari_list_voices",
        "description": "List available Kokoro voices.",
        "inputSchema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "mayari_generate_speech",
        "description": "Generate speech audio from text using Kokoro.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "text": {"type": "string", "description": "Text to synthesize."},
                "voice": {
                    "type": "string",
                    "description": "Voice code (for example bf_emma).",
                },
                "speed": {
                    "type": "number",
                    "description": "Speech speed (0.5-2.0).",
                    "default": 1.0,
                },
            },
            "required": ["text"],
        },
    },
    {
        "name": "mayari_list_audio_files",
        "description": "List generated audio files.",
        "inputSchema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "mayari_delete_audio_file",
        "description": "Delete a generated audio file by filename.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "filename": {
                    "type": "string",
                    "description": "Filename returned by mayari_list_audio_files.",
                }
            },
            "required": ["filename"],
        },
    },
]


def _backend_request(path: str, method: str = "GET", payload: Dict[str, Any] | None = None) -> Dict[str, Any]:
    url = f"{BACKEND_URL}{path}"
    body = None
    headers = {"Content-Type": "application/json"}
    if payload is not None:
        body = json.dumps(payload).encode("utf-8")
    request = Request(url, data=body, headers=headers, method=method)

    try:
        with urlopen(request, timeout=30) as response:
            text = response.read().decode("utf-8")
            if not text:
                return {}
            return json.loads(text)
    except HTTPError as exc:
        text = exc.read().decode("utf-8", errors="ignore")
        raise RuntimeError(f"HTTP {exc.code}: {text or exc.reason}") from exc
    except URLError as exc:
        raise RuntimeError(f"Backend unavailable: {exc.reason}") from exc


def _handle_tool_call(name: str, arguments: Dict[str, Any]) -> str:
    if name == "health_check":
        return json.dumps(_backend_request("/health"), indent=2)

    if name == "mayari_status":
        health = _backend_request("/health")
        return json.dumps({"backend_url": BACKEND_URL, "health": health}, indent=2)

    if name == "mayari_list_voices":
        return json.dumps(_backend_request("/api/kokoro/voices"), indent=2)

    if name == "mayari_generate_speech":
        text = str(arguments.get("text", "")).strip()
        if not text:
            return json.dumps({"error": "text is required"}, indent=2)

        voice = str(arguments.get("voice") or "bf_emma")
        speed = float(arguments.get("speed") or 1.0)
        result = _backend_request(
            "/api/kokoro/generate",
            method="POST",
            payload={"text": text, "voice": voice, "speed": speed},
        )
        if "audio_url" in result:
            result["audio_url"] = f"{BACKEND_URL}{result['audio_url']}"
        return json.dumps(result, indent=2)

    if name == "mayari_list_audio_files":
        data = _backend_request("/api/kokoro/audio/list")
        files = data.get("audio_files", [])
        for item in files:
            audio_url = item.get("audio_url")
            if isinstance(audio_url, str) and audio_url.startswith("/"):
                item["audio_url"] = f"{BACKEND_URL}{audio_url}"
        return json.dumps(data, indent=2)

    if name == "mayari_delete_audio_file":
        filename = str(arguments.get("filename", "")).strip()
        if not filename:
            return json.dumps({"error": "filename is required"}, indent=2)
        return json.dumps(_backend_request(f"/api/kokoro/audio/{filename}", method="DELETE"), indent=2)

    return json.dumps({"error": f"Unknown tool: {name}"}, indent=2)


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt: str, *args: Any) -> None:
        LOGGER.info(fmt, *args)

    def do_POST(self) -> None:  # noqa: N802
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8") if length else "{}"
        try:
            obj = json.loads(raw)
        except json.JSONDecodeError as exc:
            self._write_json(
                {
                    "jsonrpc": "2.0",
                    "id": None,
                    "error": {"code": -32700, "message": f"Parse error: {exc}"},
                }
            )
            return

        req_id = obj.get("id")
        method = obj.get("method")
        params = obj.get("params") or {}

        if method == "initialize":
            protocol = params.get("protocolVersion", "2024-11-05")
            self._write_json(
                {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {
                        "protocolVersion": protocol,
                        "serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION},
                        "capabilities": {"tools": {"list": True, "call": True}},
                    },
                }
            )
            return

        if method == "notifications/initialized":
            self._write_json({"jsonrpc": "2.0", "id": req_id, "result": {}})
            return

        if method in ("tools/list", "tools.list"):
            self._write_json({"jsonrpc": "2.0", "id": req_id, "result": {"tools": MCP_TOOLS}})
            return

        if method in ("tools/call", "tools.call"):
            tool_name = params.get("name")
            arguments = params.get("arguments") or {}
            try:
                text = _handle_tool_call(str(tool_name), arguments)
                self._write_json(
                    {
                        "jsonrpc": "2.0",
                        "id": req_id,
                        "result": {"content": [{"type": "text", "text": text}]},
                    }
                )
            except Exception as exc:  # pylint: disable=broad-except
                LOGGER.exception("Tool call failed")
                self._write_json(
                    {
                        "jsonrpc": "2.0",
                        "id": req_id,
                        "error": {"code": -32000, "message": str(exc)},
                    }
                )
            return

        self._write_json(
            {
                "jsonrpc": "2.0",
                "id": req_id,
                "error": {"code": -32601, "message": f"Method not found: {method}"},
            }
        )

    def _write_json(self, payload: Dict[str, Any]) -> None:
        data = json.dumps(payload).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


def main() -> None:
    parser = argparse.ArgumentParser(description="Mayari MCP server")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    args = parser.parse_args()

    server = HTTPServer((args.host, args.port), Handler)
    LOGGER.info("Starting %s on http://%s:%s", SERVER_NAME, args.host, args.port)
    LOGGER.info("Using Mayari backend: %s", BACKEND_URL)
    server.serve_forever()


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Mayari MCP server (JSON-RPC 2.0 over HTTP) with REST parity endpoints."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import logging
from logging.handlers import RotatingFileHandler
import os
from pathlib import Path
import re
import subprocess
import sys
import threading
import urllib.error
import urllib.parse
import urllib.request
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any


APP_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_HOST = os.environ.get("MAYARI_MCP_HOST", "127.0.0.1")
DEFAULT_PORT = int(os.environ.get("MAYARI_MCP_PORT", "8086"))
DEFAULT_BACKEND_URL = os.environ.get("MAYARI_BACKEND_URL", "http://127.0.0.1:8787")
DEFAULT_LOG_FILE = APP_ROOT / "runs" / "logs" / "mayari_mcp_server.log"

LOGGER = logging.getLogger("mayari_mcp_server")
LOGGER_LOCK = threading.Lock()


def _setup_logging(log_file: Path) -> None:
    log_file.parent.mkdir(parents=True, exist_ok=True)
    handler = RotatingFileHandler(log_file, maxBytes=1_000_000, backupCount=3)
    formatter = logging.Formatter(
        fmt="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    handler.setFormatter(formatter)
    LOGGER.setLevel(logging.INFO)
    LOGGER.handlers.clear()
    LOGGER.addHandler(handler)


def _read_pubspec_version() -> str:
    pubspec = APP_ROOT / "pubspec.yaml"
    if not pubspec.exists():
        return "0.0.0+0"
    for line in pubspec.read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("version:"):
            return line.split(":", 1)[1].strip()
    return "0.0.0+0"


def _voice_catalog() -> list[dict[str, Any]]:
    tts_file = APP_ROOT / "lib" / "services" / "tts_service.dart"
    if not tts_file.exists():
        return []

    src = tts_file.read_text(encoding="utf-8")
    start = src.find("const List<TtsVoice> defaultVoices = [")
    if start == -1:
        return []
    end = src.find("];", start)
    if end == -1:
        return []
    block = src[start:end]

    pattern = re.compile(
        r"TtsVoice\(\s*"
        r"id:\s*'(?P<id>[^']+)'.*?"
        r"name:\s*'(?P<name>[^']+)'.*?"
        r"gender:\s*'(?P<gender>[^']+)'.*?"
        r"grade:\s*'(?P<grade>[^']+)'.*?"
        r"languageCode:\s*'(?P<language_code>[^']+)'.*?"
        r"languageName:\s*'(?P<language_name>[^']+)'.*?"
        r"(?:isDefault:\s*(?P<is_default>true|false))?.*?"
        r"\)",
        re.DOTALL,
    )

    voices: list[dict[str, Any]] = []
    for match in pattern.finditer(block):
        data = match.groupdict()
        voices.append(
            {
                "id": data["id"],
                "name": data["name"],
                "gender": data["gender"],
                "grade": data["grade"],
                "language_code": data["language_code"],
                "language_name": data["language_name"],
                "is_default": data.get("is_default") == "true",
            }
        )
    return voices


VOICE_CATALOG = _voice_catalog()

MCP_TOOLS: list[dict[str, Any]] = [
    {
        "name": "health_check",
        "description": "Check whether the Mayari MCP server is running and probe backend health.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "mayari_system_info",
        "description": "Return Mayari version, platform details, and MCP runtime info.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "include_paths": {
                    "type": "boolean",
                    "description": "Include filesystem paths in response.",
                }
            },
        },
    },
    {
        "name": "mayari_list_voices",
        "description": "List supported Mayari/Kokoro voices, optionally filtered by language code.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "language_code": {
                    "type": "string",
                    "description": "Optional language code filter (for example en-gb, ja-jp).",
                }
            },
        },
    },
    {
        "name": "mayari_generate_preview",
        "description": "Generate a local preview audio file from text via macOS speech synthesis.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "text": {
                    "type": "string",
                    "description": "Text to synthesize into a preview audio file.",
                },
                "voice": {
                    "type": "string",
                    "description": "Optional voice identifier metadata label.",
                },
                "rate": {
                    "type": "integer",
                    "description": "macOS say rate, default 180.",
                },
            },
            "required": ["text"],
        },
    },
]


class AppContext:
    def __init__(self, host: str, port: int, backend_url: str):
        self.host = host
        self.port = port
        self.backend_url = backend_url
        self.version = _read_pubspec_version()

    def _probe_backend_health(self) -> tuple[bool, str]:
        if not self.backend_url:
            return False, "backend_url not configured"
        url = f"{self.backend_url.rstrip('/')}/health"
        req = urllib.request.Request(url, method="GET")
        try:
            with urllib.request.urlopen(req, timeout=2) as resp:
                return resp.status == 200, f"http {resp.status}"
        except urllib.error.URLError as exc:
            return False, str(exc)
        except TimeoutError:
            return False, "timeout"

    def tool_health_check(self, _: dict[str, Any]) -> dict[str, Any]:
        backend_ok, backend_detail = self._probe_backend_health()
        return {
            "status": "ok",
            "mcp_server": "running",
            "app": "Mayari",
            "version": self.version,
            "backend_url": self.backend_url,
            "backend_reachable": backend_ok,
            "backend_detail": backend_detail,
            "timestamp_utc": dt.datetime.utcnow().isoformat(timespec="seconds") + "Z",
        }

    def tool_system_info(self, args: dict[str, Any]) -> dict[str, Any]:
        include_paths = bool(args.get("include_paths", False))
        result: dict[str, Any] = {
            "app": "Mayari",
            "version": self.version,
            "python": sys.version.split()[0],
            "platform": sys.platform,
            "mcp_host": self.host,
            "mcp_port": self.port,
            "voice_count": len(VOICE_CATALOG),
        }
        if include_paths:
            result["app_root"] = str(APP_ROOT)
            result["runs_log_dir"] = str(APP_ROOT / "runs" / "logs")
        return result

    def tool_list_voices(self, args: dict[str, Any]) -> dict[str, Any]:
        language_code = str(args.get("language_code", "")).strip().lower()
        voices = VOICE_CATALOG
        if language_code:
            voices = [
                v
                for v in voices
                if str(v.get("language_code", "")).lower() == language_code
            ]
        return {"count": len(voices), "voices": voices}

    def tool_generate_preview(self, args: dict[str, Any]) -> dict[str, Any]:
        text = str(args.get("text", "")).strip()
        if not text:
            raise ValueError("text is required")
        if len(text) > 5000:
            raise ValueError("text exceeds 5000 characters")

        rate = int(args.get("rate", 180))
        voice = str(args.get("voice", "")).strip()

        preview_dir = (
            Path.home()
            / "Library"
            / "Application Support"
            / "Mayari"
            / "mcp-previews"
        )
        preview_dir.mkdir(parents=True, exist_ok=True)

        stamp = dt.datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        filename = f"mayari_preview_{stamp}_{os.getpid()}.aiff"
        output_path = preview_dir / filename

        cmd = ["say", "-r", str(rate), "-o", str(output_path), text]
        try:
            subprocess.run(cmd, check=True, timeout=60, capture_output=True, text=True)
        except FileNotFoundError as exc:
            raise RuntimeError("macOS 'say' command not found") from exc
        except subprocess.CalledProcessError as exc:
            detail = (exc.stderr or exc.stdout or "").strip()
            raise RuntimeError(f"preview generation failed: {detail}") from exc
        except subprocess.TimeoutExpired as exc:
            raise RuntimeError("preview generation timed out") from exc

        size_bytes = output_path.stat().st_size if output_path.exists() else 0
        return {
            "status": "ok",
            "provider": "macos_say",
            "voice_label": voice or "default",
            "rate": rate,
            "path": str(output_path),
            "size_bytes": size_bytes,
        }

    def dispatch_tool(self, name: str, args: dict[str, Any]) -> dict[str, Any]:
        if name == "health_check":
            return self.tool_health_check(args)
        if name == "mayari_system_info":
            return self.tool_system_info(args)
        if name == "mayari_list_voices":
            return self.tool_list_voices(args)
        if name == "mayari_generate_preview":
            return self.tool_generate_preview(args)
        raise ValueError(f"unknown tool: {name}")


class MCPHandler(BaseHTTPRequestHandler):
    server_version = "MayariMCP/1.0"
    protocol_version = "HTTP/1.1"

    @property
    def app(self) -> AppContext:
        return self.server.app_context  # type: ignore[attr-defined]

    def log_message(self, fmt: str, *args: Any) -> None:
        with LOGGER_LOCK:
            LOGGER.info("%s - %s", self.client_address[0], fmt % args)

    def _read_json_body(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length > 0 else b"{}"
        if not raw:
            return {}
        try:
            return json.loads(raw.decode("utf-8"))
        except json.JSONDecodeError as exc:
            raise ValueError(f"invalid JSON body: {exc}") from exc

    def _send_json(self, status: int, payload: dict[str, Any]) -> None:
        data = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _rpc_success(self, request_id: Any, result: dict[str, Any]) -> dict[str, Any]:
        return {"jsonrpc": "2.0", "id": request_id, "result": result}

    def _rpc_error(
        self, request_id: Any, code: int, message: str, data: Any | None = None
    ) -> dict[str, Any]:
        err: dict[str, Any] = {"code": code, "message": message}
        if data is not None:
            err["data"] = data
        return {"jsonrpc": "2.0", "id": request_id, "error": err}

    def _handle_initialize(self, request_id: Any) -> dict[str, Any]:
        return self._rpc_success(
            request_id,
            {
                "serverInfo": {"name": "mayari-mcp-server", "version": "1.0.0"},
                "capabilities": {"tools": {}},
                "instructions": (
                    "Use tools/list then tools/call to interact with Mayari MCP tools."
                ),
            },
        )

    def _handle_tools_list(self, request_id: Any) -> dict[str, Any]:
        return self._rpc_success(request_id, {"tools": MCP_TOOLS})

    def _handle_tools_call(self, request_id: Any, params: dict[str, Any]) -> dict[str, Any]:
        name = str(params.get("name", "")).strip()
        args = params.get("arguments", {})
        if not isinstance(args, dict):
            return self._rpc_error(request_id, -32602, "arguments must be an object")
        try:
            tool_result = self.app.dispatch_tool(name, args)
            return self._rpc_success(
                request_id,
                {
                    "content": [
                        {
                            "type": "text",
                            "text": json.dumps(tool_result, ensure_ascii=True),
                        }
                    ],
                    "structuredContent": tool_result,
                },
            )
        except Exception as exc:  # noqa: BLE001
            with LOGGER_LOCK:
                LOGGER.exception("tool call failed: %s", name)
            return self._rpc_error(request_id, -32000, str(exc))

    def _handle_rpc(self, body: dict[str, Any]) -> dict[str, Any]:
        request_id = body.get("id")
        if body.get("jsonrpc") != "2.0":
            return self._rpc_error(request_id, -32600, "jsonrpc must be '2.0'")

        method = body.get("method")
        params = body.get("params", {})
        if not isinstance(params, dict):
            return self._rpc_error(request_id, -32602, "params must be an object")

        if method == "initialize":
            return self._handle_initialize(request_id)
        if method == "tools/list":
            return self._handle_tools_list(request_id)
        if method == "tools/call":
            return self._handle_tools_call(request_id, params)
        return self._rpc_error(request_id, -32601, f"method not found: {method}")

    def do_GET(self) -> None:  # noqa: N802
        parsed = urllib.parse.urlparse(self.path)
        query = urllib.parse.parse_qs(parsed.query)
        try:
            if parsed.path == "/api/health":
                self._send_json(HTTPStatus.OK, self.app.tool_health_check({}))
                return
            if parsed.path == "/api/system/info":
                include_paths = query.get("include_paths", ["false"])[0].lower() == "true"
                self._send_json(
                    HTTPStatus.OK,
                    self.app.tool_system_info({"include_paths": include_paths}),
                )
                return
            if parsed.path == "/api/tts/voices":
                language_code = query.get("language_code", [""])[0]
                self._send_json(
                    HTTPStatus.OK,
                    self.app.tool_list_voices({"language_code": language_code}),
                )
                return
            self._send_json(
                HTTPStatus.NOT_FOUND,
                {"error": "not found", "path": parsed.path},
            )
        except Exception as exc:  # noqa: BLE001
            with LOGGER_LOCK:
                LOGGER.exception("GET handler failed")
            self._send_json(HTTPStatus.INTERNAL_SERVER_ERROR, {"error": str(exc)})

    def do_POST(self) -> None:  # noqa: N802
        parsed = urllib.parse.urlparse(self.path)
        try:
            body = self._read_json_body()
            if parsed.path in ("/", "/mcp"):
                response = self._handle_rpc(body)
                self._send_json(HTTPStatus.OK, response)
                return

            if parsed.path == "/api/tts/generate_preview":
                result = self.app.tool_generate_preview(body)
                self._send_json(HTTPStatus.OK, result)
                return

            self._send_json(
                HTTPStatus.NOT_FOUND,
                {"error": "not found", "path": parsed.path},
            )
        except ValueError as exc:
            self._send_json(HTTPStatus.BAD_REQUEST, {"error": str(exc)})
        except Exception as exc:  # noqa: BLE001
            with LOGGER_LOCK:
                LOGGER.exception("POST handler failed")
            self._send_json(HTTPStatus.INTERNAL_SERVER_ERROR, {"error": str(exc)})


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the Mayari MCP server")
    parser.add_argument("--host", default=DEFAULT_HOST, help="Bind host")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="Bind port")
    parser.add_argument(
        "--backend-url",
        default=DEFAULT_BACKEND_URL,
        help="Optional backend URL for health probes",
    )
    parser.add_argument(
        "--log-file",
        default=str(DEFAULT_LOG_FILE),
        help="Path to rotating log file",
    )
    args = parser.parse_args()

    _setup_logging(Path(args.log_file))
    with LOGGER_LOCK:
        LOGGER.info(
            "starting Mayari MCP server host=%s port=%s backend_url=%s",
            args.host,
            args.port,
            args.backend_url,
        )

    app_context = AppContext(args.host, args.port, args.backend_url)
    server = ThreadingHTTPServer((args.host, args.port), MCPHandler)
    server.app_context = app_context  # type: ignore[attr-defined]

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        with LOGGER_LOCK:
            LOGGER.info("Mayari MCP server stopped")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

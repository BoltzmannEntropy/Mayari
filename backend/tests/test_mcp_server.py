import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch


def _load_mcp_module():
    repo_root = Path(__file__).resolve().parents[2]
    module_path = repo_root / "bin" / "mayari_mcp_server.py"
    spec = importlib.util.spec_from_file_location("mayari_mcp_server", module_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load MCP module from {module_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class TestMayariMcpServer(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.module = _load_mcp_module()

    def test_tool_definitions_have_required_fields(self):
        tools = self.module.MCP_TOOLS
        self.assertIsInstance(tools, list)
        self.assertGreater(len(tools), 0)

        for tool in tools:
            self.assertIn("name", tool)
            self.assertIn("description", tool)
            self.assertIn("inputSchema", tool)
            self.assertIsInstance(tool["inputSchema"], dict)
            self.assertEqual(tool["inputSchema"].get("type"), "object")

    def test_tool_names_are_unique(self):
        names = [tool["name"] for tool in self.module.MCP_TOOLS]
        self.assertEqual(len(names), len(set(names)))

    def test_required_tools_exist(self):
        names = {tool["name"] for tool in self.module.MCP_TOOLS}
        self.assertIn("health_check", names)
        self.assertIn("mayari_status", names)
        self.assertIn("mayari_list_voices", names)
        self.assertIn("mayari_generate_speech", names)

    def test_unknown_tool_returns_structured_error(self):
        result = self.module._handle_tool_call("not_a_real_tool", {})
        payload = json.loads(result)
        self.assertIn("error", payload)
        self.assertIn("Unknown tool", payload["error"])

    def test_generate_tool_dispatches_backend_call(self):
        with patch.object(self.module, "_backend_request") as mock_backend:
            mock_backend.return_value = {"audio_url": "/audio/demo.wav"}
            result = self.module._handle_tool_call(
                "mayari_generate_speech",
                {"text": "Hello world", "voice": "bf_emma", "speed": 1.0},
            )
            payload = json.loads(result)
            self.assertIn("audio_url", payload)
            self.assertTrue(payload["audio_url"].startswith(self.module.BACKEND_URL))
            mock_backend.assert_called_once()


if __name__ == "__main__":
    unittest.main()

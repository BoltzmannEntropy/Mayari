import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class McpScreen extends StatefulWidget {
  const McpScreen({super.key});

  @override
  State<McpScreen> createState() => _McpScreenState();
}

class _McpScreenState extends State<McpScreen> {
  final TextEditingController _hostController = TextEditingController(
    text: '127.0.0.1',
  );
  final TextEditingController _portController = TextEditingController(
    text: '8086',
  );

  bool _serverRunning = false;
  bool _checking = false;
  List<Map<String, dynamic>> _tools = [];
  DateTime? _lastCheck;
  Timer? _pollTimer;

  String get _mcpUrl =>
      'http://${_hostController.text}:${_portController.text}';

  @override
  void initState() {
    super.initState();
    _checkServerStatus();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _checkServerStatus();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _checkServerStatus() async {
    if (_checking) {
      return;
    }
    setState(() => _checking = true);
    try {
      final response = await http
          .post(
            Uri.parse(_mcpUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'jsonrpc': '2.0',
              'method': 'tools/list',
              'params': {},
              'id': 1,
            }),
          )
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final result = body['result'] as Map<String, dynamic>?;
        final tools = (result?['tools'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        if (!mounted) {
          return;
        }
        setState(() {
          _serverRunning = true;
          _tools = tools;
          _lastCheck = DateTime.now();
        });
      } else if (mounted) {
        setState(() => _serverRunning = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _serverRunning = false);
      }
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  void _copyConfig() {
    final config = '''
{
  "mcpServers": {
    "mayari": {
      "command": "python3",
      "args": ["/absolute/path/to/bin/mayari_mcp_server.py"],
      "env": {
        "MAYARI_BACKEND_URL": "http://127.0.0.1:8787"
      }
    }
  }
}''';
    Clipboard.setData(ClipboardData(text: config));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Claude config copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusLabel = _serverRunning ? 'Running' : 'Stopped';
    final statusColor = _serverRunning ? Colors.green : Colors.red;

    return Scaffold(
      appBar: AppBar(title: const Text('MCP Integration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.hub_rounded,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Mayari MCP Integration',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Chip(
                      avatar: Icon(
                        _serverRunning ? Icons.check_circle : Icons.cancel,
                        size: 18,
                        color: statusColor,
                      ),
                      label: Text(statusLabel),
                      labelStyle: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_checking)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Server Status',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _hostController,
                                decoration: const InputDecoration(
                                  labelText: 'Host',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: _portController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Port',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _lastCheck == null
                              ? 'Last check: never'
                              : 'Last check: ${_lastCheck!.toIso8601String()}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            FilledButton.icon(
                              onPressed: _checkServerStatus,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Available Tools',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Chip(label: Text('${_tools.length} tools')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_tools.isEmpty)
                          Text(
                            _serverRunning
                                ? 'No tools reported by server.'
                                : 'Server is offline.',
                            style: theme.textTheme.bodyMedium,
                          )
                        else
                          ..._tools.map(
                            (tool) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                tool['name']?.toString() ?? 'unnamed_tool',
                              ),
                              subtitle: Text(
                                tool['description']?.toString() ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Claude Code Setup',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Copy MCP JSON config, then update script path in your Claude settings.',
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _copyConfig,
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy Configuration'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

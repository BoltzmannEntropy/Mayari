import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/log_service.dart';

/// Provider for logs panel visibility
final logsPanelVisibleProvider = StateProvider<bool>((ref) => true);

/// Provider for logs panel height
final logsPanelHeightProvider = StateProvider<double>((ref) => 150);

class LogsPanel extends ConsumerStatefulWidget {
  const LogsPanel({super.key});

  @override
  ConsumerState<LogsPanel> createState() => _LogsPanelState();
}

class _LogsPanelState extends ConsumerState<LogsPanel> {
  late final ScrollController _logScrollController;

  @override
  void initState() {
    super.initState();
    _logScrollController = ScrollController();
  }

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(logServiceProvider);
    final isVisible = ref.watch(logsPanelVisibleProvider);
    final panelHeight = ref.watch(logsPanelHeightProvider);

    if (!isVisible) {
      return _buildCollapsedBar(context);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Resize handle
        _buildResizeHandle(context),
        // Header bar
        _buildHeader(context),
        // Log content
        Container(
          height: panelHeight,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: logs.isEmpty
              ? const Center(
                  child: Text(
                    'No logs yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  controller: _logScrollController,
                  reverse: true,
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final entry = logs[logs.length - 1 - index];
                    return _buildLogEntry(context, entry);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCollapsedBar(BuildContext context) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.expand_less, size: 16),
            onPressed: () {
              ref.read(logsPanelVisibleProvider.notifier).state = true;
            },
            tooltip: 'Show logs',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          Text('System Logs', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildResizeHandle(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          final currentHeight = ref.read(logsPanelHeightProvider);
          final newHeight = currentHeight - details.delta.dy;
          ref.read(logsPanelHeightProvider.notifier).state = newHeight.clamp(
            80,
            400,
          );
        },
        child: Container(
          height: 6,
          color: Theme.of(context).dividerColor,
          child: Center(
            child: Container(
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final logService = ref.read(logServiceProvider.notifier);

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.expand_more, size: 16),
            onPressed: () {
              ref.read(logsPanelVisibleProvider.notifier).state = false;
            },
            tooltip: 'Collapse',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          Text('System Logs', style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          // Clear logs
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16),
            onPressed: () => logService.clear(),
            tooltip: 'Clear logs',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          // Export logs
          IconButton(
            icon: const Icon(Icons.download, size: 16),
            onPressed: () async {
              final path = await logService.exportLogs();
              if (context.mounted && path != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Logs exported to: $path'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            tooltip: 'Export logs',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(BuildContext context, LogEntry entry) {
    Color levelColor;
    switch (entry.level) {
      case LogLevel.debug:
        levelColor = Colors.grey;
        break;
      case LogLevel.info:
        levelColor = Colors.blue;
        break;
      case LogLevel.warning:
        levelColor = Colors.orange;
        break;
      case LogLevel.error:
        levelColor = Colors.red;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          Text(
            entry.formattedTime,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey,
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 8),
          // Level indicator
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: levelColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              entry.levelIcon,
              style: TextStyle(
                color: levelColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Source
          Container(
            constraints: const BoxConstraints(minWidth: 60),
            child: Text(
              entry.source,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Message
          Expanded(
            child: Text(
              entry.message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

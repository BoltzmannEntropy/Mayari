import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

enum LogLevel { debug, info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String source;
  final String message;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
  });

  String get levelIcon {
    switch (level) {
      case LogLevel.debug:
        return 'D';
      case LogLevel.info:
        return 'I';
      case LogLevel.warning:
        return 'W';
      case LogLevel.error:
        return 'E';
    }
  }

  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  @override
  String toString() {
    return '[$formattedTime] [$levelIcon] [$source] $message';
  }
}

class LogService extends StateNotifier<List<LogEntry>> {
  static const int maxLogs = 500;

  LogService() : super([]) {
    log(LogLevel.info, 'System', 'Mayari started');
  }

  void log(LogLevel level, String source, String message) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      source: source,
      message: message,
    );

    // Also print to console for debugging
    print(entry.toString());

    state = [...state, entry];

    // Trim old logs
    if (state.length > maxLogs) {
      state = state.sublist(state.length - maxLogs);
    }
  }

  void debug(String source, String message) => log(LogLevel.debug, source, message);
  void info(String source, String message) => log(LogLevel.info, source, message);
  void warning(String source, String message) => log(LogLevel.warning, source, message);
  void error(String source, String message) => log(LogLevel.error, source, message);

  void clear() {
    state = [];
    log(LogLevel.info, 'System', 'Logs cleared');
  }

  Future<String?> exportLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'mayari_logs_$timestamp.txt';
      final file = File(p.join(directory.path, fileName));

      final buffer = StringBuffer();
      buffer.writeln('Mayari Log Export');
      buffer.writeln('Generated: ${DateTime.now()}');
      buffer.writeln('=' * 60);
      buffer.writeln();

      for (final entry in state) {
        buffer.writeln(entry.toString());
      }

      await file.writeAsString(buffer.toString());
      log(LogLevel.info, 'System', 'Logs exported to: ${file.path}');
      return file.path;
    } catch (e) {
      log(LogLevel.error, 'System', 'Failed to export logs: $e');
      return null;
    }
  }
}

/// Provider for log service
final logServiceProvider = StateNotifierProvider<LogService, List<LogEntry>>((ref) {
  return LogService();
});

/// Convenience function to get logger
LogService getLogger(WidgetRef ref) => ref.read(logServiceProvider.notifier);

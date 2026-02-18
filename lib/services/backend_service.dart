import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

/// Manages the bundled Mayari backend lifecycle for macOS desktop builds.
class BackendService {
  BackendService._internal();

  static final BackendService _instance = BackendService._internal();
  factory BackendService() => _instance;

  static const String backendHost = String.fromEnvironment(
    'MAYARI_BACKEND_HOST',
    defaultValue: '127.0.0.1',
  );
  static const int backendPort = int.fromEnvironment(
    'MAYARI_BACKEND_PORT',
    defaultValue: 8787,
  );

  final StreamController<String> _statusController =
      StreamController<String>.broadcast();
  Process? _backendProcess;
  bool _isStarting = false;
  bool _hasAttemptedAutoStart = false;
  String _status = 'Backend idle';

  Stream<String> get statusStream => _statusController.stream;
  String get currentStatus => _status;
  bool get isStarting => _isStarting;

  String? get bundledBackendPath {
    if (!Platform.isMacOS) return null;

    final executable = Platform.resolvedExecutable;
    final macosDir = path.dirname(executable);
    final contentsDir = path.dirname(macosDir);
    final resourcesDir = path.join(contentsDir, 'Resources');
    final backendDir = path.join(resourcesDir, 'backend');
    if (Directory(backendDir).existsSync()) {
      return backendDir;
    }
    return null;
  }

  bool get hasBundledBackend => bundledBackendPath != null;

  String? _resolveBundledPython(String backendPath) {
    final resourcesDir = path.dirname(backendPath);
    final candidates = <String>[
      path.join(resourcesDir, 'python', 'bin', 'python3'),
      path.join(resourcesDir, 'python', 'bin', 'python'),
      path.join(backendPath, 'venv', 'bin', 'python3'),
      path.join(backendPath, 'venv', 'bin', 'python'),
    ];
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    return null;
  }

  Map<String, String> _runtimeEnvironment(String backendPath) {
    final home = Platform.environment['HOME'] ?? '';
    final supportDir = home.isNotEmpty
        ? path.join(home, 'Library', 'Application Support', 'Mayari')
        : '/tmp/Mayari';
    final cacheDir = home.isNotEmpty
        ? path.join(home, 'Library', 'Caches', 'Mayari')
        : '/tmp/Mayari/cache';
    final logDir = home.isNotEmpty
        ? path.join(home, 'Library', 'Logs', 'Mayari')
        : '/tmp/Mayari/logs';
    final outputDir = path.join(supportDir, 'outputs');
    final hfHome = path.join(supportDir, 'huggingface');
    final hfHub = path.join(hfHome, 'hub');

    for (final dir in <String>[
      supportDir,
      cacheDir,
      logDir,
      outputDir,
      hfHub,
    ]) {
      try {
        Directory(dir).createSync(recursive: true);
      } catch (_) {
        // Ignore mkdir failures; backend will surface runtime errors if needed.
      }
    }

    final pythonPath = <String>[
      backendPath,
      if ((Platform.environment['PYTHONPATH'] ?? '').isNotEmpty)
        Platform.environment['PYTHONPATH']!,
    ].join(':');

    return <String, String>{
      ...Platform.environment,
      'PYTHONUNBUFFERED': '1',
      'PYTHONPATH': pythonPath,
      'PYTHONPYCACHEPREFIX': path.join(cacheDir, 'pycache'),
      'XDG_CACHE_HOME': cacheDir,
      'MAYARI_RUNTIME_HOME': supportDir,
      'MAYARI_LOG_DIR': logDir,
      'MAYARI_OUTPUT_DIR': outputDir,
      'HF_HOME': hfHome,
      'HUGGINGFACE_HUB_CACHE': hfHub,
      'TRANSFORMERS_CACHE': hfHub,
      'MAYARI_BACKEND_HOST': backendHost,
      'MAYARI_BACKEND_PORT': backendPort.toString(),
    };
  }

  Future<bool> isBackendRunning() async {
    try {
      final socket = await Socket.connect(
        backendHost,
        backendPort,
        timeout: const Duration(milliseconds: 600),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> ensureBackendRunning({bool forceRetry = false}) async {
    if (await isBackendRunning()) {
      _updateStatus('Backend connected');
      return true;
    }

    if (_isStarting) {
      return _waitForBackend(const Duration(seconds: 20));
    }

    if (_hasAttemptedAutoStart && !forceRetry) {
      return false;
    }
    _hasAttemptedAutoStart = true;

    final backendPath = bundledBackendPath;
    if (backendPath == null) {
      _updateStatus('No bundled backend found (development mode)');
      return false;
    }

    final pythonBin = _resolveBundledPython(backendPath);
    if (pythonBin == null) {
      _updateStatus('Bundled Python runtime not found');
      return false;
    }

    _isStarting = true;
    _updateStatus('Starting bundled backend...');

    try {
      final launcherScript = path.join(backendPath, 'run_backend.sh');
      final useLauncherScript = File(launcherScript).existsSync();
      final env = _runtimeEnvironment(backendPath);

      final process = await Process.start(
        useLauncherScript ? '/bin/bash' : pythonBin,
        useLauncherScript ? <String>[launcherScript] : <String>['main.py'],
        workingDirectory: backendPath,
        environment: env,
      );

      _backendProcess = process;
      process.stdout
          .transform(const SystemEncoding().decoder)
          .listen((data) => _handleBackendOutput(data, isError: false));
      process.stderr
          .transform(const SystemEncoding().decoder)
          .listen((data) => _handleBackendOutput(data, isError: true));

      final ready = await _waitForBackend(const Duration(seconds: 45));
      if (ready) {
        _updateStatus('Backend started');
        _isStarting = false;
        return true;
      }

      _updateStatus('Backend failed to start');
      _isStarting = false;
      return false;
    } catch (error) {
      _updateStatus('Backend launch error: $error');
      _isStarting = false;
      return false;
    }
  }

  void _handleBackendOutput(String output, {required bool isError}) {
    final trimmed = output.trim();
    if (trimmed.isEmpty) {
      return;
    }
    debugPrint('[MayariBackend] $trimmed');

    final lower = trimmed.toLowerCase();
    if (lower.contains('address already in use')) {
      _updateStatus('Backend port $backendPort is already in use');
      return;
    }
    if (lower.contains('application startup complete') ||
        lower.contains('uvicorn running')) {
      _updateStatus('Backend ready');
      return;
    }
    if (isError && (lower.contains('error') || lower.contains('exception'))) {
      _updateStatus(trimmed);
    }
  }

  Future<bool> _waitForBackend(Duration timeout) async {
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < timeout) {
      if (await isBackendRunning()) {
        return true;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  Future<void> stopBackend() async {
    final process = _backendProcess;
    if (process == null) {
      return;
    }
    _updateStatus('Stopping backend...');
    process.kill(ProcessSignal.sigterm);
    await Future.delayed(const Duration(seconds: 1));
    try {
      process.kill(ProcessSignal.sigkill);
    } catch (_) {
      // Process already exited.
    }
    _backendProcess = null;
    _updateStatus('Backend stopped');
  }

  void _updateStatus(String next) {
    _status = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
    debugPrint('[BackendService] $next');
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/model_download_provider.dart';

/// Dialog for downloading the TTS model
class ModelDownloadDialog extends ConsumerStatefulWidget {
  const ModelDownloadDialog({super.key});

  @override
  ConsumerState<ModelDownloadDialog> createState() => _ModelDownloadDialogState();
}

class _ModelDownloadDialogState extends ConsumerState<ModelDownloadDialog> {
  bool _downloadStarted = false;

  @override
  void initState() {
    super.initState();
    // Auto-start download when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDownload();
    });
  }

  Future<void> _startDownload() async {
    if (_downloadStarted) return;
    setState(() => _downloadStarted = true);

    final notifier = ref.read(modelDownloadProvider.notifier);
    final success = await notifier.startDownload();

    if (success && mounted) {
      // Close dialog after short delay to show completion
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  void _cancel() {
    ref.read(modelDownloadProvider.notifier).cancelDownload();
    Navigator.of(context).pop(false);
  }

  void _retry() {
    setState(() => _downloadStarted = false);
    _startDownload();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(modelDownloadProvider);
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.download_rounded,
                  size: 28,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'TTS Model Download',
                  style: theme.textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Status message
            Text(
              status.statusMessage ?? _getDefaultStatusMessage(status.state),
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),

            // Progress or status indicator
            _buildProgressSection(status, theme),

            const SizedBox(height: 8),

            // File size info
            if (status.isDownloading || status.needsDownload)
              Text(
                'Model size: ~340 MB',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

            // Error message
            if (status.hasError && status.errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.onErrorContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status.errorMessage!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: _buildActionButtons(status),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(ModelDownloadStatus status, ThemeData theme) {
    if (status.isReady) {
      return Row(
        children: [
          Icon(
            Icons.check_circle,
            color: theme.colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            'Download complete!',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    if (status.isDownloading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: status.progress,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(status.progress * 100).toInt()}%',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    if (status.hasError) {
      return Icon(
        Icons.error_outline,
        color: theme.colorScheme.error,
        size: 32,
      );
    }

    // Checking state
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  List<Widget> _buildActionButtons(ModelDownloadStatus status) {
    if (status.isReady) {
      return [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Done'),
        ),
      ];
    }

    if (status.hasError) {
      return [
        TextButton(
          onPressed: _cancel,
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _retry,
          child: const Text('Retry'),
        ),
      ];
    }

    if (status.isDownloading) {
      return [
        TextButton(
          onPressed: _cancel,
          child: const Text('Cancel'),
        ),
      ];
    }

    // Checking state
    return [
      TextButton(
        onPressed: _cancel,
        child: const Text('Cancel'),
      ),
    ];
  }

  String _getDefaultStatusMessage(ModelDownloadState state) {
    switch (state) {
      case ModelDownloadState.checking:
        return 'Checking model status...';
      case ModelDownloadState.notDownloaded:
        return 'Preparing to download TTS model...';
      case ModelDownloadState.downloading:
        return 'Downloading TTS model...';
      case ModelDownloadState.ready:
        return 'TTS model is ready!';
      case ModelDownloadState.error:
        return 'Download failed';
    }
  }
}

/// Shows the model download dialog
Future<bool?> showModelDownloadDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const ModelDownloadDialog(),
  );
}

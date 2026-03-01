import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/audiobook_provider.dart';

class AudiobookJobsPanel extends ConsumerStatefulWidget {
  const AudiobookJobsPanel({super.key});

  @override
  ConsumerState<AudiobookJobsPanel> createState() => _AudiobookJobsPanelState();
}

class _AudiobookJobsPanelState extends ConsumerState<AudiobookJobsPanel> {
  late final Timer _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(audiobookJobsProvider);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(
                  Icons.work_history,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Jobs History',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${jobs.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: jobs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'No jobs yet',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: jobs.length,
                    itemBuilder: (context, index) {
                      return _JobCard(job: jobs[index], now: _now);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _JobCard extends ConsumerWidget {
  const _JobCard({required this.job, required this.now});

  final AudiobookJob job;
  final DateTime now;

  String _formatTime(DateTime dateTime) {
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final mm = dateTime.minute.toString().padLeft(2, '0');
    final ss = dateTime.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  String _formatElapsed(Duration duration) {
    final seconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(audiobookJobsProvider.notifier);
    final playback = ref.read(audiobookPlaybackProvider.notifier);
    final kindLabel = switch (job.jobType) {
      AudiobookJobType.generation => 'Generate',
      AudiobookJobType.optimizedExport => 'Export',
    };
    final statusColor = switch (job.status) {
      AudiobookJobStatus.queued => Colors.grey,
      AudiobookJobStatus.running => theme.colorScheme.primary,
      AudiobookJobStatus.completed => Colors.green,
      AudiobookJobStatus.failed => theme.colorScheme.error,
      AudiobookJobStatus.cancelled => theme.colorScheme.outline,
    };

    final statusLabel = switch (job.status) {
      AudiobookJobStatus.queued => 'Queued',
      AudiobookJobStatus.running => 'Running',
      AudiobookJobStatus.completed => 'Done',
      AudiobookJobStatus.failed => 'Failed',
      AudiobookJobStatus.cancelled => 'Cancelled',
    };
    final startTime = job.startedAt ?? job.createdAt;
    final endTime = job.finishedAt ?? now;
    final elapsed = endTime.difference(startTime);
    final timerLabel =
        '${job.startedAt == null ? 'Queued' : 'Started'} '
        '${_formatTime(startTime)}'
        ' · '
        '${job.isTerminal ? 'elapsed' : '+'}${_formatElapsed(elapsed)}';
    final pathToDisplay = job.resultPath ?? job.outputPath;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  job.title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  kindLabel,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (job.status == AudiobookJobStatus.running ||
              job.status == AudiobookJobStatus.queued) ...[
            LinearProgressIndicator(
              value: job.status == AudiobookJobStatus.queued
                  ? null
                  : (job.progress > 0 ? job.progress : null),
              minHeight: 2,
            ),
            const SizedBox(height: 6),
          ],
          Text(
            timerLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            job.message.isEmpty ? statusLabel : job.message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          SelectableText(
            pathToDisplay,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          if (job.errorMessage != null && job.errorMessage!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              job.errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontSize: 10,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              if (job.status == AudiobookJobStatus.completed &&
                  job.resultPath != null)
                IconButton(
                  icon: const Icon(Icons.play_arrow, size: 16),
                  onPressed: () async {
                    final resultPath = job.resultPath;
                    if (resultPath == null || !File(resultPath).existsSync()) {
                      return;
                    }
                    final book = Audiobook(
                      id: 'job_${job.id}',
                      title: job.title,
                      path: resultPath,
                      durationSeconds: 0,
                      chunks: job.totalChunks,
                      voice: job.voice,
                      speed: job.speed,
                      createdAt: job.finishedAt ?? job.createdAt,
                    );
                    await playback.play(book);
                  },
                  tooltip: 'Play output',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
              if (job.status == AudiobookJobStatus.completed &&
                  job.resultPath != null)
                IconButton(
                  icon: const Icon(Icons.folder_open, size: 16),
                  onPressed: () => Process.run('open', ['-R', job.resultPath!]),
                  tooltip: 'Open Folder',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
              if (job.status == AudiobookJobStatus.failed ||
                  job.status == AudiobookJobStatus.cancelled)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  onPressed: () => notifier.retry(job.id),
                  tooltip: 'Retry',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
              if (job.status == AudiobookJobStatus.queued)
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  onPressed: () => notifier.cancelQueued(job.id),
                  tooltip: 'Cancel',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
              const Spacer(),
              if (job.status != AudiobookJobStatus.running)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  onPressed: () => notifier.remove(job.id),
                  tooltip: 'Remove',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

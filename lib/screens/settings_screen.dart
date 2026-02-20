import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../providers/tts_provider.dart';
import '../providers/model_download_provider.dart';
import '../services/storage_service.dart';
import '../services/log_service.dart';
import '../version.dart';
import '../widgets/dialogs/model_download_dialog.dart';
import 'about_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import 'license_screen.dart';
import 'pro_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: Row(
        children: [
          // Sidebar navigation
          Container(
            width: 200,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildNavItem(Icons.tune, 'General', 0),
                _buildNavItem(Icons.record_voice_over, 'Text-to-Speech', 1),
              ],
            ),
          ),
          // Content area
          Expanded(
            child: _selectedTab == 0
                ? const _GeneralSettingsPane()
                : const _TtsSettingsPane(),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedTab == index;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => setState(() => _selectedTab = index),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
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

class _GeneralSettingsPane extends ConsumerWidget {
  const _GeneralSettingsPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Appearance Section
              _buildSectionHeader(context, 'Appearance'),
              const SizedBox(height: 12),
              _buildCard(
                context,
                child: ListTile(
                  leading: const Icon(Icons.palette),
                  title: const Text('Theme'),
                  subtitle: const Text('Follow system theme'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Theme follows system settings'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // About & Legal Section
              _buildSectionHeader(context, 'About & Legal'),
              const SizedBox(height: 12),
              _buildCard(
                context,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('About Mayari'),
                      subtitle: Text('Version $appVersion'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('Privacy Policy'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen(),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: const Text('Terms of Service'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TermsOfServiceScreen(),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.article_outlined),
                      title: const Text('Licenses'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LicenseScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Diagnostics section
              _buildSectionHeader(context, 'Diagnostics'),
              const SizedBox(height: 12),
              _buildCard(
                context,
                child: ListTile(
                  leading: const Icon(Icons.manage_search_rounded),
                  title: const Text('Export System Logs'),
                  subtitle: const Text('Export logs for troubleshooting'),
                  trailing: FilledButton.tonal(
                    onPressed: () async {
                      final logger = ref.read(logServiceProvider.notifier);
                      final path = await logger.exportLogs();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              path == null
                                  ? 'Failed to export logs'
                                  : 'Logs exported to $path',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Export'),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Pro section
              _buildSectionHeader(context, 'Pro'),
              const SizedBox(height: 12),
              _buildCard(
                context,
                child: ListTile(
                  leading: const Icon(Icons.workspace_premium_rounded),
                  title: const Text('Mayari Pro'),
                  subtitle: const Text('7-day trial with license activation'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const ProScreen())),
                ),
              ),
              const SizedBox(height: 24),

              // Developer Section
              _buildSectionHeader(context, 'Developer'),
              const SizedBox(height: 12),
              _buildCard(
                context,
                child: ListTile(
                  leading: const Icon(Icons.business),
                  title: const Text('Qneura.ai'),
                  subtitle: const Text('https://qneura.ai'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildCard(BuildContext context, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _TtsSettingsPane extends ConsumerStatefulWidget {
  const _TtsSettingsPane();

  @override
  ConsumerState<_TtsSettingsPane> createState() => _TtsSettingsPaneState();
}

class _TtsSettingsPaneState extends ConsumerState<_TtsSettingsPane> {
  String _selectedVoice = 'bf_emma';
  double _selectedSpeed = 1.0;
  bool _autoAdvancePages = true;
  bool _highlightCurrentParagraph = true;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPreviewPlaying = false;
  String? _modelDirectoryPath;
  StreamSubscription<PlayerState>? _previewSubscription;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadModelPaths();
  }

  @override
  void dispose() {
    _previewSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final storage = ref.read(storageServiceProvider);
    final settings = await storage.loadTtsSettings();
    if (mounted) {
      setState(() {
        _selectedVoice = settings.defaultVoice;
        _selectedSpeed = settings.defaultSpeed;
        _autoAdvancePages = settings.autoAdvancePages;
        _highlightCurrentParagraph = settings.highlightCurrentParagraph;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!mounted) return;
    setState(() => _isSaving = true);

    final settings = TtsSettings(
      defaultVoice: _selectedVoice,
      defaultSpeed: _selectedSpeed,
      autoAdvancePages: _autoAdvancePages,
      highlightCurrentParagraph: _highlightCurrentParagraph,
    );

    final storage = ref.read(storageServiceProvider);
    await storage.saveTtsSettings(settings);

    ref.read(ttsProvider.notifier).loadSettings(settings);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _loadModelPaths() async {
    final modelDir = await ref.read(ttsServiceProvider).getModelDirectoryPath();
    if (!mounted) return;
    setState(() => _modelDirectoryPath = modelDir);
  }

  Future<void> _previewVoice() async {
    if (!mounted) return;

    final modelStatus = ref.read(modelDownloadProvider);
    if (!modelStatus.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please download the TTS model first'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isPreviewPlaying = true);

    final service = ref.read(ttsServiceProvider);

    _previewSubscription?.cancel();
    _previewSubscription = service.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        if (mounted) {
          setState(() => _isPreviewPlaying = false);
        }
        _previewSubscription?.cancel();
      }
    });

    final success = await service.speak(
      'Hello, this is a preview of the selected voice.',
      voice: _selectedVoice,
      speed: _selectedSpeed,
    );

    if (!success && mounted) {
      setState(() => _isPreviewPlaying = false);
      _previewSubscription?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final voicesAsync = ref.watch(ttsVoicesProvider);
    final modelStatus = ref.watch(modelDownloadProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Model Status Section
              _buildSectionHeader(context, 'TTS Model'),
              const SizedBox(height: 12),
              _buildModelStatusCard(context, modelStatus),
              const SizedBox(height: 24),

              // Speed Settings
              _buildSectionHeader(context, 'Speed Settings'),
              const SizedBox(height: 12),
              _buildCard(
                context,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Default Speed',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Voice selection is available via the speaker cards in the reader',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<double>(
                        value: _selectedSpeed,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedSpeed = value);
                          }
                        },
                        items: speedOptions.map((speed) {
                          String label = speedDisplayName(speed);
                          if (speed == 1.0) label += ' (Normal)';
                          return DropdownMenuItem(
                            value: speed,
                            child: Text(label),
                          );
                        }).toList(),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Playback Options
              _buildSectionHeader(context, 'Playback Options'),
              const SizedBox(height: 12),
              _buildCard(
                context,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Auto-advance pages'),
                      subtitle: const Text(
                        'Automatically turn pages while reading',
                      ),
                      value: _autoAdvancePages,
                      onChanged: (value) =>
                          setState(() => _autoAdvancePages = value),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Highlight current paragraph'),
                      subtitle: const Text(
                        'Show visual highlight on text being read',
                      ),
                      value: _highlightCurrentParagraph,
                      onChanged: (value) =>
                          setState(() => _highlightCurrentParagraph = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Save button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    onPressed: _isSaving ? null : _saveSettings,
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Settings'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildCard(BuildContext context, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildModelStatusCard(
    BuildContext context,
    ModelDownloadStatus status,
  ) {
    final theme = Theme.of(context);

    IconData icon;
    Color iconColor;
    String title;
    String subtitle;
    Widget? action;

    if (status.isReady) {
      icon = Icons.check_circle;
      iconColor = Colors.green;
      title = 'TTS Model Ready';
      subtitle = 'Kokoro TTS model is installed and ready to use';
      action = null;
    } else if (status.isDownloading) {
      icon = Icons.downloading;
      iconColor = theme.colorScheme.primary;
      title = 'Downloading...';
      subtitle = '${(status.progress * 100).toInt()}% complete';
      action = SizedBox(
        width: 100,
        child: LinearProgressIndicator(value: status.progress),
      );
    } else if (status.hasError) {
      icon = Icons.error_outline;
      iconColor = theme.colorScheme.error;
      title = 'Download Failed';
      subtitle = status.errorMessage ?? 'Please try again';
      action = FilledButton(
        onPressed: () => showModelDownloadDialog(context),
        child: const Text('Retry'),
      );
    } else {
      icon = Icons.cloud_download_outlined;
      iconColor = theme.colorScheme.primary;
      title = 'TTS Model Required';
      subtitle =
          'Download the Kokoro TTS model (~340 MB) to enable text-to-speech';
      action = FilledButton.icon(
        onPressed: () => showModelDownloadDialog(context),
        icon: const Icon(Icons.download),
        label: const Text('Download Model'),
      );
    }

    final modelDir = _modelDirectoryPath;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: status.isReady
            ? Colors.green.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status.isReady
              ? Colors.green.withValues(alpha: 0.3)
              : theme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null) ...[const SizedBox(width: 16), action],
            ],
          ),
          if (modelDir != null) ...[
            const SizedBox(height: 12),
            Text(
              'Model location',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              '$modelDir/kokoro-v1_0.safetensors\n$modelDir/voices.npz',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

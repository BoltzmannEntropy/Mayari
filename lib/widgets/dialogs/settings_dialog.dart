import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../providers/tts_provider.dart';
import '../../services/storage_service.dart';
import '../../services/log_service.dart';
import '../../version.dart';
import '../../screens/about_screen.dart';
import '../../screens/privacy_policy_screen.dart';
import '../../screens/terms_of_service_screen.dart';
import '../../screens/license_screen.dart';
import '../../screens/mcp_screen.dart';
import '../../screens/pro_screen.dart';

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        height: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildTabButton('General', 0),
                const SizedBox(width: 8),
                _buildTabButton('TTS', 1),
              ],
            ),
            const Divider(),
            Expanded(
              child: _selectedTab == 0
                  ? const _GeneralSettingsTab()
                  : const _TtsSettingsTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTab == index;
    return TextButton(
      onPressed: () => setState(() => _selectedTab = index),
      style: TextButton.styleFrom(
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
      ),
      child: Text(label),
    );
  }
}

class _GeneralSettingsTab extends ConsumerWidget {
  const _GeneralSettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Appearance Section
          Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Theme'),
            subtitle: const Text('Follow system theme'),
            trailing: const Icon(Icons.chevron_right),
            contentPadding: EdgeInsets.zero,
            onTap: () {
              // Theme selection would go here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Theme follows system settings'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const Divider(),

          // About & Legal Section
          const SizedBox(height: 16),
          Text('About & Legal', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About Mayari'),
            subtitle: Text('Version $appVersion'),
            trailing: const Icon(Icons.chevron_right),
            contentPadding: EdgeInsets.zero,
            onTap: () {
              Navigator.of(context).pop(); // Close settings dialog
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AboutScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            contentPadding: EdgeInsets.zero,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.chevron_right),
            contentPadding: EdgeInsets.zero,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('Licenses'),
            trailing: const Icon(Icons.chevron_right),
            contentPadding: EdgeInsets.zero,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const LicenseScreen()));
            },
          ),
          const Divider(),

          // Diagnostics section
          const SizedBox(height: 16),
          Text('Diagnostics', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.hub_rounded),
            title: const Text('MCP Integration'),
            subtitle: const Text('View MCP server status and tool list'),
            trailing: const Icon(Icons.chevron_right),
            contentPadding: EdgeInsets.zero,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const McpScreen()));
            },
          ),
          ListTile(
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
                            : 'Diagnostic logs exported to $path',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Export'),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(),

          // Pro section
          const SizedBox(height: 16),
          Text('Pro', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.workspace_premium_rounded),
            title: const Text('Mayari Pro'),
            subtitle: const Text(
              '7-day trial with Polar.sh and LemonSqueezy license activation',
            ),
            trailing: const Icon(Icons.chevron_right),
            contentPadding: EdgeInsets.zero,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProScreen()));
            },
          ),
          const Divider(),

          // Developer Section
          const SizedBox(height: 16),
          Text('Developer', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.business),
            title: const Text('Qneura.ai'),
            subtitle: const Text('https://qneura.ai'),
            contentPadding: EdgeInsets.zero,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Link copied: https://qneura.ai'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TtsSettingsTab extends ConsumerStatefulWidget {
  const _TtsSettingsTab();

  @override
  ConsumerState<_TtsSettingsTab> createState() => _TtsSettingsTabState();
}

class _TtsSettingsTabState extends ConsumerState<_TtsSettingsTab> {
  String _selectedVoice = 'bf_emma';
  double _selectedSpeed = 1.0;
  bool _autoAdvancePages = true;
  bool _highlightCurrentParagraph = true;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPreviewPlaying = false;
  StreamSubscription<PlayerState>? _previewSubscription;

  @override
  void initState() {
    super.initState();
    _loadSettings();
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

    // Update the provider
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

  Future<void> _previewVoice() async {
    if (!mounted) return;
    setState(() => _isPreviewPlaying = true);

    final service = ref.read(ttsServiceProvider);

    // Listen for playback completion
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

    // If speak failed, reset the state
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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Default Voice', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: voicesAsync.when(
                  data: (voices) => DropdownButtonFormField<String>(
                    initialValue: _selectedVoice,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedVoice = value);
                      }
                    },
                    items: voices.map((voice) {
                      return DropdownMenuItem(
                        value: voice.id,
                        child: Text(
                          '${voice.name} (${voice.gender}, ${voice.grade})',
                        ),
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
                  loading: () => const LinearProgressIndicator(),
                  error: (_, error) => const Text('Error loading voices'),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isPreviewPlaying ? null : _previewVoice,
                icon: _isPreviewPlaying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow, size: 18),
                label: const Text('Preview'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Default Speed', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<double>(
            initialValue: _selectedSpeed,
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedSpeed = value);
              }
            },
            items: speedOptions.map((speed) {
              String label = speedDisplayName(speed);
              if (speed == 1.0) label += ' (Normal)';
              return DropdownMenuItem(value: speed, child: Text(label));
            }).toList(),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Playback Options',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Auto-advance pages'),
            subtitle: const Text('Automatically turn pages while reading'),
            value: _autoAdvancePages,
            onChanged: (value) => setState(() => _autoAdvancePages = value),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('Highlight current paragraph'),
            subtitle: const Text('Show visual highlight on text being read'),
            value: _highlightCurrentParagraph,
            onChanged: (value) =>
                setState(() => _highlightCurrentParagraph = value),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows the settings dialog
Future<void> showSettingsDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) => const SettingsDialog(),
  );
}

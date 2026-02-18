import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// License screen showing app license and third-party licenses
class LicenseScreen extends StatelessWidget {
  const LicenseScreen({super.key});

  static const String _overviewUrl =
      'https://github.com/BoltzmannEntropy/Mayari/blob/master/LICENSE.md';
  static const String _sourceLicenseUrl =
      'https://github.com/BoltzmannEntropy/Mayari/blob/master/LICENSE';
  static const String _binaryLicenseUrl =
      'https://github.com/BoltzmannEntropy/Mayari/blob/master/BINARY-LICENSE.txt';

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('License'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Licensing Overview',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 24),

                _buildSection(
                  context,
                  title: 'Mayari Application License',
                  content:
                      'Source code is licensed under the Business Source License 1.1 (BSL).\n\n'
                      'Production use is permitted under the Additional Use Grant.\n\n'
                      'Official DMG/executable binaries are governed by a separate Binary Distribution License. Commercial use or redistribution of the Binary is not allowed.\n\n'
                      'See LICENSE and BINARY-LICENSE.txt for full terms.',
                ),

                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resources',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: () => _launchUrl(_overviewUrl),
                              icon: const Icon(Icons.info_outline),
                              label: const Text('License Overview'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () => _launchUrl(_sourceLicenseUrl),
                              icon: const Icon(Icons.code),
                              label: const Text('Source License'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () => _launchUrl(_binaryLicenseUrl),
                              icon: const Icon(Icons.inventory_2),
                              label: const Text('Binary License'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                Text(
                  'Third-Party Licenses',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),

                _buildLicenseCard(
                  context,
                  name: 'Flutter',
                  license: 'BSD 3-Clause License',
                  copyright: 'Copyright 2014 The Flutter Authors',
                  url: 'https://flutter.dev',
                ),

                _buildLicenseCard(
                  context,
                  name: 'Syncfusion Flutter PDF Viewer',
                  license: 'Syncfusion Community License',
                  copyright: 'Copyright Syncfusion Inc.',
                  url: 'https://www.syncfusion.com/flutter-widgets/flutter-pdf-viewer',
                ),

                _buildLicenseCard(
                  context,
                  name: 'Syncfusion Flutter PDF',
                  license: 'Syncfusion Community License',
                  copyright: 'Copyright Syncfusion Inc.',
                  url: 'https://www.syncfusion.com/flutter-widgets/pdf-library',
                ),

                _buildLicenseCard(
                  context,
                  name: 'Riverpod',
                  license: 'MIT License',
                  copyright: 'Copyright 2020 Remi Rousselet',
                  url: 'https://riverpod.dev',
                ),

                _buildLicenseCard(
                  context,
                  name: 'just_audio',
                  license: 'MIT License',
                  copyright: 'Copyright 2019-2024 Ryan Heise',
                  url: 'https://pub.dev/packages/just_audio',
                ),

                _buildLicenseCard(
                  context,
                  name: 'file_picker',
                  license: 'MIT License',
                  copyright: 'Copyright Miguel Ruivo',
                  url: 'https://pub.dev/packages/file_picker',
                ),

                _buildLicenseCard(
                  context,
                  name: 'path_provider',
                  license: 'BSD 3-Clause License',
                  copyright: 'Copyright 2013 The Flutter Authors',
                  url: 'https://pub.dev/packages/path_provider',
                ),

                _buildLicenseCard(
                  context,
                  name: 'desktop_drop',
                  license: 'MIT License',
                  copyright: 'Copyright mixins',
                  url: 'https://pub.dev/packages/desktop_drop',
                ),

                _buildLicenseCard(
                  context,
                  name: 'uuid',
                  license: 'MIT License',
                  copyright: 'Copyright Yulian Kuncheff',
                  url: 'https://pub.dev/packages/uuid',
                ),

                _buildLicenseCard(
                  context,
                  name: 'flutter_markdown',
                  license: 'BSD 3-Clause License',
                  copyright: 'Copyright 2016 The Flutter Authors',
                  url: 'https://pub.dev/packages/flutter_markdown',
                ),

                _buildLicenseCard(
                  context,
                  name: 'http',
                  license: 'BSD 3-Clause License',
                  copyright: 'Copyright 2014 The Dart Authors',
                  url: 'https://pub.dev/packages/http',
                ),

                const SizedBox(height: 24),
                _buildSection(
                  context,
                  title: 'TTS Engine Credits',
                  content:
                      'Mayari supports integration with the following text-to-speech engines:\n\n'
                      '- Kokoro TTS: High-quality neural text-to-speech\n'
                      '- System TTS: Platform native speech synthesis\n\n'
                      'Please refer to the respective documentation and licenses for these TTS engines.',
                ),

                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () {
                      showLicensePage(
                        context: context,
                        applicationName: 'Mayari',
                        applicationVersion: '1.0.0',
                        applicationLegalese: '2025 QNeura.ai',
                      );
                    },
                    child: const Text('View All Flutter Package Licenses'),
                  ),
                ),

                const SizedBox(height: 32),
                Center(
                  child: Text(
                    '2025 QNeura.ai. All rights reserved.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor,
            ),
          ),
          child: Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                  fontFamily: 'monospace',
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildLicenseCard(
    BuildContext context, {
    required String name,
    required String license,
    required String copyright,
    required String url,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            license,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            copyright,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }
}

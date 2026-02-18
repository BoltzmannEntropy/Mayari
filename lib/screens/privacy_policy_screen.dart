import 'package:flutter/material.dart';

/// Privacy Policy screen for App Store compliance
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String _lastUpdated = 'February 2026';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
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
                  'Privacy Policy',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Last updated: $_lastUpdated',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(height: 24),

                _buildSection(
                  context,
                  title: 'Introduction',
                  content:
                      'Mayari ("we", "our", or "the app") is a PDF quote extraction and text-to-speech application developed by QNeura.ai. This Privacy Policy explains how we handle information when you use the app.',
                ),

                _buildSection(
                  context,
                  title: 'Data Collection',
                  content:
                      'Mayari is designed to be local-first. We do not collect personal information by default, and we do not track usage behavior or sell data to third parties. Your content remains on your device unless you choose to share it.',
                ),

                _buildSection(
                  context,
                  title: 'On-Device Processing',
                  content:
                      'Text-to-speech and PDF processing features run locally using on-device or user-configured engines. Your content is processed on your device and is not sent to external servers by default.',
                ),

                _buildSection(
                  context,
                  title: 'Data Storage',
                  content:
                      'Files you import or generate are stored locally on your device. You control when and how to delete or share this data.',
                ),

                _buildSection(
                  context,
                  title: 'Third-Party Services',
                  content:
                      'The app may utilize system-level services provided by your operating system or locally hosted TTS services. If you enable external endpoints, those services are governed by their own privacy policies.',
                ),

                _buildSection(
                  context,
                  title: 'Data Security',
                  content:
                      'Since all data is stored locally on your device, the security of your data depends on your device\'s security measures. We recommend using standard device security features.',
                ),

                _buildSection(
                  context,
                  title: 'Children\'s Privacy',
                  content:
                      'Mayari does not knowingly collect any information from children under the age of 13.',
                ),

                _buildSection(
                  context,
                  title: 'Changes to This Policy',
                  content:
                      'We may update this Privacy Policy from time to time. Changes will be reflected in the "Last updated" date at the top of this policy.',
                ),

                _buildSection(
                  context,
                  title: 'Contact Us',
                  content:
                      'If you have any questions about this Privacy Policy, please contact solomon@qneura.ai or visit https://qneura.ai/apps.html.',
                ),

                const SizedBox(height: 32),
                Center(
                  child: Text(
                    '2026 QNeura.ai. All rights reserved.',
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }
}

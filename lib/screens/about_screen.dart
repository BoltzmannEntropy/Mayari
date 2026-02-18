import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../version.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import 'license_screen.dart';

/// About screen showing app information, credits, and links
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _appName = 'Mayari';
  static const String _author = 'QNeura.ai';
  static const String _authorUrl = 'https://qneura.ai';
  static const String _copyright = '2025 QNeura.ai. All rights reserved.';
  static const String _appDescription =
      'PDF quote extraction tool for academic research with text-to-speech support.';

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to open link')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About $_appName'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // App Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.menu_book,
                    size: 60,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),

                // App Name and Version
                Text(
                  _appName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version $appVersion',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  _appDescription,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),

                // Important Notice
                _buildSection(
                  context,
                  title: 'Important Notice',
                  child: Text(
                    'Mayari is a research productivity tool. Extracted quotes, OCR, and '
                    'TTS output should be reviewed by the user before publication or citation.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 16),

                // What This Project Does
                _buildSection(
                  context,
                  title: 'What This Project Does',
                  child: Text(
                    '• Reads PDFs with integrated navigation and zoom\n'
                    '• Extracts quotes with source metadata for research notes\n'
                    '• Supports read-aloud and audiobook-style output workflows\n'
                    '• Helps organize source snippets for writing and citation',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ),
                const SizedBox(height: 16),

                // Author
                _buildSection(
                  context,
                  title: 'Developer',
                  child: InkWell(
                    onTap: () => _launchUrl(context, _authorUrl),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.business,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _author,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.open_in_new,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Links
                _buildSection(
                  context,
                  title: 'Links',
                  child: Column(
                    children: [
                      _buildLinkTile(
                        context,
                        icon: Icons.language,
                        label: 'Website',
                        url: _authorUrl,
                      ),
                      _buildLinkTile(
                        context,
                        icon: Icons.code,
                        label: 'GitHub',
                        url: 'https://github.com/qneura-ai/mayari',
                      ),
                      _buildLinkTile(
                        context,
                        icon: Icons.bug_report,
                        label: 'Report Issue',
                        url: 'https://github.com/qneura-ai/mayari/issues',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Credits
                _buildSection(
                  context,
                  title: 'Model Credits & Licenses',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCreditItem(
                        context,
                        name: 'Kokoro TTS',
                        description: 'High-quality text-to-speech engine',
                      ),
                      _buildCreditItem(
                        context,
                        name: 'Syncfusion Flutter PDF',
                        description: 'PDF viewing and text extraction',
                      ),
                      _buildCreditItem(
                        context,
                        name: 'Flutter & Dart',
                        description: 'Cross-platform UI framework',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Kokoro TTS (Apache-2.0) · Syncfusion PDF (vendor terms) · Flutter (BSD-3)',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Legal
                _buildSection(
                  context,
                  title: 'Legal',
                  child: Column(
                    children: [
                      _buildNavigationTile(
                        context,
                        icon: Icons.privacy_tip,
                        label: 'Privacy Policy',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyScreen(),
                          ),
                        ),
                      ),
                      _buildNavigationTile(
                        context,
                        icon: Icons.description,
                        label: 'Terms of Service',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TermsOfServiceScreen(),
                          ),
                        ),
                      ),
                      _buildNavigationTile(
                        context,
                        icon: Icons.article,
                        label: 'License',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LicenseScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Copyright
                Text(
                  'Source: BSL 1.1 · Binary: Binary Distribution License',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _copyright,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
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
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildLinkTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String url,
  }) {
    return InkWell(
      onTap: () => _launchUrl(context, url),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            Icon(Icons.open_in_new, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditItem(
    BuildContext context, {
    required String name,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

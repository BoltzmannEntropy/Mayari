import 'package:flutter/material.dart';

/// Terms of Service screen for App Store compliance
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  static const String _lastUpdated = 'February 2026';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
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
                  'Terms of Service',
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
                  title: '1. Acceptance of Terms',
                  content:
                      'By downloading, installing, or using Mayari (the "Service"), you agree to be bound by these Terms of Service. If you do not agree to these terms, do not use the Service. Additional guidelines may apply to specific features and are incorporated by reference.',
                ),

                _buildSection(
                  context,
                  title: '2. Description of Service',
                  content:
                      'Mayari is a PDF quote extraction and text-to-speech application designed for academic research. The Service allows you to import PDFs, extract and organize quotes, generate audio playback, and export annotations.',
                ),

                _buildSection(
                  context,
                  title: '3. User Conduct',
                  content:
                      'You agree to use the Service only for lawful purposes and to respect intellectual property rights. Do not use the Service to impersonate others, process content you do not have rights to use, or generate deceptive or harmful output.',
                ),

                _buildSection(
                  context,
                  title: '4. Intellectual Property',
                  content:
                      'The Service and its original content (excluding user-provided content) are the exclusive property of QNeura.ai and its licensors. You retain ownership of your content. Nothing in these terms grants you rights to use QNeura.ai trademarks or branding.',
                ),

                _buildSection(
                  context,
                  title: '5. AI Features Disclaimer',
                  content:
                      'AI-generated outputs may be inaccurate, imperfect, or unsuitable for critical use cases. You should verify important information using original sources.',
                ),

                _buildSection(
                  context,
                  title: '6. Disclaimer of Warranties',
                  content:
                      'THE SERVICE IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED.',
                ),

                _buildSection(
                  context,
                  title: '7. Limitation of Liability',
                  content:
                      'IN NO EVENT SHALL QNEURA.AI BE LIABLE FOR ANY DAMAGES (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF DATA OR PROFIT, OR DUE TO BUSINESS INTERRUPTION) ARISING OUT OF THE USE OR INABILITY TO USE THE SERVICE.',
                ),

                _buildSection(
                  context,
                  title: '8. Changes to Terms',
                  content:
                      'We may update these Terms from time to time. Continued use of the Service after changes constitutes acceptance of the updated terms.',
                ),

                _buildSection(
                  context,
                  title: '9. Contact Us',
                  content:
                      'If you have questions about these Terms, please contact solomon@qneura.ai or visit https://qneura.ai/apps.html.',
                ),

                _buildSection(
                  context,
                  title: '10. External Content Sources',
                  content:
                      'The Service may include third-party libraries or text-to-speech providers. These components are governed by their respective licenses and terms. You are responsible for complying with third-party terms.',
                ),

                _buildSection(
                  context,
                  title: '11. Apple Standard EULA',
                  content:
                      'If you download Mayari via the Apple App Store, the Apple Standard EULA applies: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/.',
                ),

                _buildSection(
                  context,
                  title: '12. License & Distribution',
                  content:
                      'Source code is licensed under the Business Source License 1.1 (see LICENSE). Official DMG/executable binaries are governed by a separate Binary Distribution License. Commercial use or redistribution of the Binary is not allowed. See LICENSE.md for details.',
                ),

                _buildSection(
                  context,
                  title: '13. Paid Features',
                  content:
                      'If paid features are offered, purchases are processed by the storefront or payment provider. Subscription management and cancellations are handled through your account with that provider.',
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

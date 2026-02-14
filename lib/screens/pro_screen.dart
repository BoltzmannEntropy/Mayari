import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ProScreen extends StatefulWidget {
  const ProScreen({super.key});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  static const int _defaultTrialDays = 7;
  static const String _kTrialStartedAt = 'trial_started_at';
  static const String _kTrialDurationDays = 'trial_duration_days';
  static const String _kProActivated = 'pro_activated';
  static const String _kLicenseKey = 'license_key';
  static const String _kPolarCheckout = 'polar_checkout_url';
  static const String _kPolarPortal = 'polar_portal_url';

  final _licenseController = TextEditingController();
  final _checkoutController = TextEditingController();
  final _portalController = TextEditingController();
  final _licenseFocusNode = FocusNode();

  bool _loading = true;
  bool _activating = false;
  bool _proActivated = false;
  int _trialDaysLeft = _defaultTrialDays;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _licenseController.dispose();
    _checkoutController.dispose();
    _portalController.dispose();
    _licenseFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc();

    final rawStarted = prefs.getString(_kTrialStartedAt);
    final startedAt = DateTime.tryParse(rawStarted ?? '')?.toUtc() ?? now;
    if (rawStarted == null) {
      await prefs.setString(_kTrialStartedAt, startedAt.toIso8601String());
    }

    final duration = prefs.getInt(_kTrialDurationDays) ?? _defaultTrialDays;
    if (!prefs.containsKey(_kTrialDurationDays)) {
      await prefs.setInt(_kTrialDurationDays, _defaultTrialDays);
    }

    final elapsed = now.difference(startedAt).inDays;
    final daysLeft = (duration - elapsed).clamp(0, duration);

    if (!mounted) return;
    setState(() {
      _proActivated = prefs.getBool(_kProActivated) ?? false;
      _trialDaysLeft = daysLeft;
      _licenseController.text = prefs.getString(_kLicenseKey) ?? '';
      _checkoutController.text =
          prefs.getString(_kPolarCheckout) ?? 'https://polar.sh';
      _portalController.text =
          prefs.getString(_kPolarPortal) ?? 'https://polar.sh';
      _loading = false;
    });
  }

  Future<void> _activate() async {
    final key = _licenseController.text.trim();
    if (key.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid Polar license key.')),
      );
      return;
    }

    setState(() => _activating = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLicenseKey, key);
    await prefs.setBool(_kProActivated, true);
    await prefs.setString('license_provider', 'polar');
    await prefs.setString(
      'license_activated_at',
      DateTime.now().toUtc().toIso8601String(),
    );

    if (!mounted) return;
    setState(() {
      _proActivated = true;
      _activating = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('License activated (Polar-ready mode).')),
    );
  }

  Future<void> _savePolarUrls() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPolarCheckout, _checkoutController.text.trim());
    await prefs.setString(_kPolarPortal, _portalController.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Polar URLs saved.')));
  }

  Future<void> _openUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mayari Pro')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _proActivated
                  ? Colors.green.withValues(alpha: 0.12)
                  : const Color(0xFFF1E8DD),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _proActivated
                          ? Icons.verified_rounded
                          : Icons.warning_amber_rounded,
                      size: 34,
                      color: _proActivated ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _proActivated
                              ? 'Mayari Pro Active'
                              : 'Trial Ending Soon',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (!_proActivated)
                          Text(
                            'You have $_trialDaysLeft day${_trialDaysLeft == 1 ? '' : 's'} left in your trial',
                          ),
                      ],
                    ),
                  ],
                ),
                if (!_proActivated)
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: () => _licenseFocusNode.requestFocus(),
                        child: const Text('Enter License'),
                      ),
                      FilledButton(
                        onPressed: () => _openUrl(_checkoutController.text),
                        child: const Text('Buy License'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Activate License',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _licenseController,
                          focusNode: _licenseFocusNode,
                          decoration: const InputDecoration(
                            hintText: 'Enter your Polar license key',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _activating ? null : _activate,
                        child: _activating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Activate'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _openUrl(_portalController.text),
                    icon: const Icon(Icons.manage_accounts_rounded),
                    label: const Text('License Portal'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Polar Configuration',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _checkoutController,
                    decoration: const InputDecoration(
                      labelText: 'Polar Checkout URL',
                      hintText: 'https://polar.sh/checkout/...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _portalController,
                    decoration: const InputDecoration(
                      labelText: 'Polar Customer Portal URL',
                      hintText: 'https://polar.sh/portal/...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonal(
                    onPressed: _savePolarUrls,
                    child: const Text('Save Polar URLs'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

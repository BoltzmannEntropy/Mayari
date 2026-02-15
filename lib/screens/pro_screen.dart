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
  static const String _defaultPolarCheckoutUrl = 'https://polar.sh';
  static const String _defaultPolarPortalUrl = 'https://polar.sh';
  static const String _defaultLemonCheckoutUrl = 'https://lemonsqueezy.com';
  static const String _defaultLemonPortalUrl = 'https://lemonsqueezy.com';

  static const String _kTrialStartedAt = 'trial_started_at';
  static const String _kTrialDurationDays = 'trial_duration_days';
  static const String _kProActivated = 'pro_activated';
  static const String _kLicenseKey = 'license_key';
  static const String _kPolarCheckoutUrl = 'polar_checkout_url';
  static const String _kPolarPortalUrl = 'polar_portal_url';
  static const String _kLemonCheckoutUrl = 'lemonsqueezy_checkout_url';
  static const String _kLemonPortalUrl = 'lemonsqueezy_portal_url';
  static const String _kLicenseProvider = 'license_provider';

  final TextEditingController _licenseController = TextEditingController();
  final TextEditingController _polarCheckoutController =
      TextEditingController();
  final TextEditingController _polarPortalController = TextEditingController();
  final TextEditingController _lemonCheckoutController =
      TextEditingController();
  final TextEditingController _lemonPortalController = TextEditingController();
  final FocusNode _licenseFocusNode = FocusNode();

  bool _loading = true;
  bool _activating = false;
  bool _proActivated = false;
  int _trialDaysLeft = _defaultTrialDays;
  int _trialDurationDays = _defaultTrialDays;
  String _selectedProvider = 'polar';

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _licenseController.dispose();
    _polarCheckoutController.dispose();
    _polarPortalController.dispose();
    _lemonCheckoutController.dispose();
    _lemonPortalController.dispose();
    _licenseFocusNode.dispose();
    super.dispose();
  }

  bool _isValidProvider(String? value) {
    return value == 'polar' || value == 'lemonsqueezy';
  }

  String _providerLabel(String value) {
    return value == 'lemonsqueezy' ? 'LemonSqueezy' : 'Polar';
  }

  TextEditingController _checkoutControllerFor(String provider) {
    return provider == 'lemonsqueezy'
        ? _lemonCheckoutController
        : _polarCheckoutController;
  }

  TextEditingController _portalControllerFor(String provider) {
    return provider == 'lemonsqueezy'
        ? _lemonPortalController
        : _polarPortalController;
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc();

    final startedRaw = prefs.getString(_kTrialStartedAt);
    final startedAt = DateTime.tryParse(startedRaw ?? '')?.toUtc() ?? now;
    if (startedRaw == null) {
      await prefs.setString(_kTrialStartedAt, startedAt.toIso8601String());
    }

    final trialDays = prefs.getInt(_kTrialDurationDays) ?? _defaultTrialDays;
    if (!prefs.containsKey(_kTrialDurationDays)) {
      await prefs.setInt(_kTrialDurationDays, _defaultTrialDays);
    }

    final elapsed = now.difference(startedAt).inDays;
    final daysLeft = (trialDays - elapsed).clamp(0, trialDays);

    final providerRaw = prefs.getString(_kLicenseProvider);
    final provider = _isValidProvider(providerRaw) ? providerRaw! : 'polar';
    if (!_isValidProvider(providerRaw)) {
      await prefs.setString(_kLicenseProvider, provider);
    }

    if (!mounted) return;
    setState(() {
      _proActivated = prefs.getBool(_kProActivated) ?? false;
      _trialDurationDays = trialDays;
      _trialDaysLeft = daysLeft;
      _selectedProvider = provider;
      _licenseController.text = prefs.getString(_kLicenseKey) ?? '';
      _polarCheckoutController.text =
          prefs.getString(_kPolarCheckoutUrl) ?? _defaultPolarCheckoutUrl;
      _polarPortalController.text =
          prefs.getString(_kPolarPortalUrl) ?? _defaultPolarPortalUrl;
      _lemonCheckoutController.text =
          prefs.getString(_kLemonCheckoutUrl) ?? _defaultLemonCheckoutUrl;
      _lemonPortalController.text =
          prefs.getString(_kLemonPortalUrl) ?? _defaultLemonPortalUrl;
      _loading = false;
    });
  }

  Future<void> _activate() async {
    final key = _licenseController.text.trim();
    if (key.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enter a valid ${_providerLabel(_selectedProvider)} license key.',
          ),
        ),
      );
      return;
    }

    setState(() => _activating = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLicenseKey, key);
    await prefs.setBool(_kProActivated, true);
    await prefs.setString(_kLicenseProvider, _selectedProvider);
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
      SnackBar(
        content: Text(
          'License activated (${_providerLabel(_selectedProvider)} mode).',
        ),
      ),
    );
  }

  Future<void> _saveProviderUrls() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kPolarCheckoutUrl,
      _polarCheckoutController.text.trim(),
    );
    await prefs.setString(_kPolarPortalUrl, _polarPortalController.text.trim());
    await prefs.setString(
      _kLemonCheckoutUrl,
      _lemonCheckoutController.text.trim(),
    );
    await prefs.setString(_kLemonPortalUrl, _lemonPortalController.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Provider links saved.')));
  }

  Future<void> _openUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid URL.')));
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open URL.')));
    }
  }

  Future<void> _buyLicense(String provider) async {
    await _openUrl(_checkoutControllerFor(provider).text);
  }

  Widget _buildProviderSelector() {
    return Wrap(
      spacing: 10,
      children: [
        ChoiceChip(
          label: const Text('Polar'),
          selected: _selectedProvider == 'polar',
          onSelected: (_) => setState(() => _selectedProvider = 'polar'),
        ),
        ChoiceChip(
          label: const Text('LemonSqueezy'),
          selected: _selectedProvider == 'lemonsqueezy',
          onSelected: (_) => setState(() => _selectedProvider = 'lemonsqueezy'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final trialEnded = _trialDaysLeft <= 0;
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
                              : (trialEnded
                                    ? 'Trial Ended'
                                    : 'Trial Ending Soon'),
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (!_proActivated)
                          Text(
                            trialEnded
                                ? 'Your $_trialDurationDays-day trial has ended'
                                : 'You have $_trialDaysLeft day${_trialDaysLeft == 1 ? '' : 's'} left in your trial',
                          ),
                      ],
                    ),
                  ],
                ),
                if (!_proActivated)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: () => _licenseFocusNode.requestFocus(),
                        child: const Text('Enter License'),
                      ),
                      FilledButton(
                        onPressed: () => _buyLicense('polar'),
                        child: const Text('Buy with Polar'),
                      ),
                      FilledButton(
                        onPressed: () => _buyLicense('lemonsqueezy'),
                        child: const Text('Buy with LemonSqueezy'),
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
                  _buildProviderSelector(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _licenseController,
                          focusNode: _licenseFocusNode,
                          decoration: InputDecoration(
                            hintText:
                                'Enter your ${_providerLabel(_selectedProvider)} license key',
                            border: const OutlineInputBorder(),
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
                    onPressed: () =>
                        _openUrl(_portalControllerFor(_selectedProvider).text),
                    icon: const Icon(Icons.manage_accounts_rounded),
                    label: Text('${_providerLabel(_selectedProvider)} Portal'),
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
                    'Licensing Provider Configuration',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _polarCheckoutController,
                    decoration: const InputDecoration(
                      labelText: 'Polar Checkout URL',
                      hintText: 'https://polar.sh/checkout/...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _polarPortalController,
                    decoration: const InputDecoration(
                      labelText: 'Polar Customer Portal URL',
                      hintText: 'https://polar.sh/portal/...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _lemonCheckoutController,
                    decoration: const InputDecoration(
                      labelText: 'LemonSqueezy Checkout URL',
                      hintText: 'https://lemonsqueezy.com/checkout/...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _lemonPortalController,
                    decoration: const InputDecoration(
                      labelText: 'LemonSqueezy Customer Portal URL',
                      hintText: 'https://app.lemonsqueezy.com/my-orders/...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonal(
                    onPressed: _saveProviderUrls,
                    child: const Text('Save Provider URLs'),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_controller.dart';
import 'pin_dialog.dart';
import 'vault_service.dart';

class VaultSettingsScreen extends ConsumerStatefulWidget {
  const VaultSettingsScreen({super.key});

  @override
  ConsumerState<VaultSettingsScreen> createState() => _VaultSettingsScreenState();
}

class _VaultSettingsScreenState extends ConsumerState<VaultSettingsScreen> {
  bool _hasPin = false;
  bool _isEnabled = false;
  List<String> _lockedDomains = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final vaultService = ref.read(vaultServiceProvider);
    final hasPin = await vaultService.hasPin();
    final isEnabled = await vaultService.isVaultEnabled();
    final lockedDomains = await vaultService.getLockedDomains();

    if (mounted) {
      setState(() {
        _hasPin = hasPin;
        _isEnabled = isEnabled;
        _lockedDomains = lockedDomains;
        _loading = false;
      });
    }
  }

  Future<void> _setOrChangePin() async {
    final vaultService = ref.read(vaultServiceProvider);
    final success = await PinDialog.show(
      context,
      vaultService,
      'Vault Master Security',
      isSettingPin: true,
    );

    if (success) {
      await _loadState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔒 Vault PIN updated successfully!'),
            backgroundColor: NeonPalette.mint,
          ),
        );
      }
    }
  }

  Future<void> _resetVault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Secure Vault?'),
        content: const Text(
          'This will permanently remove your 4-digit master PIN and reset vault security to the default UNLOCKED state.\n\nAll domains will be freely accessible without a PIN.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NeonPalette.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset Vault'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final vaultService = ref.read(vaultServiceProvider);
      await vaultService.resetPin();
      await _loadState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔓 Vault reset: PIN removed and domains unlocked.'),
            backgroundColor: NeonPalette.amber,
          ),
        );
      }
    }
  }

  Future<void> _toggleLock(String domainKey) async {
    final vaultService = ref.read(vaultServiceProvider);
    await vaultService.toggleDomainLock(domainKey);
    await _loadState();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('🔐 Private Vault')),
        body: const Center(child: CircularProgressIndicator(color: NeonPalette.cyan)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔐 Private Vault', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Vault Status Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _hasPin && _isEnabled
                    ? (isDark
                        ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
                        : [Colors.indigo.shade50, Colors.white])
                    : (isDark
                        ? [const Color(0xFF1F2937), const Color(0xFF111827)]
                        : [Colors.grey.shade100, Colors.white]),
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _hasPin && _isEnabled
                    ? NeonPalette.violet.withValues(alpha: 0.4)
                    : (isDark ? NeonPalette.borderDark : Colors.grey.shade300),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (_hasPin && _isEnabled ? NeonPalette.violet : Colors.grey)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _hasPin && _isEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
                            size: 28,
                            color: _hasPin && _isEnabled ? NeonPalette.violet : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _hasPin && _isEnabled ? 'PIN Security Active' : 'Vault Unlocked',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _hasPin ? 'Master PIN is configured' : 'No PIN configured (Default)',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('set-vault-pin-button'),
                        icon: Icon(_hasPin ? Icons.key_rounded : Icons.add_moderator_rounded),
                        label: Text(_hasPin ? 'Change PIN' : 'Set Master PIN'),
                        style: FilledButton.styleFrom(
                          backgroundColor: NeonPalette.violet,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _setOrChangePin,
                      ),
                    ),
                    if (_hasPin) ...[
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        key: const Key('reset-vault-pin-button'),
                        icon: const Icon(Icons.restart_alt_rounded, color: NeonPalette.rose),
                        label: const Text('Reset', style: TextStyle(color: NeonPalette.rose)),
                        onPressed: _resetVault,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Default Behavior Explanation Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: NeonPalette.cyan.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: NeonPalette.cyan, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'What is the Default Vault Setting?',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: NeonPalette.cyan),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'By default, LifeOS leaves all sections completely open and unrestricted with no PIN prompt required. You can opt-in to 4-digit PIN protection at any time and reset it whenever you wish.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Protected Domains Configurator
          if (_hasPin) ...[
            const Text(
              'PROTECTED DOMAINS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            _buildDomainSwitchTile('finance', 'Finance & Wallets', Icons.account_balance_wallet_outlined, NeonPalette.violet, isDark),
            _buildDomainSwitchTile('journal', 'Journal & Reflections', Icons.edit_note_rounded, NeonPalette.amber, isDark),
            _buildDomainSwitchTile('notes', 'Markdown Notes', Icons.description_outlined, const Color(0xFF38BDF8), isDark),
            _buildDomainSwitchTile('wellness', 'Sleep & Energy Logs', Icons.battery_charging_full_rounded, NeonPalette.mint, isDark),
            _buildDomainSwitchTile('review', 'Weekly Reviews', Icons.rate_review_rounded, NeonPalette.cyan, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildDomainSwitchTile(String key, String title, IconData icon, Color color, bool isDark) {
    final isLocked = _lockedDomains.contains(key);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? NeonPalette.surfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? NeonPalette.borderDark : Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: SwitchListTile(
          secondary: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          subtitle: Text(
            isLocked ? 'Requires Master PIN' : 'Unlocked',
            style: TextStyle(fontSize: 11, color: isLocked ? NeonPalette.cyan : Colors.grey),
          ),
          value: isLocked,
          activeTrackColor: NeonPalette.cyan.withValues(alpha: 0.6),
          onChanged: (val) => _toggleLock(key),
        ),
      ),
    );
  }
}

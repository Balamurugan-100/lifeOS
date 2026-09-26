import 'package:flutter/material.dart';
import '../theme/theme_controller.dart';
import 'vault_service.dart';

class PinDialog extends StatefulWidget {
  const PinDialog({
    super.key,
    required this.vaultService,
    required this.domainName,
    this.isSettingPin = false,
  });

  final VaultService vaultService;
  final String domainName;
  final bool isSettingPin;

  static Future<bool> show(BuildContext context, VaultService vaultService, String domainName, {bool isSettingPin = false}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PinDialog(
        vaultService: vaultService,
        domainName: domainName,
        isSettingPin: isSettingPin,
      ),
    );
    return result ?? false;
  }

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  String _pin = '';
  String? _error;

  void _onDigit(String digit) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _error = null;
    });

    if (_pin.length == 4) {
      _submit();
    }
  }

  void _onDelete() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    if (widget.isSettingPin) {
      await widget.vaultService.setPin(_pin);
      if (mounted) Navigator.of(context).pop(true);
      return;
    }

    final isValid = await widget.vaultService.verifyPin(_pin);
    if (isValid) {
      if (mounted) Navigator.of(context).pop(true);
    } else {
      setState(() {
        _pin = '';
        _error = 'Incorrect PIN. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NeonPalette.violet.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded, size: 36, color: NeonPalette.violet),
            ),
            const SizedBox(height: 16),
            Text(
              widget.isSettingPin ? 'Create Master Vault PIN' : 'Enter Vault PIN',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              widget.isSettingPin
                  ? 'Set a 4-digit PIN to protect private logs'
                  : 'Unlock ${widget.domainName}',
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(height: 24),
            // 4 Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled
                        ? NeonPalette.cyan
                        : (isDark ? Colors.white24 : Colors.grey.shade300),
                    boxShadow: isFilled
                        ? [
                            BoxShadow(
                              color: NeonPalette.cyan.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                );
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: NeonPalette.rose, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 24),
            // Numpad
            Column(
              children: [
                _buildNumRow(['1', '2', '3'], isDark),
                _buildNumRow(['4', '5', '6'], isDark),
                _buildNumRow(['7', '8', '9'], isDark),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    _buildNumButton('0', isDark),
                    IconButton(
                      icon: const Icon(Icons.backspace_outlined),
                      onPressed: _onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumRow(List<String> digits, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: digits.map((d) => _buildNumButton(d, isDark)).toList(),
      ),
    );
  }

  Widget _buildNumButton(String digit, bool isDark) {
    return InkWell(
      onTap: () => _onDigit(digit),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final vaultServiceProvider = Provider<VaultService>((ref) {
  return VaultService();
});

class VaultService {
  static const _kPinHash = 'vault.pin_hash';
  static const _kEnabled = 'vault.enabled';
  static const _kLockedDomains = 'vault.locked_domains';

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  Future<bool> isVaultEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? false;
  }

  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPinHash) != null;
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final savedHash = prefs.getString(_kPinHash);
    if (savedHash == null) return false;
    return savedHash == _hashPin(pin);
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPinHash, _hashPin(pin));
    await prefs.setBool(_kEnabled, true);
  }

  Future<void> disableVault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, false);
  }

  Future<bool> isDomainLocked(String domainKey) async {
    final enabled = await isVaultEnabled();
    if (!enabled) return false;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kLockedDomains) ?? ['finance', 'journal', 'notes'];
    return list.contains(domainKey);
  }

  Future<void> toggleDomainLock(String domainKey) async {
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList(_kLockedDomains) ?? ['finance', 'journal', 'notes']).toList();
    if (list.contains(domainKey)) {
      list.remove(domainKey);
    } else {
      list.add(domainKey);
    }
    await prefs.setStringList(_kLockedDomains, list);
  }

  Future<List<String>> getLockedDomains() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kLockedDomains) ?? ['finance', 'journal', 'notes'];
  }
}

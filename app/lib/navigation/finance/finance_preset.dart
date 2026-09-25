import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FinancePreset {
  const FinancePreset({
    required this.id,
    required this.name,
    required this.amount,
    required this.categoryKeyword,
    required this.emoji,
  });

  final String id;
  final String name;
  final double amount;
  final String categoryKeyword;
  final String emoji;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'categoryKeyword': categoryKeyword,
        'emoji': emoji,
      };

  factory FinancePreset.fromJson(Map<String, dynamic> json) => FinancePreset(
        id: json['id'] as String,
        name: json['name'] as String,
        amount: (json['amount'] as num).toDouble(),
        categoryKeyword: json['categoryKeyword'] as String,
        emoji: json['emoji'] as String,
      );

  static const String _prefKey = 'lifeos_finance_custom_presets';

  static final List<FinancePreset> defaultPresets = [
    const FinancePreset(
      id: 'default_chai',
      name: 'Chai',
      amount: 20,
      categoryKeyword: 'Dining',
      emoji: '☕',
    ),
    const FinancePreset(
      id: 'default_lunch',
      name: 'Lunch',
      amount: 150,
      categoryKeyword: 'Dining',
      emoji: '🍛',
    ),
    const FinancePreset(
      id: 'default_fuel',
      name: 'Fuel',
      amount: 200,
      categoryKeyword: 'Transportation',
      emoji: '⛽',
    ),
    const FinancePreset(
      id: 'default_groceries',
      name: 'Groceries',
      amount: 500,
      categoryKeyword: 'Groceries',
      emoji: '🛒',
    ),
    const FinancePreset(
      id: 'default_movies',
      name: 'Movies',
      amount: 300,
      categoryKeyword: 'Entertainment',
      emoji: '🎬',
    ),
  ];

  static Future<List<FinancePreset>> loadPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null) return List.from(defaultPresets);
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => FinancePreset.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return List.from(defaultPresets);
    }
  }

  static Future<void> savePresets(List<FinancePreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = presets.map((p) => p.toJson()).toList();
    await prefs.setString(_prefKey, jsonEncode(jsonList));
  }
}

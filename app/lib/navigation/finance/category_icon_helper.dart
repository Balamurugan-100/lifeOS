import 'package:flutter/material.dart';

/// Helper mapping string icon names to Material IconData and color helpers.
class CategoryIconHelper {
  static IconData getIcon(String? iconName) {
    return switch (iconName) {
      'restaurant' => Icons.restaurant,
      'shopping_cart' => Icons.shopping_cart,
      'home' => Icons.home,
      'bolt' => Icons.bolt,
      'directions_car' => Icons.directions_car,
      'shopping_bag' => Icons.shopping_bag,
      'medical_services' => Icons.medical_services,
      'movie' => Icons.movie,
      'school' => Icons.school,
      'flight' => Icons.flight,
      'subscriptions' => Icons.subscriptions,
      'spa' => Icons.spa,
      'swap_horiz' || 'sync_alt' => Icons.swap_horiz,
      'tune' => Icons.tune,
      'category' => Icons.category,
      'account_balance_wallet' => Icons.account_balance_wallet,
      'work' => Icons.work,
      'trending_up' => Icons.trending_up,
      'card_giftcard' => Icons.card_giftcard,
      'replay' => Icons.replay,
      'monetization_on' => Icons.monetization_on,
      'account_balance' => Icons.account_balance,
      'credit_card' => Icons.credit_card,
      'savings' => Icons.savings,
      'wallet' => Icons.wallet,
      _ => Icons.payments,
    };
  }

  static Color getColor(String? colorHex, {Color defaultColor = const Color(0xFF3D5AFE)}) {
    if (colorHex == null || colorHex.isEmpty) return defaultColor;
    try {
      final hex = colorHex.replaceFirst('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}
    return defaultColor;
  }
}

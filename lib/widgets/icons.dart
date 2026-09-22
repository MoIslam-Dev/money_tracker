import 'package:flutter/material.dart';

/// Resolve an icon slug (category icon) to an [IconData].
IconData iconFor(String name) {
  const map = {
    'restaurant': Icons.restaurant_rounded,
    'local_dining': Icons.local_dining_rounded,
    'shopping_cart': Icons.shopping_cart_rounded,
    'coffee': Icons.coffee_rounded,
    'directions_bus': Icons.directions_bus_rounded,
    'local_gas_station': Icons.local_gas_station_rounded,
    'home': Icons.home_rounded,
    'bolt': Icons.bolt_rounded,
    'water_drop': Icons.water_drop_rounded,
    'propane_tank': Icons.propane_tank_rounded,
    'wifi': Icons.wifi_rounded,
    'phone_android': Icons.phone_android_rounded,
    'medical_services': Icons.medical_services_rounded,
    'checkroom': Icons.checkroom_rounded,
    'shopping_bag': Icons.shopping_bag_rounded,
    'movie': Icons.movie_rounded,
    'school': Icons.school_rounded,
    'devices': Icons.devices_rounded,
    'family_restroom': Icons.family_restroom_rounded,
    'card_giftcard': Icons.card_giftcard_rounded,
    'account_balance': Icons.account_balance_rounded,
    'savings': Icons.savings_rounded,
    'more_horiz': Icons.more_horiz_rounded,
    'payments': Icons.payments_rounded,
    'computer': Icons.computer_rounded,
    'storefront': Icons.storefront_rounded,
    'redeem': Icons.redeem_rounded,
    'currency_exchange': Icons.currency_exchange_rounded,
    'trending_up': Icons.trending_up_rounded,
  };
  return map[name] ?? Icons.category_rounded;
}

/// Luxury-matched palette used for chart slices and category chips.
const chartColors = [
  Color(0xFFC9A227),
  Color(0xFF2E9E6B),
  Color(0xFFC2652F),
  Color(0xFF8B5FA8),
  Color(0xFF2E8B8B),
  Color(0xFFC24A7A),
  Color(0xFF4A6FA5),
  Color(0xFFA88B3E),
  Color(0xFF7A7F8A),
  Color(0xFF6E8B3A),
  Color(0xFFA2688A),
  Color(0xFF3A7DDB),
];
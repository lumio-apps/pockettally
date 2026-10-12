import 'package:flutter/material.dart';

import 'models.dart';

/// Icons a category can have. The key is what is stored in the database,
/// so keys must never change; new icons can be added at the end.
const Map<String, IconData> kCategoryIcons = {
  'food': Icons.restaurant,
  'coffee': Icons.local_cafe_outlined,
  'grocery': Icons.local_grocery_store_outlined,
  'home': Icons.home_outlined,
  'travel': Icons.flight_outlined,
  'bus': Icons.directions_bus_outlined,
  'car': Icons.directions_car_outlined,
  'fuel': Icons.local_gas_station_outlined,
  'shopping': Icons.shopping_bag_outlined,
  'clothes': Icons.checkroom_outlined,
  'bills': Icons.receipt_long_outlined,
  'phone': Icons.smartphone_outlined,
  'internet': Icons.wifi,
  'power': Icons.bolt_outlined,
  'health': Icons.favorite_border,
  'medicine': Icons.medication_outlined,
  'fitness': Icons.fitness_center,
  'fun': Icons.movie_outlined,
  'music': Icons.music_note_outlined,
  'games': Icons.sports_esports_outlined,
  'education': Icons.school_outlined,
  'book': Icons.menu_book_outlined,
  'kids': Icons.child_care_outlined,
  'pets': Icons.pets_outlined,
  'gift': Icons.card_giftcard_outlined,
  'salary': Icons.payments_outlined,
  'business': Icons.work_outline,
  'savings': Icons.savings_outlined,
  'bank': Icons.account_balance_outlined,
  'tips': Icons.volunteer_activism_outlined,
  'repair': Icons.build_outlined,
  'beauty': Icons.spa_outlined,
  'other': Icons.more_horiz,
};

/// Words in a category name that suggest an icon, for categories without
/// a chosen one (also custom names like "Metro card" or "Doodh").
const List<(String, String)> _hints = [
  ('food', 'food'), ('lunch', 'food'), ('dinner', 'food'), ('restaurant', 'food'),
  ('khana', 'food'), ('coffee', 'coffee'), ('tea', 'coffee'), ('chai', 'coffee'),
  ('grocer', 'grocery'), ('milk', 'grocery'), ('doodh', 'grocery'),
  ('rent', 'home'), ('home', 'home'), ('house', 'home'),
  ('travel', 'travel'), ('flight', 'travel'), ('trip', 'travel'),
  ('bus', 'bus'), ('metro', 'bus'), ('train', 'bus'), ('transport', 'bus'),
  ('taxi', 'car'), ('car', 'car'), ('uber', 'car'),
  ('fuel', 'fuel'), ('petrol', 'fuel'), ('gas', 'fuel'),
  ('shop', 'shopping'), ('cloth', 'clothes'),
  ('bill', 'bills'), ('electric', 'power'), ('phone', 'phone'), ('mobile', 'phone'),
  ('internet', 'internet'), ('wifi', 'internet'),
  ('health', 'health'), ('doctor', 'health'), ('medic', 'medicine'),
  ('gym', 'fitness'), ('sport', 'fitness'),
  ('entertain', 'fun'), ('movie', 'fun'), ('music', 'music'), ('game', 'games'),
  ('educat', 'education'), ('school', 'education'), ('book', 'book'),
  ('kid', 'kids'), ('child', 'kids'), ('pet', 'pets'),
  ('gift', 'gift'), ('salary', 'salary'), ('wage', 'salary'),
  ('business', 'business'), ('work', 'business'), ('saving', 'savings'),
  ('bank', 'bank'), ('interest', 'bank'), ('tip', 'tips'),
  ('repair', 'repair'), ('beauty', 'beauty'), ('salon', 'beauty'),
];

/// The icon key for a category: the chosen one, else a guess from the name.
String categoryIconKey(String name, {String? chosen}) {
  if (chosen != null && kCategoryIcons.containsKey(chosen)) return chosen;
  if (name == kOtherCategory) return 'other';
  final n = name.toLowerCase();
  for (final (word, key) in _hints) {
    if (n.contains(word)) return key;
  }
  return 'other';
}

IconData categoryIcon(String name, {String? chosen}) =>
    kCategoryIcons[categoryIconKey(name, chosen: chosen)]!;

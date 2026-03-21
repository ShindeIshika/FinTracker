import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Needed for Firestore

class CategoryService {
  static final ValueNotifier<List<String>> _categories = ValueNotifier([
    'Food & Drinks',
    'Transport',
    'Shopping',
    'Entertainment',
    'Bills & Utilities',
    'Health & Fitness',
    'Others',
  ]);

  static List<String> getAll() => _categories.value;

  // ✅ Sync categories from budgets
  static void syncWithBudgets(String uid) {
  FirebaseFirestore.instance
      .collection('budgets')
      .where('uid', isEqualTo: uid)
      .snapshots()
      .listen((snapshot) {

    final existing = _categories.value.map((e) => e.toLowerCase()).toSet();

    final newCategories = snapshot.docs
        .map((doc) => (doc.data()['category'] as String)
            .trim()
            .toLowerCase())
        .where((cat) => !existing.contains(cat))
        .toList();

    if (newCategories.isNotEmpty) {
      _categories.value = [..._categories.value, ...newCategories];
    }
  });
}

static void removeDuplicates() {
  final unique = _categories.value.toSet().toList();
  _categories.value = unique;
}
  static bool addCategory(String category) {
  category = category.trim().toLowerCase(); // ✅ normalize

  // ✅ prevent duplicates (case-insensitive)
  if (_categories.value.any(
      (c) => c.trim().toLowerCase() == category)) {
    return false;
  }

  _categories.value = [..._categories.value, category];
  return true;
}

  static ValueNotifier<List<String>> get notifier => _categories;
}
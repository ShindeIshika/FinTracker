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
  category = category.trim().toLowerCase(); // Normalize category

  // Prevent duplicates (case-insensitive)
  if (_categories.value.any((c) => c.trim().toLowerCase() == category)) {
    return false; // Category already exists
  }

  _categories.value = [..._categories.value, category];  // Add the new category
  _categories.notifyListeners();  // Notify listeners for UI refresh

  // Log categories to ensure it's added
  print("Category added: $category");
  print("Categories list after adding: ${_categories.value}");

  return true;  // Return true when category is added successfully
}
  static ValueNotifier<List<String>> get notifier => _categories;
}
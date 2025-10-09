import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category.dart';

class CategoryService {
  static final CategoryService _instance = CategoryService._internal();
  factory CategoryService() => _instance;
  CategoryService._internal();

  // Cache for categories to avoid repeated network calls
  List<Category>? _cachedCategories;

  Future<List<Category>> fetchCategories() async {
    // Return cached categories if available
    if (_cachedCategories != null) {
      return _cachedCategories!;
    }

    try {
      final response = await Supabase.instance.client
          .from('categories')
          .select()
          .order('name', ascending: true);

      final List<Category> categories = [];
      for (final item in response) {
        categories.add(Category.fromMap(item));
      }

      // Cache the categories
      _cachedCategories = categories;
      
      return categories;
    } catch (e) {
      print('Error fetching categories: $e');
      // Return empty list on error
      return [];
    }
  }

  Future<Category?> getCategoryById(int id) async {
    final categories = await fetchCategories();
    try {
      return categories.firstWhere((category) => category.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<Category?> getCategoryByName(String name) async {
    final categories = await fetchCategories();
    try {
      return categories.firstWhere((category) => category.name == name);
    } catch (e) {
      return null;
    }
  }

  // Clear cache (useful when categories might have changed)
  void clearCache() {
    _cachedCategories = null;
  }
}
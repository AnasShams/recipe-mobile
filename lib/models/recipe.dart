class Recipe {
  final String id;
  final String title;
  final String ingredients;
  final String steps;
  final String? imageUrl;
  final String category;
  final int? categoryId;
  final String? userId;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isUserRecipe;

  Recipe({
    required this.id,
    required this.title,
    required this.ingredients,
    required this.steps,
    this.imageUrl,
    required this.category,
    this.categoryId,
    this.userId,
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
    required this.isUserRecipe,
  });

  factory Recipe.fromMap(Map<String, dynamic> map, {bool isUserRecipe = false}) {
    return Recipe(
      id: map['id']?.toString() ?? '',
      title: map['title'] ?? '',
      ingredients: _parseIngredients(map['ingredients']),
      steps: _parseSteps(map['steps']),
      imageUrl: map['image_url'],
      category: map['category'] ?? 'Other',
      categoryId: map['category_id'],
      userId: map['user_id'],
      isPublic: map['is_public'] ?? true,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
      isUserRecipe: isUserRecipe,
    );
  }

  static String _parseIngredients(dynamic ingredients) {
    if (ingredients is String) {
      return ingredients;
    } else if (ingredients is List) {
      return ingredients.map((item) => item.toString()).join('\n');
    }
    return '';
  }

  static String _parseSteps(dynamic steps) {
    if (steps is String) {
      return steps;
    } else if (steps is List) {
      return steps.asMap().entries.map((entry) => '${entry.key + 1}. ${entry.value}').join('\n');
    }
    return '';
  }

  Map<String, dynamic> toMap() {
    if (isUserRecipe) {
      return {
        if (id.isNotEmpty) 'id': id,
        'title': title,
        'ingredients': ingredients.split('\n').where((line) => line.trim().isNotEmpty).toList(),
        'steps': steps.split('\n').where((line) => line.trim().isNotEmpty).toList(),
        'image_url': imageUrl,
        'category': category,
        'category_id': categoryId,
        'user_id': userId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
    } else {
      return {
        if (id.isNotEmpty) 'id': id,
        'title': title,
        'ingredients': ingredients,
        'steps': steps,
        'image_url': imageUrl,
        'category': category,
        'category_id': categoryId,
        'is_public': isPublic,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
    }
  }

  Recipe copyWith({
    String? id,
    String? title,
    String? ingredients,
    String? steps,
    String? imageUrl,
    String? category,
    int? categoryId,
    String? userId,
    bool? isPublic,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isUserRecipe,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      userId: userId ?? this.userId,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isUserRecipe: isUserRecipe ?? this.isUserRecipe,
    );
  }

  @override
  String toString() {
    return 'Recipe(id: $id, title: $title, category: $category, categoryId: $categoryId, isUserRecipe: $isUserRecipe)';
  }
}
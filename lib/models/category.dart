class Category {
  final String name;
  final String? id;

  const Category({required this.name, this.id});

  static const List<Category> predefinedCategories = [
    Category(name: 'Main Course'),
    Category(name: 'Appetizer'),
    Category(name: 'Dessert'),
    Category(name: 'Breakfast'),
    Category(name: 'Lunch'),
    Category(name: 'Dinner'),
    Category(name: 'Snack'),
    Category(name: 'Soup'),
    Category(name: 'Salad'),
    Category(name: 'Beverage'),
    Category(name: 'Baked Goods'),
    Category(name: 'Vegetarian'),
    Category(name: 'Vegan'),
    Category(name: 'Seafood'),
    Category(name: 'Other'),
  ];
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_edit_recipe_page.dart';

class MyRecipesPage extends StatefulWidget {
  @override
  _MyRecipesPageState createState() => _MyRecipesPageState();
}

class _MyRecipesPageState extends State<MyRecipesPage> {
  late Future<List<Map<String, dynamic>>> _recipesFuture;

  @override
  void initState() {
    super.initState();
    _recipesFuture = fetchRecipes();
  }

  Future<List<Map<String, dynamic>>> fetchRecipes() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return [];

      final response = await Supabase.instance.client
          .from('recipes')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching recipes: $e');
      return [];
    }
  }

  void _navigateToAddRecipe() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditRecipePage(),
      ),
    );

    if (result == true && mounted) {
      setState(() {
        _recipesFuture = fetchRecipes();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Recipes'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: _navigateToAddRecipe,
              icon: Icon(Icons.add),
              label: Text('Add Recipe'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _recipesFuture = fetchRecipes();
          });
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _recipesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error loading recipes'),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _recipesFuture = fetchRecipes();
                        });
                      },
                      child: Text('Try Again'),
                    ),
                  ],
                ),
              );
            }

            final recipes = snapshot.data ?? [];

            if (recipes.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No recipes yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _navigateToAddRecipe,
                      icon: Icon(Icons.add),
                      label: Text('Add Your First Recipe'),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: recipes.length,
              padding: EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final recipe = recipes[index];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: InkWell(
                    onTap: () async {
                      final result = await Navigator.pushNamed(
                        context,
                        '/recipe_detail',
                        arguments: recipe,
                      );
                      // Refresh the list if the recipe was edited or deleted
                      if (mounted && (result == true || result == 'deleted')) {
                        setState(() {
                          _recipesFuture = fetchRecipes();
                        });
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (recipe['image_url'] != null)
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                              image: DecorationImage(
                                image: NetworkImage(recipe['image_url']),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ListTile(
                          title: Text(
                            recipe['title'] ?? 'Untitled Recipe',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (recipe['category'] != null) ...[
                                SizedBox(height: 4),
                                Chip(
                                  label: Text(recipe['category']),
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer,
                                ),
                              ],
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    recipe['is_public'] == true
                                        ? Icons.public
                                        : Icons.lock,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    recipe['is_public'] == true
                                        ? 'Public'
                                        : 'Private',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

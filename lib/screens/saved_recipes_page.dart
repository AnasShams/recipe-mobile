import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recipe.dart';

class SavedRecipesPage extends StatefulWidget {
  @override
  _SavedRecipesPageState createState() => _SavedRecipesPageState();
}

class _SavedRecipesPageState extends State<SavedRecipesPage> {
  late Future<List<Map<String, dynamic>>> _savedRecipesFuture;

  @override
  void initState() {
    super.initState();
    _savedRecipesFuture = _fetchSavedRecipes();
  }

  Future<List<Map<String, dynamic>>> _fetchSavedRecipes() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return [];

      final response = await Supabase.instance.client
          .from('saved_recipes')
          .select('''
            *,
            recipe:recipes(*),
            user_recipe:user_recipes(*)
          ''')
          .eq('user_id', user.id);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching saved recipes: $e');
      return [];
    }
  }

  Recipe _parseSavedRecipe(Map<String, dynamic> savedRecipe) {
    // Check if it's from recipes table (pre-loaded) or user_recipes table (user-created)
    final recipeData = savedRecipe['recipe'] ?? savedRecipe['user_recipe'];
    
    if (recipeData == null) {
      throw Exception('No recipe data found in saved recipe');
    }

    final isUserRecipe = savedRecipe['user_recipe'] != null;
    
    return Recipe.fromMap(recipeData, isUserRecipe: isUserRecipe);
  }

  Future<void> _unsaveRecipe(String savedRecipeId) async {
    try {
      await Supabase.instance.client
          .from('saved_recipes')
          .delete()
          .eq('id', savedRecipeId);
      
      setState(() {
        _savedRecipesFuture = _fetchSavedRecipes();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe removed from saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing recipe: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Recipes'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _savedRecipesFuture = _fetchSavedRecipes();
          });
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _savedRecipesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Error loading saved recipes'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _savedRecipesFuture = _fetchSavedRecipes();
                        });
                      },
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              );
            }

            final savedRecipes = snapshot.data ?? [];

            if (savedRecipes.isEmpty) {
              return ListView(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                        Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'No saved recipes yet',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Save recipes to access them quickly',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              itemCount: savedRecipes.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final savedRecipe = savedRecipes[index];
                
                try {
                  final recipe = _parseSavedRecipe(savedRecipe);
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: InkWell(
                      onTap: () async {
                        final result = await Navigator.pushNamed(
                          context,
                          '/recipe_detail',
                          arguments: recipe,
                        );
                        if (result != null) {
                          setState(() {
                            _savedRecipesFuture = _fetchSavedRecipes();
                          });
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (recipe.imageUrl != null)
                            Container(
                              height: 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                                image: DecorationImage(
                                  image: NetworkImage(recipe.imageUrl!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        recipe.title,
                                        style: Theme.of(context).textTheme.titleLarge,
                                      ),
                                    ),
                                    if (recipe.isUserRecipe)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'User Recipe',
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: Colors.blue[700],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (recipe.category.isNotEmpty)
                                  Chip(
                                    label: Text(recipe.category),
                                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      recipe.isUserRecipe ? 'User Created' : 'Pre-loaded Recipe',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.bookmark_remove, color: Colors.red),
                                      onPressed: () => _unsaveRecipe(savedRecipe['id'].toString()),
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
                } catch (e) {
                  print('Error parsing saved recipe: $e');
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: ListTile(
                      leading: const Icon(Icons.error, color: Colors.red),
                      title: const Text('Error loading recipe'),
                      subtitle: Text('ID: ${savedRecipe['id']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.bookmark_remove, color: Colors.red),
                        onPressed: () => _unsaveRecipe(savedRecipe['id'].toString()),
                      ),
                    ),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recipe.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Recipe>> _recipesFuture;

  @override
  void initState() {
    super.initState();
    _recipesFuture = _fetchPublicRecipes();
  }

  Future<List<Recipe>> _fetchPublicRecipes() async {
    try {
      // Fetch pre-loaded public recipes
      final preloadedRecipesResponse = await Supabase.instance.client
          .from('recipes')
          .select()
          .eq('is_public', true)
          .order('created_at', ascending: false);

      // Fetch user-created public recipes
      final userRecipesResponse = await Supabase.instance.client
          .from('user_recipes')
          .select()
          .order('created_at', ascending: false);

      final List<Recipe> allRecipes = [];

      // Add pre-loaded recipes
      for (final item in preloadedRecipesResponse) {
        allRecipes.add(Recipe.fromMap(item, isUserRecipe: false));
      }

      // Add user recipes
      for (final item in userRecipesResponse) {
        allRecipes.add(Recipe.fromMap(item, isUserRecipe: true));
      }

      // Sort by creation date (newest first)
      allRecipes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return allRecipes;
    } catch (error) {
      print('Error fetching recipes: $error');
      return [];
    }
  }

  Future<void> _refreshRecipes() async {
    setState(() {
      _recipesFuture = _fetchPublicRecipes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Recipes'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshRecipes,
        child: FutureBuilder<List<Recipe>>(
          future: _recipesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Error loading recipes'),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _refreshRecipes,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final recipes = snapshot.data ?? [];

            if (recipes.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.restaurant, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'No recipes available',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pull down to refresh',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              itemCount: recipes.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final recipe = recipes[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: InkWell(
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/recipe_detail',
                      arguments: recipe,
                    ).then((_) => _refreshRecipes()),
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
                              if (recipe.category.isNotEmpty) ...[
                                Chip(
                                  label: Text(recipe.category),
                                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                ),
                                const SizedBox(height: 8),
                              ],
                              Text(
                                recipe.isUserRecipe ? 'User Created' : 'Pre-loaded Recipe',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
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
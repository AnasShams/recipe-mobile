import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
          .select('*, recipe:recipes(*)')
          .eq('user_id', user.id);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching saved recipes: $e');
      return [];
    }
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
          SnackBar(content: Text('Recipe removed from saved')),
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
        title: Text('Saved Recipes'),
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
              return Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error loading saved recipes'),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _savedRecipesFuture = _fetchSavedRecipes();
                        });
                      },
                      child: Text('Try Again'),
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
                        SizedBox(height: 16),
                        Text(
                          'No saved recipes yet',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SizedBox(height: 8),
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
              padding: EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final savedRecipe = savedRecipes[index];
                final recipe = savedRecipe['recipe'] as Map<String, dynamic>;
                
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
                              if (recipe['category'] != null)
                                Chip(
                                  label: Text(recipe['category']),
                                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.bookmark_remove),
                            onPressed: () => _unsaveRecipe(savedRecipe['id'].toString()),
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

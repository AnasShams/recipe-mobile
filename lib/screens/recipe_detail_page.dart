import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recipe.dart';

class RecipeDetailPage extends StatefulWidget {
  @override
  _RecipeDetailPageState createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  bool _isDeleting = false;
  bool _isSaving = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _checkIfSaved();
  }

  Future<void> _checkIfSaved() async {
    final recipe = ModalRoute.of(context)!.settings.arguments as Recipe;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('saved_recipes')
          .select()
          .eq('recipe_id', recipe.id)
          .eq('user_id', user.id)
          .limit(1);
      
      if (mounted) {
        setState(() {
          _isSaved = response.isNotEmpty;
        });
      }
    } catch (e) {
      print('Error checking saved status: $e');
    }
  }

  Future<void> _toggleSave(Recipe recipe) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to save recipes')),
        );
        return;
      }

      if (_isSaved) {
        // Unsave the recipe
        await Supabase.instance.client
            .from('saved_recipes')
            .delete()
            .eq('recipe_id', recipe.id)
            .eq('user_id', user.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recipe removed from saved')),
          );
        }
      } else {
        // Save the recipe
        await Supabase.instance.client
            .from('saved_recipes')
            .insert({
              'recipe_id': recipe.id,
              'user_id': user.id,
              'saved_at': DateTime.now().toIso8601String(),
            });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recipe saved successfully')),
          );
        }
      }

      if (mounted) {
        setState(() {
          _isSaved = !_isSaved;
        });
      }
    } catch (e) {
      print('Error toggling save: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving recipe: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteRecipe(BuildContext context, Recipe recipe) async {
    if (_isDeleting) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      // First delete any saved recipes references
      await Supabase.instance.client
          .from('saved_recipes')
          .delete()
          .eq('recipe_id', recipe.id);
      
      // Then delete the recipe itself
      await Supabase.instance.client
          .from('recipes')
          .delete()
          .eq('id', recipe.id);
      
      if (mounted) {
        Navigator.of(context).pop('deleted');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe deleted successfully')),
        );
      }
    } catch (e) {
      print('Error deleting recipe: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting recipe: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = ModalRoute.of(context)!.settings.arguments as Recipe;
    final currentUser = Supabase.instance.client.auth.currentUser;
    final isOwner = currentUser?.id == recipe.userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Details'),
        actions: [
          if (!isOwner) 
            IconButton(
              icon: _isSaving
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      _isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: _isSaved ? Theme.of(context).colorScheme.primary : null,
                    ),
              tooltip: _isSaved ? 'Unsave Recipe' : 'Save Recipe',
              onPressed: _isSaving ? null : () => _toggleSave(recipe),
            ),
          if (isOwner) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Recipe',
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/edit_recipe',
                  arguments: recipe,
                ).then((edited) {
                  if (edited == true) {
                    Navigator.pop(context, true);
                  }
                });
              },
            ),
            IconButton(
              icon: _isDeleting 
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.delete),
              tooltip: 'Delete Recipe',
              onPressed: _isDeleting
                  ? null
                  : () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Recipe'),
                          content: const Text('Are you sure you want to delete this recipe?'),
                          actions: [
                            TextButton(
                              child: const Text('Cancel'),
                              onPressed: () => Navigator.pop(context),
                            ),
                            TextButton(
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                _deleteRecipe(context, recipe);
                              },
                            ),
                          ],
                        ),
                      );
                    },
            ),
          ],
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy Recipe',
            onPressed: () {
              final textToCopy = '''
${recipe.title}

Category: ${recipe.category}

Ingredients:
${recipe.ingredients}

Steps:
${recipe.steps}
''';
              Clipboard.setData(ClipboardData(text: textToCopy));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Recipe copied to clipboard')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recipe.imageUrl != null)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(recipe.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SelectableText(
              recipe.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            if (recipe.category.isNotEmpty)
              Chip(
                label: Text(recipe.category),
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              ),
            const SizedBox(height: 16),
            Text(
              'Ingredients',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              recipe.ingredients,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Text(
              'Steps',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              recipe.steps,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}